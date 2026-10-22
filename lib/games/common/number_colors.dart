import 'package:flutter/material.dart';

/// 숫자마다 정해진 색 (1 빨강, 2 주황, 3 노랑 … 무지개 순서).
/// 숫자 보기·도장에서 같은 숫자는 늘 같은 색이라 색으로도 기억할 수 있다.
abstract final class NumberColors {
  static const colors = [
    Color(0xFFE8463A), // 1
    Color(0xFFFF8A1F), // 2
    Color(0xFFF5B400), // 3
    Color(0xFF3DB04B), // 4
    Color(0xFF1E88E5), // 5
    Color(0xFF7E57C2), // 6
    Color(0xFFEC5A9B), // 7
    Color(0xFF00A6A6), // 8
    Color(0xFF8D6E4C), // 9
    Color(0xFF546E7A), // 10
  ];

  static Color of(int n) => colors[(n - 1).clamp(0, colors.length - 1)];
}
