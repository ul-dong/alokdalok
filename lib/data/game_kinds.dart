import 'package:flutter/material.dart';

import '../services/game_state.dart';

/// 놀이터에서 쓰는 놀이 정보: 부르는 말, 이름표 색.
/// (놀이 이름 `title`·단계 수 `stageCount`는 `services/game_state.dart`의 `GameKindInfo`)
///
/// 놀이터에서 누르는 그림은 그 놀이의 내용물(1·2·3 계단 미끄럼틀=숫자, 풍선 다발=색깔,
/// 도형 블록=모양, 큰 공·작은 공=크기, 양말 한 켤레=짝 맞추기)이고,
/// `screens/playground_art.dart`의 `PlayItemPainter`가 그린다. 아이에게는 그림 이름 대신
/// 이름표에 적힌 놀이 이름만 들려준다 (보이는 글자와 들리는 말이 같게).
extension GameKindPlayground on GameKind {
  /// 기구나 이름표를 눌렀을 때 하는 말: 놀이 이름 ("숫자 놀이!", "짝 맞추기!")
  String get invite => '$title!';

  /// 길게 눌렀을 때 들려주는 놀이 이름 ("숫자 놀이야!", "짝 맞추기야!").
  /// 놀이 이름이 모두 받침 없이 끝나서 "야"를 붙인다.
  String get nameLine => '$title야!';

  /// 이름표·카드 바탕색
  Color get tint => switch (this) {
    GameKind.number => const Color(0xFFFFD9E3),
    GameKind.color => const Color(0xFFD6F2E4),
    GameKind.shape => const Color(0xFFFFF0C4),
    GameKind.size => const Color(0xFFDCEEFB),
    GameKind.match => const Color(0xFFE9E1F7),
  };

  /// 이름표 테두리·글자 강조색
  Color get accent => switch (this) {
    GameKind.number => const Color(0xFFE0607E),
    GameKind.color => const Color(0xFF3FA877),
    GameKind.shape => const Color(0xFFD9A43A),
    GameKind.size => const Color(0xFF4F95CF),
    GameKind.match => const Color(0xFF8D6CC9),
  };
}
