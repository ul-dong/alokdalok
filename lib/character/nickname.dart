import 'dart:math';

/// 닉네임 규칙과 검증. 닉네임은 기기 안에만 저장하고 어디에도 보내지 않는다.
class Nickname {
  Nickname._();

  static const String fallback = '꼬마친구';
  static const int maxLength = 8;

  /// 이름을 비워 두면 여기서 하나를 골라 준다 (화면에 예시로 보여 주지는 않는다)
  static const randomPool = [
    '별이',
    '구름이',
    '콩이',
    '하늘이',
    '보리',
    '토리',
    '꽃님이',
    '해님이',
    '방울이',
    '달님이',
    '솜이',
    '도토리',
    '초코',
    '딸기',
    '봄이',
    '사랑이',
  ];

  static String random([Random? rng]) =>
      randomPool[(rng ?? Random()).nextInt(randomPool.length)];

  /// 부적절한 단어 목록 (포함 여부로 검사). 필요하면 여기에 추가한다.
  static const _blocked = [
    '시발',
    '씨발',
    'ㅅㅂ',
    '병신',
    'ㅂㅅ',
    '개새',
    '새끼',
    '좆',
    '존나',
    '졸라',
    '미친',
    '닥쳐',
    '꺼져',
    '죽어',
    '죽일',
    '섹스',
    '야동',
    '변태',
    '바보',
    '멍청',
    '찐따',
    '등신',
    '애미',
    '애비',
    '느금',
    'fuck',
    'shit',
    'sex',
    'bitch',
    'damn',
  ];

  // 완성형 한글, 영문, 숫자만 허용 (공백·특수문자·이모지·자모 단독 불가)
  static final _allowed = RegExp(r'^[가-힣a-zA-Z0-9]+$');

  /// 검증 결과. 문제가 없으면 null, 있으면 부모가 읽을 짧은 안내 문구.
  static String? validate(String? raw) {
    final value = raw ?? '';
    if (value.trim().isEmpty) return '닉네임을 입력해 주세요.';
    if (value.contains(RegExp(r'\s'))) return '띄어쓰기 없이 입력해 주세요.';
    if (value.runes.length > maxLength) return '$maxLength글자까지 쓸 수 있어요.';
    if (!_allowed.hasMatch(value)) return '한글, 영문, 숫자만 쓸 수 있어요.';
    final lower = value.toLowerCase();
    for (final word in _blocked) {
      if (lower.contains(word)) return '다른 닉네임을 써 주세요.';
    }
    return null;
  }

  static bool isValid(String? value) => validate(value) == null;

  /// 저장된 값이 손상되었거나 규칙에 맞지 않으면 기본값으로 복구한다.
  static String sanitize(Object? stored) {
    if (stored is String && isValid(stored)) return stored;
    return fallback;
  }
}
