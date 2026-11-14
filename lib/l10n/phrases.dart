import '../character/zodiac.dart';
import '../data/game_objects.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import '../games/common/scene_game.dart' show Season;
import '../services/game_state.dart' show GameKind;
import 'en/english_phrases.dart';
import 'ko/korean_phrases.dart';
import 'l10n.dart';

/// 문장 조립기: 놀이 문제·칭찬·이름처럼 낱말을 이어 붙여 만드는 말.
///
/// 언어마다 문법이 달라서(한국어는 조사 이/가·을/를과 셈 단위 개/마리, 영어는 관사와 복수형)
/// 고정 문구(ARB)로는 만들 수 없는 말을 여기서 만든다. 한국어 구현([KoreanPhrases])은
/// 녹음 음성 팩과 글자 하나까지 같아야 한다 (test/voice_ko_snapshot_test.dart).
///
/// 놀이 코드는 [Phrases.current]를 쓴다 (지금 앱 언어, 기본 한국어).
abstract class Phrases {
  const Phrases();

  /// 'ko' / 'en'
  String get code;

  static const ko = KoreanPhrases();
  static const en = EnglishPhrases();

  /// [code] 언어의 조립기 (모르는 언어는 한국어)
  static Phrases of(String code) => switch (code) {
    'en' => en,
    _ => ko,
  };

  /// 지금 앱 언어의 조립기
  static Phrases get current => of(L10n.code);

  // ---------- 낱말 ----------

  /// 물건 이름: 사과 / apple
  String object(ObjectKind k);

  /// 색 이름: 빨간색 / red
  String colorName(GameColor c);

  /// 색 + 물건: 빨간 풍선 / red balloon (색이 없으면 물건 이름만)
  String objectLabel(ObjectKind k, [GameColor? c]);

  /// 모양 이름: 동그라미 / circle
  String shape(ShapeKind s);

  /// 색 + 모양 (보기 읽기용): 빨간 세모 / red triangle
  String coloredShape(GameColor c, ShapeKind s);

  /// 계절: 봄 / spring
  String season(Season s);

  /// 놀이 이름: 숫자 놀이 / Numbers
  String gameTitle(GameKind g);

  /// 친구(동물) 이름: 호랑이 / tiger
  String animal(Zodiac z);

  String itemName(Item i);
  String itemSlot(ItemSlot s);
  String outfitTheme(OutfitTheme t);
  String vehicleName(Vehicle v);
  String paintName(VehiclePaint p);

  // ---------- 수 ----------

  /// 셀 때 하는 말 한 마디: 하나 / One
  String count(int n);

  /// 하나, 둘, 셋 / One, two, three
  String countUpTo(int n);

  // ---------- 이름 말하기 ----------

  /// 누르면 말해 주는 이름: 사과! / 빨간 사과! (확장 색만 붙인다)
  String sayName(ObjectKind k, [GameColor? c]);

  /// 이름표를 외치듯 말하기: 사과! / Apple!
  String exclaim(String label);

  /// 모양을 누르면: 동그라미! / Circle!
  String sayShape(ShapeKind s);

  /// 놀이터 그림을 눌렀을 때: 숫자 놀이! / Numbers!
  String gameInvite(GameKind g);

  /// 길게 눌렀을 때 놀이 이름: 숫자 놀이야! / This is Numbers!
  String gameNameLine(GameKind g);

  /// 친구 인사: 나는 호랑이야! / I'm a tiger!
  String friendHello(Zodiac z);

  // ---------- 숫자 놀이 ----------

  /// 사과가 몇 개 있을까요? / How many apples?
  /// (흩어 놓지 않은 쉬운 문제는 색을 말하지 않는다)
  String howMany(ObjectKind k, GameColor? c, {required bool scattered});

  /// 빨간 풍선이 세 개! / Three red balloons!
  String countAnswer(ObjectKind k, GameColor? c, int n);

  // ---------- 색깔 놀이 ----------

  /// 빨간 자동차를 찾아볼까요? / Can you find the red car?
  String findColored(GameColor c, ObjectKind k);

  /// 빨간색! 정말 잘했어요! / Red! Great job!
  String colorPraise(GameColor c);

  /// 이건 파란색이에요. 빨간색을 찾아볼까요? / This is blue. Can you find red?
  String colorWrong(GameColor picked, GameColor target);

  // ---------- 모양 놀이 ----------

  /// 동그라미를 찾아볼까요? / Can you find the circle?
  String findShape(ShapeKind s);

  /// 똑같은 모양을 찾아볼까요? / Can you find the same shape?
  String findSameShape();

  /// 이건 세모예요. 동그라미를 다시 찾아볼까요?
  String shapeWrong(ShapeKind picked, ShapeKind target);

  /// 동그라미! 정말 잘했어요! / Circle! Great job!
  String shapePraise(ShapeKind s);

  /// 견본 그림 이름: 견본 동그라미 / Sample circle
  String shapeSample(ShapeKind s);

  // ---------- 크기 놀이 ----------

  /// 큰 사과를 찾아볼까요? / 가장 작은 오리를 찾아볼까요? / Can you find the biggest duck?
  String findSize(SizeAsk a, ObjectKind k, {required bool superlative});

  /// 큰 사과를 다시 찾아볼까요? / Let's look again for the big apple!
  String sizeWrong(SizeAsk a, ObjectKind k, {required bool superlative});

  /// 힌트 이름표: 큰 쪽 / Big one
  String sizeSide(SizeAsk a);

  // ---------- 짝 맞추기 ----------
  // [c]는 같은 물건 다른 색 단계일 때만 준다 (색을 붙여 말한다).

  /// 사과! 똑같은 사과를 찾아볼까요? / Apple! Can you find another apple?
  String matchPicked(ObjectKind k, GameColor? c);

  /// 똑같은 사과를 찾아볼까요? (한 장을 고른 뒤 문제 글)
  String matchFind(ObjectKind k, GameColor? c);

  /// 똑같은 사과를 다시 찾아볼까요? / Let's look again for another apple!
  String matchWrong(ObjectKind k, GameColor? c);

  /// 사과! 똑같아요! / Apple! They match!
  String matchMatched(ObjectKind k, GameColor? c);

  /// 마지막 짝: 사과! 똑같아요! 정말 잘했어요!
  String matchFinished(ObjectKind k, GameColor? c);

  // ---------- 탈것 색칠 ----------

  /// 빨간색으로 칠했어요! / Painted red!
  String paintedWith(VehiclePaint p);

  /// 빨간색은 코인 10개가 필요해요. / Red needs 10 coins.
  String paintNeedsCoins(VehiclePaint p, int price);

  /// 위 말 + "놀이하면서 모아 볼까요?"
  String paintNeedsCoinsAsk(VehiclePaint p, int price);

  // ---------- 이름 짓기 ----------

  /// 비워 두면 지어 주는 이름 목록
  List<String> get randomNames;

  /// 저장된 닉네임을 보여 줄 때 (기본 이름은 그 언어로)
  String nickname(String stored);
}
