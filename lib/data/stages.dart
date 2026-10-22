import 'dart:math' as math;

import 'game_objects.dart';

/// 숫자 놀이 문제 방식
enum NumberMode {
  /// 한 가지 사물만 줄 맞춰 놓고 전부 세기 (1~3단계)
  single,

  /// 여러 사물을 흩어 놓고 "사과는 몇 개?" 처럼 한 가지만 세기
  mixKinds,

  /// 같은 사물을 여러 색으로 흩어 놓고 "빨간 풍선은 몇 개?" 세기
  mixColors,

  /// 사물도 색도 섞어 놓고 "파란 자동차는 몇 개?" 세기
  mixBoth,
}

/// 숫자 놀이 단계. 연령 모드를 추가할 때는 이 목록을 늘리거나 연령별 목록을 따로 만든다.
class NumberStage {
  const NumberStage({
    required this.id,
    required this.min,
    required this.max,
    required this.choiceCount,
    required this.objects,
    this.mode = NumberMode.single,
    this.kindsShown = 1,
    this.colors = const [],
    this.colorsShown = 1,
    this.totalMax = 10,
  });

  final int id;

  /// 정답(세는 물건 수)의 범위
  final int min;
  final int max;
  final int choiceCount;
  final List<ObjectKind> objects;
  final NumberMode mode;

  /// 한 화면에 섞는 사물 종류 수 (mixKinds, mixBoth)
  final int kindsShown;

  /// 섞을 수 있는 색 (mixColors, mixBoth)
  final List<GameColor> colors;

  /// 한 화면에 섞는 색 수
  final int colorsShown;

  /// 화면에 놓는 물건 전체 수의 최대값
  final int totalMax;

  bool get scattered => mode != NumberMode.single;
}

/// 색깔 놀이 단계.
class ColorStage {
  const ColorStage({
    required this.id,
    required this.colors,
    required this.choiceCount,
    required this.mixedShapes,
    required this.swatchFromStart,
    required this.objects,
  });

  final int id;
  final List<GameColor> colors;
  final int choiceCount;

  /// true면 보기마다 다른 사물을 써서 모양으로도 구분할 수 있게 한다 (가장 쉬움).
  final bool mixedShapes;

  /// true면 처음부터 찾을 색을 크게 보여 준다. false면 한 번 틀렸을 때 힌트로 보여 준다.
  final bool swatchFromStart;
  final List<ObjectKind> objects;
}

/// 모양 놀이 단계 (모래놀이터).
class ShapeStage {
  const ShapeStage({
    required this.id,
    required this.shapes,
    required this.choiceCount,
    this.sameColor = false,
    this.rotate = false,
    this.matchSample = false,
    this.colors = GameColor.all,
  });

  final int id;

  /// 이 단계에 나오는 모양
  final List<ShapeKind> shapes;
  final int choiceCount;

  /// true면 보기를 모두 같은 색으로 칠해 색으로는 고를 수 없게 한다.
  final bool sameColor;

  /// true면 보기 모양을 비스듬히 돌려 놓는다.
  final bool rotate;

  /// true면 이름 대신 견본을 보여 주고 "똑같은 모양"을 찾는다.
  final bool matchSample;

  final List<GameColor> colors;

  /// 견본이 처음부터 보이는지 (견본 찾기 단계만. 이름을 듣고 찾는 단계는 한 번 틀리면 힌트로)
  bool get showsSample => matchSample;
}

/// 크기 놀이 단계 (시소).
class SizeStage {
  const SizeStage({
    required this.id,
    required this.choiceCount,
    required this.smallest,
    required this.objects,
    this.colors = GameColor.all,
  });

  final int id;

  /// 보기 수. 3개 이상이면 "가장 큰/가장 작은"으로 묻는다.
  final int choiceCount;

  /// 가장 작은 물건의 크기 (가장 큰 물건 = 1). 클수록 차이가 작아 어렵다.
  final double smallest;
  final List<ObjectKind> objects;
  final List<GameColor> colors;

  /// "가장"을 붙여 묻는지
  bool get superlative => choiceCount >= 3;

  /// 큰 것부터 작은 것까지 같은 비율로 줄어드는 크기 목록
  List<double> get scales => [
    for (var i = 0; i < choiceCount; i++)
      i == 0 ? 1.0 : _pow(smallest, i / (choiceCount - 1)),
  ];

  /// 이웃한 두 크기의 비율 (큰 것 / 작은 것). 단계가 오를수록 작아진다.
  double get stepRatio => 1 / _pow(smallest, 1 / (choiceCount - 1));

  static double _pow(double x, double e) => math.pow(x, e).toDouble();
}

/// 짝 맞추기 단계 (회전목마).
class MatchStage {
  const MatchStage({
    required this.id,
    required this.pairs,
    required this.objects,
    this.colorVariant = false,
    this.colors = GameColor.all,
  });

  final int id;

  /// 짝 수 (카드는 그 두 배)
  final int pairs;
  final List<ObjectKind> objects;

  /// true면 같은 물건을 색만 다르게 놓고 같은 색끼리 짝짓는다 (마지막 단계).
  final bool colorVariant;
  final List<GameColor> colors;

  int get cardCount => pairs * 2;
}

class Stages {
  Stages._();

  static const number = [
    NumberStage(
      id: 1,
      min: 1,
      max: 3,
      choiceCount: 3,
      objects: [ObjectKind.apple, ObjectKind.star, ObjectKind.duck],
    ),
    NumberStage(
      id: 2,
      min: 1,
      max: 5,
      choiceCount: 3,
      objects: [
        ObjectKind.apple,
        ObjectKind.car,
        ObjectKind.star,
        ObjectKind.fish,
        ObjectKind.duck,
      ],
    ),
    NumberStage(
      id: 3,
      min: 1,
      max: 10,
      choiceCount: 3,
      objects: [
        ObjectKind.apple,
        ObjectKind.car,
        ObjectKind.star,
        ObjectKind.fish,
        ObjectKind.duck,
        ObjectKind.balloon,
      ],
    ),
    // 4단계부터: 여러 물건을 흩어 놓고 그중 한 가지만 세기
    NumberStage(
      id: 4,
      min: 1,
      max: 5,
      choiceCount: 3,
      mode: NumberMode.mixKinds,
      kindsShown: 2,
      totalMax: 8,
      objects: [
        ObjectKind.apple,
        ObjectKind.duck,
        ObjectKind.star,
        ObjectKind.fish,
        ObjectKind.car,
      ],
    ),
    NumberStage(
      id: 5,
      min: 1,
      max: 5,
      choiceCount: 3,
      mode: NumberMode.mixColors,
      colors: [
        GameColor.red,
        GameColor.blue,
        GameColor.yellow,
        GameColor.green,
      ],
      colorsShown: 2,
      totalMax: 8,
      objects: [ObjectKind.balloon, ObjectKind.ball, ObjectKind.car],
    ),
    NumberStage(
      id: 6,
      min: 2,
      max: 7,
      choiceCount: 3,
      mode: NumberMode.mixKinds,
      kindsShown: 3,
      totalMax: 12,
      objects: [
        ObjectKind.apple,
        ObjectKind.duck,
        ObjectKind.star,
        ObjectKind.fish,
        ObjectKind.car,
        ObjectKind.flower,
      ],
    ),
    NumberStage(
      id: 7,
      min: 1,
      max: 6,
      choiceCount: 3,
      mode: NumberMode.mixColors,
      colors: GameColor.all,
      colorsShown: 3,
      totalMax: 12,
      objects: [ObjectKind.balloon, ObjectKind.ball, ObjectKind.flower],
    ),
    NumberStage(
      id: 8,
      min: 1,
      max: 6,
      choiceCount: 4,
      mode: NumberMode.mixBoth,
      kindsShown: 2,
      colors: [
        GameColor.orange,
        GameColor.purple,
        GameColor.pink,
        GameColor.green,
      ],
      colorsShown: 2,
      totalMax: 12,
      objects: [ObjectKind.balloon, ObjectKind.car, ObjectKind.ball],
    ),
  ];

  static const color = [
    ColorStage(
      id: 1,
      colors: [GameColor.red, GameColor.blue, GameColor.yellow],
      choiceCount: 2,
      mixedShapes: true,
      swatchFromStart: true,
      objects: [
        ObjectKind.car,
        ObjectKind.balloon,
        ObjectKind.ball,
        ObjectKind.star,
      ],
    ),
    ColorStage(
      id: 2,
      // 단계마다 다른 색을 만나게: 1단계 빨·파·노 → 2단계 초록·주황·보라
      colors: [GameColor.green, GameColor.orange, GameColor.purple],
      choiceCount: 3,
      mixedShapes: false,
      swatchFromStart: false,
      objects: [
        ObjectKind.car,
        ObjectKind.balloon,
        ObjectKind.ball,
        ObjectKind.fish,
      ],
    ),
    ColorStage(
      id: 3,
      colors: [
        GameColor.red,
        GameColor.yellow,
        GameColor.green,
        GameColor.pink,
      ],
      choiceCount: 3,
      mixedShapes: false,
      swatchFromStart: false,
      objects: [
        ObjectKind.car,
        ObjectKind.balloon,
        ObjectKind.ball,
        ObjectKind.fish,
        ObjectKind.flower,
      ],
    ),
    ColorStage(
      id: 4,
      colors: GameColor.all,
      choiceCount: 4,
      mixedShapes: false,
      swatchFromStart: false,
      objects: [
        ObjectKind.car,
        ObjectKind.balloon,
        ObjectKind.ball,
        ObjectKind.fish,
        ObjectKind.flower,
      ],
    ),
    ColorStage(
      id: 5,
      colors: GameColor.extended,
      choiceCount: 4,
      mixedShapes: false,
      swatchFromStart: false,
      objects: [
        ObjectKind.car,
        ObjectKind.balloon,
        ObjectKind.ball,
        ObjectKind.flower,
        ObjectKind.star,
      ],
    ),
  ];

  static const _allShapes = ShapeKind.values;

  static const shape = [
    // 1: 쉬운 세 모양, 보기 2개, 색이 다르다. 견본은 한 번 틀리면 회색으로
    // (처음부터 정답과 같은 견본을 보여 주면 소리를 듣지 않고 그림만 맞춰도 풀려서 뺐다)
    ShapeStage(
      id: 1,
      shapes: [ShapeKind.circle, ShapeKind.triangle, ShapeKind.square],
      choiceCount: 2,
      colors: [GameColor.red, GameColor.blue, GameColor.yellow],
    ),
    // 2: 여섯 모양, 보기 3개 (색은 달라도 됨)
    ShapeStage(id: 2, shapes: _allShapes, choiceCount: 3),
    // 3: 모두 같은 색 → 모양만 보고 찾기
    ShapeStage(id: 3, shapes: _allShapes, choiceCount: 3, sameColor: true),
    // 4: 같은 색 + 비스듬히 돌린 모양, 보기 4개
    ShapeStage(
      id: 4,
      shapes: _allShapes,
      choiceCount: 4,
      sameColor: true,
      rotate: true,
    ),
    // 5: 견본과 똑같은 모양 찾기 (견본은 다른 색, 보기는 돌려 놓음)
    ShapeStage(
      id: 5,
      shapes: _allShapes,
      choiceCount: 4,
      sameColor: true,
      rotate: true,
      matchSample: true,
    ),
  ];

  static const size = [
    SizeStage(
      id: 1,
      choiceCount: 2,
      smallest: .45,
      objects: [ObjectKind.apple, ObjectKind.ball, ObjectKind.balloon],
      colors: [GameColor.red, GameColor.blue, GameColor.yellow],
    ),
    SizeStage(
      id: 2,
      choiceCount: 2,
      smallest: .62,
      objects: [
        ObjectKind.apple,
        ObjectKind.ball,
        ObjectKind.duck,
        ObjectKind.car,
        ObjectKind.star,
      ],
    ),
    // 3단계부터 보기 3개 이상 → "가장 큰 / 가장 작은"
    SizeStage(
      id: 3,
      choiceCount: 3,
      smallest: .45,
      objects: [
        ObjectKind.apple,
        ObjectKind.ball,
        ObjectKind.duck,
        ObjectKind.fish,
        ObjectKind.balloon,
      ],
    ),
    SizeStage(
      id: 4,
      choiceCount: 3,
      smallest: .62,
      objects: [
        ObjectKind.car,
        ObjectKind.star,
        ObjectKind.fish,
        ObjectKind.flower,
        ObjectKind.balloon,
      ],
    ),
    SizeStage(id: 5, choiceCount: 4, smallest: .58, objects: ObjectKind.values),
  ];

  static const match = [
    MatchStage(
      id: 1,
      pairs: 2,
      objects: [ObjectKind.apple, ObjectKind.duck, ObjectKind.car],
    ),
    MatchStage(
      id: 2,
      pairs: 3,
      objects: [
        ObjectKind.apple,
        ObjectKind.duck,
        ObjectKind.car,
        ObjectKind.star,
        ObjectKind.ball,
      ],
    ),
    MatchStage(id: 3, pairs: 4, objects: ObjectKind.values),
    MatchStage(id: 4, pairs: 5, objects: ObjectKind.values),
    // 마지막: 같은 물건을 여러 색으로 → 같은 색끼리 짝
    MatchStage(
      id: 5,
      pairs: 6,
      colorVariant: true,
      objects: [
        ObjectKind.balloon,
        ObjectKind.car,
        ObjectKind.ball,
        ObjectKind.fish,
        ObjectKind.star,
      ],
    ),
  ];
}
