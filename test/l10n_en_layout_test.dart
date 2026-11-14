// 영어 화면이 568x320, 844x390, 1280x800에서 넘치지 않는지 (글자가 한국어보다 길다).
// 같은 화면을 한국어로도 돌려 둘 다 깨지지 않는지 본다.
import 'package:alokdalok/app.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/play_clock.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'l10n_screens.dart';

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  for (final size in l10nSizes) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    for (final code in ['en', 'ko']) {
      for (final sc in l10nScreens) {
        testWidgets('$code ${sc.name} 화면이 $name에서 넘치지 않는다', (t) async {
          await setSize(t, size);
          final s = await l10nState(code);
          await sc.setup?.call(s);
          await t.pumpWidget(l10nApp(s, sc.build(), code));
          await settle(t, sc.wait);
          expect(t.takeException(), isNull);
          if (sc.name == 'settings') {
            // 긴 설정 화면은 끝까지 내려 보며 확인한다
            for (var i = 0; i < 12; i++) {
              await t.drag(
                find.byType(SingleChildScrollView).first,
                const Offset(0, -300),
              );
              await t.pump(const Duration(milliseconds: 100));
              expect(t.takeException(), isNull);
            }
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 3));
        });
      }
    }

    testWidgets('en 앱 전체(홈) + 덮개(눈 지킴이·놀이 시간)가 $name에서 넘치지 않는다', (t) async {
      await setSize(t, size);
      var now = DateTime(2026, 11, 14, 9);
      final eye = EyeGuard(now: () => now);
      final s = await l10nState('en', eye: eye, now: () => now);
      await s.setPlayLimit(10);
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      expect(L10n.code, 'en');
      expect(find.text('Playground'), findsOneWidget);
      expect(t.takeException(), isNull);
      // 눈 지킴이 경고
      for (var i = 0; i < 5; i++) {
        eye.feed(const FaceReading(size: .9, yaw: 0, pitch: 0, roll: 0));
        now = now.add(const Duration(seconds: 1));
      }
      await settle(t, 6);
      expect(eye.alert, EyeAlert.tooClose);
      expect(find.text('Too close to the screen!'), findsOneWidget);
      expect(t.takeException(), isNull);
      eye.feed(null);
      // 놀이 시간 끝
      for (var i = 0; i < 130; i++) {
        now = now.add(const Duration(seconds: 5));
        await t.pump(const Duration(seconds: 5));
      }
      await settle(t, 5);
      expect(s.playBlock, isNot(PlayBlock.none));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('영어에서는 화면에 한글이 보이지 않는다 (홈·놀이·상점·설정)', (t) async {
    await setSize(t, const Size(1280, 800));
    final hangul = RegExp('[가-힣]');
    for (final sc in l10nScreens) {
      final s = await l10nState('en');
      await sc.setup?.call(s);
      await t.pumpWidget(l10nApp(s, sc.build(), 'en'));
      await settle(t, sc.wait);
      final texts = [
        for (final w in t.widgetList<Text>(find.byType(Text)))
          w.data ?? w.textSpan?.toPlainText() ?? '',
        for (final w in t.widgetList<RichText>(find.byType(RichText)))
          w.text.toPlainText(),
        for (final w in t.widgetList<Pressable>(find.byType(Pressable)))
          w.semanticLabel ?? '',
      ];
      final korean = texts.where(hangul.hasMatch).toSet();
      // 설정의 언어 고르기에는 '한국어'가 그대로 보인다
      korean.remove('한국어');
      expect(korean, isEmpty, reason: sc.name);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    }
  });
}
