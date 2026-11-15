// 다국어: 언어 고르기, 저장 버전 8(언어 설정), 영어 ARB에 빠진 키가 없는지.
import 'dart:convert';
import 'dart:io';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart'
    show MaterialPageRoute, Navigator, Scrollable;
import 'package:alokdalok/screens/home_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String code) =>
    (jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map)
        .cast<String, Object?>();

Iterable<String> _keys(Map<String, Object?> arb) =>
    arb.keys.where((k) => !k.startsWith('@'));

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  group('언어 고르기', () {
    test('자동이면 기기 언어 목록에서 처음 지원하는 언어', () {
      expect(
        AppLanguage.resolve('auto', const [Locale('en', 'US')]),
        const Locale('en'),
      );
      expect(
        AppLanguage.resolve('auto', const [Locale('ko', 'KR')]),
        const Locale('ko'),
      );
      expect(
        AppLanguage.resolve('auto', const [Locale('ja'), Locale('en', 'GB')]),
        const Locale('en'),
      );
    });

    test('지원하지 않는 언어뿐이거나 목록이 없으면 한국어', () {
      expect(
        AppLanguage.resolve('auto', const [Locale('ja')]),
        const Locale('ko'),
      );
      expect(AppLanguage.resolve('auto', null), const Locale('ko'));
      expect(AppLanguage.resolve('auto', const []), const Locale('ko'));
    });

    test('직접 고르면 기기 언어와 상관없이 그 언어', () {
      expect(
        AppLanguage.resolve('ko', const [Locale('en')]),
        const Locale('ko'),
      );
      expect(
        AppLanguage.resolve('en', const [Locale('ko')]),
        const Locale('en'),
      );
    });

    test('L10n.current는 기본 한국어, use로 바꾼다', () {
      expect(L10n.code, 'ko');
      expect(L10n.current.app_title, '알록달록 꼬마 놀이터');
      expect(L10n.use(const Locale('en', 'US')), isTrue);
      expect(L10n.code, 'en');
      expect(L10n.current.app_title, 'Balloon Playground');
      expect(L10n.use(const Locale('en')), isFalse, reason: '같은 언어');
      expect(L10n.use(const Locale('ja')), isFalse, reason: '지원 안 함');
      expect(L10n.code, 'en');
    });
  });

  group('저장 버전 8: 언어 설정', () {
    test('새로 설치하면 자동', () {
      expect(SaveData.initial().language, 'auto');
      expect(SaveData.decode(null).language, 'auto');
    });

    test('버전 7 저장값은 한국어로 고정 (쓰던 언어 그대로)', () {
      final json = SaveData.migrate({
        'version': 7,
        'nickname': '보리',
        'coins': 42,
        'lastGame': 'color',
        'lastStage': 2,
      });
      expect(json['version'], SaveData.currentVersion);
      expect(json['language'], 'ko');
      final d = SaveData.fromJson(json);
      expect(d.language, 'ko');
      expect(d.coins, 42);
      expect(d.lastGame, 'color');
      expect(d.lastStage, 2);
    });

    test('아주 예전 저장값도 한국어', () {
      expect(SaveData.decode(jsonEncode({'version': 1})).language, 'ko');
    });

    test('저장하고 다시 읽으면 그대로, 이상한 값은 자동', () {
      final d = SaveData.initial()..language = 'en';
      expect(SaveData.decode(d.encode()).language, 'en');
      final bad = d.toJson()..['language'] = 'xx';
      expect(SaveData.decode(jsonEncode(bad)).language, 'auto');
      final missing = d.toJson()..remove('language');
      expect(SaveData.decode(jsonEncode(missing)).language, 'auto');
    });
  });

  group('ARB', () {
    test('영어 ARB에 빠진 키도, 남는 키도 없다', () {
      final ko = _keys(_arb('ko')).toSet();
      final en = _keys(_arb('en')).toSet();
      expect(ko.difference(en), isEmpty, reason: '영어에 빠진 키');
      expect(en.difference(ko), isEmpty, reason: '한국어에 없는 키');
    });

    test('영어 문구는 비어 있지 않고 한글이 없다', () {
      final en = _arb('en');
      final hangul = RegExp('[가-힣]');
      for (final k in _keys(en)) {
        final v = en[k] as String;
        expect(v.trim(), isNotEmpty, reason: k);
        expect(hangul.hasMatch(v), isFalse, reason: '$k: $v');
      }
    });

    test('영어 문구는 Jua 글꼴에 있는 글자(ASCII)만 쓴다', () {
      // Jua에는 기본 라틴 글자만 있다 (’ – … 같은 글자는 다른 글꼴로 바뀌어 어색하다)
      final en = _arb('en');
      final ok = RegExp(r'^[ -~\n]*$');
      for (final k in _keys(en)) {
        expect(ok.hasMatch(en[k] as String), isTrue, reason: '$k: ${en[k]}');
      }
    });

    test('자리 표시자({name})가 두 언어에서 같다', () {
      final ko = _arb('ko'), en = _arb('en');
      final ph = RegExp(r'\{(\w+)');
      for (final k in _keys(ko)) {
        Set<String> names(String v) =>
            {for (final m in ph.allMatches(v)) m[1]!}
              ..removeAll(['plural', 'select', 'other', 'one']);
        expect(names(en[k] as String), names(ko[k] as String), reason: k);
      }
    });

    test('키 이름은 화면_용도 (소문자로 시작, 밑줄 하나 이상)', () {
      final pattern = RegExp(r'^[a-z][a-zA-Z0-9]*_[a-zA-Z0-9_]+$');
      for (final k in _keys(_arb('ko'))) {
        expect(pattern.hasMatch(k), isTrue, reason: k);
      }
    });
  });

  group('앱 언어 바꾸기', () {
    Future<GameState> app(WidgetTester t, String language) async {
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      await s.setNickname('보리');
      await s.setParentGate(false);
      await s.setLanguage(language);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(milliseconds: 300));
      return s;
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('자동: 한국어 기기면 한국어', (t) async {
      final s = await app(t, 'auto');
      expect(L10n.code, 'ko');
      expect(s.audio.locale, 'ko');
      await close(t);
    });

    testWidgets('자동: 영어 기기면 영어, 다시 한국어로 고를 수 있다', (t) async {
      t.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(
        () =>
            t.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')],
      );
      final s = await app(t, 'auto');
      expect(L10n.code, 'en');
      expect(s.audio.locale, 'en');
      await s.setLanguage('ko');
      await t.pump(const Duration(milliseconds: 300));
      expect(L10n.code, 'ko');
      expect(s.audio.locale, 'ko');
      await close(t);
    });

    testWidgets('설정에서 English를 누르면 앱이 영어로, 자동을 누르면 기기 언어로', (t) async {
      final s = await app(t, 'auto');
      // 홈 위에 설정 화면을 연다 (부모 확인은 다른 테스트에서 본다)
      Navigator.of(
        t.element(find.byType(HomeScreen)),
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final english = find.byWidgetPredicate(
        (w) => w is Pressable && w.semanticLabel == 'English',
      );
      await t.scrollUntilVisible(
        english,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(english);
      await t.pump(const Duration(milliseconds: 500));
      expect(s.language, 'en');
      expect(L10n.code, 'en');
      expect(find.text('Settings'), findsOneWidget);
      final auto = find.byWidgetPredicate(
        (w) => w is Pressable && w.semanticLabel == 'Auto',
      );
      await t.tap(auto);
      await t.pump(const Duration(milliseconds: 500));
      expect(s.language, 'auto');
      expect(L10n.code, 'ko', reason: '테스트 기기는 한국어');
      expect(find.text('설정'), findsOneWidget);
      await close(t);
    });

    testWidgets('English를 고르면 화면 문구와 목소리 언어가 영어', (t) async {
      final s = await app(t, 'en');
      expect(L10n.code, 'en');
      expect(s.audio.locale, 'en');
      final ctx = t.element(find.byType(RootGate));
      expect(L10n.of(ctx).settings_language, 'Language');
      await close(t);
    });
  });
}
