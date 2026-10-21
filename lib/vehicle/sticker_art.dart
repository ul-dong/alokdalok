import 'dart:math';

import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
import '../data/vehicles.dart';

/// 스티커 그림. 외곽선 없이 흰 테두리만 두른 말랑한 스티커 (친구·탈것과 같은 납작한 그림체).
class StickerArt {
  StickerArt._();

  /// [o]를 중심으로 반지름 [r]만큼의 스티커를 그린다.
  static void draw(
    Canvas c,
    StickerKind kind,
    Color color,
    Offset o,
    double r,
  ) {
    final shape = path(kind, o, r);
    // 스티커 흰 테두리 (외곽선 없음)
    c.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .32
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(shape, Paint()..color = color);
    _details(c, kind, o, r);
  }

  static Path path(StickerKind kind, Offset o, double r) {
    switch (kind) {
      case StickerKind.star:
        return _star(o, r, .48);
      case StickerKind.heart:
        return Path()
          ..moveTo(o.dx, o.dy + r * .85)
          ..cubicTo(
            o.dx - r * 1.3,
            o.dy,
            o.dx - r * .7,
            o.dy - r * 1.05,
            o.dx,
            o.dy - r * .35,
          )
          ..cubicTo(
            o.dx + r * .7,
            o.dy - r * 1.05,
            o.dx + r * 1.3,
            o.dy,
            o.dx,
            o.dy + r * .85,
          )
          ..close();
      case StickerKind.flower:
        var p = Path()..addOval(Rect.fromCircle(center: o, radius: r * .45));
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(
              Rect.fromCircle(
                center: o + Offset(cos(a), sin(a)) * r * .55,
                radius: r * .42,
              ),
            ),
          );
        }
        return p;
      case StickerKind.lightning:
        return Path()
          ..moveTo(o.dx + r * .2, o.dy - r)
          ..lineTo(o.dx - r * .6, o.dy + r * .1)
          ..lineTo(o.dx - r * .05, o.dy + r * .1)
          ..lineTo(o.dx - r * .25, o.dy + r)
          ..lineTo(o.dx + r * .6, o.dy - r * .15)
          ..lineTo(o.dx + r * .05, o.dy - r * .15)
          ..close();
      case StickerKind.moon:
        return Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: o, radius: r)),
          Path()..addOval(
            Rect.fromCircle(
              center: o + Offset(r * .45, -r * .3),
              radius: r * .8,
            ),
          ),
        );
      case StickerKind.rainbow:
        return Path.combine(
          PathOperation.difference,
          Path()
            ..addArc(
              Rect.fromCircle(center: o + Offset(0, r * .4), radius: r),
              pi,
              pi,
            )
            ..close(),
          Path()
            ..addArc(
              Rect.fromCircle(center: o + Offset(0, r * .4), radius: r * .45),
              pi,
              pi,
            )
            ..close(),
        );
      case StickerKind.paw:
        var p = Path()
          ..addOval(
            Rect.fromCenter(
              center: o + Offset(0, r * .3),
              width: r * 1.1,
              height: r * .9,
            ),
          );
        for (final d in [
          Offset(-r * .65, -r * .2),
          Offset(-r * .22, -r * .65),
          Offset(r * .22, -r * .65),
          Offset(r * .65, -r * .2),
        ]) {
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(Rect.fromCircle(center: o + d, radius: r * .27)),
          );
        }
        return p;
      case StickerKind.smile:
        return Path()..addOval(Rect.fromCircle(center: o, radius: r));
      case StickerKind.cloud:
        var p = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: o + Offset(0, r * .2),
                width: r * 2,
                height: r * .9,
              ),
              Radius.circular(r * .45),
            ),
          );
        for (final (d, rr) in [
          (Offset(-r * .4, -r * .1), r * .5),
          (Offset(r * .25, -r * .3), r * .62),
        ]) {
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(Rect.fromCircle(center: o + d, radius: rr)),
          );
        }
        return p;
      case StickerKind.note:
        return Path.combine(
          PathOperation.union,
          Path()..addOval(
            Rect.fromCenter(
              center: o + Offset(-r * .3, r * .55),
              width: r * .9,
              height: r * .65,
            ),
          ),
          Path()
            ..moveTo(o.dx + r * .05, o.dy + r * .5)
            ..lineTo(o.dx + r * .05, o.dy - r)
            ..lineTo(o.dx + r * .75, o.dy - r * .6)
            ..lineTo(o.dx + r * .75, o.dy - r * .3)
            ..lineTo(o.dx + r * .3, o.dy - r * .52)
            ..lineTo(o.dx + r * .3, o.dy + r * .5)
            ..close(),
        );
    }
  }

  static void _details(Canvas c, StickerKind kind, Offset o, double r) {
    if (kind == StickerKind.smile) {
      final ink = Paint()..color = AnimalPainter.feature;
      c.drawCircle(o + Offset(-r * .35, -r * .2), r * .13, ink);
      c.drawCircle(o + Offset(r * .35, -r * .2), r * .13, ink);
      c.drawArc(
        Rect.fromCircle(center: o + Offset(0, r * .05), radius: r * .45),
        .3,
        pi - .6,
        false,
        AnimalPainter.stroke(r * .1, AnimalPainter.feature),
      );
    } else if (kind == StickerKind.flower) {
      c.drawCircle(o, r * .28, Paint()..color = const Color(0xFFFFE08A));
    } else if (kind == StickerKind.rainbow) {
      final rect = Rect.fromCircle(
        center: o + Offset(0, r * .4),
        radius: r * .72,
      );
      c.drawArc(
        rect,
        pi,
        pi,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .14,
      );
    }
  }

  static Path _star(Offset o, double r, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * inner;
      final pt = o + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }
}

/// 스티커 하나를 위젯으로 (팔레트 버튼용)
class StickerIcon extends StatelessWidget {
  const StickerIcon({
    super.key,
    required this.kind,
    required this.color,
    this.size = 48,
  });

  final StickerKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StickerIconPainter(kind, color)),
  );
}

class _StickerIconPainter extends CustomPainter {
  _StickerIconPainter(this.kind, this.color);
  final StickerKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => StickerArt.draw(
    canvas,
    kind,
    color,
    size.center(Offset.zero),
    size.shortestSide * .36,
  );

  @override
  bool shouldRepaint(_StickerIconPainter old) =>
      old.kind != kind || old.color != color;
}
