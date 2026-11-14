import '../../character/nickname.dart';
import '../../character/zodiac.dart';
import '../../data/game_objects.dart';
import '../../data/item_catalog.dart';
import '../../data/vehicles.dart';
import '../../games/common/scene_game.dart' show Season;
import '../../services/game_state.dart' show GameKind;
import '../phrases.dart';
import 'korean_numbers.dart';

/// 마지막 글자에 받침이 있는지 (조사 고르기용)
bool hasBatchim(String word) {
  if (word.isEmpty) return false;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// 한국어 문장 조립기: 받침에 맞는 조사(이/가, 은/는, 을/를)와 셈 단위(개/마리).
///
/// 여기서 만든 문장은 녹음 음성 팩(assets/voice/ko)의 문장과 글자 하나까지 같아야
/// 통문장 녹음이 재생된다. 바꾸면 test/voice_ko_snapshot_test.dart가 알려 준다.
class KoreanPhrases extends Phrases {
  const KoreanPhrases();

  @override
  String get code => 'ko';

  // ---------- 조사 ----------

  /// 사과가 / 별이
  static String subject(String w) => '$w${hasBatchim(w) ? '이' : '가'}';

  /// 사과는 / 별은
  static String topic(String w) => '$w${hasBatchim(w) ? '은' : '는'}';

  /// 사과를 / 별을
  static String objectCase(String w) => '$w${hasBatchim(w) ? '을' : '를'}';

  // ---------- 낱말 ----------

  @override
  String object(ObjectKind k) => switch (k) {
    ObjectKind.apple => '사과',
    ObjectKind.car => '자동차',
    ObjectKind.star => '별',
    ObjectKind.fish => '물고기',
    ObjectKind.duck => '오리',
    ObjectKind.balloon => '풍선',
    ObjectKind.ball => '공',
    ObjectKind.flower => '꽃',
  };

  /// 셀 때 붙이는 말: 동물은 '마리', 나머지는 '개'
  String counter(ObjectKind k) => switch (k) {
    ObjectKind.fish || ObjectKind.duck => '마리',
    _ => '개',
  };

  @override
  String colorName(GameColor c) => switch (c.id) {
    'red' => '빨간색',
    'blue' => '파란색',
    'yellow' => '노란색',
    'green' => '초록색',
    'orange' => '주황색',
    'purple' => '보라색',
    'pink' => '분홍색',
    'brown' => '갈색',
    'gray' => '회색',
    _ => c.id,
  };

  /// 꾸며 주는 색 이름: 빨간 (빨간 자동차)
  String colorAdjective(GameColor c) => switch (c.id) {
    'red' => '빨간',
    'blue' => '파란',
    'yellow' => '노란',
    'green' => '초록',
    'orange' => '주황',
    'purple' => '보라',
    'pink' => '분홍',
    'brown' => '갈색',
    'gray' => '회색',
    _ => c.id,
  };

  @override
  String objectLabel(ObjectKind k, [GameColor? c]) =>
      c == null ? object(k) : '${colorAdjective(c)} ${object(k)}';

  @override
  String shape(ShapeKind s) => switch (s) {
    ShapeKind.circle => '동그라미',
    ShapeKind.triangle => '세모',
    ShapeKind.square => '네모',
    ShapeKind.star => '별',
    ShapeKind.heart => '하트',
    ShapeKind.diamond => '다이아',
  };

  /// "이건 세모예요." / "이건 별이에요."
  String thisIsShape(ShapeKind s) {
    final w = shape(s);
    return '이건 $w${hasBatchim(w) ? '이에요.' : '예요.'}';
  }

  /// '큰' / '작은'
  String sizeAdjective(SizeAsk a) => a == SizeAsk.big ? '큰' : '작은';

  @override
  String coloredShape(GameColor c, ShapeKind s) =>
      '${colorAdjective(c)} ${shape(s)}';

  @override
  String season(Season s) => switch (s) {
    Season.spring => '봄',
    Season.summer => '여름',
    Season.autumn => '가을',
    Season.winter => '겨울',
  };

  @override
  String gameTitle(GameKind g) => switch (g) {
    GameKind.number => '숫자 놀이',
    GameKind.color => '색깔 놀이',
    GameKind.shape => '모양 놀이',
    GameKind.size => '크기 놀이',
    GameKind.match => '짝 맞추기',
  };

  @override
  String animal(Zodiac z) => z.look.animal;

  @override
  String itemName(Item i) => i.nameKo;

  @override
  String itemSlot(ItemSlot s) => switch (s) {
    ItemSlot.head => '머리',
    ItemSlot.outfit => '옷',
    ItemSlot.shoes => '신발',
    ItemSlot.accessory => '장식',
    ItemSlot.back => '등',
  };

  @override
  String outfitTheme(OutfitTheme t) => switch (t) {
    OutfitTheme.robot => '로봇',
    OutfitTheme.princess => '공주',
    OutfitTheme.fire => '소방관',
    OutfitTheme.police => '경찰',
    OutfitTheme.army => '군인',
    OutfitTheme.caveman => '원시인',
    OutfitTheme.astronaut => '우주비행사',
    OutfitTheme.doctor => '의사',
    OutfitTheme.chef => '요리사',
    OutfitTheme.farmer => '농부',
    OutfitTheme.train => '기관사',
    OutfitTheme.pirate => '해적',
    OutfitTheme.wizard => '마법사',
    OutfitTheme.dino => '공룡',
    OutfitTheme.hero => '슈퍼히어로',
    OutfitTheme.soccer => '축구선수',
    OutfitTheme.ballet => '발레리나',
  };

  @override
  String vehicleName(Vehicle v) => v.nameKo;

  @override
  String paintName(VehiclePaint p) => p.nameKo;

  // ---------- 수 ----------

  @override
  String count(int n) => KoreanNumbers.count(n);

  @override
  String countUpTo(int n) => KoreanNumbers.countUpTo(n);

  // ---------- 이름 말하기 ----------

  @override
  String sayName(ObjectKind k, [GameColor? c]) =>
      c != null && GameColor.extended.contains(c)
      ? '${colorAdjective(c)} ${object(k)}!'
      : '${object(k)}!';

  @override
  String exclaim(String label) => '$label!';

  @override
  String sayShape(ShapeKind s) => '${shape(s)}!';

  @override
  String gameInvite(GameKind g) => '${gameTitle(g)}!';

  /// 놀이 이름이 모두 받침 없이 끝나서 "야"를 붙인다.
  @override
  String gameNameLine(GameKind g) => '${gameTitle(g)}야!';

  /// 진짜 동물 이름. 받침이 있으면 "이야"
  @override
  String friendHello(Zodiac z) {
    final b = animal(z);
    return '나는 $b${hasBatchim(b) ? '이야' : '야'}!';
  }

  // ---------- 숫자 놀이 ----------

  @override
  String howMany(ObjectKind k, GameColor? c, {required bool scattered}) =>
      scattered
      ? '${topic(objectLabel(k, c))} 몇 ${counter(k)} 있을까요?'
      : '${subject(object(k))} 몇 ${counter(k)} 있을까요?';

  @override
  String countAnswer(ObjectKind k, GameColor? c, int n) =>
      '${subject(objectLabel(k, c))} ${KoreanNumbers.pieces(n, counter(k))}!';

  // ---------- 색깔 놀이 ----------

  @override
  String findColored(GameColor c, ObjectKind k) =>
      '${colorAdjective(c)} ${objectCase(object(k))} 찾아볼까요?';

  @override
  String colorPraise(GameColor c) => '${colorName(c)}! 정말 잘했어요!';

  @override
  String colorWrong(GameColor picked, GameColor target) =>
      '이건 ${colorName(picked)}이에요. ${colorName(target)}을 찾아볼까요?';

  // ---------- 모양 놀이 ----------

  @override
  String findShape(ShapeKind s) => '${objectCase(shape(s))} 찾아볼까요?';

  @override
  String findSameShape() => '똑같은 모양을 찾아볼까요?';

  @override
  String shapeWrong(ShapeKind picked, ShapeKind target) =>
      '${thisIsShape(picked)} ${objectCase(shape(target))} 다시 찾아볼까요?';

  @override
  String shapePraise(ShapeKind s) => '${shape(s)}! 정말 잘했어요!';

  @override
  String shapeSample(ShapeKind s) => '견본 ${shape(s)}';

  // ---------- 크기 놀이 ----------

  String _sizeTarget(SizeAsk a, ObjectKind k, bool superlative) =>
      '${superlative ? '가장 ' : ''}${sizeAdjective(a)} '
      '${objectCase(object(k))}';

  @override
  String findSize(SizeAsk a, ObjectKind k, {required bool superlative}) =>
      '${_sizeTarget(a, k, superlative)} 찾아볼까요?';

  @override
  String sizeWrong(SizeAsk a, ObjectKind k, {required bool superlative}) =>
      '${_sizeTarget(a, k, superlative)} 다시 찾아볼까요?';

  @override
  String sizeSide(SizeAsk a) => '${sizeAdjective(a)} 쪽';

  // ---------- 짝 맞추기 ----------

  String _same(ObjectKind k, GameColor? c) =>
      '똑같은 ${objectCase(objectLabel(k, c))}';

  @override
  String matchPicked(ObjectKind k, GameColor? c) =>
      '${objectLabel(k, c)}! ${matchFind(k, c)}';

  @override
  String matchFind(ObjectKind k, GameColor? c) => '${_same(k, c)} 찾아볼까요?';

  @override
  String matchWrong(ObjectKind k, GameColor? c) => '${_same(k, c)} 다시 찾아볼까요?';

  @override
  String matchMatched(ObjectKind k, GameColor? c) =>
      '${objectLabel(k, c)}! 똑같아요!';

  @override
  String matchFinished(ObjectKind k, GameColor? c) =>
      '${matchMatched(k, c)} 정말 잘했어요!';

  // ---------- 탈것 색칠 ----------

  @override
  String paintedWith(VehiclePaint p) => '${paintName(p)}으로 칠했어요!';

  @override
  String paintNeedsCoins(VehiclePaint p, int price) =>
      '${paintName(p)}은 코인 $price개가 필요해요.';

  @override
  String paintNeedsCoinsAsk(VehiclePaint p, int price) =>
      '${paintNeedsCoins(p, price)} 놀이하면서 모아 볼까요?';

  // ---------- 이름 짓기 ----------

  @override
  List<String> get randomNames => Nickname.randomPool;

  @override
  String nickname(String stored) => stored;
}
