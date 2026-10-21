// 같이 세기 숫자판(정답·오답 중간), 멈춤 화면(꾹 누르는 중), 놀이 화면, 물건 그림 모음
// 실행: flutter test test_preview/play_polish_preview_test.dart --update-goldens
import 'dart:math';

import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/common/object_art.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/shape_game/shape_art.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_preview_test.dart' show st;

const sizes = [Size(568, 320), Size(844, 390), Size(1280, 800)];

Future<void> _pump(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder _choice(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(PillButton));

int _boardNumber(WidgetTester t) {
  final f = find.byKey(CountBoard.numberKey);
  if (f.evaluate().isEmpty) return -1;
  return int.tryParse(t.widget<Text>(f).data!.trim()) ?? 0;
}

Future<void> _open(WidgetTester t, Size size, Widget home) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  final s = await st();
  await t.pumpWidget(
    AppScope(
      state: s,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: home,
      ),
    ),
  );
  await _pump(t, 1200);
}

Future<void> _shot(WidgetTester t, String name) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('shots/$name.png'),
);

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
}

void main() {
  for (final size in sizes) {
    final w = size.width.toInt();
    for (final (stage, seed) in [(3, 4), (8, 3)]) {
      final q = NumberQuestion.generate(Stages.number[stage - 1], Random(seed));
      testWidgets('count wrong $stage $w', (t) async {
        await _open(
          t,
          size,
          NumberGameScreen(stageId: stage, random: Random(seed)),
        );
        await t.tap(_choice('${q.choices.firstWhere((c) => c != q.count)}'));
        // 숫자판이 2를 막 띄운 순간 (도장이 찍히는 중)
        for (var i = 0; i < 200 && _boardNumber(t) < min(2, q.count); i++) {
          await t.pump(const Duration(milliseconds: 20));
        }
        await _pump(t, 150);
        await _shot(t, 'count_wrong_${stage}_$w');
        await _close(t);
      });
      testWidgets('count right $stage $w', (t) async {
        await _open(
          t,
          size,
          NumberGameScreen(stageId: stage, random: Random(seed)),
        );
        await t.tap(_choice('${q.count}'));
        // 마지막 숫자 + 칭찬이 뜬 순간
        for (var i = 0; i < 300 && _boardNumber(t) < q.count; i++) {
          await t.pump(const Duration(milliseconds: 20));
        }
        await _pump(t, 250);
        await _shot(t, 'count_right_${stage}_$w');
        await _close(t);
      });
    }

    testWidgets('pause $w', (t) async {
      await _open(t, size, NumberGameScreen(stageId: 1, random: Random(1)));
      await t.tap(
        find.byWidgetPredicate(
          (x) => x is Pressable && x.semanticLabel == '잠깐 멈추기',
        ),
      );
      await _pump(t, 300);
      await _shot(t, 'pause_$w');
      // 꾹 누르는 중: 고리가 반쯤 찼다
      final g = await t.startGesture(t.getCenter(find.byType(HoldToConfirm)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 450));
      await _shot(t, 'pause_hold_$w');
      await g.up();
      await _close(t);
    });

    for (final kind in GameKind.values) {
      testWidgets('game ${kind.name} $w', (t) async {
        await _open(t, size, gameScreen(kind, 1, random: Random(7)));
        await _shot(t, 'play_${kind.name}1_$w');
        await _close(t);
      });
    }
  }

  testWidgets('object sheet', (t) async {
    t.view.physicalSize = const Size(1000, 420);
    t.view.devicePixelRatio = 1;
    const tints = [
      GameColor.red,
      GameColor.blue,
      GameColor.yellow,
      GameColor.green,
    ];
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xFFFBF6EC),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in const [28.0, 64.0])
                  Wrap(
                    children: [
                      for (final k in ObjectKind.values)
                        for (final c in tints.take(s < 40 ? 1 : 2))
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: ObjectIcon(k, color: c.color, size: s),
                          ),
                    ],
                  ),
                Wrap(
                  children: [
                    for (final k in ObjectKind.values)
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: ObjectIcon(k, size: 110),
                      ),
                  ],
                ),
                Wrap(
                  children: [
                    for (final sh in ShapeKind.values)
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: ShapeIcon(
                          sh,
                          color: tints[sh.index % 4].color,
                          size: 80,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _shot(t, 'object_sheet');
  });
}
