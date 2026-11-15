// 첫 실행 부모님 카메라 안내 (2026-11-15, 사용자 결정, docs/MASTER_PROMPT.md 눈 보호)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/screens/camera_notice_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/zodiac_picker_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/backup_code.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l10n_screens.dart';

/// 카메라 창을 연 횟수만 세는 가짜 카메라. [deny]면 권한 거부처럼 [EyeSensorDenied]를 던진다.
class _Camera implements EyeSensor {
  bool deny = false;
  int samples = 0, stops = 0;

  @override
  bool keepCamera = true;

  @override
  String get mode => '';

  @override
  bool get supported => true;

  @override
  EyeDetectStats? get detectStats => null;

  @override
  double defaultDistanceCm(double size) => 1 / size;

  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async {
    samples++;
    if (deny) throw const EyeSensorDenied('카메라 사용을 허용해 주세요');
    return null;
  }

  @override
  Future<void> stop() async => stops++;
}

Future<void> _size(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _wait(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// 화면을 내리고 눈 지킴이가 카메라를 끌 때까지(1초 지연) 기다린다
Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await _wait(t, 1500);
}

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is PillButton && w.semanticLabel == label);

void main() {
  group('첫 실행', () {
    Future<(GameState, _Camera, MemoryStorage)> app(WidgetTester t) async {
      await _size(t, const Size(844, 390));
      final cam = _Camera();
      final storage = MemoryStorage();
      final s = GameState(
        storage: storage,
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: cam),
      );
      await s.load();
      await t.pumpWidget(AlokdalokApp(state: s));
      await _wait(t);
      return (s, cam, storage);
    }

    testWidgets('친구 고르기보다 먼저 안내가 뜨고, 그동안 카메라를 열지 않는다', (t) async {
      final (s, cam, _) = await app(t);
      expect(s.cameraNoticeNeeded, isTrue);
      expect(find.byType(CameraNoticeScreen), findsOneWidget);
      expect(find.byType(ZodiacPickerScreen), findsNothing);
      expect(find.text('부모님께 알려 드려요'), findsOneWidget);
      expect(_button('허용하고 시작'), findsOneWidget);
      expect(_button('나중에'), findsOneWidget);
      // 기본 켜짐은 그대로지만, 안내가 끝나기 전에는 카메라가 꺼져 있다
      expect(s.eyeGuardOn, isTrue);
      await _wait(t, 3000);
      expect(cam.samples, 0);
      expect(s.eye.enabled, isFalse);
      expect(s.eye.running, isFalse);
      // 안내는 글자로만 (부모님용): 목소리를 내지 않는다
      expect((s.audio as RecordingAudio).spoken, isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('[허용하고 시작]을 누른 뒤에야 권한을 묻고, 허용되면 친구 고르기로', (t) async {
      final (s, cam, storage) = await app(t);
      expect(cam.samples, 0);
      await t.tap(_button('허용하고 시작'));
      await _wait(t);
      expect(cam.samples, greaterThan(0)); // 이때 처음 카메라(권한 창)를 연다
      expect(find.byType(CameraNoticeScreen), findsNothing);
      expect(find.byType(ZodiacPickerScreen), findsOneWidget);
      expect(s.eyeGuardOn, isTrue);
      expect(s.eye.enabled, isTrue);
      expect(s.eye.running, isTrue); // 친구 고르기(아이 화면)에서 눈 지킴이가 돈다
      expect(s.cameraPermission, 'granted');
      final saved = SaveData.decode(storage.raw);
      expect(saved.cameraNoticeSeen, isTrue);
      expect(saved.cameraPermission, 'granted');
      expect(t.takeException(), isNull);
      await _close(t);
    });

    testWidgets('[나중에]: 눈 지킴이만 꺼지고, 설정에서 켤 수 있다고 알린 뒤 앱은 그대로', (t) async {
      final (s, cam, storage) = await app(t);
      await t.tap(_button('나중에'));
      await _wait(t);
      expect(find.textContaining('설정에서 언제든 다시 켤 수 있어요'), findsOneWidget);
      expect(find.byType(ZodiacPickerScreen), findsNothing);
      await t.tap(_button('확인'));
      await _wait(t);
      expect(find.byType(ZodiacPickerScreen), findsOneWidget);
      expect(cam.samples, 0); // 권한을 묻지 않았다
      expect(s.eyeGuardOn, isFalse);
      expect(s.eye.enabled, isFalse);
      expect(s.cameraPermission, 'later');
      // 다시 강요하지 않는다: 다시 열어도 안내가 없다
      final again = GameState(
        storage: storage,
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: cam),
      );
      await again.load();
      expect(again.cameraNoticeNeeded, isFalse);
      expect(again.eye.enabled, isFalse);
      // 앱은 정상: 첫 실행 흐름을 마치고 홈으로
      await s.skipNickname();
      await _wait(t);
      expect(find.text('놀이터 가기'), findsOneWidget);
      await _wait(t, 3000);
      expect(cam.samples, 0);
      expect(t.takeException(), isNull);
    });

    testWidgets('권한을 거절하면 눈 지킴이만 꺼지고 앱은 그대로', (t) async {
      final (s, cam, _) = await app(t);
      cam.deny = true;
      await t.tap(_button('허용하고 시작'));
      await _wait(t);
      expect(cam.samples, 1);
      expect(find.textContaining('눈 지킴이를 꺼 두었어요'), findsOneWidget);
      await t.tap(_button('확인'));
      await _wait(t);
      expect(find.byType(ZodiacPickerScreen), findsOneWidget);
      expect(s.eyeGuardOn, isFalse);
      expect(s.eye.enabled, isFalse);
      expect(s.cameraPermission, 'denied');
      await s.skipNickname();
      await _wait(t, 3000);
      expect(find.text('놀이터 가기'), findsOneWidget);
      expect(cam.samples, 1); // 다시 열지 않는다
      expect(t.takeException(), isNull);
    });

    testWidgets('이미 쓰던 사람(v8 저장값)은 안내 없이 그대로', (t) async {
      await _size(t, const Size(844, 390));
      final cam = _Camera();
      final storage = MemoryStorage()
        ..raw = jsonEncode({
          'version': 8,
          'nickname': '별이',
          'nicknameChosen': true,
          'eyeGuardOn': true,
        });
      final s = GameState(
        storage: storage,
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: cam),
      );
      await s.load();
      expect(s.cameraNoticeNeeded, isFalse);
      expect(s.eye.enabled, isTrue);
      await t.pumpWidget(AlokdalokApp(state: s));
      await _wait(t);
      expect(find.byType(CameraNoticeScreen), findsNothing);
      expect(find.text('놀이터 가기'), findsOneWidget);
      expect(cam.samples, greaterThan(0));
      await _close(t);
    });

    test('눈 지킴이를 쓸 수 없는 기기에서는 안내를 띄우지 않는다', () async {
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      expect(s.eye.supported, isFalse); // 테스트(데스크톱)에는 카메라가 없다
      expect(s.cameraNoticeNeeded, isFalse);
    });
  });

  group('설정에서 다시 켜기', () {
    Future<(GameState, _Camera)> settings(WidgetTester t, String answer) async {
      await _size(t, const Size(1280, 800));
      final cam = _Camera();
      final s = GameState(
        storage: MemoryStorage(),
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: cam),
      );
      await s.load();
      await s.setNickname('별이');
      await s.answerCameraNotice(answer);
      await t.pumpWidget(
        AppScope(
          state: s,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await _wait(t);
      return (s, cam);
    }

    for (final answer in ['later', 'denied']) {
      testWidgets('$answer 뒤 켜면 안내가 다시 나오고, 허용해야 켜진다', (t) async {
        final (s, cam) = await settings(t, answer);
        expect(s.eyeGuardOn, isFalse);
        await t.tap(find.text('눈 지킴이'));
        await _wait(t);
        expect(find.byType(CameraNoticeScreen), findsOneWidget);
        expect(_button('허용하고 켜기'), findsOneWidget);
        expect(s.eyeGuardOn, isFalse);
        expect(cam.samples, 0);
        await t.tap(_button('허용하고 켜기'));
        await _wait(t);
        expect(cam.samples, 1);
        expect(find.byType(CameraNoticeScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(s.eyeGuardOn, isTrue);
        expect(s.cameraPermission, 'granted');
        // 설정(부모님 화면)에서는 카메라를 계속 켜 두지 않는다
        expect(s.eye.running, isFalse);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('설정에서 다시 [나중에]면 꺼진 채로 설정에 돌아온다', (t) async {
      final (s, cam) = await settings(t, 'later');
      await t.tap(find.text('눈 지킴이'));
      await _wait(t);
      await t.tap(_button('나중에'));
      await _wait(t);
      expect(find.byType(CameraNoticeScreen), findsNothing);
      expect(s.eyeGuardOn, isFalse);
      expect(cam.samples, 0);
    });

    testWidgets('허용한 적이 있으면 끄고 켤 때 안내 없이 바로', (t) async {
      final (s, cam) = await settings(t, 'granted');
      await t.tap(find.text('눈 지킴이'));
      await _wait(t);
      expect(s.eyeGuardOn, isFalse);
      await t.tap(find.text('눈 지킴이'));
      await _wait(t);
      expect(find.byType(CameraNoticeScreen), findsNothing);
      expect(s.eyeGuardOn, isTrue);
    });
  });

  group('저장 v9', () {
    test('새로 설치: 안내 전, 권한 모름, 눈 지킴이 기본 켜짐', () {
      final d = SaveData.decode(null);
      expect(SaveData.currentVersion, 9);
      expect(d.cameraNoticeSeen, isFalse);
      expect(d.cameraPermission, 'unknown');
      expect(d.eyeGuardOn, isTrue);
    });

    test('v8 → v9: 안내를 본 것으로 두고(이미 권한 창을 봤다), 다른 값은 그대로', () {
      final json = SaveData.migrate({
        'version': 8,
        'nickname': '보리',
        'coins': 42,
        'eyeGuardOn': false,
        'language': 'en',
      });
      expect(json['version'], 9);
      expect(json['cameraNoticeSeen'], isTrue);
      expect(json['cameraPermission'], 'unknown');
      final d = SaveData.fromJson(json);
      expect(d.cameraNoticeSeen, isTrue);
      expect(d.cameraPermission, 'unknown');
      expect(d.eyeGuardOn, isFalse);
      expect(d.coins, 42);
      expect(d.language, 'en');
    });

    test('아주 예전 저장값(v1)도 v9까지 오면 안내를 다시 띄우지 않는다', () {
      final d = SaveData.decode(jsonEncode({'version': 1}));
      expect(d.cameraNoticeSeen, isTrue);
      expect(d.eyeGuardOn, isTrue);
    });

    test('저장하고 다시 읽으면 그대로, 이상한 값은 기본값', () {
      final d = SaveData.initial()
        ..cameraNoticeSeen = true
        ..cameraPermission = 'denied';
      final back = SaveData.decode(d.encode());
      expect(back.cameraNoticeSeen, isTrue);
      expect(back.cameraPermission, 'denied');
      final bad = d.toJson()
        ..['cameraPermission'] = 'yes'
        ..['cameraNoticeSeen'] = 'true';
      final fixed = SaveData.decode(jsonEncode(bad));
      expect(fixed.cameraPermission, 'unknown');
      expect(fixed.cameraNoticeSeen, isFalse);
    });

    test('백업 글자에는 넣지 않고, 복구해도 이 기기의 안내·권한·눈 지킴이를 쓴다', () async {
      final other = SaveData.initial()
        ..nicknameChosen = true
        ..cameraNoticeSeen = true
        ..cameraPermission = 'granted'
        ..eyeGuardOn = true;
      final code = BackupCode.encode(other);
      final body = code.substring(6, code.lastIndexOf('-'));
      final json = utf8.decode(base64Url.decode(base64Url.normalize(body)));
      expect(json, isNot(contains('cameraNoticeSeen')));
      expect(json, isNot(contains('cameraPermission')));

      final s = GameState(
        storage: MemoryStorage(),
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: _Camera()),
      );
      await s.load();
      await s.answerCameraNotice('later');
      expect(await s.restoreBackup(code), isNull);
      expect(s.nicknameChosen, isTrue);
      expect(s.cameraNoticeNeeded, isFalse);
      expect(s.cameraPermission, 'later');
      expect(s.eyeGuardOn, isFalse); // 안내 없이 권한 창이 뜨지 않게
      expect(s.eye.enabled, isFalse);
    });
  });

  group('화면 크기와 글자', () {
    for (final code in ['ko', 'en']) {
      for (final size in l10nSizes) {
        final name = '$code ${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('안내 화면 세 단계가 넘치지 않는다 ($name)', (t) async {
          await _size(t, size);
          final cam = _Camera()..deny = true;
          final s = GameState(
            storage: MemoryStorage(),
            audio: RecordingAudio(),
            eyeGuard: EyeGuard(sensor: cam),
          );
          await s.load();
          final l = lookupAppLocalizations(Locale(code));
          Future<void> check(Widget home) async {
            await t.pumpWidget(l10nApp(s, home, code));
            await _wait(t, 400);
            expect(t.takeException(), isNull);
            // 버튼은 60px 넘게
            for (final b in t.widgetList<PillButton>(find.byType(PillButton))) {
              expect(b.height, greaterThanOrEqualTo(60));
            }
          }

          await check(CameraNoticeScreen(onDone: (_) {}));
          await t.tap(_button(l.cameraNotice_later));
          await _wait(t, 400);
          expect(find.text(l.cameraNotice_laterDone), findsOneWidget);
          expect(t.takeException(), isNull);

          await check(CameraNoticeScreen(key: UniqueKey(), onDone: (_) {}));
          await t.tap(_button(l.cameraNotice_allow));
          await _wait(t, 400);
          expect(find.text(l.cameraNotice_deniedDone), findsOneWidget);
          expect(t.takeException(), isNull);

          await check(
            CameraNoticeScreen(
              key: UniqueKey(),
              fromSettings: true,
              onDone: (_) {},
            ),
          );
          expect(_button(l.cameraNotice_allowSettings), findsOneWidget);
        });
      }
    }

    test('안내 문구는 Jua 글꼴에 있는 글자만 쓴다 (· → × 같은 글자 없음)', () {
      final glyphs = _juaCodePoints();
      for (final code in ['ko', 'en']) {
        final arb = jsonDecode(
          File('lib/l10n/app_$code.arb').readAsStringSync(),
        ) as Map<String, Object?>;
        for (final e in arb.entries) {
          if (!e.key.startsWith('cameraNotice_')) continue;
          final missing = (e.value as String).runes
              .where((r) => !glyphs.contains(r))
              .map(String.fromCharCode)
              .toSet();
          expect(missing, isEmpty, reason: '$code ${e.key}');
        }
      }
    });
  });
}

/// Jua 글꼴의 cmap(형식 4·12)에 있는 글자 번호
Set<int> _juaCodePoints() {
  final d = ByteData.sublistView(
    File('assets/fonts/Jua-Regular.ttf').readAsBytesSync(),
  );
  final tables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes([
      for (var k = 0; k < 4; k++) d.getUint8(rec + k),
    ]);
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  final out = <int>{};
  final subtables = d.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final o = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    switch (d.getUint16(o)) {
      case 4:
        final segs = d.getUint16(o + 6) ~/ 2;
        for (var s = 0; s < segs; s++) {
          final end = d.getUint16(o + 14 + 2 * s);
          final start = d.getUint16(o + 16 + 2 * segs + 2 * s);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            out.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(o + 12);
        for (var g = 0; g < groups; g++) {
          final start = d.getUint32(o + 16 + 12 * g);
          final end = d.getUint32(o + 20 + 12 * g);
          for (var c = start; c <= end; c++) {
            out.add(c);
          }
        }
    }
  }
  return out;
}
