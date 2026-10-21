import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/game_objects.dart';

/// 모양 놀이의 모양을 그린다 (100 x 100 좌표계).
/// 외곽선 없는 납작한 원색 면 + 아래 두께 띠 + 오른쪽 아래 연한 그늘 + 반짝임.
class ShapePainter extends CustomPainter {
  ShapePainter(
    this.shape,
    this.color, {
    this.angle = 0,
    this.outlineOnly = false,
  });

  final ShapeKind shape;
  final Color color;

  /// 시계 방향 기울기 (도)
  final double angle;

  /// 속을 비운 점선 모양 (모래 위에 찍힌 자국 같은 견본)
  final bool outlineOnly;

  /// 모양 윤곽 (가운데 50,50 기준, 회전 전)
  static Path pathOf(ShapeKind shape) {
    switch (shape) {
      case ShapeKind.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 40));
      case ShapeKind.triangle:
        // 꼭짓점을 살짝 둥글린 정삼각형
        final pts = [
          for (var i = 0; i < 3; i++)
            Offset(
              50 + cos(-pi / 2 + i * 2 * pi / 3) * 46,
              56 + sin(-pi / 2 + i * 2 * pi / 3) * 46,
            ),
        ];
        return _rounded(pts, 7);
      case ShapeKind.square:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: const Offset(50, 50),
              width: 72,
              height: 72,
            ),
            const Radius.circular(8),
          ),
        );
      case ShapeKind.star:
        final pts = [
          for (var i = 0; i < 10; i++)
            Offset(
              50 + cos(-pi / 2 + i * pi / 5) * (i.isEven ? 46 : 20),
              53 + sin(-pi / 2 + i * pi / 5) * (i.isEven ? 46 : 20),
            ),
        ];
        return _rounded(pts, 3);
      case ShapeKind.heart:
        return Path()
          ..moveTo(50, 88)
          ..cubicTo(20, 68, 8, 52, 8, 36)
          ..cubicTo(8, 20, 20, 12, 31, 12)
          ..cubicTo(40, 12, 47, 18, 50, 26)
          ..cubicTo(53, 18, 60, 12, 69, 12)
          ..cubicTo(80, 12, 92, 20, 92, 36)
          ..cubicTo(92, 52, 80, 68, 50, 88)
          ..close();
      case ShapeKind.diamond:
        // 세로로 긴 마름모 (돌린 네모와 헷갈리지 않게)
        return _rounded(const [
          Offset(50, 4),
          Offset(80, 50),
          Offset(50, 96),
          Offset(20, 50),
        ], 5);
    }
  }

  /// 꼭짓점을 반지름 [r]만큼 둥글린 다각형
  static Path _rounded(List<Offset> pts, double r) {
    final p = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n];
      final a = cur + (prev - cur) / (prev - cur).distance * r;
      final b = cur + (next - cur) / (next - cur).distance * r;
      i == 0 ? p.moveTo(a.dx, a.dy) : p.lineTo(a.dx, a.dy);
      p.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    // 돌려도 칸 밖으로 나가지 않게 살짝 줄인다
    if (angle != 0) canvas.scale(.9);
    canvas.rotate(angle * pi / 180);
    canvas.translate(-50, -50);
    final path = pathOf(shape);
    if (outlineOnly) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .18));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      // 아래쪽 그림자 띠로 도톰하게
      canvas.drawPath(
        path.shift(const Offset(0, 4)),
        Paint()..color = Color.lerp(color, Colors.black, .25)!,
      );
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          path,
          path.shift(const Offset(-5, -6)),
        ),
        Paint()..color = Color.lerp(color, Colors.black, .12)!,
      );
      // 반짝임
      final shine = switch (shape) {
        ShapeKind.circle => const Offset(34, 32),
        ShapeKind.triangle => const Offset(42, 40),
        ShapeKind.square => const Offset(28, 28),
        ShapeKind.star => const Offset(44, 36),
        ShapeKind.heart => const Offset(26, 30),
        ShapeKind.diamond => const Offset(42, 34),
      };
      canvas.drawOval(
        Rect.fromCenter(center: shine, width: 12, height: 8),
        Paint()..color = Colors.white.withValues(alpha: .75),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.angle != angle ||
      old.outlineOnly != outlineOnly;
}

class ShapeIcon extends StatelessWidget {
  const ShapeIcon(
    this.shape, {
    super.key,
    required this.color,
    this.size = 64,
    this.angle = 0,
    this.outlineOnly = false,
  });

  final ShapeKind shape;
  final Color color;
  final double size;
  final double angle;
  final bool outlineOnly;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: ShapePainter(
        shape,
        color,
        angle: angle,
        outlineOnly: outlineOnly,
      ),
    ),
  );
}
