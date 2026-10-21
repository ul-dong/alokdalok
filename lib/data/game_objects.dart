import 'dart:ui';

/// 게임에 나오는 사물 종류. 모양은 lib/games/common/object_art.dart에서 그린다.
enum ObjectKind { apple, car, star, fish, duck, balloon, ball, flower }

extension ObjectKindInfo on ObjectKind {
  /// 한국어 이름 (enum 기본 name과 겹치지 않게 ko)
  String get ko => switch (this) {
    ObjectKind.apple => '사과',
    ObjectKind.car => '자동차',
    ObjectKind.star => '별',
    ObjectKind.fish => '물고기',
    ObjectKind.duck => '오리',
    ObjectKind.balloon => '풍선',
    ObjectKind.ball => '공',
    ObjectKind.flower => '꽃',
  };

  /// 받침에 맞는 주격 조사 (사과가 / 별이)
  String get subject => '$ko${hasBatchim(ko) ? '이' : '가'}';

  /// 받침에 맞는 보조사 (사과는 / 별은)
  String get topic => '$ko${hasBatchim(ko) ? '은' : '는'}';

  /// 받침에 맞는 목적격 조사 (자동차를 / 별을)
  String get object => '$ko${hasBatchim(ko) ? '을' : '를'}';

  /// 셀 때 붙이는 말: 동물은 '마리', 나머지는 '개'
  String get counter => switch (this) {
    ObjectKind.fish || ObjectKind.duck => '마리',
    _ => '개',
  };

  /// 숫자 놀이에서 쓰는 기본 색
  Color get naturalColor => switch (this) {
    ObjectKind.apple => const Color(0xFFF26B5E),
    ObjectKind.car => const Color(0xFF6FA8E8),
    ObjectKind.star => const Color(0xFFFFCF4D),
    ObjectKind.fish => const Color(0xFFFF9F5A),
    ObjectKind.duck => const Color(0xFFFFDD5C),
    ObjectKind.balloon => const Color(0xFFF59AB5),
    ObjectKind.ball => const Color(0xFF8ED37A),
    ObjectKind.flower => const Color(0xFFF59AB5),
  };
}

/// 마지막 글자에 받침이 있는지 (조사 고르기용)
bool hasBatchim(String word) {
  if (word.isEmpty) return false;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// 색깔 놀이에서 쓰는 색. 새 색은 여기에 추가하고 color_stages에서 단계에 넣는다.
class GameColor {
  const GameColor(this.id, this.name, this.adjective, this.color);

  final String id;

  /// '빨간색'
  final String name;

  /// '빨간' (빨간 자동차)
  final String adjective;
  final Color color;

  static const red = GameColor('red', '빨간색', '빨간', Color(0xFFE8352B));
  static const blue = GameColor('blue', '파란색', '파란', Color(0xFF1E6FE0));
  static const yellow = GameColor('yellow', '노란색', '노란', Color(0xFFFFCC00));
  static const green = GameColor('green', '초록색', '초록', Color(0xFF19A84A));
  static const orange = GameColor('orange', '주황색', '주황', Color(0xFFFF7A00));
  static const purple = GameColor('purple', '보라색', '보라', Color(0xFF7E3FD1));

  static const pink = GameColor('pink', '분홍색', '분홍', Color(0xFFFF4F9A));
  static const brown = GameColor('brown', '갈색', '갈색', Color(0xFF8B5A2B));

  static const all = [red, blue, yellow, green, orange, purple];

  /// 더 어려운 단계용 (분홍·갈색 추가)
  static const extended = [...all, pink, brown];

  @override
  String toString() => id;
}
