/// 유아가 사물을 셀 때 쓰는 고유어 수사.
class KoreanNumbers {
  KoreanNumbers._();

  /// 하나, 둘, 셋 … 열 (세기)
  static const counting = [
    '하나',
    '둘',
    '셋',
    '넷',
    '다섯',
    '여섯',
    '일곱',
    '여덟',
    '아홉',
    '열',
  ];

  /// 한, 두, 세 … 열 (+ 개)
  static const _counter = [
    '한',
    '두',
    '세',
    '네',
    '다섯',
    '여섯',
    '일곱',
    '여덟',
    '아홉',
    '열',
  ];

  static String count(int n) => (n >= 1 && n <= 10) ? counting[n - 1] : '$n';

  /// "세 개", "두 마리"
  static String pieces(int n, [String unit = '개']) =>
      (n >= 1 && n <= 10) ? '${_counter[n - 1]} $unit' : '$n$unit';

  /// "하나, 둘, 셋"
  static String countUpTo(int n) =>
      [for (var i = 1; i <= n; i++) count(i)].join(', ');
}
