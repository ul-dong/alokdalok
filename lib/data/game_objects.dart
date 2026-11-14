import 'dart:ui';

import '../l10n/ko/korean_phrases.dart';
import '../l10n/phrases.dart';

/// 게임에 나오는 사물 종류. 모양은 lib/games/common/object_art.dart에서 그린다.
enum ObjectKind { apple, car, star, fish, duck, balloon, ball, flower }

extension ObjectKindInfo on ObjectKind {
  // 한국어 낱말·조사는 문장 조립기(lib/l10n/ko/korean_phrases.dart)에 있다.
  // 아래 넷은 한국어 전용 바로가기 (한국어 음성 목록·테스트용). 화면과 말에는 [Phrases.current].

  /// 한국어 이름 (사과)
  String get ko => Phrases.ko.object(this);

  /// 받침에 맞는 주격 조사 (사과가 / 별이)
  String get subject => KoreanPhrases.subject(ko);

  /// 받침에 맞는 보조사 (사과는 / 별은)
  String get topic => KoreanPhrases.topic(ko);

  /// 받침에 맞는 목적격 조사 (자동차를 / 별을)
  String get object => KoreanPhrases.objectCase(ko);

  /// 누르면 말해 주는 이름 (지금 언어): "사과!" / 색이 있으면 "빨간 사과!"
  String sayName([GameColor? color]) => Phrases.current.sayName(this, color);

  /// 한국어 셈 단위: 동물은 '마리', 나머지는 '개'
  String get counter => Phrases.ko.counter(this);

  /// 색을 바꿔 칠해도 되는 물건인지.
  /// 공·풍선·자동차·별·꽃·물고기처럼 원래 여러 색인 것만 바꾼다.
  /// 사과(빨강)·오리(노랑)처럼 고유한 색이 있는 물건은 늘 원래 색이다
  /// (노란 사과는 3살 아이에게 헷갈린다).
  bool get tintable => fixedColor == null;

  /// 고유한 색이 있는 물건의 색 (색을 바꿀 수 있는 물건은 null)
  GameColor? get fixedColor => switch (this) {
    ObjectKind.apple => GameColor.red,
    ObjectKind.duck => GameColor.yellow,
    _ => null,
  };

  /// 이 물건을 [wanted] 색으로 칠하려 할 때 실제로 쓸 색 (고유색이 있으면 그 색)
  GameColor colorFor(GameColor wanted) => fixedColor ?? wanted;

  /// 그릴 때 쓸 색: 고유색이 있으면 [wanted]를 무시한다
  Color? paintColor(Color? wanted) => fixedColor?.color ?? wanted;

  /// 이 색으로 내도 되는지 (색깔 놀이 보기 등)
  bool allows(GameColor c) => fixedColor == null || fixedColor!.id == c.id;

  /// 색을 정하지 않았을 때의 기본 색
  Color get naturalColor => switch (this) {
    ObjectKind.apple => GameColor.red.color,
    ObjectKind.car => const Color(0xFF6FA8E8),
    ObjectKind.star => const Color(0xFFFFCF4D),
    ObjectKind.fish => const Color(0xFFFF9F5A),
    ObjectKind.duck => GameColor.yellow.color,
    ObjectKind.balloon => const Color(0xFFF59AB5),
    ObjectKind.ball => const Color(0xFF8ED37A),
    ObjectKind.flower => const Color(0xFFF59AB5),
  };
}

/// 색깔 놀이에서 쓰는 색. 새 색은 여기에 추가하고 color_stages에서 단계에 넣는다.
class GameColor {
  const GameColor(this.id, this.color);

  final String id;
  final Color color;

  /// 한국어 색 이름 '빨간색' (한국어 전용 바로가기. 화면과 말에는 [Phrases.current])
  String get name => Phrases.ko.colorName(this);

  /// 한국어 꾸밈말 '빨간' (빨간 자동차)
  String get adjective => Phrases.ko.colorAdjective(this);

  static const red = GameColor('red', Color(0xFFE8352B));
  static const blue = GameColor('blue', Color(0xFF1E6FE0));
  static const yellow = GameColor('yellow', Color(0xFFFFCC00));
  static const green = GameColor('green', Color(0xFF19A84A));
  static const orange = GameColor('orange', Color(0xFFFF7A00));
  static const purple = GameColor('purple', Color(0xFF7E3FD1));

  static const pink = GameColor('pink', Color(0xFFFF4F9A));
  static const brown = GameColor('brown', Color(0xFF8B5A2B));

  /// 힌트 견본용 회색 (보기 색으로는 쓰지 않는다)
  static const gray = GameColor('gray', Color(0xFF9AA3AD));

  static const all = [red, blue, yellow, green, orange, purple];

  /// 더 어려운 단계용 (분홍·갈색 추가)
  static const extended = [...all, pink, brown];

  @override
  String toString() => id;
}

/// 모양 놀이(모래놀이터)에 나오는 모양. 그림은 lib/games/shape_game/shape_art.dart.
enum ShapeKind { circle, triangle, square, star, heart, diamond }

extension ShapeKindInfo on ShapeKind {
  /// 한국어 이름 (동그라미). 한국어 전용 바로가기
  String get ko => Phrases.ko.shape(this);

  /// 동그라미를 / 별을
  String get object => KoreanPhrases.objectCase(ko);

  /// "이건 세모예요." / "이건 별이에요."
  String get thisIs => Phrases.ko.thisIsShape(this);

  /// 돌려도 모양이 그대로인지 (동그라미)
  bool get rotationFree => this == ShapeKind.circle;
}

/// 크기 놀이에서 묻는 쪽
enum SizeAsk { big, small }

extension SizeAskInfo on SizeAsk {
  /// 한국어 '큰' / '작은' (한국어 전용 바로가기)
  String get adjective => Phrases.ko.sizeAdjective(this);
}
