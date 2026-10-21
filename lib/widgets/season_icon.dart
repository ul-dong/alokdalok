import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../games/common/scene_game.dart';

/// 계절 그림 아이콘 (직접 그린 그림): 봄=벚꽃, 여름=해, 가을=단풍잎, 겨울=눈송이.
class SeasonIcon extends StatelessWidget {
  const SeasonIcon(this.season, {super.key, this.size = 30, this.dim = false});
  final Season season;
  final double size;

  /// 잠긴 단계처럼 흐리게
  final bool dim;

  static Color colorOf(Season s) => switch (s) {
    Season.spring => const Color(0xFFF59AB5),
    Season.summer => const Color(0xFFFFB93B),
    Season.autumn => const Color(0xFFE9824A),
    Season.winter => const Color(0xFF6FB7E8),
  };

  /// 단계 카드 바탕에 아주 옅게 까는 계절 색
  static Color tintOf(Season s) => switch (s) {
    Season.spring => const Color(0xFFFFF3F5),
    Season.summer => const Color(0xFFFFF8E1),
    Season.autumn => const Color(0xFFFFF1E6),
    Season.winter => const Color(0xFFEFF7FD),
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: season.ko,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SeasonPainter(season, dim)),
    ),
  );
}

class _SeasonPainter extends CustomPainter {
  _SeasonPainter(this.season, this.dim);
  final Season season;
  final bool dim;

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 40;
    c.save();
    c.scale(u);
    final main = dim ? Palette.creamDeep : SeasonIcon.colorOf(season);
    final ol = Paint()
      ..color = dim
          ? Palette.outlineSoft.withValues(alpha: .4)
          : Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = main;
    const o = Offset(20, 20);
    switch (season) {
      case Season.spring:
        // 다섯 잎 벚꽃 (잎 끝이 살짝 패인 모양)
        final petals = Path();
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          petals.addOval(
            Rect.fromCircle(
              center: o + Offset(cos(a), sin(a)) * 9,
              radius: 7.5,
            ),
          );
        }
        c.drawPath(petals, fill);
        c.drawPath(petals, ol);
        c.drawCircle(
          o,
          5,
          Paint()..color = dim ? Palette.cream : const Color(0xFFFFE08A),
        );
      case Season.summer:
        for (var i = 0; i < 8; i++) {
          final a = i * pi / 4;
          c.drawLine(
            o + Offset(cos(a), sin(a)) * 13,
            o + Offset(cos(a), sin(a)) * 18,
            Paint()
              ..color = main
              ..strokeWidth = 3.4
              ..strokeCap = StrokeCap.round,
          );
        }
        c.drawCircle(o, 10.5, fill);
        c.drawCircle(o, 10.5, ol);
      case Season.autumn:
        // 둥근 단풍잎 + 줄기
        final leaf = Path()
          ..moveTo(20, 4)
          ..quadraticBezierTo(27, 10, 34, 9)
          ..quadraticBezierTo(32, 16, 36, 22)
          ..quadraticBezierTo(28, 24, 24, 31)
          ..lineTo(20, 28)
          ..lineTo(16, 31)
          ..quadraticBezierTo(12, 24, 4, 22)
          ..quadraticBezierTo(8, 16, 6, 9)
          ..quadraticBezierTo(13, 10, 20, 4)
          ..close();
        c.drawPath(leaf, fill);
        c.drawPath(leaf, ol);
        c.drawLine(const Offset(20, 12), const Offset(20, 37), ol);
      case Season.winter:
        final line = Paint()
          ..color = main
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final a = i * pi / 3 + pi / 2;
          final d = Offset(cos(a), sin(a)) * 16;
          c.drawLine(o - d, o + d, line);
          // 가지
          for (final sgn in [-1.0, 1.0]) {
            final tip = o + d * sgn;
            final mid = o + d * sgn * .55;
            final side = Offset(-d.dy, d.dx) / 16 * 5;
            c.drawLine(
              mid,
              tip - d * sgn * .05 + side,
              line..strokeWidth = 2.6,
            );
            c.drawLine(mid, tip - d * sgn * .05 - side, line);
            line.strokeWidth = 3.4;
          }
        }
        c.drawCircle(o, 3.5, fill);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_SeasonPainter old) =>
      old.season != season || old.dim != dim;
}
