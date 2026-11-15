// Android 15+ edge-to-edge(targetSdk 36 에서는 끌 수 없음) 점검용 미리보기.
// 노치(가로로 들면 왼쪽)·제스처 바(아래) 여백이 있을 때 버튼이 그 밑으로 들어가지 않는지 본다.
// 큰 화면 세로 창(Android 16 은 sw600dp 이상에서 가로 고정을 무시할 수 있다)은 "돌려 주세요" 안내가 뜬다.
// 실행: flutter test test_preview/insets_preview_test.dart --update-goldens → shots/insets_*.png
import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_preview_test.dart' show st;

Future<void> _pump(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // 노치 44(왼쪽, 가로로 든 휴대폰), 제스처 바 24(아래) — 몰입 모드가 풀린 순간도 함께 본다
  const notch = FakeViewPadding(left: 44, bottom: 24);
  final pages = <String, Widget? Function()>{
    'home': () => null,
    'number': () => NumberGameScreen(stageId: 5, random: Random(2)),
    'shop': () => const ShopScreen(),
  };
  for (final size in const [Size(844, 390), Size(568, 320)]) {
    for (final e in pages.entries) {
      final w = size.width.toInt();
      testWidgets('insets ${e.key} $w', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.view.padding = notch;
        t.view.viewPadding = notch;
        addTearDown(t.view.reset);
        final s = await st();
        final page = e.value();
        await t.pumpWidget(
          page == null
              ? AlokdalokApp(state: s)
              : AppScope(
                  state: s,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: buildAppTheme(),
                    home: page,
                  ),
                ),
        );
        await _pump(t);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile('shots/insets_${e.key}_$w.png'),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('insets tablet portrait', (t) async {
    // Android 16 큰 화면에서 세로로 열린 경우 → 돌려 달라는 안내
    t.view.physicalSize = const Size(800, 1280);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(t.view.reset);
    final s = await st();
    await t.pumpWidget(AlokdalokApp(state: s));
    await _pump(t);
    expect(find.byType(RotateHint), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('shots/insets_tablet_portrait.png'),
    );
    await t.pumpWidget(const SizedBox());
  });
}
