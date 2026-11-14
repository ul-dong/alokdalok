// 다국어 미리보기: 같은 화면을 한국어·영어로 그린다 (shots/l10n_<언어>_<화면>_<폭>.png).
// 영어 글자가 Jua 글꼴로 깨지지 않는지, 길어진 글자가 넘치거나 너무 작아지지 않는지 눈으로 본다.
// 실행: flutter test test_preview/l10n_preview_test.dart --update-goldens
import 'package:alokdalok/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/l10n_screens.dart';

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  for (final size in l10nSizes) {
    final w = size.width.toInt();
    for (final code in ['ko', 'en']) {
      for (final sc in l10nScreens) {
        testWidgets('$code ${sc.name} $w', (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final s = await l10nState(code);
          await sc.setup?.call(s);
          await t.pumpWidget(l10nApp(s, sc.build(), code));
          for (var i = 0; i < sc.wait; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          if (sc.scroll > 0) {
            await t.drag(
              find.byType(SingleChildScrollView).first,
              Offset(0, -sc.scroll),
            );
            await t.pump(const Duration(milliseconds: 500));
          }
          expect(t.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp).first,
            matchesGoldenFile('shots/l10n_${code}_${sc.name}_$w.png'),
          );
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 3));
        });
      }
    }
  }
}
