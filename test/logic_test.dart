import 'dart:math';

import 'package:alokdalok/character/nickname.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/common/korean_numbers.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('숫자 문제', () {
    test('모든 단계에서 정답이 보기에 있고, 범위 안이고, 보기가 서로 다르다', () {
      for (final stage in Stages.number) {
        final rng = Random(stage.id);
        NumberQuestion? prev;
        for (var i = 0; i < 500; i++) {
          final q = NumberQuestion.generate(stage, rng, previous: prev);
          expect(q.choices, contains(q.count));
          expect(q.count, inInclusiveRange(stage.min, stage.max));
          expect(q.choices.length, stage.choiceCount);
          expect(q.choices.toSet().length, q.choices.length);
          expect(
            q.choices.every((c) => c >= stage.min && c <= stage.max),
            isTrue,
          );
          expect(q.choices, orderedEquals([...q.choices]..sort()));
          expect(stage.objects, contains(q.kind));
          prev = q;
        }
      }
    });

    test('4단계부터: 흩어 놓은 물건 중 세는 물건 수가 정답과 같고, 헷갈리는 물건이 섞여 있다', () {
      final scattered = Stages.number.where((s) => s.scattered).toList();
      expect(scattered.length, greaterThanOrEqualTo(5));
      expect(Stages.number.take(3).every((s) => !s.scattered), isTrue);
      for (final stage in scattered) {
        final rng = Random(stage.id * 31);
        for (var i = 0; i < 400; i++) {
          final q = NumberQuestion.generate(stage, rng);
          final targets = q.scene.where((o) => o.target).toList();
          final others = q.scene.where((o) => !o.target).toList();
          expect(targets.length, q.count);
          expect(q.targetsInOrder.length, q.count);
          expect(others, isNotEmpty, reason: '섞여 있어야 세는 연습이 된다');
          expect(q.scene.length, lessThanOrEqualTo(stage.totalMax));
          for (final o in targets) {
            expect(o.kind, q.kind);
            expect(o.color?.id, q.color?.id);
          }
          // 헷갈리는 물건은 세는 물건과 (사물, 색) 중 하나라도 달라야 한다
          for (final o in others) {
            expect(o.kind != q.kind || o.color?.id != q.color?.id, isTrue);
          }
          switch (stage.mode) {
            case NumberMode.mixKinds:
              expect(q.color, isNull);
              expect(
                q.scene.map((o) => o.kind).toSet().length,
                stage.kindsShown,
              );
            case NumberMode.mixColors:
              expect(q.color, isNotNull);
              expect(q.scene.map((o) => o.kind).toSet(), {q.kind});
            case NumberMode.mixBoth:
              expect(q.color, isNotNull);
              expect(others.any((o) => o.kind == q.kind), isTrue);
              expect(others.any((o) => o.color?.id == q.color!.id), isTrue);
            case NumberMode.single:
              fail('흩어 놓는 단계');
          }
          // 화면 안에 있고 서로 칸이 겹치지 않는다
          final cells = <(int, int)>{};
          for (final o in q.scene) {
            expect(o.x, inInclusiveRange(0, 1));
            expect(o.y, inInclusiveRange(0, 1));
            cells.add(((o.x * q.cols).floor(), (o.y * q.rows).floor()));
          }
          expect(cells.length, q.scene.length);
        }
      }
    });

    test('섞인 문제 문구: "빨간 풍선은 몇 개", "오리는 몇 마리"', () {
      final balloons = NumberQuestion(
        kind: ObjectKind.balloon,
        color: GameColor.red,
        count: 2,
        choices: const [1, 2, 3],
        scene: const [
          SceneObject(
            kind: ObjectKind.balloon,
            color: GameColor.red,
            x: .1,
            y: .1,
            target: true,
          ),
          SceneObject(
            kind: ObjectKind.balloon,
            color: GameColor.red,
            x: .5,
            y: .1,
            target: true,
          ),
          SceneObject(
            kind: ObjectKind.balloon,
            color: GameColor.blue,
            x: .9,
            y: .1,
            target: false,
          ),
        ],
      );
      expect(balloons.prompt, '빨간 풍선은 몇 개 있을까요?');
      expect(balloons.answerLine, '빨간 풍선이 두 개!');
      final ducks = NumberQuestion(
        kind: ObjectKind.duck,
        count: 1,
        choices: const [1, 2, 3],
        scene: const [
          SceneObject(
            kind: ObjectKind.duck,
            color: null,
            x: .1,
            y: .1,
            target: true,
          ),
          SceneObject(
            kind: ObjectKind.apple,
            color: null,
            x: .5,
            y: .5,
            target: false,
          ),
        ],
      );
      expect(ducks.prompt, '오리는 몇 마리 있을까요?');
      expect(ducks.answerLine, '오리가 한 마리!');
      final stars = NumberQuestion(
        kind: ObjectKind.star,
        count: 3,
        choices: const [2, 3, 4],
      );
      expect(stars.answerLine, '별이 세 개!');
    });

    test('정답이면 correct, 오답이면 wrong, 오답 보기는 다시 누를 수 없다', () {
      final round = NumberRound(
        NumberQuestion(kind: ObjectKind.apple, count: 2, choices: [1, 2, 3]),
      );
      expect(round.showHint, isFalse);
      expect(round.answer(3), AnswerOutcome.wrong);
      expect(round.firstTry, isFalse);
      expect(round.showHint, isTrue, reason: '한 번 틀리면 같이 세기 힌트');
      expect(round.answer(3), AnswerOutcome.ignored);
      expect(round.isDisabled(3), isTrue);
      expect(round.answer(2), AnswerOutcome.correct);
      expect(round.answer(1), AnswerOutcome.ignored, reason: '맞힌 뒤에는 입력 무시');
    });

    test('보기에 없는 값은 무시', () {
      final round = NumberRound(
        NumberQuestion(kind: ObjectKind.car, count: 1, choices: [1, 2, 3]),
      );
      expect(round.answer(9), AnswerOutcome.ignored);
      expect(round.firstTry, isTrue);
    });

    test('틀린 보기가 줄어들어 무한 반복 없이 반드시 끝난다', () {
      final rng = Random(3);
      for (final stage in Stages.number) {
        final q = NumberQuestion.generate(stage, rng);
        final round = NumberRound(q);
        var taps = 0;
        for (final c in q.choices) {
          taps++;
          if (round.answer(c) == AnswerOutcome.correct) break;
        }
        expect(round.solved, isTrue);
        expect(taps, lessThanOrEqualTo(q.choices.length));
      }
    });

    test('문구: 동물은 마리, 나머지는 개 / 받침에 맞는 조사', () {
      expect(
        NumberQuestion(
          kind: ObjectKind.apple,
          count: 2,
          choices: [1, 2],
        ).prompt,
        '사과가 몇 개 있을까요?',
      );
      expect(
        NumberQuestion(kind: ObjectKind.star, count: 2, choices: [1, 2]).prompt,
        '별이 몇 개 있을까요?',
      );
      expect(
        NumberQuestion(kind: ObjectKind.duck, count: 2, choices: [1, 2]).prompt,
        '오리가 몇 마리 있을까요?',
      );
      expect(KoreanNumbers.pieces(3), '세 개');
      expect(KoreanNumbers.pieces(2, '마리'), '두 마리');
      expect(KoreanNumbers.countUpTo(3), '하나, 둘, 셋');
    });
  });

  group('색깔 문제', () {
    test('정답 색은 단계 색 중 하나이고, 보기 색이 겹치지 않는다', () {
      for (final stage in Stages.color) {
        final rng = Random(stage.id * 7);
        ColorQuestion? prev;
        for (var i = 0; i < 300; i++) {
          final q = ColorQuestion.generate(stage, rng, previous: prev);
          expect(q.choices.length, stage.choiceCount);
          expect(
            q.choices.map((c) => c.color.id).toSet().length,
            stage.choiceCount,
          );
          expect(stage.colors, contains(q.target.color));
          if (!stage.mixedShapes) {
            expect(
              q.choices.map((c) => c.kind).toSet().length,
              1,
              reason: '같은 모양이면 색으로만 구분',
            );
          }
          if (prev != null) {
            expect(q.target.color.id, isNot(prev.target.color.id));
          }
          prev = q;
        }
      }
    });

    test('정답 판정과 힌트', () {
      final q = ColorQuestion(
        choices: const [
          ColorChoice(ObjectKind.car, GameColor.blue),
          ColorChoice(ObjectKind.car, GameColor.red),
          ColorChoice(ObjectKind.car, GameColor.yellow),
        ],
        answerIndex: 1,
      );
      expect(q.prompt, '빨간 자동차를 찾아볼까요?');
      final round = ColorRound(q, swatchFromStart: false);
      expect(round.showSwatch, isFalse);
      expect(round.answer(0), AnswerOutcome.wrong);
      expect(round.showSwatch, isTrue, reason: '한 번 틀리면 색 견본 힌트');
      expect(round.highlightAnswer, isFalse);
      expect(round.answer(2), AnswerOutcome.wrong);
      expect(round.highlightAnswer, isTrue, reason: '두 번 틀리면 정답 반짝임');
      expect(round.answer(1), AnswerOutcome.correct);
      expect(round.firstTry, isFalse);
    });

    test('범위를 벗어난 입력은 무시', () {
      final q = ColorQuestion(
        choices: const [ColorChoice(ObjectKind.ball, GameColor.red)],
        answerIndex: 0,
      );
      final round = ColorRound(q, swatchFromStart: true);
      expect(round.answer(5), AnswerOutcome.ignored);
      expect(round.answer(-1), AnswerOutcome.ignored);
      expect(round.showSwatch, isTrue);
    });
  });

  group('닉네임 검증', () {
    test('허용', () {
      for (final ok in ['별이', '구름이', 'Momo', '토리7', '가나다라마바사아']) {
        expect(Nickname.validate(ok), isNull, reason: ok);
      }
      for (final s in Nickname.randomPool) {
        expect(Nickname.isValid(s), isTrue, reason: s);
      }
      expect(Nickname.isValid(Nickname.fallback), isTrue);
    });

    test('길이·공백·특수문자·이모지·자모 단독·금지어 차단', () {
      expect(Nickname.validate(''), isNotNull);
      expect(Nickname.validate('   '), isNotNull);
      expect(Nickname.validate(null), isNotNull);
      expect(Nickname.validate('가나다라마바사아자'), isNotNull, reason: '9글자');
      expect(Nickname.validate('별 이'), isNotNull);
      expect(Nickname.validate('별이!'), isNotNull);
      expect(Nickname.validate('별이😀'), isNotNull);
      expect(Nickname.validate('ㅎㅎ'), isNotNull);
      expect(Nickname.validate('바보야'), isNotNull);
      expect(Nickname.validate('SHIT'), isNotNull, reason: '대소문자 무관');
    });

    test('저장값 손상 시 기본값 복구', () {
      expect(Nickname.sanitize(null), Nickname.fallback);
      expect(Nickname.sanitize(123), Nickname.fallback);
      expect(Nickname.sanitize('별 이!'), Nickname.fallback);
      expect(Nickname.sanitize('콩이'), '콩이');
    });
  });

  group('목소리 고르기', () {
    test('부드러운 여성 목소리를 남성 목소리보다 먼저 고른다', () {
      expect(
        DeviceAudio.voiceScore('Microsoft SunHi Online (Natural) - Korean'),
        greaterThan(
          DeviceAudio.voiceScore('Microsoft InJoon Online (Natural) - Korean'),
        ),
      );
      expect(
        DeviceAudio.voiceScore('Google 한국의'),
        greaterThan(DeviceAudio.voiceScore('Microsoft Heami - Korean')),
      );
      expect(
        DeviceAudio.voiceScore('ko-kr-x-ism-local'),
        greaterThan(DeviceAudio.voiceScore('ko-kr-x-koc-local')),
      );
      expect(DeviceAudio.voiceScore('Yuna'), greaterThan(0));
    });
  });
}
