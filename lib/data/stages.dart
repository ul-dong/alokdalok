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
}
