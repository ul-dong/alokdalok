import 'dart:ui';

/// 고를 수 있는 친구: 12지신 12마리 + 공룡 12마리. 저장값에는 [name](영문 id)을 쓴다.
/// (이름은 예전 저장값과 맞추려고 Zodiac 그대로 둔다)
enum Zodiac {
  rat,
  ox,
  tiger,
  rabbit,
  dragon,
  snake,
  horse,
  sheep,
  monkey,
  rooster,
  dog,
  pig,
  // 공룡
  trex,
  triceratops,
  stegosaurus,
  brachiosaurus,
  ankylosaurus,
  pteranodon,
  parasaurolophus,
  pachycephalosaurus,
  velociraptor,
  spinosaurus,
  iguanodon,
  dilophosaurus,
}

/// 친구 고르기 탭
enum FriendGroup { zodiac, dino }

class ZodiacLook {
  const ZodiacLook({
    required this.animal,
    required this.buddy,
    required this.fur,
    required this.light,
    required this.accent,
  });

  /// 동물 이름 (쥐, 소 …)
  final String animal;

  /// 아이가 부르기 쉬운 친구 이름 (찍찍이, 음매 …)
  final String buddy;

  /// 기본 털색
  final Color fur;

  /// 배·주둥이 등 밝은 부분
  final Color light;

  /// 무늬·뿔·볏 등 포인트
  final Color accent;
}

extension ZodiacInfo on Zodiac {
  ZodiacLook get look => switch (this) {
    Zodiac.rat => const ZodiacLook(
      animal: '쥐',
      buddy: '찍찍이',
      fur: Color(0xFFC2C0C8),
      light: Color(0xFFE9E6EC),
      accent: Color(0xFFF5B8C4),
    ),
    Zodiac.ox => const ZodiacLook(
      animal: '소',
      buddy: '음매',
      fur: Color(0xFFFFFFFF),
      light: Color(0xFFF7B7C0),
      accent: Color(0xFF3F3330),
    ),
    Zodiac.tiger => const ZodiacLook(
      animal: '호랑이',
      buddy: '어흥이',
      fur: Color(0xFFFFC45E),
      light: Color(0xFFFFFFFF),
      accent: Color(0xFF5B4033),
    ),
    Zodiac.rabbit => const ZodiacLook(
      animal: '토끼',
      buddy: '깡총이',
      fur: Color(0xFFFFFFFF),
      light: Color(0xFFFFFFFF),
      accent: Color(0xFFF5B8C4),
    ),
    Zodiac.dragon => const ZodiacLook(
      animal: '용',
      buddy: '용용이',
      fur: Color(0xFF7BCADD),
      light: Color(0xFFFFE7A3),
      accent: Color(0xFFFFB13B),
    ),
    Zodiac.snake => const ZodiacLook(
      animal: '뱀',
      buddy: '스르르',
      fur: Color(0xFF9DD067),
      light: Color(0xFFE4F2B8),
      accent: Color(0xFF6BA347),
    ),
    Zodiac.horse => const ZodiacLook(
      animal: '말',
      buddy: '히힝이',
      fur: Color(0xFFD69C66),
      light: Color(0xFFF3D9B5),
      accent: Color(0xFF8E5A3A),
    ),
    Zodiac.sheep => const ZodiacLook(
      animal: '양',
      buddy: '매애',
      fur: Color(0xFFFFFBF0),
      light: Color(0xFFFFFBF0),
      accent: Color(0xFFF6CFB0),
    ),
    Zodiac.monkey => const ZodiacLook(
      animal: '원숭이',
      buddy: '우끼',
      fur: Color(0xFFB07B55),
      light: Color(0xFFF3CFA8),
      accent: Color(0xFF8A5E42),
    ),
    Zodiac.rooster => const ZodiacLook(
      animal: '닭',
      buddy: '꼬꼬',
      fur: Color(0xFFFFFFFF),
      light: Color(0xFFFFFFFF),
      accent: Color(0xFFE8433A),
    ),
    Zodiac.dog => const ZodiacLook(
      animal: '강아지',
      buddy: '멍멍이',
      fur: Color(0xFFEFB06C),
      light: Color(0xFFFFF3DE),
      accent: Color(0xFF9A6646),
    ),
    Zodiac.pig => const ZodiacLook(
      animal: '돼지',
      buddy: '꿀꿀이',
      fur: Color(0xFFFFC2CF),
      light: Color(0xFFFFE1E7),
      accent: Color(0xFFF08FA6),
    ),
    Zodiac.trex => const ZodiacLook(
      animal: '티라노사우루스',
      buddy: '티라노',
      fur: Color(0xFF82CF7E),
      light: Color(0xFFF4EFC8),
      accent: Color(0xFF55A75A),
    ),
    // 겸딩이가 좋아하는 산호빛 빨강 + 크림색 뿔
    Zodiac.triceratops => const ZodiacLook(
      animal: '트리케라톱스',
      buddy: '트리케라',
      fur: Color(0xFFEF8178),
      light: Color(0xFFF4A196),
      accent: Color(0xFFF3DDB0),
    ),
    Zodiac.stegosaurus => const ZodiacLook(
      animal: '스테고사우루스',
      buddy: '스테고',
      fur: Color(0xFF9CCFEE),
      light: Color(0xFFE8F5FC),
      accent: Color(0xFFF27FA6),
    ),
    Zodiac.brachiosaurus => const ZodiacLook(
      animal: '브라키오사우루스',
      buddy: '브라키오',
      fur: Color(0xFFB9A2E0),
      light: Color(0xFFF1EAFB),
      accent: Color(0xFF8E74C7),
    ),
    Zodiac.ankylosaurus => const ZodiacLook(
      animal: '안킬로사우루스',
      buddy: '안킬로',
      fur: Color(0xFFD2AD80),
      light: Color(0xFFF3E3CC),
      accent: Color(0xFFA27A52),
    ),
    Zodiac.pteranodon => const ZodiacLook(
      animal: '프테라노돈',
      buddy: '프테라',
      fur: Color(0xFFF7A868),
      light: Color(0xFFFFE3C4),
      accent: Color(0xFFE0543A),
    ),
    Zodiac.parasaurolophus => const ZodiacLook(
      animal: '파라사우롤로푸스',
      buddy: '파라사',
      fur: Color(0xFF7FCFC2),
      light: Color(0xFFE2F6F2),
      accent: Color(0xFFF2A65A),
    ),
    Zodiac.pachycephalosaurus => const ZodiacLook(
      animal: '파키케팔로사우루스',
      buddy: '파키',
      fur: Color(0xFFE59FB6),
      light: Color(0xFFFBE6EE),
      accent: Color(0xFFB8708C),
    ),
    Zodiac.velociraptor => const ZodiacLook(
      animal: '벨로시랩터',
      buddy: '랩터',
      fur: Color(0xFFA6B1CC),
      light: Color(0xFFEEF1F7),
      accent: Color(0xFFF2584A),
    ),
    Zodiac.spinosaurus => const ZodiacLook(
      animal: '스피노사우루스',
      buddy: '스피노',
      fur: Color(0xFF6B9BE0),
      light: Color(0xFFDCEBFB),
      accent: Color(0xFFFF9F45),
    ),
    Zodiac.iguanodon => const ZodiacLook(
      animal: '이구아노돈',
      buddy: '이구아노',
      fur: Color(0xFFBCD86A),
      light: Color(0xFFF0F6D2),
      accent: Color(0xFF86A23A),
    ),
    Zodiac.dilophosaurus => const ZodiacLook(
      animal: '딜로포사우루스',
      buddy: '딜로포',
      fur: Color(0xFFFFD663),
      light: Color(0xFFFFF4D0),
      accent: Color(0xFFE8433A),
    ),
  };

  FriendGroup get group =>
      index >= Zodiac.trex.index ? FriendGroup.dino : FriendGroup.zodiac;
  bool get isDino => group == FriendGroup.dino;

  /// "나는 호랑이야!" (진짜 동물 이름. 받침이 있으면 "이야")
  String get hello {
    final b = look.animal;
    final last = b.runes.last;
    final batchim =
        last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 != 0;
    return '나는 $b${batchim ? '이야' : '야'}!';
  }

  static List<Zodiac> of(FriendGroup g) =>
      Zodiac.values.where((z) => z.group == g).toList(growable: false);

  static Zodiac parse(Object? v, {Zodiac fallback = Zodiac.tiger}) {
    if (v is String) {
      for (final z in Zodiac.values) {
        if (z.name == v) return z;
      }
    }
    return fallback;
  }
}
