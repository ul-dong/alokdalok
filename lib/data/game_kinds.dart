import 'package:flutter/material.dart';

import '../services/game_state.dart';

/// 놀이터에서 쓰는 놀이 정보: 기구 이름, 부르는 말, 이름표 색.
/// (놀이 이름 `title`·단계 수 `stageCount`는 `services/game_state.dart`의 `GameKindInfo`)
extension GameKindPlayground on GameKind {
  /// 놀이터 기구 이름
  String get equipment => switch (this) {
    GameKind.number => '미끄럼틀',
    GameKind.color => '그네',
    GameKind.shape => '모래놀이터',
    GameKind.size => '시소',
    GameKind.match => '회전목마',
  };

  /// 기구를 눌렀을 때 하는 말 ("미끄럼틀! 숫자 놀이를 해 볼까요?")
  String get invite => '$equipment! $title를 해 볼까요?';

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
