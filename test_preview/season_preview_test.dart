// 계절 배경 4종 미리보기 (shots/season_<계절>_<폭>.png)
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/games/common/scene_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(844, 390), Size(1280, 800)]) {
    for (final season in Season.values) {
      testWidgets('season ${season.name} ${size.width}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: Scaffold(body: SceneBackground(season: season)),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'shots/season_${season.name}_${size.width.toInt()}.png',
          ),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
