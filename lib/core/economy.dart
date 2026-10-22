/// 코인 획득량 설정. 밸런스 조정은 이 파일만 고치면 된다.
/// (아이템 가격은 lib/data/item_catalog.dart 의 각 아이템 price 값)
class Economy {
  Economy._();

  /// 한 번에 맞혔을 때
  static const int correctFirstTry = 2;

  /// 다시 시도해서 맞혔을 때 (틀려도 차감은 절대 없음)
  static const int correctAfterRetry = 1;

  /// 한 판(문제 묶음)을 끝냈을 때
  static const int sessionComplete = 3;

  /// 생애 첫 놀이를 끝냈을 때 한 번
  static const int firstPlayBonus = 5;

  /// 어떤 단계를 처음으로 끝냈을 때 한 번
  static const int newStageBonus = 5;

  /// 처음 시작할 때 주는 코인 (바로 아이템 하나를 사 볼 수 있게)
  static const int startingCoins = 10;

  /// 한 판의 문제 수 (약 30초~2분)
  static const int questionsPerSession = 5;

  /// 짝 맞추기 한 판의 카드 판 수 (한 판이 길어지지 않게 3장, 2026-10-22 결정)
  static const int matchQuestionsPerSession = 3;

  /// 같은 문제에서 이만큼 틀리면 시각 힌트를 보여 준다
  static const int hintAfterWrong = 1;

  /// 보유 코인 상한 (저장값 손상 방지용)
  static const int maxCoins = 99999;
}
