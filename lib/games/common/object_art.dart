import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/game_objects.dart';

/// 숫자·색깔 놀이에 나오는 사물을 만화풍으로 그린다 (100 x 100 좌표계).
class ObjectPainter extends CustomPainter {
  ObjectPainter(this.kind, this.color, {this.faded = false});

  final ObjectKind kind;
  final Color color;
  final bool faded;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);
    if (faded) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = const Color(0x59000000),
      );
    }
    _draw(canvas);
    if (faded) canvas.restore();
    canvas.restore();
  }

  Paint get _stroke => Paint()
    ..color = Palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _fs(Canvas c, Path p, Color fill) {
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, _stroke);
  }

  Color get _dark => Color.lerp(color, Colors.black, .18)!;

  void _shine(Canvas c, Offset o, double w, double h) {
    c.drawOval(
      Rect.fromCenter(center: o, width: w, height: h),
      Paint()..color = Colors.white.withValues(alpha: .75),
    );
  }

  void _draw(Canvas c) {
    switch (kind) {
      case ObjectKind.apple:
        final body = Path()
          ..moveTo(50, 30)
          ..cubicTo(30, 18, 8, 32, 12, 56)
          ..cubicTo(16, 82, 36, 94, 50, 86)
          ..cubicTo(64, 94, 84, 82, 88, 56)
          ..cubicTo(92, 32, 70, 18, 50, 30)
          ..close();
        c.drawLine(
          const Offset(50, 30),
          const Offset(54, 12),
          _stroke..strokeWidth = 5,
        );
        final leaf = Path()
          ..moveTo(55, 18)
          ..quadraticBezierTo(70, 6, 80, 14)
          ..quadraticBezierTo(70, 26, 55, 18)
          ..close();
        _fs(c, leaf, const Color(0xFF8ED37A));
        _fs(c, body, color);
        _shine(c, const Offset(30, 46), 10, 16);
      case ObjectKind.car:
        final body = Path()
          ..addRRect(RRect.fromLTRBR(8, 46, 92, 76, const Radius.circular(12)));
        final top = Path()
          ..moveTo(26, 48)
          ..lineTo(34, 26)
          ..quadraticBezierTo(36, 22, 42, 22)
          ..lineTo(62, 22)
          ..quadraticBezierTo(67, 22, 70, 27)
          ..lineTo(78, 48)
          ..close();
        _fs(c, top, color);
        _fs(c, body, color);
        c.drawPath(
          Path()..addRRect(
            RRect.fromLTRBR(37, 28, 50, 44, const Radius.circular(3)),
          ),
          Paint()..color = const Color(0xFFDFF3FF),
        );
        c.drawPath(
          Path()..addRRect(
            RRect.fromLTRBR(55, 28, 68, 44, const Radius.circular(3)),
          ),
          Paint()..color = const Color(0xFFDFF3FF),
        );
        c.drawCircle(
          const Offset(86, 58),
          4,
          Paint()..color = const Color(0xFFFFE97A),
        );
        for (final x in [28.0, 72.0]) {
          final w = Path()
            ..addOval(Rect.fromCircle(center: Offset(x, 78), radius: 11));
          _fs(c, w, const Color(0xFF5A4A44));
          c.drawCircle(
            Offset(x, 78),
            4,
            Paint()..color = const Color(0xFFD9D2CC),
          );
        }
        _shine(c, const Offset(20, 56), 10, 5);
      case ObjectKind.star:
        final p = Path();
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * pi / 5;
          final r = i.isEven ? 44.0 : 21.0;
          final pt = Offset(50 + cos(a) * r, 54 + sin(a) * r);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        p.close();
        _fs(c, p, color);
        _face(c, const Offset(50, 58), 7);
      case ObjectKind.fish:
        final tail = Path()
          ..moveTo(70, 50)
          ..lineTo(94, 30)
          ..quadraticBezierTo(88, 50, 94, 70)
          ..close();
        _fs(c, tail, _dark);
        final body = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(44, 50),
              width: 66,
              height: 46,
            ),
          );
        _fs(c, body, color);
        c.drawArc(
          Rect.fromCenter(center: const Offset(52, 50), width: 18, height: 30),
          -pi / 2,
          pi,
          false,
          _stroke..color = _dark,
        );
        c.drawCircle(const Offset(28, 46), 5, Paint()..color = Palette.catEye);
        c.drawCircle(
          const Offset(26.5, 44.5),
          1.6,
          Paint()..color = Colors.white,
        );
        _shine(c, const Offset(38, 36), 12, 5);
      case ObjectKind.duck:
        final body = Path()
          ..moveTo(20, 60)
          ..quadraticBezierTo(14, 88, 50, 90)
          ..quadraticBezierTo(86, 90, 88, 64)
          ..quadraticBezierTo(90, 52, 80, 58)
          ..quadraticBezierTo(60, 66, 44, 56)
          ..close();
        _fs(c, body, color);
        final head = Path()
          ..addOval(Rect.fromCircle(center: const Offset(36, 38), radius: 20));
        _fs(c, head, color);
        final beak = Path()
          ..moveTo(16, 40)
          ..quadraticBezierTo(2, 42, 6, 48)
          ..quadraticBezierTo(14, 50, 20, 46)
          ..close();
        _fs(c, beak, const Color(0xFFFF9F5A));
        c.drawCircle(const Offset(32, 34), 4, Paint()..color = Palette.catEye);
        c.drawCircle(const Offset(31, 33), 1.3, Paint()..color = Colors.white);
        c.drawArc(
          Rect.fromCenter(center: const Offset(58, 70), width: 30, height: 18),
          0,
          pi,
          false,
          _stroke..color = _dark,
        );
        c.drawOval(
          Rect.fromCenter(center: const Offset(40, 46), width: 8, height: 5),
          Paint()..color = Palette.catCheek,
        );
      case ObjectKind.balloon:
        final string = Path()
          ..moveTo(50, 76)
          ..quadraticBezierTo(42, 86, 50, 92)
          ..quadraticBezierTo(56, 96, 50, 100);
        c.drawPath(string, _stroke..strokeWidth = 2.5);
        final knot = Path()
          ..moveTo(45, 78)
          ..lineTo(55, 78)
          ..lineTo(50, 72)
          ..close();
        _fs(c, knot, color);
        final b = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(50, 40),
              width: 62,
              height: 72,
            ),
          );
        _fs(c, b, color);
        _shine(c, const Offset(36, 26), 10, 18);
      case ObjectKind.ball:
        final b = Path()
          ..addOval(Rect.fromCircle(center: const Offset(50, 52), radius: 40));
        _fs(c, b, color);
        c.save();
        c.clipPath(b);
        c.drawRect(
          const Rect.fromLTWH(0, 44, 100, 14),
          Paint()..color = Colors.white.withValues(alpha: .85),
        );
        c.restore();
        c.drawLine(
          const Offset(12, 44),
          const Offset(88, 44),
          _stroke..strokeWidth = 3,
        );
        c.drawLine(
          const Offset(12, 58),
          const Offset(88, 58),
          _stroke..strokeWidth = 3,
        );
        c.drawPath(b, _stroke);
        _shine(c, const Offset(34, 30), 14, 8);
      case ObjectKind.flower:
        c.drawLine(
          const Offset(50, 60),
          const Offset(50, 98),
          _stroke
            ..color = const Color(0xFF5DA05A)
            ..strokeWidth = 6,
        );
        // 꽃잎을 하나의 윤곽으로 합쳐 겹친 선이 보이지 않게 한다
        var petals = Path();
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          final petal = Path()
            ..addOval(
              Rect.fromCircle(
                center: Offset(50 + cos(a) * 22, 42 + sin(a) * 22),
                radius: 16,
              ),
            );
          petals = i == 0
              ? petal
              : Path.combine(PathOperation.union, petals, petal);
        }
        _fs(c, petals, color);
        _fs(
          c,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(50, 42), radius: 13),
          ),
          const Color(0xFFFFE08A),
        );
        _face(c, const Offset(50, 44), 4.5);
    }
  }

  void _face(Canvas c, Offset o, double gap) {
    final ink = Paint()..color = Palette.catEye;
    c.drawCircle(o + Offset(-gap, -2), 2.6, ink);
    c.drawCircle(o + Offset(gap, -2), 2.6, ink);
    c.drawArc(
      Rect.fromCenter(
        center: o + const Offset(0, 2),
        width: gap * 1.1,
        height: gap * .8,
      ),
      0,
      pi,
      false,
      Paint()
        ..color = Palette.catEye
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ObjectPainter old) =>
      old.kind != kind || old.color != color || old.faded != faded;
}

class ObjectIcon extends StatelessWidget {
  const ObjectIcon(
    this.kind, {
    super.key,
    this.color,
    this.size = 64,
    this.faded = false,
  });

  final ObjectKind kind;
  final Color? color;
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: ObjectPainter(kind, color ?? kind.naturalColor, faded: faded),
    ),
  );
}
