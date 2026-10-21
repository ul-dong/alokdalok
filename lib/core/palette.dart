import 'package:flutter/material.dart';

/// 레퍼런스 화면의 파스텔·만화풍 톤을 모아 둔 색상표.
/// 화면, 캐릭터, Flame 배경이 모두 이 값을 공유해 스타일을 통일한다.
class Palette {
  Palette._();

  // 외곽선: 부드러운 갈색 계열, 굵기 일정
  static const outline = Color(0xFF7A4E36);
  static const outlineSoft = Color(0xFFB08A6E);

  // UI 패널
  static const cream = Color(0xFFFBF6EC);
  static const creamDeep = Color(0xFFEFE4D2);
  static const panelShadow = Color(0x332E1A0E);
  static const text = Color(0xFF4A3426);
  static const textSoft = Color(0xFF8C6E5A);

  // 포인트 색
  static const pink = Color(0xFFF59AB5);
  static const pinkSoft = Color(0xFFFCE1E8);
  static const yellow = Color(0xFFFFD45C);
  static const yellowSoft = Color(0xFFFFF2C2);
  static const coin = Color(0xFFF2B33D);
  static const coinDeep = Color(0xFFC98A1E);
  static const mint = Color(0xFF8ED6B5);
  static const sky = Color(0xFF9FD3F2);
  static const lavender = Color(0xFFC6B5E8);
  static const peach = Color(0xFFFFB98A);

  // 배경
  static const skyTop = Color(0xFFBFE3FA);
  static const skyBottom = Color(0xFFE6F4FC);
  static const sea = Color(0xFF8FCDEB);
  static const seaDeep = Color(0xFF6DB8E0);
  static const sand = Color(0xFFF1DEB0);
  static const grass = Color(0xFFA8D97F);
  static const grassDeep = Color(0xFF86C463);

  // 고양이 캐릭터
  static const catFur = Color(0xFFF6B26B);
  static const catStripe = Color(0xFFE08C45);
  static const catBelly = Color(0xFFFFF4DF);
  static const catCheek = Color(0xFFF7A3B5);
  static const catEye = Color(0xFF3E2A20);
}

// ───────────────────────── 디자인 토큰 ─────────────────────────
// 화면마다 제각각이던 모서리·간격·글자 크기·그림자를 여기 한 곳에서 정한다.
// 새 화면을 만들 때는 숫자를 직접 쓰지 말고 이 값을 쓴다.

/// 모서리 반경
class Radii {
  Radii._();

  /// 작은 칩·배지 안쪽
  static const sm = 14.0;

  /// 작은 카드·이름표·입력칸
  static const md = 20.0;

  /// 보통 카드 (놀이 보기, 상점 칸)
  static const lg = 24.0;

  /// 큰 패널 (문제 카드, 메뉴 타일)
  static const xl = 30.0;
}

/// 간격 (4의 배수)
class Gaps {
  Gaps._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// 글자 크기 단계 (Jua 한 가지 굵기라 크기로만 위계를 만든다)
class TextSizes {
  TextSizes._();

  /// 부모님용 작은 설명
  static const caption = 14.0;

  /// 보조 설명
  static const small = 16.0;

  /// 본문·작은 버튼
  static const body = 18.0;

  /// 버튼 글자
  static const button = 20.0;

  /// 큰 버튼·카드 이름
  static const label = 22.0;

  /// 화면 제목 (작은 화면)
  static const title = 24.0;

  /// 화면 제목·질문
  static const heading = 28.0;

  /// 코인·별 숫자
  static const number = 30.0;

  /// 축하 문구
  static const hero = 36.0;
}

/// 입체감 (눌릴 것 같은 버튼: 아래로 두께 + 부드러운 바닥 그림자)
class Depth {
  Depth._();

  /// 버튼·카드 아래 두께 (px)
  static const edge = 6.0;

  /// 작은 칩의 두께
  static const edgeSmall = 4.0;

  /// 눌렸을 때 내려가는 거리
  static const press = 3.0;

  /// 바닥에 번지는 그림자
  static const softShadow = BoxShadow(
    color: Palette.panelShadow,
    blurRadius: 14,
    offset: Offset(0, 8),
  );

  /// 색이 있는 면의 두께 색 (같은 색을 조금 어둡게)
  static Color edgeOf(Color face) =>
      Color.lerp(face, const Color(0xFF6B4A35), .22)!;

  /// 두께 + 바닥 그림자
  static List<BoxShadow> raised(Color edgeColor, {double depth = edge}) => [
    BoxShadow(color: edgeColor, offset: Offset(0, depth)),
    softShadow,
  ];

  /// 두께만 (겹친 카드 안쪽처럼 그림자가 번지면 지저분한 곳)
  static List<BoxShadow> flat(Color edgeColor, {double depth = edgeSmall}) => [
    BoxShadow(color: edgeColor, offset: Offset(0, depth)),
  ];
}
