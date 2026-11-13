import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';

/// 앱 아이콘: 풍선 3개 묶음 (이미지 에셋 없이 직접 그림).
///
/// 좌표는 512×512 기준이고, 주어진 크기에 맞춰 늘이고 줄인다.
/// - [scale]: 그림(끈·풍선)만 가운데를 기준으로 줄인다. 배경은 항상 꽉 채운다.
///   안드로이드 어댑티브 전경·웹 maskable 아이콘은 0.7 (가운데 66dp 안전 원 안에 들어오게).
/// - [drawBackground]: false 면 배경을 빼고 투명하게 둔다 (어댑티브 전경용).
///
/// PNG 파일은 `tool/gen_icons_test.dart` 가 이 painter 로 만든다.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({this.scale = 1.0, this.drawBackground = true});

  final double scale;
  final bool drawBackground;

  /// 어댑티브 아이콘 배경 단색 (res/values/ic_launcher_background.xml 과 같은 값)
  static const backgroundTop = Palette.skyTop; // #BFE3FA
  static const backgroundBottom = Color(0xFFEAF6FD);

  static const _base = 512.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _base, size.height / _base);

    if (drawBackground) {
      const rect = Rect.fromLTWH(0, 0, _base, _base);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, backgroundBottom],
          ).createShader(rect),
      );
    }

    canvas.translate(_base / 2, _base / 2);
    canvas.scale(scale);
    canvas.translate(-_base / 2, -_base / 2);

    // 끈 3줄
    final string = Paint()
      ..color = Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(256, 266)
        ..quadraticBezierTo(249, 350, 256, 430),
      string,
    );
    canvas.drawPath(
      Path()
        ..moveTo(180, 303)
        ..quadraticBezierTo(198, 374, 252, 430),
      string,
    );
    canvas.drawPath(
      Path()
        ..moveTo(332, 303)
        ..quadraticBezierTo(314, 374, 260, 430),
      string,
    );

    // 가운데(맨 뒤) → 왼쪽 → 오른쪽
    _balloon(
      canvas,
      color: Palette.mint,
      knotTop: const Offset(256, 248),
      body: const Offset(256, 168),
      rx: 72,
      ry: 86,
      shine: const Offset(231, 139),
      shineRx: 17,
      shineRy: 25,
    );
    _balloon(
      canvas,
      color: Palette.pink,
      knotTop: const Offset(180, 285),
      body: const Offset(180, 212),
      rx: 66,
      ry: 79,
      shine: const Offset(158, 186),
      shineRx: 15,
      shineRy: 23,
    );
    _balloon(
      canvas,
      color: Palette.yellow,
      knotTop: const Offset(332, 285),
      body: const Offset(332, 212),
      rx: 66,
      ry: 79,
      shine: const Offset(310, 186),
      shineRx: 15,
      shineRy: 23,
    );

    canvas.restore();
  }

  /// 매듭(위 가운데 [knotTop], 폭 20·높이 22 삼각형) → 몸통 타원 → 하이라이트.
  void _balloon(
    Canvas canvas, {
    required Color color,
    required Offset knotTop,
    required Offset body,
    required double rx,
    required double ry,
    required Offset shine,
    required double shineRx,
    required double shineRy,
  }) {
    final fill = Paint()..color = color;
    Paint line(double w) => Paint()
      ..color = Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round;

    final knot = Path()
      ..moveTo(knotTop.dx - 10, knotTop.dy)
      ..lineTo(knotTop.dx + 10, knotTop.dy)
      ..lineTo(knotTop.dx, knotTop.dy + 22)
      ..close();
    canvas.drawPath(knot, fill);
    canvas.drawPath(knot, line(9));

    final oval = Rect.fromCenter(center: body, width: rx * 2, height: ry * 2);
    canvas.drawOval(oval, fill);
    canvas.drawOval(oval, line(10));

    canvas.save();
    canvas.translate(shine.dx, shine.dy);
    canvas.rotate(-20 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: shineRx * 2,
        height: shineRy * 2,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter old) =>
      old.scale != scale || old.drawBackground != drawBackground;
}
