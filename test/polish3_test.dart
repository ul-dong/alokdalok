// 남은 점 정리: 568 숫자판(작은 도장·큰 물건·16px 이상 글씨), 1280 짝 맞추기 가운데 정렬,
// 568·844 상점 칸이 땅(안내 띠)과 겹치지 않기
import 'dart:math';

import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/common/stamp.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/shop/item_widgets.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/paged_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'play_polish_test.dart' show makeState, setSize, settle, choiceButton;

/// 앱과 같은 테마(Jua 글꼴)로 띄운다: 글씨 폭을 실제와 같게 재려고
Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

/// 화면에 실제로 보이는 글씨 크기 (FittedBox 등으로 줄어든 비율까지 반영)
double shownFontSize(WidgetTester t, Finder f) {
  final text = t.widget<Text>(f);
  final scale = t.getRect(f).height / t.getSize(f).height;
  return text.style!.fontSize! * scale;
}

Future<void> close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 8000);
}

void main() {
  group('568 숫자판', () {
    for (final (stage, seed) in [(8, 3), (3, 4)]) {
      testWidgets('$stage단계: 도장은 물건보다 작고 모서리에, 숫자판 글씨는 16px 이상', (t) async {
        await setSize(t, const Size(568, 320));
        final s = await makeState();
        final q = NumberQuestion.generate(
          Stages.number[stage - 1],
          Random(seed),
        );
        await t.pumpWidget(
          wrap(s, NumberGameScreen(stageId: stage, random: Random(seed))),
        );
        await settle(t, 1200);
        final before = [
          for (final e in find.byType(Stamped).evaluate())
            (e.renderObject! as RenderBox).size.width,
        ];
        await t.tap(
          choiceButton('${q.choices.firstWhere((c) => c != q.count)}'),
        );
        await settle(t, 3000); // 판이 뜨고 몇 개 센 뒤
        expect(find.byType(CountBoard), findsOneWidget);
        for (final e in find.byType(Stamped).evaluate()) {
          final w = e.widget as Stamped;
          final size = (e.renderObject! as RenderBox).size;
          expect(w.corner, isTrue);
          expect(w.badgeSize, lessThan(size.width * .7));
        }
        // 물건이 예전(흩어 놓기 약 24px, 줄 맞추기 약 34px)보다 크다
        expect(before.reduce(min), greaterThanOrEqualTo(stage == 8 ? 34 : 36));
        expect(
          shownFontSize(
            t,
            find.descendant(
              of: find.byType(CountBoard),
              matching: find.text(NumberGameScreen.boardTitle),
            ),
          ),
          greaterThanOrEqualTo(16),
        );
        expect(
          shownFontSize(t, find.byKey(CountBoard.readingKey)),
          greaterThanOrEqualTo(16),
        );
        // 숫자는 글씨보다 훨씬 크게
        expect(
          t.getRect(find.byKey(CountBoard.numberKey)).height,
          greaterThan(40),
        );
        await close(t);
      });
    }

    testWidgets('844 화면은 예전 배치 그대로 (가운데 큰 도장, 위아래 숫자판)', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = NumberQuestion.generate(Stages.number[7], Random(3));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 8, random: Random(3))),
      );
      await settle(t, 1200);
      await t.tap(choiceButton('${q.choices.firstWhere((c) => c != q.count)}'));
      await settle(t, 3000);
      for (final e in find.byType(Stamped).evaluate()) {
        expect((e.widget as Stamped).corner, isFalse);
      }
      final title = t.getRect(
        find.descendant(
          of: find.byType(CountBoard),
          matching: find.text(NumberGameScreen.boardTitle),
        ),
      );
      final number = t.getRect(find.byKey(CountBoard.numberKey));
      expect(title.bottom, lessThanOrEqualTo(number.top + 1));
      await close(t);
    });

    test('작은 화면 흩어 놓기는 칸을 화면 비율에 맞게 나눈다', () {
      expect(compactScatterGrid(12, const Size(249, 80)), (2, 6));
      expect(compactScatterGrid(3, const Size(249, 80)), (1, 3));
      expect(isCompactField(const Size(249, 80)), isTrue);
      expect(isCompactField(const Size(387, 129)), isFalse);
    });
  });

  group('1280 보기 묶음 가운데 정렬', () {
    final screens = <String, Widget Function(int)>{
      'match': (id) => MatchGameScreen(stageId: id, random: Random(7)),
      'shape': (id) => ShapeGameScreen(stageId: id, random: Random(7)),
      'size': (id) => SizeGameScreen(stageId: id, random: Random(7)),
    };
    for (final MapEntry(key: name, value: make) in screens.entries) {
      final stages = name == 'match' ? Stages.match.length : 2;
      testWidgets('$name 1~$stages단계: 카드 묶음 중심이 판 중심에서 24px 안', (t) async {
        await setSize(t, const Size(1280, 800));
        final s = await makeState();
        for (var id = 1; id <= stages; id++) {
          await t.pumpWidget(wrap(s, make(id)));
          await settle(t, 1200);
          final tiles = find.byType(QuizTile);
          final span = [
            for (final e in tiles.evaluate())
              t.getRect(find.byWidget(e.widget)),
          ].reduce((a, b) => a.expandToInclude(b));
          final card = t.getRect(find.byType(QuizCard));
          expect(
            (span.center.dx - card.center.dx).abs(),
            lessThanOrEqualTo(24),
            reason: '$name $id: 묶음 $span, 판 $card',
          );
          // 왼쪽 "다시 듣기" 줄과 겹치지 않는다
          final replay = t.getRect(find.byType(ReplayButton));
          expect(span.left, greaterThan(replay.right));
          await close(t);
        }
      });
    }
  });

  group('상점 칸은 땅(안내 띠) 위에서 끝난다', () {
    for (final size in const [
      Size(568, 320),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      for (final vehicles in [true, false]) {
        testWidgets('${size.width.toInt()} ${vehicles ? '탈것' : '옷'}', (
          t,
        ) async {
          await setSize(t, size);
          final s = await makeState();
          await t.pumpWidget(wrap(s, ShopScreen(startWithVehicles: vehicles)));
          await settle(t, 1200);
          final ground = size.height * ShopBackdropPainter.groundTop;
          final grid = t.getRect(find.byType(PagedGrid).last);
          expect(grid.bottom, lessThanOrEqualTo(ground), reason: '칸 영역 $grid');
          final cells = vehicles
              ? find.descendant(
                  of: find.byType(PagedGrid).last,
                  matching: find.byType(AnimatedContainer),
                )
              : find.byType(ItemTile);
          expect(cells, findsWidgets);
          for (final e in cells.evaluate()) {
            final r = (e.renderObject! as RenderBox);
            final rect = r.localToGlobal(Offset.zero) & r.size;
            expect(rect.bottom, lessThanOrEqualTo(ground));
            expect(r.size.height, greaterThanOrEqualTo(60));
            expect(r.size.width, greaterThanOrEqualTo(60));
          }
          await close(t);
        });
      }
    }
  });
}
