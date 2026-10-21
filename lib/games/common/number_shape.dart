import 'dart:math';

import 'package:flutter/material.dart';

/// 숫자를 "모양"으로 보여 주기.
///
/// 아직 숫자를 못 읽는 아이도 주사위처럼 늘 같은 자리에 찍힌 발자국 모양을 보고
/// 개수를 한눈에 알아볼 수 있게 한다. (1 = 가운데 하나, 2 = 대각선 둘, 5 = 네 귀퉁이 + 가운데)
/// 6~10은 꽉 찬 5 주사위 옆에 나머지 주사위를 하나 더 놓는다.
/// 숫자마다 발자국 색이 정해져 있어서 색으로도 기억할 수 있다.
class NumberShape extends StatelessWidget {
  const NumberShape(
    this.value, {
    super.key,
    this.dieSize = 44,
    this.vertical = false,
  });

  final int value;
  final double dieSize;

  /// 좁은 버튼에서는 주사위 두 개를 위아래로 쌓는다
  final bool vertical;

  /// 숫자별 발자국 색 (1 빨강, 2 주황, 3 노랑 … 무지개 순서)
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

  static Color colorOf(int n) => colors[(n - 1).clamp(0, colors.length - 1)];

  @override
  Widget build(BuildContext context) {
    final dice = value <= 5 ? [value] : [5, value - 5];
    final color = colorOf(value);
    final gap = dieSize * .14;
    final children = [
      for (var i = 0; i < dice.length; i++) ...[
        if (i > 0) SizedBox(width: gap, height: gap),
        SizedBox(
          width: dieSize,
          height: dieSize,
          child: CustomPaint(painter: _DiePainter(dice[i], color)),
        ),
      ],
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// 주사위 눈 자리 (0~1 좌표)
const _pips = <int, List<Offset>>{
  1: [Offset(.5, .5)],
  2: [Offset(.27, .27), Offset(.73, .73)],
  3: [Offset(.25, .25), Offset(.5, .5), Offset(.75, .75)],
  4: [Offset(.27, .27), Offset(.73, .27), Offset(.27, .73), Offset(.73, .73)],
  5: [
    Offset(.25, .25),
    Offset(.75, .25),
    Offset(.5, .5),
    Offset(.25, .75),
    Offset(.75, .75),
  ],
};

class _DiePainter extends CustomPainter {
  _DiePainter(this.n, this.color);
  final int n;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s * .22),
    );
    canvas.drawRRect(r, Paint()..color = Colors.white);
    canvas.drawRRect(
      r.deflate(s * .03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .05
        ..color = color.withValues(alpha: .35),
    );
    final pips = _pips[n.clamp(1, 5)]!;
    final pawR =
        s *
        (n == 1
            ? .24
            : n <= 3
            ? .19
            : .155);
    for (final p in pips) {
      paw(canvas, Offset(p.dx * size.width, p.dy * size.height), pawR, color);
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.n != n || old.color != color;
}

/// 동물 발자국 하나 (발바닥 + 발가락 넷). [r]은 대략적인 반지름.
void paw(Canvas c, Offset o, double r, Color color) {
  final p = Paint()..color = color;
  c.drawOval(
    Rect.fromCenter(
      center: o + Offset(0, r * .35),
      width: r * 1.3,
      height: r * 1.05,
    ),
    p,
  );
  for (var i = 0; i < 4; i++) {
    final a = -pi / 2 + (i - 1.5) * .62;
    c.drawCircle(
      o + Offset(cos(a) * r * .95, sin(a) * r * .95 + r * .1),
      r * .3,
      p,
    );
  }
}
