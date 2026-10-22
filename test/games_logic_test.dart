// 모양·크기·짝 맞추기 놀이: 문제 만들기·한 문제 흐름·저장·음성 조각 (순수 Dart 로직)
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/match_game/match_round.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_round.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/games/size_game/size_round.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('새 놀이 3종은 모두 5단계', () {
    expect(Stages.shape.length, 5);
    expect(Stages.size.length, 5);
    expect(Stages.match.length, 5);
    for (final k in [GameKind.shape, GameKind.size, GameKind.match]) {
      expect(k.stageCount, 5);
    }
    for (var i = 0; i < 5; i++) {
      expect(Stages.shape[i].id, i + 1);
      expect(Stages.size[i].id, i + 1);
      expect(Stages.match[i].id, i + 1);
    }
  });

  group('모양 놀이', () {
    test('여섯 모양: 동그라미·세모·네모·별·하트·다이아', () {
      expect(ShapeKind.values.map((s) => s.ko).toList(), [
        '동그라미',
        '세모',
        '네모',
        '별',
        '하트',
        '다이아',
      ]);
      expect(Stages.shape.last.shapes.toSet(), ShapeKind.values.toSet());
    });

    test('문제: 보기 수, 서로 다른 모양, 정답은 단계 모양 중 하나', () {
      for (final stage in Stages.shape) {
        final rng = Random(stage.id);
        for (var k = 0; k < 300; k++) {
          final q = ShapeQuestion.generate(stage, rng);
          expect(q.choices.length, stage.choiceCount);
          expect(
            q.choices.map((c) => c.shape).toSet().length,
            stage.choiceCount,
            reason: '같은 모양이 두 번 나오지 않는다',
          );
          expect(q.answerIndex, inInclusiveRange(0, q.choices.length - 1));
          for (final c in q.choices) {
            expect(stage.shapes, contains(c.shape));
            expect(stage.colors.map((g) => g.id), contains(c.color.id));
          }
        }
      }
    });

    test('1단계는 쉬운 세 모양, 보기 2개, 견본은 처음에 숨김', () {
      final s = Stages.shape.first;
      expect(s.shapes.toSet(), {
        ShapeKind.circle,
        ShapeKind.triangle,
        ShapeKind.square,
      });
      expect(s.choiceCount, 2);
      expect(s.showsSample, isFalse);
      final r = ShapeRound(ShapeQuestion.generate(s, Random(1)));
      expect(r.showSample, isFalse, reason: '처음부터 견본이 보이면 그림만 맞춰도 풀린다');
    });

    test('이름 단계: 처음엔 견본 없음 → 한 번 틀리면 정답과 다른 색 견본 → 두 번 틀리면 정답 빛남', () {
      for (final stage in Stages.shape.where((s) => !s.matchSample)) {
        final rng = Random(stage.id + 40);
        for (var k = 0; k < 50; k++) {
          final r = ShapeRound(ShapeQuestion.generate(stage, rng));
          final q = r.question;
          expect(q.matchSample, isFalse);
          expect(r.showSample, isFalse, reason: '${stage.id}단계: 처음엔 견본 없음');
          final wrong = [
            for (var i = 0; i < q.choices.length; i++)
              if (i != q.answerIndex) i,
          ];
          expect(r.answer(wrong.first), AnswerOutcome.wrong);
          expect(r.showSample, isTrue, reason: '한 번 틀리면 견본 힌트');
          expect(r.highlightAnswer, isFalse);
          // 견본 색은 정답 보기와 (다른 보기들과도) 다르다
          for (final c in q.choices) {
            expect(q.sampleColor.id, isNot(c.color.id));
          }
          expect(q.sampleColor.id, isNot(q.target.color.id));
          if (wrong.length > 1) {
            expect(r.answer(wrong[1]), AnswerOutcome.wrong);
            expect(r.highlightAnswer, isTrue, reason: '두 번 틀리면 정답이 빛남');
          }
        }
      }
    });

    test('견본 찾기 단계: 견본은 처음부터 있고 정답 보기와 다른 색', () {
      final stage = Stages.shape.firstWhere((s) => s.matchSample);
      expect(stage.showsSample, isTrue);
      final rng = Random(7);
      for (var k = 0; k < 100; k++) {
        final r = ShapeRound(ShapeQuestion.generate(stage, rng));
        expect(r.showSample, isTrue);
        expect(r.question.sampleColor.id, isNot(r.question.target.color.id));
        for (final c in r.question.choices) {
          expect(r.question.sampleColor.id, isNot(c.color.id));
        }
      }
    });

    test('단계가 오르면: 같은 색 → 회전 → 견본과 같은 모양', () {
      final st = Stages.shape;
      expect(st[0].sameColor || st[1].sameColor, isFalse);
      expect(st[2].sameColor, isTrue);
      expect(st[3].rotate, isTrue);
      expect(st[4].matchSample, isTrue);
      for (var i = 1; i < st.length; i++) {
        expect(st[i].choiceCount, greaterThanOrEqualTo(st[i - 1].choiceCount));
      }
    });

    test('색이 다른 단계는 보기 색이 모두 다르고, 같은 색 단계는 모두 같다', () {
      for (final stage in Stages.shape) {
        final rng = Random(stage.id + 10);
        for (var k = 0; k < 100; k++) {
          final q = ShapeQuestion.generate(stage, rng);
          final colors = q.choices.map((c) => c.color.id).toSet();
          expect(colors.length, stage.sameColor ? 1 : q.choices.length);
        }
      }
    });

    test('회전: 돌리는 단계만 기울이고, 네모·다이아는 조금만 (서로 헷갈리지 않게)', () {
      for (final stage in Stages.shape) {
        final rng = Random(stage.id + 20);
        for (var k = 0; k < 100; k++) {
          for (final c in ShapeQuestion.generate(stage, rng).choices) {
            if (!stage.rotate || c.shape == ShapeKind.circle) {
              expect(c.angle, 0);
              continue;
            }
            expect(c.angle, isNot(0));
            if (c.shape == ShapeKind.square || c.shape == ShapeKind.diamond) {
              expect(c.angle.abs(), lessThanOrEqualTo(20));
            } else {
              expect(c.angle.abs(), lessThanOrEqualTo(40));
            }
          }
        }
      }
    });

    test('견본 찾기: 견본은 보기와 다른 색, "똑같은 모양" 으로 묻는다', () {
      final stage = Stages.shape.last;
      final rng = Random(3);
      for (var k = 0; k < 100; k++) {
        final q = ShapeQuestion.generate(stage, rng);
        expect(q.matchSample, isTrue);
        expect(q.prompt, '똑같은 모양을 찾아볼까요?');
        expect(q.sampleColor.id, isNot(q.target.color.id));
      }
    });

    test('바로 앞 문제와 같은 모양을 정답으로 내지 않는다', () {
      for (final stage in Stages.shape) {
        final rng = Random(stage.id + 30);
        ShapeQuestion? prev;
        for (var k = 0; k < 200; k++) {
          final q = ShapeQuestion.generate(stage, rng, previous: prev);
          if (prev != null) expect(q.shape, isNot(prev.shape));
          prev = q;
        }
      }
    });

    test('문장: 받침에 맞는 조사', () {
      expect(ShapeKind.circle.object, '동그라미를');
      expect(ShapeKind.star.object, '별을');
      expect(ShapeKind.triangle.thisIs, '이건 세모예요.');
      expect(ShapeKind.star.thisIs, '이건 별이에요.');
      final q = ShapeQuestion(
        choices: const [
          ShapeChoice(ShapeKind.heart, GameColor.red),
          ShapeChoice(ShapeKind.star, GameColor.blue),
        ],
        answerIndex: 0,
        sampleColor: GameColor.red,
        matchSample: false,
      );
      expect(q.prompt, '하트를 찾아볼까요?');
      expect(q.wrongLine(1), '이건 별이에요. 하트를 다시 찾아볼까요?');
      expect(q.praise, '하트! 정말 잘했어요!');
    });

    test('한 문제: 한 번 틀리면 견본 힌트, 두 번 틀리면 정답이 빛난다', () {
      final stage = Stages.shape[1]; // 견본은 힌트로만
      final r = ShapeRound(ShapeQuestion.generate(stage, Random(4)));
      final wrong = [
        for (var i = 0; i < r.question.choices.length; i++)
          if (i != r.question.answerIndex) i,
      ];
      expect(r.showSample, isFalse);
      expect(r.answer(wrong[0]), AnswerOutcome.wrong);
      expect(r.showSample, isTrue);
      expect(r.highlightAnswer, isFalse);
      expect(r.isDisabled(wrong[0]), isTrue, reason: '틀린 보기는 흐려진다');
      expect(r.answer(wrong[0]), AnswerOutcome.ignored);
      expect(r.answer(wrong[1]), AnswerOutcome.wrong);
      expect(r.highlightAnswer, isTrue);
      expect(r.firstTry, isFalse);
      expect(r.answer(r.question.answerIndex), AnswerOutcome.correct);
      expect(r.solved, isTrue);
      expect(r.answer(r.question.answerIndex), AnswerOutcome.ignored);
      expect(r.answer(-1), AnswerOutcome.ignored);
    });
  });

  group('크기 놀이', () {
    test('크기 목록: 가장 큰 것이 1이고 점점 작아진다', () {
      for (final stage in Stages.size) {
        final s = stage.scales;
        expect(s.length, stage.choiceCount);
        expect(s.first, 1.0);
        expect(s.last, closeTo(stage.smallest, 1e-9));
        for (var i = 1; i < s.length; i++) {
          expect(s[i], lessThan(s[i - 1]));
        }
      }
    });

    test('단계가 오를수록 크기 차이가 줄어든다', () {
      final ratios = [for (final s in Stages.size) s.stepRatio];
      for (var i = 1; i < ratios.length; i++) {
        expect(ratios[i], lessThan(ratios[i - 1]), reason: '${i + 1}단계');
      }
      expect(ratios.last, greaterThan(1.15), reason: '아이 눈으로 구분할 수는 있어야');
    });

    test('보기 3개 이상이면 "가장 큰 / 가장 작은"으로 묻는다', () {
      for (final stage in Stages.size) {
        final rng = Random(stage.id);
        for (var k = 0; k < 100; k++) {
          final q = SizeQuestion.generate(stage, rng);
          expect(q.superlative, stage.choiceCount >= 3);
          expect(q.prompt.startsWith('가장 '), stage.choiceCount >= 3);
          expect(q.prompt, contains(q.ask.adjective));
          expect(q.prompt, contains(q.kind.object));
        }
      }
      expect(Stages.size.any((s) => s.choiceCount >= 3), isTrue);
      expect(Stages.size.first.choiceCount, 2);
    });

    test('정답은 가장 큰(작은) 물건, 같은 물건·같은 색', () {
      for (final stage in Stages.size) {
        final rng = Random(stage.id + 5);
        final asks = <SizeAsk>{};
        for (var k = 0; k < 200; k++) {
          final q = SizeQuestion.generate(stage, rng);
          asks.add(q.ask);
          final target = q.scales[q.answerIndex];
          expect(
            target,
            q.ask == SizeAsk.big ? q.scales.reduce(max) : q.scales.reduce(min),
          );
          expect(q.scales.toSet().length, q.scales.length, reason: '같은 크기 없음');
          expect(stage.objects, contains(q.kind));
          expect(stage.colors.map((c) => c.id), contains(q.color.id));
        }
        expect(asks, SizeAsk.values.toSet(), reason: '큰 것·작은 것 모두 묻는다');
      }
    });

    test('바로 앞 문제와 다른 물건', () {
      final stage = Stages.size[2];
      final rng = Random(8);
      SizeQuestion? prev;
      for (var k = 0; k < 200; k++) {
        final q = SizeQuestion.generate(stage, rng, previous: prev);
        if (prev != null) expect(q.kind, isNot(prev.kind));
        prev = q;
      }
    });

    test('문장', () {
      final q = SizeQuestion(
        kind: ObjectKind.apple,
        color: GameColor.red,
        scales: const [1, .5],
        ask: SizeAsk.big,
        superlative: false,
      );
      expect(q.prompt, '큰 사과를 찾아볼까요?');
      expect(q.wrongLine, '큰 사과를 다시 찾아볼까요?');
      expect(q.answerIndex, 0);
      final q3 = SizeQuestion(
        kind: ObjectKind.star,
        color: GameColor.blue,
        scales: const [.7, 1, .5],
        ask: SizeAsk.small,
        superlative: true,
      );
      expect(q3.prompt, '가장 작은 별을 찾아볼까요?');
      expect(q3.answerIndex, 2);
    });

    test('한 문제: 한 번 틀리면 그림 힌트, 두 번 틀리면 정답이 빛난다', () {
      final r = SizeRound(SizeQuestion.generate(Stages.size[4], Random(2)));
      final wrong = [
        for (var i = 0; i < r.question.scales.length; i++)
          if (i != r.question.answerIndex) i,
      ];
      expect(r.showHint, isFalse);
      expect(r.answer(wrong[0]), AnswerOutcome.wrong);
      expect(r.showHint, isTrue);
      expect(r.highlightAnswer, isFalse);
      expect(r.answer(wrong[1]), AnswerOutcome.wrong);
      expect(r.highlightAnswer, isTrue);
      expect(r.answer(r.question.answerIndex), AnswerOutcome.correct);
      expect(r.firstTry, isFalse);
      expect(r.isDisabled(r.question.answerIndex), isTrue);
    });
  });

  group('짝 맞추기', () {
    test('단계별 2→2→3→3→4쌍 (최대 4쌍), 한 판 3장', () {
      expect([for (final s in Stages.match) s.pairs], [2, 2, 3, 3, 4]);
      expect(Stages.match.every((s) => s.pairs <= 4), isTrue);
      expect(Economy.matchQuestionsPerSession, 3);
      expect(Economy.questionsPerSession, 5, reason: '다른 놀이는 그대로 5문제');
      expect(Stages.match.last.colorVariant, isTrue);
      expect(Stages.match.take(4).any((s) => s.colorVariant), isFalse);
    });

    test('판: 같은 그림이 꼭 두 장씩, 짝마다 그림이 다르다', () {
      for (final stage in Stages.match) {
        final rng = Random(stage.id);
        for (var k = 0; k < 100; k++) {
          final b = MatchBoard.generate(stage, rng);
          expect(b.cards.length, stage.cardCount);
          expect(b.pairs, stage.pairs);
          final faces = <String, int>{};
          for (final c in b.cards) {
            final key = '${c.kind.name}/${c.color.id}';
            faces[key] = (faces[key] ?? 0) + 1;
          }
          expect(faces.length, stage.pairs, reason: '짝끼리 그림이 겹치지 않는다');
          expect(faces.values.every((n) => n == 2), isTrue);
          for (var i = 0; i < b.cards.length; i++) {
            final t = b.twinOf(i);
            expect(t, isNot(i));
            expect(b.cards[t].pair, b.cards[i].pair);
          }
        }
      }
    });

    test('1~4단계는 물건이 서로 다르고, 마지막 단계는 같은 물건 다른 색', () {
      for (final stage in Stages.match) {
        final b = MatchBoard.generate(stage, Random(stage.id + 3));
        final kinds = b.cards.map((c) => c.kind).toSet();
        final colors = b.cards.map((c) => c.color.id).toSet();
        if (stage.colorVariant) {
          expect(kinds.length, 1);
          expect(colors.length, stage.pairs);
        } else {
          expect(kinds.length, stage.pairs);
        }
      }
    });

    test('2단계는 1단계와 다른 물건으로 시작한다', () {
      final first = Stages.match[0].objects.toSet();
      expect(Stages.match[1].objects.toSet().intersection(first), isEmpty);
    });

    test('5단계: 같은 물건, 서로 다른 색 4가지, 색을 바꿀 수 있는 물건만', () {
      final stage = Stages.match.last;
      expect(stage.objects.every((k) => k.tintable), isTrue);
      final rng = Random(12);
      for (var k = 0; k < 100; k++) {
        final b = MatchBoard.generate(stage, rng);
        final kinds = b.cards.map((c) => c.kind).toSet();
        expect(kinds.length, 1);
        expect(kinds.single.tintable, isTrue);
        expect(b.cards.map((c) => c.color.id).toSet().length, 4);
        expect(b.colorVariant, isTrue);
      }
    });

    test('마지막 단계는 앞 판과 다른 물건으로', () {
      final stage = Stages.match.last;
      final rng = Random(4);
      MatchBoard? prev;
      for (var k = 0; k < 50; k++) {
        final b = MatchBoard.generate(stage, rng, previous: prev);
        if (prev != null) {
          expect(b.cards.first.kind, isNot(prev.cards.first.kind));
        }
        prev = b;
      }
    });

    MatchRound roundOf(List<int> pairs) => MatchRound(
      MatchBoard(
        cards: [
          for (final p in pairs)
            MatchCard(p, ObjectKind.values[p], GameColor.all[p]),
        ],
        colorVariant: false,
      ),
    );

    test('차례로 두 장: 고르기 → 짝 → 끝', () {
      final r = roundOf([0, 1, 0, 1]);
      expect(r.pick(0), MatchOutcome.selected);
      expect(r.selected, 0);
      expect(r.pick(0), MatchOutcome.ignored, reason: '같은 카드를 또 눌러도 그대로');
      expect(r.pick(2), MatchOutcome.matched);
      expect(r.selected, isNull);
      expect(r.matched, {0, 2});
      expect(r.pick(2), MatchOutcome.ignored, reason: '맞춘 카드는 끝');
      expect(r.pick(1), MatchOutcome.selected);
      expect(r.pick(3), MatchOutcome.finished);
      expect(r.solved, isTrue);
      expect(r.firstTry, isTrue);
      expect(r.pick(0), MatchOutcome.ignored);
    });

    test('틀리면 그 카드가 흐려지고 힌트, 두 번 틀리면 짝이 빛난다', () {
      final r = roundOf([0, 1, 2, 0, 1, 2]);
      r.pick(0);
      expect(r.showHint, isFalse);
      expect(r.pick(1), MatchOutcome.wrong);
      expect(r.selected, 0, reason: '첫 장은 골라 둔 채로 다시 찾는다');
      expect(r.showHint, isTrue);
      expect(r.isDisabled(1), isTrue);
      expect(r.glowIndex, isNull);
      expect(r.pick(1), MatchOutcome.ignored);
      expect(r.pick(2), MatchOutcome.wrong);
      expect(r.glowIndex, 3);
      expect(r.pick(3), MatchOutcome.matched);
      expect(r.wrongPicks, isEmpty, reason: '짝을 찾으면 흐림이 풀린다');
      expect(r.isDisabled(1), isFalse);
      expect(r.showHint, isFalse);
      expect(r.mistakes, 2);
      expect(r.firstTry, isFalse);
    });

    test('문장: 이름·색 이름', () {
      final b = MatchBoard(
        cards: const [
          MatchCard(0, ObjectKind.apple, GameColor.red),
          MatchCard(0, ObjectKind.apple, GameColor.red),
        ],
        colorVariant: false,
      );
      expect(b.pickedLine(0), '사과! 똑같은 사과를 찾아볼까요?');
      expect(b.wrongLine(0), '똑같은 사과를 다시 찾아볼까요?');
      expect(b.matchedLine(1), '사과! 똑같아요!');
      final c = MatchBoard(cards: b.cards, colorVariant: true);
      expect(c.pickedLine(0), '빨간 사과! 똑같은 빨간 사과를 찾아볼까요?');
    });
  });

  group('보기 격자', () {
    test('작은 휴대폰에서도 카드 12장이 60px 이상, 가로 밀기 없음', () {
      final g = TileGrid.fit(12, const Size(442, 136), gap: 10);
      expect(g.rows * g.cols, greaterThanOrEqualTo(12));
      expect(g.tile, greaterThanOrEqualTo(60));
      expect(g.cols * g.tile + (g.cols - 1) * 10, lessThanOrEqualTo(442));
      expect(g.rows * g.tile + (g.rows - 1) * 10, lessThanOrEqualTo(136));
    });

    test('넓은 화면에서 보기 4개는 한 줄', () {
      final g = TileGrid.fit(4, const Size(900, 300));
      expect(g.rows, 1);
      expect(g.cols, 4);
      final big = TileGrid.fit(2, const Size(2000, 2000), maxTile: 230);
      expect(big.tile, 230, reason: '한계를 주면 그보다 커지지 않는다');
    });
  });

  group('진입과 저장', () {
    test('놀이 종류 값 하나로 화면을 연다', () {
      expect(gameScreen(GameKind.number, 1), isA<NumberGameScreen>());
      expect(gameScreen(GameKind.color, 1), isA<ColorGameScreen>());
      expect(gameScreen(GameKind.shape, 2), isA<ShapeGameScreen>());
      expect(gameScreen(GameKind.size, 3), isA<SizeGameScreen>());
      expect(gameScreen(GameKind.match, 4), isA<MatchGameScreen>());
      expect((gameScreen(GameKind.shape, 2) as ShapeGameScreen).stageId, 2);
      expect(
        GameKind.values.map((k) => k.name),
        containsAll(['shape', 'size', 'match']),
      );
      expect(GameKind.shape.title, '모양 놀이');
      expect(GameKind.size.title, '크기 놀이');
      expect(GameKind.match.title, '짝 맞추기');
      expect(stageArt(GameKind.shape, 1), isNotNull);
      expect(stageArt(GameKind.number, 1), isNull);
    });

    test('놀이 종류별로 깬 단계·열린 단계를 따로 저장', () async {
      final storage = MemoryStorage();
      final a = GameState(storage: storage, audio: RecordingAudio());
      await a.load();
      final r = await a.completeSession(GameKind.shape, 1);
      expect(r.unlockedStage, 2);
      expect(r.newStage, Economy.newStageBonus);
      await a.completeSession(GameKind.match, 1);
      await a.completeSession(GameKind.match, 2);
      expect(a.unlockedStage(GameKind.shape), 2);
      expect(a.unlockedStage(GameKind.size), 1);
      expect(a.unlockedStage(GameKind.match), 3);
      expect(a.unlockedStage(GameKind.number), 1, reason: '다른 놀이는 그대로');
      expect(a.unlockedStage(GameKind.color), 1);

      final b = GameState(storage: storage, audio: RecordingAudio());
      await b.load();
      expect(b.unlockedStage(GameKind.shape), 2);
      expect(b.clearedStages(GameKind.shape), {1});
      expect(b.clearedStages(GameKind.match), {1, 2});
      expect(b.clearedStages(GameKind.size), isEmpty);
    });

    test('마지막 단계를 깨도 단계 수를 넘지 않는다', () async {
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      for (var i = 1; i <= 5; i++) {
        await s.completeSession(GameKind.size, i);
      }
      expect(s.unlockedStage(GameKind.size), 5);
      expect(s.clearedStages(GameKind.size), {1, 2, 3, 4, 5});
    });

    test('저장 형식: 새 항목만 더했고 버전은 그대로', () {
      // 놀이 트랙은 버전을 올리지 않는다. 버전 번호는 안전·저장 트랙 담당 (v6)
      expect(SaveData.currentVersion, 6);
      final d = SaveData.initial()
        ..shapeStageUnlocked = 3
        ..shapeStageCleared = {1, 2}
        ..sizeStageUnlocked = 2
        ..sizeStageCleared = {1}
        ..matchStageUnlocked = 5
        ..matchStageCleared = {1, 2, 3, 4};
      final back = SaveData.decode(d.encode());
      expect(back.shapeStageUnlocked, 3);
      expect(back.shapeStageCleared, {1, 2});
      expect(back.sizeStageUnlocked, 2);
      expect(back.sizeStageCleared, {1});
      expect(back.matchStageUnlocked, 5);
      expect(back.matchStageCleared, {1, 2, 3, 4});
    });

    test('예전 저장값(새 항목 없음)은 1단계부터, 깨진 값은 걸러낸다', () {
      final old = SaveData.decode(
        jsonEncode({'version': 5, 'numberStageUnlocked': 3, 'coins': 40}),
      );
      expect(old.numberStageUnlocked, 3);
      expect(old.shapeStageUnlocked, 1);
      expect(old.matchStageCleared, isEmpty);
      final bad = SaveData.decode(
        jsonEncode({
          'version': 5,
          'shapeStageUnlocked': 99,
          'sizeStageUnlocked': 'x',
          'matchStageCleared': [0, 1, 6, 'a', 3],
        }),
      );
      expect(bad.shapeStageUnlocked, 1);
      expect(bad.sizeStageUnlocked, 1);
      expect(bad.matchStageCleared, {1, 3});
    });
  });

  group('녹음 음성 조각', () {
    final lines = VoiceLines.all();
    final pack = VoicePack({
      for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3',
    });

    test('새 놀이의 모든 문장이 녹음 조각으로 나눠진다 (문장 목록 내보내기에 포함)', () {
      final samples = <String>[
        '모양 놀이를 해 볼까요?',
        '크기 놀이를 해 볼까요?',
        '짝 맞추기를 해 볼까요?',
        MatchBoard.prompt,
      ];
      for (final stage in Stages.shape) {
        final rng = Random(stage.id);
        for (var k = 0; k < 100; k++) {
          final q = ShapeQuestion.generate(stage, rng);
          samples
            ..add(q.prompt)
            ..add(q.praise);
          for (var i = 0; i < q.choices.length; i++) {
            if (i != q.answerIndex) samples.add(q.wrongLine(i));
          }
        }
      }
      for (final stage in Stages.size) {
        final rng = Random(stage.id);
        for (var k = 0; k < 100; k++) {
          final q = SizeQuestion.generate(stage, rng);
          samples
            ..add(q.prompt)
            ..add(q.wrongLine)
            ..add(q.praise);
        }
      }
      for (final stage in Stages.match) {
        final rng = Random(stage.id);
        for (var k = 0; k < 30; k++) {
          final b = MatchBoard.generate(stage, rng);
          for (var i = 0; i < b.cards.length; i++) {
            samples
              ..add(b.pickedLine(i))
              ..add(b.wrongLine(i))
              ..add('${b.matchedLine(i)} 정말 잘했어요!');
          }
        }
      }
      for (final t in samples) {
        expect(pack.plan(t), isNotNull, reason: t);
      }
      expect(lines.toSet().length, lines.length, reason: '중복 없음');
    });
  });
}
