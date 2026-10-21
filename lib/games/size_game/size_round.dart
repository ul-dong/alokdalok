import 'dart:math';

import '../../core/economy.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../number_game/number_round.dart' show AnswerOutcome;

export '../number_game/number_round.dart' show AnswerOutcome;

/// 크기 문제 한 개: 같은 물건(같은 색)을 크기만 다르게 놓는다.
class SizeQuestion {
  SizeQuestion({
    required this.kind,
    required this.color,
    required this.scales,
    required this.ask,
    required this.superlative,
  });

  final ObjectKind kind;
  final GameColor color;

  /// 보기마다의 크기 (가장 큰 것 = 1)
  final List<double> scales;
  final SizeAsk ask;

  /// "가장"을 붙이는지 (보기 3개 이상)
  final bool superlative;

  int get answerIndex {
    var best = 0;
    for (var i = 1; i < scales.length; i++) {
      final better = ask == SizeAsk.big
          ? scales[i] > scales[best]
          : scales[i] < scales[best];
      if (better) best = i;
    }
    return best;
  }

  /// '큰 사과를' / '가장 작은 오리를'
  String get _target =>
      '${superlative ? '가장 ' : ''}${ask.adjective} ${kind.object}';

  /// 예: "큰 사과를 찾아볼까요?" / "가장 작은 오리를 찾아볼까요?"
  String get prompt => '$_target 찾아볼까요?';

  /// 틀렸을 때: "가장 큰 사과를 다시 찾아볼까요?"
  String get wrongLine => '$_target 다시 찾아볼까요?';

  String get praise => '정말 잘했어요!';

  static SizeQuestion generate(
    SizeStage stage,
    Random rng, {
    SizeQuestion? previous,
  }) {
    final kinds = [...stage.objects]..shuffle(rng);
    if (previous != null && kinds.first == previous.kind && kinds.length > 1) {
      kinds.add(kinds.removeAt(0));
    }
    final colors = [...stage.colors]..shuffle(rng);
    final scales = [...stage.scales]..shuffle(rng);
    return SizeQuestion(
      kind: kinds.first,
      // 사과는 빨강, 오리는 노랑: 고유색이 있는 물건은 색을 바꾸지 않는다
      color: kinds.first.colorFor(colors.first),
      scales: scales,
      ask: SizeAsk.values[rng.nextInt(2)],
      superlative: stage.superlative,
    );
  }
}

class SizeRound {
  SizeRound(this.question);

  final SizeQuestion question;
  final Set<int> wrongPicks = {};
  bool solved = false;

  bool get firstTry => wrongPicks.isEmpty;

  /// 한 번 틀리면 크기 비교 그림 힌트
  bool get showHint => wrongPicks.length >= Economy.hintAfterWrong;

  /// 두 번 틀리면 정답이 반짝인다.
  bool get highlightAnswer => wrongPicks.length >= Economy.hintAfterWrong + 1;

  bool isDisabled(int index) => wrongPicks.contains(index) || solved;

  AnswerOutcome answer(int index) {
    if (solved ||
        index < 0 ||
        index >= question.scales.length ||
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
