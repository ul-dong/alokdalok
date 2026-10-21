import 'dart:math';

import '../../core/economy.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../common/korean_numbers.dart';

/// 흩어 놓은 화면 속 물건 하나. 위치는 화면 칸 안의 비율(0~1).
class SceneObject {
  const SceneObject({
    required this.kind,
    required this.color,
    required this.x,
    required this.y,
    required this.target,
  });

  final ObjectKind kind;

  /// null이면 사물의 기본 색
  final GameColor? color;
  final double x;
  final double y;

  /// 세어야 하는 물건인지
  final bool target;
}

/// 숫자 문제 한 개. 화면과 무관한 순수 로직이라 단위 테스트로 검증한다.
class NumberQuestion {
  NumberQuestion({
    required this.kind,
    required this.count,
    required this.choices,
    this.color,
    this.scene = const [],
    this.cols = 1,
    this.rows = 1,
  }) : assert(choices.contains(count)),
       assert(scene.isEmpty || scene.where((o) => o.target).length == count);

  /// 세는 사물
  final ObjectKind kind;

  /// 세는 색 (색으로 세는 문제일 때만)
  final GameColor? color;
  final int count;

  /// 오름차순 정렬된 보기 (작은 수가 왼쪽)
  final List<int> choices;

  /// 흩어 놓은 물건들 (비어 있으면 줄 맞춰 [count]개만 보여 주는 쉬운 문제)
  final List<SceneObject> scene;

  /// 흩어 놓을 때 쓴 칸 수 (화면 비율 계산용)
  final int cols;
  final int rows;

  bool get scattered => scene.isNotEmpty;

  /// "빨간 풍선" / "사과"
  String get label =>
      color == null ? kind.ko : '${color!.adjective} ${kind.ko}';

  String get prompt {
    if (!scattered) return '${kind.subject} 몇 ${kind.counter} 있을까요?';
    final topic = '$label${hasBatchim(label) ? '은' : '는'}';
    return '$topic 몇 ${kind.counter} 있을까요?';
  }

  /// 맞혔을 때: "빨간 풍선이 세 개!"
  String get answerLine {
    final subject = '$label${hasBatchim(label) ? '이' : '가'}';
    return '$subject ${KoreanNumbers.pieces(count, kind.counter)}!';
  }

  /// 세는 물건만, 읽는 순서(위→아래, 왼→오른)로
  List<SceneObject> get targetsInOrder {
    final t = scene.where((o) => o.target).toList()
      ..sort((a, b) {
        final dy = (a.y - b.y);
        if (dy.abs() > .12) return dy.sign.toInt();
        return a.x.compareTo(b.x);
      });
    return t;
  }

  static NumberQuestion generate(
    NumberStage stage,
    Random rng, {
    NumberQuestion? previous,
  }) {
    ObjectKind kind;
    int count;
    var guard = 0;
    do {
      kind = stage.objects[rng.nextInt(stage.objects.length)];
      count = stage.min + rng.nextInt(stage.max - stage.min + 1);
      guard++;
      // 바로 앞 문제와 같은 개수·사물은 피한다
    } while (previous != null &&
        (previous.count == count || previous.kind == kind) &&
        guard < 20);

    final pool = [
      for (var n = stage.min; n <= stage.max; n++)
        if (n != count) n,
    ];
    // 큰 범위에서는 정답 근처 숫자를 우선해 너무 쉬운 보기만 나오지 않게 한다
    pool.sort((a, b) => (a - count).abs().compareTo((b - count).abs()));
    final near = pool.take(max(stage.choiceCount + 1, 4)).toList()
      ..shuffle(rng);
    final choices = <int>[count, ...near.take(stage.choiceCount - 1)]..sort();

    if (!stage.scattered) {
      return NumberQuestion(kind: kind, count: count, choices: choices);
    }
    return _scatter(stage, rng, kind, count, choices);
  }

  /// 여러 물건을 섞어서 흩어 놓는다.
  static NumberQuestion _scatter(
    NumberStage stage,
    Random rng,
    ObjectKind kind,
    int count,
    List<int> choices,
  ) {
    GameColor? color;
    // (사물, 색) 묶음: 정답이 아닌 "헷갈리는 물건" 종류들
    final others = <(ObjectKind, GameColor?)>[];
    switch (stage.mode) {
      case NumberMode.single:
        break;
      case NumberMode.mixKinds:
        final kinds = [...stage.objects]
          ..remove(kind)
          ..shuffle(rng);
        for (final k in kinds.take(stage.kindsShown - 1)) {
          others.add((k, null));
        }
      case NumberMode.mixColors:
        final colors = [...stage.colors]..shuffle(rng);
        color = colors.first;
        for (final c in colors.skip(1).take(stage.colorsShown - 1)) {
          others.add((kind, c));
        }
      case NumberMode.mixBoth:
        final colors = [...stage.colors]..shuffle(rng);
        color = colors.first;
        final otherColor = colors[1];
        final kinds = [...stage.objects]
          ..remove(kind)
          ..shuffle(rng);
        final otherKind = kinds.first;
        // 같은 사물 다른 색, 다른 사물 같은 색, 둘 다 다른 것: 사물과 색을 모두 봐야 한다
        others
          ..add((kind, otherColor))
          ..add((otherKind, color))
          ..add((otherKind, otherColor));
    }

    // 헷갈리는 물건 수: 종류마다 최소 1개, 전체가 totalMax를 넘지 않게
    final room = max(others.length, stage.totalMax - count);
    final extra = <int>[for (final _ in others) 1];
    var left =
        min(room, max(others.length * 2, 3 + rng.nextInt(3))) - others.length;
    while (left > 0 && others.isNotEmpty) {
      extra[rng.nextInt(extra.length)]++;
      left--;
    }

    final items = <(ObjectKind, GameColor?, bool)>[
      for (var i = 0; i < count; i++) (kind, color, true),
      for (var j = 0; j < others.length; j++)
        for (var i = 0; i < extra[j]; i++) (others[j].$1, others[j].$2, false),
    ];

    // 칸을 넉넉히 나눠 무작위 칸에 놓고 조금씩 흔들어 "흩어 놓은" 느낌을 준다
    final n = items.length;
    // 가로로 긴 화면이라 줄은 적게(2~3줄), 칸은 물건 수보다 넉넉하게
    final rows = n <= 7 ? 2 : 3;
    final cols = max(3, (n * 1.4 / rows).ceil());
    final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(rng);
    items.shuffle(rng);
    final scene = <SceneObject>[
      for (var i = 0; i < n; i++)
        SceneObject(
          kind: items[i].$1,
          color: items[i].$2,
          target: items[i].$3,
          x: (cells[i] % cols + .5 + (rng.nextDouble() - .5) * .2) / cols,
          y: (cells[i] ~/ cols + .5 + (rng.nextDouble() - .5) * .16) / rows,
        ),
    ];
    return NumberQuestion(
      kind: kind,
      color: color,
      count: count,
      choices: choices,
      scene: scene,
      cols: cols,
      rows: rows,
    );
  }
}

enum AnswerOutcome { correct, wrong, ignored }

/// 한 문제를 푸는 동안의 상태 (틀린 보기, 힌트, 첫 시도 여부)
class NumberRound {
  NumberRound(this.question);

  final NumberQuestion question;
  final Set<int> wrongPicks = {};
  bool solved = false;

  bool get firstTry => wrongPicks.isEmpty;

  /// 한 번 틀리면 사물 하나하나에 번호를 붙여 같이 세어 보는 힌트를 보여 준다.
  bool get showHint => wrongPicks.length >= Economy.hintAfterWrong;

  bool isDisabled(int choice) => wrongPicks.contains(choice) || solved;

  AnswerOutcome answer(int choice) {
    if (solved ||
        wrongPicks.contains(choice) ||
        !question.choices.contains(choice)) {
      return AnswerOutcome.ignored;
    }
    if (choice == question.count) {
      solved = true;
      return AnswerOutcome.correct;
    }
    // 틀린 보기는 흐리게만 하고 다시 고를 수 없게 해서, 보기가 줄어들며 반드시 끝난다.
    wrongPicks.add(choice);
    return AnswerOutcome.wrong;
  }
}
