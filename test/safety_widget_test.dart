import 'package:alokdalok/app.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/backup_code.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/play_clock.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:alokdalok/widgets/play_guard_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const sizes = [Size(568, 320), Size(844, 390), Size(1280, 800)];

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

class Rig {
  Rig() {
    state = GameState(storage: MemoryStorage(), audio: audio, now: () => now);
  }
  final audio = RecordingAudio();
  late final GameState state;
  DateTime now = DateTime(2026, 10, 21, 9);
}

Future<Rig> rig({int limit = 10, int brk = 10}) async {
  final r = Rig();
  final s = r.state;
  await s.load();
  await s.setNickname('별이');
  await s.setPlayLimit(limit);
  await s.setEyeBreak(brk);
  return r;
}

/// 앱의 1초 타이머가 돌도록 시간을 흘린다 (가짜 시계도 같이)
Future<void> play(WidgetTester t, Rig r, Duration d) async {
  const step = Duration(seconds: 5);
  var left = d;
  while (left > Duration.zero) {
    r.now = r.now.add(step);
    await t.pump(step);
    left -= step;
  }
}

/// 부모 확인 판에 보이는 문제를 풀어 답을 누른다
Future<void> solveGate(WidgetTester t, {bool wrong = false}) async {
  final q = t.widget<Text>(find.byKey(ParentalGate.questionKey)).data!;
  var answer = ParentalGate.answerOf(q);
  if (wrong) answer = answer == 18 ? 12 : answer + 1;
  for (final d in '$answer'.split('')) {
    await t.tap(pressable('숫자 $d'));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('부모 확인', () {
    Future<Future<bool>> open(WidgetTester t, GameState s) async {
      late BuildContext ctx;
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      final f = confirmParent(ctx);
      await t.pump(const Duration(milliseconds: 300));
      return f;
    }

    testWidgets('덧셈 답을 숫자 패드로 누르면 통과', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig();
      final f = await open(t, r.state);
      expect(find.byType(ParentalGate), findsOneWidget);
      expect(r.audio.spoken.last, '부모님을 불러 주세요.');
      await solveGate(t);
      expect(await f, isTrue);
      expect(find.byType(ParentalGate), findsNothing);
    });

    testWidgets('틀리면 새 문제를 내고 닫히지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig();
      var done = false;
      final f = (await open(t, r.state))..then((_) => done = true);
      await solveGate(t, wrong: true);
      expect(done, isFalse);
      expect(find.byType(ParentalGate), findsOneWidget);
      expect(find.text('답이 달라요. 새 문제를 풀어 주세요.'), findsOneWidget);
      await solveGate(t);
      expect(await f, isTrue);
    });

    testWidgets('지우기로 고쳐 쓰고 확인을 누를 수 있다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig();
      final f = await open(t, r.state);
      final q = t.widget<Text>(find.byKey(ParentalGate.questionKey)).data!;
      final answer = '${ParentalGate.answerOf(q)}';
      await t.tap(pressable('숫자 ${answer[0]}'));
      await t.pump();
      await t.tap(pressable('지우기'));
      await t.pump();
      await t.tap(pressable('숫자 ${answer[0]}'));
      await t.pump();
      await t.tap(pressable('숫자 ${answer[1]}'));
      await t.pump(const Duration(milliseconds: 300));
      expect(await f, isTrue);
    });

    testWidgets('닫기를 누르면 false', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig();
      final f = await open(t, r.state);
      await t.tap(pressable('닫기'));
      await t.pump(const Duration(milliseconds: 300));
      expect(await f, isFalse);
      expect(find.byType(ParentalGate), findsNothing);
    });

    testWidgets('설정에서 부모 확인을 끄면 문제 없이 바로 true', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig();
      await r.state.setParentGate(false);
      final f = await open(t, r.state);
      expect(find.byType(ParentalGate), findsNothing);
      expect(await f, isTrue);
    });

    for (final size in sizes) {
      testWidgets('숫자 패드가 ${size.width.toInt()}x${size.height.toInt()}에서 '
          '넘치지 않고 칸이 60px 이상', (t) async {
        await setSize(t, size);
        final r = await rig();
        await open(t, r.state);
        expect(t.takeException(), isNull);
        for (var d = 0; d <= 9; d++) {
          final box = t.getSize(pressable('숫자 $d'));
          expect(box.height, greaterThanOrEqualTo(60), reason: '숫자 $d');
          expect(box.width, greaterThanOrEqualTo(60), reason: '숫자 $d');
        }
        await t.tap(pressable('닫기'));
        await t.pump(const Duration(milliseconds: 300));
      });
    }
  });

  group('놀이 시간 덮개', () {
    testWidgets('하루 시간이 다 되면 "오늘은 여기까지!", 부모 확인 후 15분 더', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig(limit: 10, brk: 20);
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 9, seconds: 50));
      expect(find.text('오늘은 여기까지!'), findsNothing);
      await play(t, r, const Duration(seconds: 15));
      expect(find.text('오늘은 여기까지!'), findsOneWidget);
      expect(r.audio.spoken, contains('오늘은 여기까지! 내일 또 만나요.'));
      expect(t.takeException(), isNull);
      await play(t, r, const Duration(seconds: 30)); // 부모님을 부르러 간 사이

      // 부모 확인을 닫으면 다시 덮개로
      await t.tap(pressable('부모님: 15분 더'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(ParentalGate), findsOneWidget);
      await t.tap(pressable('닫기'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('오늘은 여기까지!'), findsOneWidget);

      await t.tap(pressable('부모님: 15분 더'));
      await t.pump(const Duration(milliseconds: 300));
      await solveGate(t);
      expect(find.text('오늘은 여기까지!'), findsNothing);
      expect(find.byType(ParentalGate), findsNothing);
      expect(r.state.play.bonusMinutes, 15);
      expect(r.audio.spoken.last, '15분 더 놀 수 있어요.');

      await play(t, r, const Duration(minutes: 15));
      expect(find.text('오늘은 여기까지!'), findsOneWidget);

      // 다음 날 아침이면 저절로 풀린다
      r.now = DateTime(2026, 10, 22, 8);
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('오늘은 여기까지!'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('덮개가 떠 있으면 아래 화면을 누를 수 없다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig(limit: 10, brk: 20);
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 10, seconds: 5));
      expect(find.text('오늘은 여기까지!'), findsOneWidget);
      final before = r.audio.played.length;
      await t.tapAt(const Offset(30, 30)); // 홈 톱니바퀴 자리
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsScreen), findsNothing);
      expect(r.audio.played.length, before);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('제한 없음이면 오래 놀아도 덮지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig(limit: 0, brk: 20);
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 19));
      expect(find.text('오늘은 여기까지!'), findsNothing);
      expect(r.state.playBlock, PlayBlock.none);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('눈 쉬기 덮개', () {
    testWidgets('10분 이어서 놀면 20초 "창밖 먼 곳을 봐요", 저절로 사라진다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig(limit: 0, brk: 10);
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 9, seconds: 50));
      expect(find.text('창밖 먼 곳을 봐요'), findsNothing);
      await play(t, r, const Duration(seconds: 10));
      expect(find.text('창밖 먼 곳을 봐요'), findsOneWidget);
      expect(r.audio.spoken.last, '창밖 먼 곳을 봐요.');
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is WindowViewPainter,
        ),
        findsOneWidget,
      );
      final ring = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ShrinkingRingPainter,
      );
      expect(ring, findsOneWidget);
      final full =
          (t.widget<CustomPaint>(ring).painter! as ShrinkingRingPainter)
              .fraction;
      await play(t, r, const Duration(seconds: 10));
      final half =
          (t.widget<CustomPaint>(ring).painter! as ShrinkingRingPainter)
              .fraction;
      expect(half, lessThan(full), reason: '고리가 줄어든다');
      expect(half, closeTo(.5, .1));
      await play(t, r, const Duration(seconds: 10));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('창밖 먼 곳을 봐요'), findsNothing);
      expect(r.audio.spoken.last, '잘 쉬었어요! 다시 놀아요.');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('앱을 5분 넘게 안 보면 쉰 것으로 친다', (t) async {
      await setSize(t, const Size(844, 390));
      final r = await rig(limit: 0, brk: 10);
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 8));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      r.now = r.now.add(const Duration(minutes: 6));
      await t.pump(const Duration(seconds: 1));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(seconds: 1));
      expect(r.state.play.used, const Duration(minutes: 8));
      await play(t, r, const Duration(minutes: 8));
      expect(find.text('창밖 먼 곳을 봐요'), findsNothing);
      await play(t, r, const Duration(minutes: 2, seconds: 5));
      expect(find.text('창밖 먼 곳을 봐요'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  for (final size in sizes) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('덮개 3종(여기까지·부모 확인·눈 쉬기)이 $name에서 넘치지 않는다', (t) async {
      await setSize(t, size);
      final r = await rig(limit: 10, brk: 20);
      await r.state.purchase('crown_gold');
      await t.pumpWidget(AlokdalokApp(state: r.state));
      await t.pump(const Duration(seconds: 1));
      await play(t, r, const Duration(minutes: 10, seconds: 5));
      expect(find.text('오늘은 여기까지!'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(pressable('부모님: 15분 더'));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      await solveGate(t);
      await play(t, r, const Duration(minutes: 10));
      expect(find.text('창밖 먼 곳을 봐요'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('설정 화면(새 항목 포함)이 $name에서 넘치지 않는다', (t) async {
      await setSize(t, size);
      final r = await rig();
      await t.pumpWidget(
        AppScope(
          state: r.state,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      for (final label in ['눈 보호', '놀이 시간', '눈 쉬기 간격', '소리', '부모 확인', '백업']) {
        await t.scrollUntilVisible(find.text(label), 150);
        await t.pump();
        expect(find.text(label), findsOneWidget, reason: label);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    });
  }

  group('설정 화면', () {
    Future<Rig> openSettings(WidgetTester t) async {
      await setSize(t, const Size(1280, 800));
      String? clip;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') return {'text': clip};
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final r = await rig();
      await t.pumpWidget(
        AppScope(
          state: r.state,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      return r;
    }

    testWidgets('놀이 시간·눈 쉬기·눈 보호 거리·부모 확인을 고를 수 있다', (t) async {
      final r = await openSettings(t);
      expect(r.state.eyeGuardOn, isTrue, reason: '눈 보호 기본 켜짐');
      await t.tap(pressable('30분'));
      await t.pump();
      expect(r.state.playLimitMin, 30);
      await t.tap(pressable('제한 없음'));
      await t.pump();
      expect(r.state.playLimitMin, 0);
      await t.tap(pressable('20분마다'));
      await t.pump();
      expect(r.state.eyeBreakMin, 20);
      await t.tap(pressable('40cm'));
      await t.pump();
      expect(r.state.eyeDistanceCm, 40);
      expect(r.state.eye.tooCloseCm, 40);
      final gate = pressable('설정 전에 덧셈 문제 켜짐');
      await t.scrollUntilVisible(gate, 200);
      await t.tap(gate);
      await t.pump();
      expect(r.state.parentGateOn, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('백업 글자를 보여 주고, 잘못된 글자는 거절, 맞는 글자는 복구', (t) async {
      final r = await openSettings(t);
      final code = r.state.exportBackup();
      final make = pressable('백업 글자 만들기');
      await t.scrollUntilVisible(make, 150);
      await t.ensureVisible(make);
      await t.pump();
      await t.tap(make);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(code), findsOneWidget);
      await t.tap(pressable('복사하기'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('복사했어요'), findsOneWidget);
      await t.tap(pressable('닫기'));
      await t.pump(const Duration(milliseconds: 400));

      // 다른 기기: 기록이 없는 상태에서 붙여 넣기
      await r.state.resetAll();
      await r.state.setNickname('새싹');
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(pressable('백업 글자로 복구'));
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byType(TextField), '아무 글자');
      await t.tap(pressable('복구하기'));
      await t.pump(const Duration(milliseconds: 100));
      expect(
        find.text(BackupCode.message(BackupError.notBackup)),
        findsOneWidget,
      );
      expect(r.state.nickname, '새싹');

      await t.enterText(find.byType(TextField), '${code.substring(0, 30)}xx');
      await t.tap(pressable('복구하기'));
      await t.pump(const Duration(milliseconds: 100));
      expect(
        find.text(BackupCode.message(BackupError.damaged)),
        findsOneWidget,
      );

      await t.enterText(find.byType(TextField), code);
      await t.tap(pressable('복구하기'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(TextField), findsNothing);
      expect(r.state.nickname, '별이');
      expect(find.text('백업 글자로 기록을 되살렸어요'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    for (final size in sizes) {
      testWidgets('백업 창이 ${size.width.toInt()}x${size.height.toInt()}에서 '
          '넘치지 않는다', (t) async {
        await setSize(t, size);
        final r = await rig();
        await t.pumpWidget(
          AppScope(
            state: r.state,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await t.pump(const Duration(milliseconds: 500));
        final make = pressable('백업 글자 만들기');
        await t.scrollUntilVisible(make, 150);
        await t.ensureVisible(make);
        await t.pump();
        await t.tap(make);
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        await t.tap(pressable('닫기'));
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(pressable('백업 글자로 복구'));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  });
}
