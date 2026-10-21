import 'package:flutter/material.dart';

import '../services/game_state.dart';

/// 놀이터에서 쓰는 놀이 정보: 부르는 말, 이름표 색.
/// (놀이 이름 `title`·단계 수 `stageCount`는 `services/game_state.dart`의 `GameKindInfo`)
///
/// 놀이터 기구 그림(미끄럼틀=숫자, 그네=색깔, 모래놀이터=모양, 시소=크기, 회전목마=짝 맞추기)은
/// `screens/playground_art.dart`의 `EquipmentPainter`가 그린다. 아이에게는 기구 이름 대신
/// 이름표에 적힌 놀이 이름만 들려준다 (보이는 글자와 들리는 말이 같게).
extension GameKindPlayground on GameKind {
  /// 기구나 이름표를 눌렀을 때 하는 말: 놀이 이름 ("숫자 놀이!", "짝 맞추기!")
  String get invite => '$title!';

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
