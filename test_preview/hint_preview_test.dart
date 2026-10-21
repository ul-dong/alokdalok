import 'dart:math';

import 'package:alokdalok/games/common/stamp.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alokdalok/widgets/common.dart';

import 'screens_preview_test.dart' show st;

void main() {
  for (final stage in [2, 5]) {
    testWidgets('hint stamp $stage', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      final s = await st();
      await t.pumpWidget(AppScope(
        state: s,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: NumberGameScreen(stageId: stage, random: Random(3)),
        ),
      ));
      await t.pump(const Duration(seconds: 1));
      // 틀린 보기를 찾을 때까지 하나씩 눌러 본다
      for (var d = 10; d >= 1; d--) {
        final f = find.text('$d');
        if (f.evaluate().isEmpty) continue;
        await t.tap(f.last);
        for (var k = 0; k < 6; k++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        if (find.byType(BigPop).evaluate().isNotEmpty) {
          debugPrint('BIGPOP ${t.getRect(find.byType(BigPop))}');
          break;
        }
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/hint_pop_$stage.png'));
      for (var i = 0; i < 26; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/hint_stamp_$stage.png'));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  }
}
