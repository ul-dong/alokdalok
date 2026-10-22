import 'dart:math';

import '../../core/economy.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../number_game/number_round.dart' show AnswerOutcome;

export '../number_game/number_round.dart' show AnswerOutcome;

/// 모양 보기 하나: 모양 + 색 + 기울기(도)
class ShapeChoice {
  const ShapeChoice(this.shape, this.color, {this.angle = 0});
  final ShapeKind shape;
  final GameColor color;

  /// 시계 방향 기울기 (도). 0이면 바로 놓음.
  final double angle;
}

/// 모양 문제 한 개.
class ShapeQuestion {
  ShapeQuestion({
    required this.choices,
    required this.answerIndex,
    required this.sampleColor,
    required this.matchSample,
  });

  final List<ShapeChoice> choices;
  final int answerIndex;

  /// 견본을 칠할 색. 늘 정답 보기와 다른 색이라 색만 보고 고를 수 없다.
  /// (이름 단계의 힌트 견본은 회색, 견본 찾기 단계는 보기와 다른 색)
  final GameColor sampleColor;

  /// true면 견본을 보고 "똑같은 모양"을 찾는다
  final bool matchSample;

  ShapeChoice get target => choices[answerIndex];
  ShapeKind get shape => target.shape;

  /// 예: "동그라미를 찾아볼까요?" / "똑같은 모양을 찾아볼까요?"
  String get prompt =>
      matchSample ? '똑같은 모양을 찾아볼까요?' : '${shape.object} 찾아볼까요?';

  /// 틀렸을 때: "이건 세모예요. 동그라미를 다시 찾아볼까요?"
  String wrongLine(int picked) {
    final p = choices[picked].shape;
    return '${p.thisIs} ${shape.object} 다시 찾아볼까요?';
  }

  /// 맞혔을 때: "동그라미! 정말 잘했어요!"
  String get praise => '${shape.ko}! 정말 잘했어요!';

  /// 기울기 후보: 네모·다이아는 조금만 (많이 돌리면 서로 닮아 보인다)
  static const _smallTilt = [-18.0, -12.0, 12.0, 18.0];
  static const _bigTilt = [-35.0, -25.0, 25.0, 35.0];

  static double tiltFor(ShapeKind s, Random rng) {
    if (s.rotationFree) return 0;
    final list = (s == ShapeKind.square || s == ShapeKind.diamond)
        ? _smallTilt
        : _bigTilt;
    return list[rng.nextInt(list.length)];
  }

  static ShapeQuestion generate(
    ShapeStage stage,
    Random rng, {
    ShapeQuestion? previous,
  }) {
    final shapes = [...stage.shapes]..shuffle(rng);
    // 바로 앞 문제와 같은 모양을 정답으로 내지 않는다
    if (previous != null &&
        shapes.first == previous.shape &&
        shapes.length > 1) {
      shapes.add(shapes.removeAt(0));
    }
    final picked = shapes.take(stage.choiceCount).toList();

    final colors = [...stage.colors]..shuffle(rng);
    final same = colors.first;
    final choices = <ShapeChoice>[
      for (var i = 0; i < picked.length; i++)
        ShapeChoice(
          picked[i],
          stage.sameColor ? same : colors[i % colors.length],
          angle: stage.rotate ? tiltFor(picked[i], rng) : 0,
        ),
    ];
    // 견본 색: 정답 보기와 같은 색이면 그림만 맞춰 보고 고를 수 있으므로 늘 다른 색으로.
    // 견본 찾기 단계는 보기에 없는 다른 색, 이름 단계의 힌트 견본은 회색 (색이 아니라 모양을 보게)
    final used = {for (final c in choices) c.color.id};
    final sampleColor = stage.matchSample
        ? colors.firstWhere(
            (c) => !used.contains(c.id),
            orElse: () => GameColor.gray,
          )
        : GameColor.gray;

    final target = choices.first;
    choices.shuffle(rng);
    return ShapeQuestion(
      choices: choices,
      answerIndex: choices.indexOf(target),
      sampleColor: sampleColor,
      matchSample: stage.matchSample,
    );
  }
}

class ShapeRound {
  ShapeRound(this.question);

  final ShapeQuestion question;
  final Set<int> wrongPicks = {};
  bool solved = false;

  bool get firstTry => wrongPicks.isEmpty;

  /// 견본 그림: 견본 찾기 단계는 처음부터 (견본을 보는 과제),
  /// 이름을 듣고 찾는 단계는 처음엔 숨기고 한 번 틀리면 회색 견본을 힌트로.
  /// (처음부터 보이면 소리를 듣지 않고 그림만 맞춰도 풀리기 때문)
  bool get showSample =>
      question.matchSample || wrongPicks.length >= Economy.hintAfterWrong;

  /// 두 번 틀리면 정답이 반짝인다.
  bool get highlightAnswer => wrongPicks.length >= Economy.hintAfterWrong + 1;

  bool isDisabled(int index) => wrongPicks.contains(index) || solved;

  AnswerOutcome answer(int index) {
    if (solved ||
        index < 0 ||
        index >= question.choices.length ||
        wrongPicks.contains(index)) {
      return AnswerOutcome.ignored;
    }
    if (index == question.answerIndex) {
      solved = true;
      return AnswerOutcome.correct;
    }
    wrongPicks.add(index);
    return AnswerOutcome.wrong;
  }
}
