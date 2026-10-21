import 'dart:math';

import '../../core/economy.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../number_game/number_round.dart' show AnswerOutcome;

export '../number_game/number_round.dart' show AnswerOutcome;

class ColorChoice {
  const ColorChoice(this.kind, this.color);
  final ObjectKind kind;
  final GameColor color;
}

/// 색깔 문제 한 개.
class ColorQuestion {
  ColorQuestion({required this.choices, required this.answerIndex});

  final List<ColorChoice> choices;
  final int answerIndex;

  ColorChoice get target => choices[answerIndex];

  /// 예: "빨간 자동차를 찾아볼까요?"
  String get prompt => '${target.color.adjective} ${target.kind.object} 찾아볼까요?';

  static ColorQuestion generate(
    ColorStage stage,
    Random rng, {
    ColorQuestion? previous,
  }) {
    final colors = [...stage.colors]..shuffle(rng);
    // 바로 앞 문제와 같은 색을 정답으로 내지 않는다
    if (previous != null &&
        colors.first.id == previous.target.color.id &&
        colors.length > 1) {
      colors.add(colors.removeAt(0));
    }
    final picked = colors.take(stage.choiceCount).toList();

    final kinds = [...stage.objects]..shuffle(rng);
    final choices = <ColorChoice>[
      for (var i = 0; i < picked.length; i++)
        ColorChoice(
          stage.mixedShapes ? kinds[i % kinds.length] : kinds.first,
          picked[i],
        ),
    ];
    // 정답은 picked[0]. 위치를 섞는다.
    final target = choices.first;
    choices.shuffle(rng);
    return ColorQuestion(
      choices: choices,
      answerIndex: choices.indexOf(target),
    );
  }
}

class ColorRound {
  ColorRound(this.question, {required this.swatchFromStart});

  final ColorQuestion question;
  final bool swatchFromStart;
  final Set<int> wrongPicks = {};
  bool solved = false;

  bool get firstTry => wrongPicks.isEmpty;

  /// 찾을 색을 크게 보여 줄지. 쉬운 단계는 처음부터, 그 외에는 한 번 틀리면 힌트로.
  bool get showSwatch =>
      swatchFromStart || wrongPicks.length >= Economy.hintAfterWrong;

  /// 두 번 이상 틀리면 정답을 반짝여 알려 준다.
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
