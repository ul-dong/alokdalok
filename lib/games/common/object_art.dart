import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/game_objects.dart';

/// 놀이에 나오는 사물을 그린다 (100 x 100 좌표계).
/// 캐릭터와 같은 그림체: 외곽선 없이 납작한 원색·파스텔 면, 같은 색 계열의 그늘·무늬 면.
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

  /// 같은 색 계열의 진한 면 (그늘·날개·꼬리)
  Color get _dark => Color.lerp(color, Colors.black, .16)!;

  /// 같은 색 계열의 밝은 면 (배·창)
  Color get _light => Color.lerp(color, Colors.white, .45)!;

  /// 외곽선 없는 납작한 면 + 오른쪽 아래 가장자리의 연한 그늘 (캐릭터와 같은 그림체).
  /// 그늘 면이 있어 밝은 바탕에서도 모양이 또렷하다.
  void _flat(
    Canvas c,
    Path p,
    Color fill, {
    Offset shade = const Offset(-5, -6),
  }) {
    c.drawPath(p, Paint()..color = fill);
    final crescent = Path.combine(PathOperation.difference, p, p.shift(shade));
    c.drawPath(crescent, Paint()..color = Color.lerp(fill, Colors.black, .13)!);
  }

  /// 둥근 끝의 굵은 띠 (줄기·끈·꼭지). 선이 아니라 색 면으로 쓴다.
  void _band(Canvas c, Path p, Color col, double w) => c.drawPath(
    p,
    Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  void _shine(Canvas c, Offset o, double w, double h) {
    c.drawOval(
      Rect.fromCenter(center: o, width: w, height: h),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
  }

  static const _leaf = Color(0xFF5DBB5A);
  static const _stem = Color(0xFF9A6A44);
  static const _glass = Color(0xFFDDF1FF);
  static const _tyre = Color(0xFF4F4A52);
  static const _hub = Color(0xFFD9D6DC);
  static const _beak = Color(0xFFFF8A3D);

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
        _band(
          c,
          Path()
            ..moveTo(50, 32)
            ..quadraticBezierTo(50, 20, 55, 12),
          _stem,
          6,
        );
        final leaf = Path()
          ..moveTo(55, 19)
          ..quadraticBezierTo(68, 4, 82, 13)
          ..quadraticBezierTo(70, 28, 55, 19)
          ..close();
        c.drawPath(leaf, Paint()..color = _leaf);
        _flat(c, body, color);
        _shine(c, const Offset(30, 46), 10, 17);
      case ObjectKind.car:
        final top = Path()
          ..moveTo(24, 50)
          ..lineTo(33, 27)
          ..quadraticBezierTo(36, 21, 43, 21)
          ..lineTo(62, 21)
          ..quadraticBezierTo(68, 21, 71, 27)
          ..lineTo(80, 50)
          ..close();
        final body = Path()
          ..addRRect(RRect.fromLTRBR(6, 44, 94, 78, const Radius.circular(13)));
        final whole = Path.combine(PathOperation.union, top, body);
        _flat(c, whole, color);
        for (final w in [
          RRect.fromLTRBR(37, 27, 50, 43, const Radius.circular(4)),
          RRect.fromLTRBR(55, 27, 68, 43, const Radius.circular(4)),
        ]) {
          c.drawRRect(w, Paint()..color = _glass);
        }
        // 차체 아래 띠 (진한 같은 색)
        c.drawRRect(
          RRect.fromLTRBR(6, 66, 94, 78, const Radius.circular(10)),
          Paint()..color = _dark,
        );
        c.drawCircle(
          const Offset(87, 55),
          4.5,
          Paint()..color = const Color(0xFFFFE97A),
        );
        for (final x in [28.0, 72.0]) {
          c.drawCircle(Offset(x, 78), 12, Paint()..color = _tyre);
          c.drawCircle(Offset(x, 78), 5, Paint()..color = _hub);
        }
        _shine(c, const Offset(19, 54), 10, 5);
      case ObjectKind.star:
        final p = Path();
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * pi / 5;
          final r = i.isEven ? 45.0 : 22.0;
          final pt = Offset(50 + cos(a) * r, 54 + sin(a) * r);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        p.close();
        _flat(c, p, color, shade: const Offset(-4, -5));
        _face(c, const Offset(50, 58), 7);
        _shine(c, const Offset(40, 40), 7, 5);
      case ObjectKind.fish:
        final tail = Path()
          ..moveTo(68, 50)
          ..lineTo(95, 29)
          ..quadraticBezierTo(87, 50, 95, 71)
          ..close();
        c.drawPath(tail, Paint()..color = _dark);
        final body = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(44, 50),
              width: 68,
              height: 48,
            ),
          );
        _flat(c, body, color);
        // 지느러미 (진한 같은 색 면)
        final fin = Path()
          ..moveTo(48, 40)
          ..quadraticBezierTo(62, 44, 56, 62)
          ..quadraticBezierTo(50, 52, 48, 40)
          ..close();
        c.drawPath(fin, Paint()..color = _dark);
        // 배 (밝은 같은 색 면)
        c.drawOval(
          Rect.fromCenter(center: const Offset(36, 62), width: 28, height: 10),
          Paint()..color = _light,
        );
        c.drawCircle(
          const Offset(27, 45),
          5.5,
          Paint()..color = Palette.catEye,
        );
        c.drawCircle(
          const Offset(25.5, 43.5),
          1.8,
          Paint()..color = Colors.white,
        );
        _shine(c, const Offset(40, 35), 12, 5);
      case ObjectKind.duck:
        final body = Path()
          ..moveTo(20, 60)
          ..quadraticBezierTo(14, 90, 50, 91)
          ..quadraticBezierTo(87, 91, 89, 64)
          ..quadraticBezierTo(91, 51, 80, 57)
          ..quadraticBezierTo(60, 66, 44, 56)
          ..close();
        final head = Path()
          ..addOval(Rect.fromCircle(center: const Offset(36, 38), radius: 20));
        final beak = Path()
          ..moveTo(18, 39)
          ..quadraticBezierTo(2, 40, 5, 47)
          ..quadraticBezierTo(13, 51, 21, 46)
          ..close();
        c.drawPath(beak, Paint()..color = _beak);
        _flat(c, Path.combine(PathOperation.union, body, head), color);
        // 날개 (진한 같은 색 면)
        final wing = Path()
          ..moveTo(44, 66)
          ..quadraticBezierTo(58, 58, 74, 66)
          ..quadraticBezierTo(62, 82, 44, 66)
          ..close();
        c.drawPath(wing, Paint()..color = _dark);
        c.drawCircle(
          const Offset(32, 34),
          4.2,
          Paint()..color = Palette.catEye,
        );
        c.drawCircle(const Offset(31, 33), 1.4, Paint()..color = Colors.white);
        c.drawOval(
          Rect.fromCenter(center: const Offset(41, 45), width: 8, height: 5),
          Paint()..color = Palette.catCheek,
        );
      case ObjectKind.balloon:
        _band(
          c,
          Path()
            ..moveTo(50, 78)
            ..quadraticBezierTo(42, 87, 50, 92)
            ..quadraticBezierTo(56, 96, 50, 100),
          const Color(0xFFB9A796),
          2.5,
        );
        final knot = Path()
          ..moveTo(44, 80)
          ..lineTo(56, 80)
          ..lineTo(50, 72)
          ..close();
        c.drawPath(knot, Paint()..color = _dark);
        final b = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(50, 40),
              width: 64,
              height: 74,
            ),
          );
        _flat(c, b, color);
        _shine(c, const Offset(35, 25), 10, 19);
      case ObjectKind.ball:
        final b = Path()
          ..addOval(Rect.fromCircle(center: const Offset(50, 52), radius: 41));
        _flat(c, b, color);
        c.save();
        c.clipPath(b);
        // 흰 띠 (비치볼 무늬)
        c.drawRect(
          const Rect.fromLTWH(0, 43, 100, 16),
          Paint()..color = Colors.white.withValues(alpha: .9),
        );
        c.restore();
        _shine(c, const Offset(33, 29), 14, 8);
      case ObjectKind.flower:
        _band(
          c,
          Path()
            ..moveTo(50, 60)
            ..lineTo(50, 98),
          _leaf,
          7,
        );
        final leaf = Path()
          ..moveTo(50, 86)
          ..quadraticBezierTo(62, 70, 76, 74)
          ..quadraticBezierTo(66, 90, 50, 86)
          ..close();
        c.drawPath(leaf, Paint()..color = _leaf);
        // 꽃잎을 하나의 면으로 합친다
        var petals = Path();
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          final petal = Path()
            ..addOval(
              Rect.fromCircle(
                center: Offset(50 + cos(a) * 22, 42 + sin(a) * 22),
                radius: 17,
              ),
            );
          petals = i == 0
              ? petal
              : Path.combine(PathOperation.union, petals, petal);
        }
        _flat(c, petals, color);
        c.drawCircle(
          const Offset(50, 42),
          13,
          Paint()..color = const Color(0xFFFFE08A),
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
      // 사과는 늘 빨강, 오리는 늘 노랑 (고유색이 있는 물건은 색을 바꾸지 않는다)
      painter: ObjectPainter(
        kind,
        kind.paintColor(color) ?? kind.naturalColor,
        faded: faded,
      ),
    ),
  );
}
