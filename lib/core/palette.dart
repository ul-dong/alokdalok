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
