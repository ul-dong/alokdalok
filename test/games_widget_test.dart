// 모양·크기·짝 맞추기 놀이 화면: 화면 크기별 넘침, 문제 음성, 힌트, 코인, 한 판 흐름
import 'dart:math';

import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/core/palette.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/common/journey_trail.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/match_game/match_round.dart';
import 'package:alokdalok/games/shape_game/shape_art.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_round.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/games/size_game/size_round.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> makeState() async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  return s;
}

Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(home: home),
);

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder tile(int i) => find.byType(QuizTile).at(i);

Future<void> tapTile(WidgetTester t, int i) async {
  await t.tap(tile(i));
  await t.pump(const Duration(milliseconds: 50));
}

QuizTile tileWidget(WidgetTester t, int i) => t.widget<QuizTile>(tile(i));

RecordingAudio audioOf(GameState s) => s.audio as RecordingAudio;

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 7));
}

void main() {
  const kinds = [GameKind.shape, GameKind.size, GameKind.match];

  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    for (final kind in kinds) {
      testWidgets(
        '${kind.title} 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 '
        '모든 단계가 깨지지 않는다',
        (t) async {
          await setSize(t, size);
          final s = await makeState();
          for (var id = 1; id <= kind.stageCount; id++) {
            await t.pumpWidget(
              wrap(s, gameScreen(kind, id, random: Random(id))),
            );
            await settle(t, 800);
            expect(t.takeException(), isNull, reason: '$id단계');
            // 보기 칸은 아이 손가락에 맞게 60px 이상
            final first = t.getSize(tile(0));
            expect(
              first.shortestSide,
              greaterThanOrEqualTo(60),
              reason: '$id단계 칸 크기',
            );
            await t.pumpWidget(const SizedBox());
          }
          await done(t);
        },
      );
    }
  }

  testWidgets('단계 고르기: 새 놀이도 같은 화면으로 열고, 잠긴 단계는 안내', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    for (final kind in kinds) {
      await t.pumpWidget(wrap(s, StagePicker(game: kind)));
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.text(kind.title), findsOneWidget);
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is Pressable && w.semanticLabel == '2단계 아직 열리지 않음',
        ),
      );
      await settle(t, 200);
      expect(audioOf(s).spoken.last, '앞 단계를 먼저 놀아 볼까요?');
    }
    await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.size)));
    await settle(t);
    await t.tap(
      find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == '1단계'),
    );
    await settle(t, 800);
    expect(find.byType(SizeGameScreen), findsOneWidget);
    await done(t);
  });

  group('모양 놀이', () {
    testWidgets('문제를 말하고, 다시 듣기로 또 들려준다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = ShapeQuestion.generate(Stages.shape[1], Random(3));
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 2, random: Random(3))),
      );
      await settle(t);
      expect(audioOf(s).spoken.last, q.prompt);
      expect(find.text(q.prompt), findsOneWidget);
      final n = audioOf(s).spoken.length;
      await t.tap(find.byType(ReplayButton));
      await settle(t, 200);
      expect(audioOf(s).spoken.length, n + 1);
      expect(audioOf(s).spoken.last, q.prompt);
      expect(t.getSize(find.byType(ReplayButton)).width, 62, reason: '큰 62px');
      await done(t);
    });

    testWidgets('틀리면 부드럽게 다시, 견본 힌트·흐림 → 두 번 틀리면 정답이 빛난다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = ShapeQuestion.generate(Stages.shape[1], Random(5));
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 2, random: Random(5))),
      );
      await settle(t);
      expect(find.byType(QuizHintBox), findsNothing, reason: '2단계 견본은 힌트로만');
      final coins = s.coins;
      final wrong = [
        for (var i = 0; i < q.choices.length; i++)
          if (i != q.answerIndex) i,
      ];
      await tapTile(t, wrong[0]);
      await settle(t, 400);
      expect(s.coins, coins, reason: '틀려도 코인은 그대로');
      expect(audioOf(s).played.last, Sfx.tryAgain);
      expect(audioOf(s).spoken.last, q.wrongLine(wrong[0]));
      expect(audioOf(s).spoken.last, contains('다시 찾아볼까요?'));
      expect(find.text('다시 찾아볼까요?'), findsOneWidget, reason: '말풍선');
      expect(find.byType(QuizHintBox), findsOneWidget, reason: '그림 힌트');
      expect(tileWidget(t, wrong[0]).faded, isTrue);
      expect(tileWidget(t, q.answerIndex).glow, isFalse);

      await tapTile(t, wrong[1]);
      await settle(t, 400);
      expect(tileWidget(t, q.answerIndex).glow, isTrue);

      await tapTile(t, q.answerIndex);
      await settle(t, 300);
      expect(s.coins, coins + Economy.correctAfterRetry);
      final played = audioOf(s).played;
      expect(played.last, Sfx.correct);
      expect(audioOf(s).spoken.last, q.praise);
      await settle(t, 2400);
      expect(t.takeException(), isNull);
      await done(t);
    });

    testWidgets('5문제를 끝내면 별·코인 결과, 다음 단계가 열린다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await makeState();
      final mirror = Random(11);
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 1, random: Random(11))),
      );
      await settle(t);
      final start = s.coins;
      ShapeQuestion? prev;
      for (var i = 0; i < Economy.questionsPerSession; i++) {
        final q = ShapeQuestion.generate(
          Stages.shape[0],
          mirror,
          previous: prev,
        );
        prev = q;
        expect(audioOf(s).spoken.last, q.prompt, reason: '${i + 1}번 문제');
        await tapTile(t, q.answerIndex);
        await settle(t, 2400);
      }
      await settle(t, 600);
      expect(find.text('또 하기'), findsOneWidget);
      expect(find.text('다음 단계'), findsOneWidget);
      expect(find.text('집으로'), findsOneWidget);
      expect(
        s.coins,
        start +
            Economy.correctFirstTry * Economy.questionsPerSession +
            Economy.sessionComplete +
            Economy.firstPlayBonus +
            Economy.newStageBonus,
      );
      expect(s.unlockedStage(GameKind.shape), 2);
      expect(s.clearedStages(GameKind.shape), {1});
      expect(s.unlockedStage(GameKind.size), 1);
      expect(audioOf(s).played, contains(Sfx.fanfare));

      // 또 하기: 처음부터 다시
      await t.tap(find.text('또 하기'));
      await settle(t, 400);
      expect(find.text('또 하기'), findsNothing);
      await done(t);
    });

    testWidgets('단계마다 계절 음악', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 2, random: Random(1))),
      );
      await settle(t);
      expect(audioOf(s).music, 'summer');
      await t.pumpWidget(
        wrap(
          s,
          SizeGameScreen(key: const ValueKey(3), stageId: 3, random: Random(1)),
        ),
      );
      await settle(t);
      expect(audioOf(s).music, 'autumn');
      await t.pumpWidget(
        wrap(s, MatchGameScreen(stageId: 4, random: Random(1))),
      );
      await settle(t);
      expect(audioOf(s).music, 'winter');
      await t.pumpWidget(const SizedBox());
      await settle(t, 200);
      expect(audioOf(s).music, isNull, reason: '나가면 음악 끔');
      await done(t);
    });

    testWidgets('견본 찾기 단계는 견본을 처음부터 보여 준다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 5, random: Random(2))),
      );
      await settle(t);
      expect(find.byType(QuizHintBox), findsOneWidget);
      expect(audioOf(s).spoken.last, '똑같은 모양을 찾아볼까요?');
      // 견본 색은 보기(정답 포함) 색과 다르다: 색이 아니라 모양을 보고 찾게
      final sample = t.widget<ShapeIcon>(
        find.descendant(
          of: find.byType(QuizHintBox),
          matching: find.byType(ShapeIcon),
        ),
      );
      final tileColors = {
        for (final w in t.widgetList<ShapeIcon>(
          find.descendant(
            of: find.byType(QuizTile),
            matching: find.byType(ShapeIcon),
          ),
        ))
          w.color,
      };
      expect(tileColors, isNot(contains(sample.color)));
      await done(t);
    });

    testWidgets('1단계(이름 듣고 찾기): 처음엔 견본 없음, 한 번 틀리면 정답과 다른 색 견본', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = ShapeQuestion.generate(Stages.shape[0], Random(9));
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 1, random: Random(9))),
      );
      await settle(t);
      expect(audioOf(s).spoken.last, q.prompt);
      expect(q.matchSample, isFalse);
      expect(
        find.byType(QuizHintBox),
        findsNothing,
        reason: '처음부터 견본이 보이면 소리를 듣지 않고 그림만 맞춰도 풀린다',
      );
      final wrong = q.answerIndex == 0 ? 1 : 0;
      await tapTile(t, wrong);
      await settle(t, 400);
      expect(find.byType(QuizHintBox), findsOneWidget, reason: '한 번 틀리면 견본 힌트');
      final sample = t.widget<ShapeIcon>(
        find.descendant(
          of: find.byType(QuizHintBox),
          matching: find.byType(ShapeIcon),
        ),
      );
      expect(sample.shape, q.shape);
      final answer = t.widget<ShapeIcon>(
        find.descendant(
          of: tile(q.answerIndex),
          matching: find.byType(ShapeIcon),
        ),
      );
      expect(sample.color, isNot(answer.color), reason: '견본 색은 정답 보기와 다르다');
      expect(tileWidget(t, q.answerIndex).glow, isFalse);
      expect(t.takeException(), isNull);
      await done(t);
    });
  });

  group('크기 놀이', () {
    testWidgets('틀리면 크기 그림 힌트, 맞히면 효과음·칭찬·코인', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = SizeQuestion.generate(Stages.size[2], Random(7));
      await t.pumpWidget(
        wrap(s, SizeGameScreen(stageId: 3, random: Random(7))),
      );
      await settle(t);
      expect(audioOf(s).spoken.last, q.prompt);
      expect(q.prompt, startsWith('가장 '));
      expect(find.byType(SizeHint), findsNothing);
      final coins = s.coins;
      final wrong = q.answerIndex == 0 ? 1 : 0;
      await tapTile(t, wrong);
      await settle(t, 400);
      expect(s.coins, coins);
      expect(audioOf(s).spoken.last, q.wrongLine);
      expect(find.byType(SizeHint), findsOneWidget);
      expect(tileWidget(t, wrong).faded, isTrue);
      await tapTile(t, q.answerIndex);
      await settle(t, 300);
      expect(s.coins, coins + Economy.correctAfterRetry);
      expect(audioOf(s).played.last, Sfx.correct);
      await settle(t, 2400);
      // 다음 문제
      final mirror = Random(7);
      SizeQuestion.generate(Stages.size[2], mirror);
      final q2 = SizeQuestion.generate(Stages.size[2], mirror, previous: q);
      expect(audioOf(s).spoken.last, q2.prompt);
      expect(find.byType(SizeHint), findsNothing, reason: '새 문제는 힌트 없이');
      await done(t);
    });

    testWidgets('5문제를 한 번에 맞히면 별 5개', (t) async {
      await setSize(t, const Size(568, 320));
      final s = await makeState();
      final mirror = Random(21);
      await t.pumpWidget(
        wrap(s, SizeGameScreen(stageId: 1, random: Random(21))),
      );
      await settle(t);
      final stars = s.stars;
      SizeQuestion? prev;
      for (var i = 0; i < Economy.questionsPerSession; i++) {
        final q = SizeQuestion.generate(Stages.size[0], mirror, previous: prev);
        prev = q;
        await tapTile(t, q.answerIndex);
        await settle(t, 2400);
      }
      await settle(t, 600);
      expect(t.takeException(), isNull);
      expect(find.text('또 하기'), findsOneWidget);
      expect(s.stars, stars + Economy.questionsPerSession);
      expect(
        t
            .widgetList<StarIcon>(find.byType(StarIcon))
            .where((w) => w.size >= 44 && w.color == Palette.yellow)
            .length,
        5,
        reason: '다른 놀이는 그대로 5문제 = 별 5개',
      );
      expect(t.widget<PawProgress>(find.byType(PawProgress)).total, 5);
      expect(s.unlockedStage(GameKind.size), 2);
      await done(t);
    });
  });

  group('짝 맞추기', () {
    List<(int, int)> pairsOf(MatchBoard b) {
      final out = <(int, int)>[];
      final seen = <int>{};
      for (var i = 0; i < b.cards.length; i++) {
        if (seen.contains(i)) continue;
        final j = b.twinOf(i);
        seen.addAll([i, j]);
        out.add((i, j));
      }
      return out;
    }

    testWidgets('카드는 모두 보이고, 두 장을 차례로 눌러 짝을 맞춘다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final b = MatchBoard.generate(Stages.match[2], Random(4));
      await t.pumpWidget(
        wrap(s, MatchGameScreen(stageId: 3, random: Random(4))),
      );
      await settle(t);
      expect(find.byType(QuizTile), findsNWidgets(6), reason: '3쌍 = 6장');
      expect(audioOf(s).spoken.last, MatchBoard.prompt);
      final pairs = pairsOf(b);
      final (a0, a1) = pairs[0];
      await tapTile(t, a0);
      expect(tileWidget(t, a0).selected, isTrue);
      expect(audioOf(s).spoken.last, b.pickedLine(a0));
      // 다시 듣기는 지금 찾는 그림을 말한다
      await t.tap(find.byType(ReplayButton));
      await t.pump(const Duration(milliseconds: 50));
      expect(audioOf(s).spoken.last, b.pickedLine(a0));

      final coins = s.coins;
      await tapTile(t, a1);
      await settle(t, 300);
      expect(tileWidget(t, a0).done, isTrue);
      expect(tileWidget(t, a1).done, isTrue);
      expect(audioOf(s).played.last, Sfx.correct);
      expect(audioOf(s).spoken.last, b.matchedLine(a1));
      expect(s.coins, coins, reason: '판을 다 맞췄을 때 코인');

      for (final (x, y) in pairs.skip(1)) {
        await tapTile(t, x);
        await tapTile(t, y);
      }
      await settle(t, 300);
      expect(s.coins, coins + Economy.correctFirstTry);
      await settle(t, 2400);
      expect(t.takeException(), isNull);
      await done(t);
    });

    testWidgets('짝이 아니면 흐려지고 그림 힌트, 두 번 틀리면 짝이 빛난다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await makeState();
      final b = MatchBoard.generate(Stages.match[4], Random(6));
      await t.pumpWidget(
        wrap(s, MatchGameScreen(stageId: 5, random: Random(6))),
      );
      await settle(t);
      expect(find.byType(QuizTile), findsNWidgets(8), reason: '4쌍 = 8장');
      final (a, twin) = pairsOf(b).first;
      final others = [
        for (var i = 0; i < b.cards.length; i++)
          if (i != a && i != twin) i,
      ];
      await tapTile(t, a);
      expect(find.byType(QuizHintBox), findsNothing);
      await tapTile(t, others[0]);
      await settle(t, 300);
      expect(audioOf(s).played.last, Sfx.tryAgain);
      expect(audioOf(s).spoken.last, b.wrongLine(a));
      expect(
        audioOf(s).spoken.last,
        contains(b.cards[a].color.adjective),
        reason: '마지막 단계는 색 이름으로 말한다',
      );
      expect(tileWidget(t, others[0]).faded, isTrue);
      expect(tileWidget(t, a).selected, isTrue);
      expect(find.byType(QuizHintBox), findsOneWidget);
      await tapTile(t, others[1]);
      await settle(t, 300);
      expect(tileWidget(t, twin).glow, isTrue);
      await tapTile(t, twin);
      await settle(t, 600);
      expect(tileWidget(t, others[0]).faded, isFalse, reason: '짝을 찾으면 흐림이 풀린다');
      expect(find.byType(QuizHintBox), findsNothing);
      await done(t);
    });

    testWidgets('3판을 끝내면 3문제 기준 결과(발자국·별·코인), 틀린 판은 별 없이 코인 1', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final mirror = Random(9);
      await t.pumpWidget(
        wrap(s, MatchGameScreen(stageId: 1, random: Random(9))),
      );
      await settle(t);
      // 위 발자국과 아래 골인 길이 3칸
      expect(t.widget<PawProgress>(find.byType(PawProgress)).total, 3);
      expect(t.widget<JourneyTrail>(find.byType(JourneyTrail)).total, 3);
      final start = s.coins;
      final stars = s.stars;
      MatchBoard? prev;
      for (var k = 0; k < Economy.matchQuestionsPerSession; k++) {
        final b = MatchBoard.generate(Stages.match[0], mirror, previous: prev);
        prev = b;
        final pairs = pairsOf(b);
        if (k == 0) {
          // 첫 판은 한 번 틀린다
          await tapTile(t, pairs[0].$1);
          await tapTile(t, pairs[1].$1);
          await settle(t, 200);
        }
        for (final (x, y) in pairs) {
          if (k != 0 || x != pairs[0].$1) await tapTile(t, x);
          await tapTile(t, y);
        }
        await settle(t, 2400);
        expect(t.widget<PawProgress>(find.byType(PawProgress)).done, k + 1);
      }
      await settle(t, 600);
      expect(find.text('또 하기'), findsOneWidget);
      expect(s.stars, stars + 2);
      // 결과 별: 3칸 중 노란 별 2개
      final resultStars = t
          .widgetList<StarIcon>(find.byType(StarIcon))
          .where((w) => w.size >= 44)
          .toList();
      expect(resultStars.length, 3);
      expect(resultStars.where((w) => w.color == Palette.yellow).length, 2);
      final earned =
          Economy.correctAfterRetry +
          Economy.correctFirstTry * 2 +
          Economy.sessionComplete +
          Economy.firstPlayBonus +
          Economy.newStageBonus;
      expect(s.coins, start + earned);
      expect(find.text('+$earned'), findsOneWidget, reason: '결과 금액 = 실제 지급액');
      expect(s.unlockedStage(GameKind.match), 2);
      await done(t);
    });
  });
}
