import 'dart:math';

import '../../core/economy.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';

/// 짝 맞추기 카드 한 장. 같은 [pair] 번호끼리 짝이다.
class MatchCard {
  const MatchCard(this.pair, this.kind, this.color);
  final int pair;
  final ObjectKind kind;
  final GameColor color;

  /// '사과' / (색 단계) '빨간 사과'
  String label(bool withColor) =>
      withColor ? '${color.adjective} ${kind.ko}' : kind.ko;

  /// '사과를' / '빨간 사과를'
  String objectLabel(bool withColor) {
    final l = label(withColor);
    return '$l${hasBatchim(l) ? '을' : '를'}';
  }
}

/// 짝 맞추기 판 하나 (= 문제 하나). 카드는 뒤집지 않고 모두 보인다.
class MatchBoard {
  MatchBoard({required this.cards, required this.colorVariant});

  final List<MatchCard> cards;

  /// 같은 물건 다른 색 단계 (이름에 색을 붙여 말한다)
  final bool colorVariant;

  int get pairs => cards.length ~/ 2;

  /// [index] 카드의 짝 위치
  int twinOf(int index) {
    for (var i = 0; i < cards.length; i++) {
      if (i != index && cards[i].pair == cards[index].pair) return i;
    }
    return -1;
  }

  String labelOf(int i) => cards[i].label(colorVariant);

  static const prompt = '똑같은 그림 두 장을 찾아볼까요?';

  /// 한 장을 골랐을 때: "사과! 똑같은 사과를 찾아볼까요?"
  String pickedLine(int i) =>
      '${labelOf(i)}! 똑같은 ${cards[i].objectLabel(colorVariant)} 찾아볼까요?';

  /// 짝이 아닐 때: "똑같은 사과를 다시 찾아볼까요?"
  String wrongLine(int selected) =>
      '똑같은 ${cards[selected].objectLabel(colorVariant)} 다시 찾아볼까요?';

  /// 짝을 맞췄을 때: "사과! 똑같아요!"
  String matchedLine(int i) => '${labelOf(i)}! 똑같아요!';

  static MatchBoard generate(
    MatchStage stage,
    Random rng, {
    MatchBoard? previous,
  }) {
    final colors = [...stage.colors]..shuffle(rng);
    final kinds = [...stage.objects]..shuffle(rng);
    final faces = <(ObjectKind, GameColor)>[];
    if (stage.colorVariant) {
      // 같은 물건 한 가지 + 색 여러 가지 (앞 판과 다른 물건으로).
      // 색을 바꿀 수 있는 물건만 쓴다 (사과·오리는 늘 제 색).
      kinds.removeWhere((k) => !k.tintable);
      if (previous != null &&
          kinds.first == previous.cards.first.kind &&
          kinds.length > 1) {
        kinds.add(kinds.removeAt(0));
      }
      for (var i = 0; i < stage.pairs; i++) {
        faces.add((kinds.first, colors[i % colors.length]));
      }
    } else {
      for (var i = 0; i < stage.pairs; i++) {
        final kind = kinds[i % kinds.length];
        // 사과는 빨강, 오리는 노랑: 고유색이 있는 물건은 색을 바꾸지 않는다
        faces.add((kind, kind.colorFor(colors[i % colors.length])));
      }
    }
    final cards = <MatchCard>[
      for (var p = 0; p < faces.length; p++) ...[
        MatchCard(p, faces[p].$1, faces[p].$2),
        MatchCard(p, faces[p].$1, faces[p].$2),
      ],
    ]..shuffle(rng);
    return MatchBoard(cards: cards, colorVariant: stage.colorVariant);
  }
}

/// 카드를 눌렀을 때 결과
enum MatchOutcome {
  /// 무시 (이미 맞춘 카드, 흐려진 카드, 같은 카드 다시 누름)
  ignored,

  /// 첫 장을 골랐다
  selected,

  /// 짝이 아니다 (첫 장은 그대로 골라 둔 채 다시 찾는다)
  wrong,

  /// 짝을 맞췄다 (판이 아직 남음)
  matched,

  /// 마지막 짝까지 맞췄다
  finished,
}

class MatchRound {
  MatchRound(this.board);

  final MatchBoard board;

  /// 짝을 맞춘 카드 위치
  final Set<int> matched = {};

  /// 지금 골라 둔 첫 장
  int? selected;

  /// 지금 고른 카드의 짝을 찾다가 틀린 카드 (흐려진다)
  final Set<int> wrongPicks = {};

  /// 이 판에서 틀린 횟수 (0이면 한 번에 맞힘)
  int mistakes = 0;

  bool get solved => matched.length == board.cards.length;
  bool get firstTry => mistakes == 0;

  /// 한 번 틀리면 찾는 그림을 크게 보여 준다
  bool get showHint =>
      selected != null && wrongPicks.length >= Economy.hintAfterWrong;

  /// 두 번 틀리면 짝 카드가 반짝인다
  int? get glowIndex =>
      selected != null && wrongPicks.length >= Economy.hintAfterWrong + 1
      ? board.twinOf(selected!)
      : null;

  bool isDisabled(int i) =>
      solved || matched.contains(i) || wrongPicks.contains(i);

  MatchOutcome pick(int i) {
    if (i < 0 || i >= board.cards.length || isDisabled(i) || i == selected) {
      return MatchOutcome.ignored;
    }
    final first = selected;
    if (first == null) {
      selected = i;
      return MatchOutcome.selected;
    }
    if (board.cards[i].pair == board.cards[first].pair) {
      matched.addAll([first, i]);
      selected = null;
      wrongPicks.clear();
      return solved ? MatchOutcome.finished : MatchOutcome.matched;
    }
    wrongPicks.add(i);
    mistakes++;
    return MatchOutcome.wrong;
  }
}
