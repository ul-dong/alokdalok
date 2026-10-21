import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/game_state.dart';

/// 놀이터 그림 (모두 직접 그린 오리지널 그림).
/// 기구: 미끄럼틀=숫자, 그네=색깔, 모래놀이터=모양, 시소=크기, 회전목마=짝 맞추기.

Paint _fill(Color c) => Paint()..color = c;
Paint _line(double w, [Color c = Palette.outline]) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// 놀이터 배경: 하늘, 해, 무지개, 구름, 연, 먼 언덕과 나무, 울타리, 덤불, 꽃, 모랫길.
/// 모두 멈춰 있는 그림이다 (계속 움직이는 것 없음). 넓은 화면일수록 장식이 늘어난다.
class PlaygroundBackgroundPainter extends CustomPainter {
  const PlaygroundBackgroundPainter({this.groundLevel = .56});

  /// 잔디가 시작하는 높이 (0~1)
  final double groundLevel;

  /// 화면 비율에 맞는 잔디 높이: 키가 큰 화면(태블릿)은 땅을 내려서 하늘이 너무 넓지 않게.
  static double groundFor(Size s) {
    final aspect = s.height / max(1.0, s.width);
    return (.5 + (aspect - .46) * 1.1).clamp(.5, .64).toDouble();
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final g = h * groundLevel;
    // 사물 크기 단위 (작은 쪽 기준)
    final u = min(w * .62, h) / 400;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.skyTop, Palette.skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, g)),
    );

    // 무지개 (언덕 뒤에서 떠오르는 큰 반원, 아주 옅게)
    final rc = Offset(w * .36, g + h * .02);
    final rr = min(w * .3, g * .78);
    const bands = [
      Color(0xFFF7A3A3),
      Color(0xFFFFC98A),
      Color(0xFFFFE89A),
      Color(0xFFB9E3A0),
      Color(0xFFA9D6F5),
      Color(0xFFC9B8EC),
    ];
    final bw = rr * .07;
    for (var i = 0; i < bands.length; i++) {
      c.drawArc(
        Rect.fromCircle(center: rc, radius: rr - i * bw),
        pi,
        pi,
        false,
        Paint()
          ..color = bands[i].withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bw + .5,
      );
    }

    // 해 (빛무리 + 볼터치 얼굴 없이 단순하게)
    final sun = Offset(w * .9, h * .15);
    final sr = max(h * .055, 22 * u);
    c.drawCircle(sun, sr * 1.5, _fill(const Color(0x33FFE08A)));
    c.drawCircle(sun, sr * 1.22, _fill(const Color(0xFFFFE08A)));
    c.drawCircle(sun, sr, _fill(const Color(0xFFFFCF4D)));

    // 구름 (넓은 화면일수록 많이)
    void cloud(double x, double y, double r) {
      final p = _fill(Colors.white.withValues(alpha: .95));
      c.drawCircle(Offset(x, y), r, p);
      c.drawCircle(Offset(x + r * .9, y + r * .2), r * .8, p);
      c.drawCircle(Offset(x - r * .9, y + r * .25), r * .7, p);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - r * 1.5, y, r * 3.1, r * .9),
          Radius.circular(r * .45),
        ),
        p,
      );
    }

    final cr = 22 * u;
    cloud(w * .18, g * .2, cr * 1.1);
    cloud(w * .55, g * .13, cr * .9);
    if (g > 260) {
      cloud(w * .7, g * .42, cr * .8);
      cloud(w * .06, g * .52, cr * .7);
    }

    // 연 (하늘에 멈춰 있는 마름모 연과 꼬리)
    if (g > 200) {
      final k = Offset(w * .68, g * .3);
      final ks = 26 * u;
      final kite = Path()
        ..moveTo(k.dx, k.dy - ks)
        ..lineTo(k.dx + ks * .7, k.dy)
        ..lineTo(k.dx, k.dy + ks)
        ..lineTo(k.dx - ks * .7, k.dy)
        ..close();
      c.drawPath(kite, _fill(const Color(0xFFF26B5E)));
      c.save();
      c.clipPath(kite);
      c.drawRect(
        Rect.fromLTRB(k.dx, k.dy - ks, k.dx + ks, k.dy),
        _fill(const Color(0xFFFFCF4D)),
      );
      c.drawRect(
        Rect.fromLTRB(k.dx - ks, k.dy, k.dx, k.dy + ks),
        _fill(const Color(0xFFFFCF4D)),
      );
      c.restore();
      c.drawPath(kite, _line(2.4 * u + .6));
      final tail = Path()..moveTo(k.dx, k.dy + ks);
      for (var i = 1; i <= 3; i++) {
        tail.quadraticBezierTo(
          k.dx + (i.isOdd ? 10 : -10) * u,
          k.dy + ks + (i - .5) * 16 * u,
          k.dx,
          k.dy + ks + i * 16 * u,
        );
      }
      c.drawPath(tail, _line(1.8 * u + .4));
      for (var i = 1; i <= 3; i++) {
        final bow = Offset(k.dx, k.dy + ks + i * 16 * u);
        c.drawOval(
          Rect.fromCenter(center: bow, width: 10 * u, height: 6 * u),
          _fill(i.isOdd ? Palette.pink : const Color(0xFF6FB7E8)),
        );
      }
    }

    // 먼 언덕 (두 겹)
    Path hills(double base, double amp, int n, double phase) {
      final p = Path()..moveTo(0, base);
      for (var i = 0; i <= n; i++) {
        final x = w * i / n;
        p.quadraticBezierTo(
          x - w / (2 * n),
          base - amp * (1 + ((i + phase) % 2) * .6),
          x,
          base,
        );
      }
      return p
        ..lineTo(w, base + 4)
        ..lineTo(0, base + 4)
        ..close();
    }

    c.drawPath(hills(g, h * .1, 5, 1), _fill(const Color(0xFFD6EFBE)));
    c.drawPath(hills(g, h * .06, 7, 0), _fill(const Color(0xFFC1E5A0)));

    // 나무 (둥근 잎, 갈색 외곽선)
    void tree(double x, double scale, Color leaf) {
      final th = 60 * u * scale;
      final trunk = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - th * .08, g - th * .5, th * .16, th * .52),
        Radius.circular(th * .05),
      );
      c.drawRRect(trunk, _fill(const Color(0xFFB98A5E)));
      c.drawRRect(trunk, _line(2 * u + .4));
      final crown = Path()
        ..addOval(
          Rect.fromCircle(center: Offset(x, g - th * .78), radius: th * .36),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(x - th * .26, g - th * .6),
            radius: th * .24,
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(x + th * .26, g - th * .58),
            radius: th * .25,
          ),
        );
      // 동그라미 세 개를 합친 한 덩어리 (안쪽 겹친 선이 보이지 않게)
      final leaves = _union(crown);
      c.drawPath(leaves, _fill(leaf));
      c.drawPath(leaves, _line(2 * u + .4));
      // 열매 몇 개
      for (final o in [const Offset(-.12, -.82), const Offset(.18, -.66)]) {
        c.drawCircle(
          Offset(x + o.dx * th, g + o.dy * th),
          th * .045,
          _fill(const Color(0xFFF26B5E)),
        );
      }
    }

    tree(w * .045, 1.15, const Color(0xFF8CCB6A));
    tree(w * .965, .95, const Color(0xFF7DBE5C));
    if (w > 700) {
      tree(w * .29, .7, const Color(0xFF9AD27A));
      tree(w * .74, .8, const Color(0xFF8CCB6A));
    }

    // 잔디
    c.drawRect(
      Rect.fromLTWH(0, g, w, h - g),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.grass, Palette.grassDeep],
        ).createShader(Rect.fromLTWH(0, g, w, h - g)),
    );
    // 울타리 (흰 말뚝 + 가로대, 갈색 외곽선은 얇게)
    final fy = g - h * .005;
    final postH = max(18 * u, h * .06);
    final postW = max(7 * u, h * .016);
    final railPaint = _fill(const Color(0xFFFFFBF2));
    final rail1 = Rect.fromLTWH(0, fy - postH * .72, w, postW * .55);
    final rail2 = Rect.fromLTWH(0, fy - postH * .36, w, postW * .55);
    for (final r in [rail1, rail2]) {
      c.drawRect(r, railPaint);
      c.drawLine(
        r.bottomLeft,
        r.bottomRight,
        _line(1, const Color(0x33B08A6E)),
      );
    }
    for (var x = w * .015; x < w; x += max(22 * u, w * .04)) {
      final post = Path()
        ..moveTo(x, fy)
        ..lineTo(x, fy - postH + postW * .5)
        ..lineTo(x + postW / 2, fy - postH)
        ..lineTo(x + postW, fy - postH + postW * .5)
        ..lineTo(x + postW, fy)
        ..close();
      c.drawPath(post, railPaint);
      c.drawPath(post, _line(1.2, const Color(0x66B08A6E)));
    }
    // 울타리 앞 덤불
    final bush = _fill(const Color(0xFF8FCC6E));
    final bushDeep = _fill(const Color(0xFF7DBE5C));
    for (final bx in [.12, .44, .58, .86]) {
      final o = Offset(w * bx, fy + 2 * u);
      final r = 14 * u;
      c.drawCircle(o + Offset(-r * .9, 0), r * .8, bushDeep);
      c.drawCircle(o, r, bush);
      c.drawCircle(o + Offset(r * .9, r * .1), r * .75, bushDeep);
    }

    // 모랫길 (앞쪽으로 넓어지는 띠)
    final path = Path()
      ..moveTo(0, h * .86)
      ..quadraticBezierTo(w * .5, h * .76, w, h * .84)
      ..lineTo(w, h * .95)
      ..quadraticBezierTo(w * .5, h * .87, 0, h * .98)
      ..close();
    c.drawPath(path, _fill(Palette.sand.withValues(alpha: .85)));
    // 잔디 풀잎
    final blade = _line(max(1.5, h * .005), const Color(0xFF79B957));
    final rnd = Random(7);
    final blades = (w / 30).round();
    for (var i = 0; i < blades; i++) {
      final x = rnd.nextDouble() * w;
      final y = g + h * .05 + rnd.nextDouble() * (h - g) * .7;
      c.drawLine(Offset(x, y), Offset(x - 3, y - h * .02), blade);
      c.drawLine(Offset(x, y), Offset(x + 3, y - h * .022), blade);
    }
    // 작은 꽃 (울타리 밑 덤불 사이에만: 기구 그림과 겹치지 않게)
    const petals = [
      Color(0xFFF59AB5),
      Color(0xFFFFFFFF),
      Color(0xFFFFCF4D),
      Color(0xFFC6B5E8),
    ];
    for (var i = 0; i < (w / 110).round(); i++) {
      final x = rnd.nextDouble() * w;
      final y = g + (h - g) * (.05 + rnd.nextDouble() * .05);
      final pr = 3.6 * u;
      final col = petals[i % petals.length];
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * pi / 5;
        c.drawCircle(
          Offset(x, y) + Offset(cos(a), sin(a)) * pr,
          pr,
          _fill(col),
        );
      }
      c.drawCircle(Offset(x, y), pr * .8, _fill(const Color(0xFFFFB347)));
    }
  }

  @override
  bool shouldRepaint(PlaygroundBackgroundPainter old) =>
      old.groundLevel != groundLevel;
}

/// 놀이 기구 하나. 100×100 칸 좌표로 그린 뒤 크기에 맞춘다.
class EquipmentPainter extends CustomPainter {
  const EquipmentPainter(this.kind);
  final GameKind kind;

  @override
  void paint(Canvas c, Size s) {
    final u = min(s.width, s.height) / 100;
    c.save();
    c.translate((s.width - 100 * u) / 2, s.height - 100 * u);
    c.scale(u);
    // 땅 그림자
    c.drawOval(
      const Rect.fromLTWH(8, 90, 84, 9),
      _fill(const Color(0x22000000)),
    );
    switch (kind) {
      case GameKind.number:
        _slide(c);
      case GameKind.color:
        _swing(c);
      case GameKind.shape:
        _sandbox(c);
      case GameKind.size:
        _seesaw(c);
      case GameKind.match:
        _carousel(c);
    }
    c.restore();
  }

  static final _ol = _line(2.6);

  void _slide(Canvas c) {
    // 사다리
    final rail = _fill(const Color(0xFFFFCF4D));
    for (final x in [16.0, 30.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 22, 6, 72),
        const Radius.circular(3),
      );
      c.drawRRect(r, rail);
      c.drawRRect(r, _ol);
    }
    for (var y = 34.0; y < 92; y += 12) {
      c.drawLine(Offset(21, y), Offset(31, y), _line(3.4));
    }
    // 꼭대기 발판과 지붕
    final deck = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 20, 32, 7),
      const Radius.circular(3),
    );
    c.drawRRect(deck, _fill(const Color(0xFF6FB7E8)));
    c.drawRRect(deck, _ol);
    final roof = Path()
      ..moveTo(10, 10)
      ..lineTo(28, 0)
      ..lineTo(46, 10)
      ..close();
    c.drawPath(roof, _fill(const Color(0xFFF26B5E)));
    c.drawPath(roof, _ol);
    c.drawLine(const Offset(14, 10), const Offset(14, 20), _line(3));
    c.drawLine(const Offset(42, 10), const Offset(42, 20), _line(3));
    // 미끄럼판
    final chute = Path()
      ..moveTo(40, 20)
      ..cubicTo(62, 26, 66, 72, 94, 84)
      ..lineTo(94, 94)
      ..cubicTo(62, 84, 56, 40, 40, 30)
      ..close();
    c.drawPath(chute, _fill(Palette.pink));
    c.drawPath(chute, _ol);
    final shine = Path()
      ..moveTo(44, 24)
      ..cubicTo(60, 32, 64, 70, 90, 86);
    c.drawPath(shine, _line(2.2, Colors.white.withValues(alpha: .8)));
  }

  void _swing(Canvas c) {
    final frame = _line(6, const Color(0xFF4F95CF));
    // 양쪽 A자 다리
    for (final (top, l, r) in [(14.0, 4.0, 24.0), (86.0, 76.0, 96.0)]) {
      c.drawLine(Offset(top, 12), Offset(l, 94), frame);
      c.drawLine(Offset(top, 12), Offset(r, 94), frame);
    }
    c.drawLine(const Offset(10, 12), const Offset(90, 12), _line(7));
    c.drawLine(
      const Offset(10, 12),
      const Offset(90, 12),
      _line(4.5, const Color(0xFF6FB7E8)),
    );
    // 그네 두 개 (줄 + 의자)
    for (final (x, color) in [
      (36.0, const Color(0xFFF26B5E)),
      (64.0, const Color(0xFFFFCF4D)),
    ]) {
      c.drawLine(Offset(x - 7, 13), Offset(x - 7, 70), _line(1.8));
      c.drawLine(Offset(x + 7, 13), Offset(x + 7, 70), _line(1.8));
      final seat = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 10, 68, 20, 6),
        const Radius.circular(3),
      );
      c.drawRRect(seat, _fill(color));
      c.drawRRect(seat, _ol);
    }
  }

  void _sandbox(Canvas c) {
    // 나무 테두리 (앞이 넓은 사다리꼴)
    final outer = Path()
      ..moveTo(16, 56)
      ..lineTo(84, 56)
      ..lineTo(96, 92)
      ..lineTo(4, 92)
      ..close();
    c.drawPath(outer, _fill(const Color(0xFFD9A066)));
    c.drawPath(outer, _ol);
    final sand = Path()
      ..moveTo(21, 60)
      ..lineTo(79, 60)
      ..lineTo(88, 86)
      ..lineTo(12, 86)
      ..close();
    c.drawPath(sand, _fill(Palette.sand));
    // 모래성: 네모 + 세모 + 동그라미 깃발
    final castle = Rect.fromLTWH(30, 52, 22, 22);
    c.drawRect(castle, _fill(const Color(0xFFF5D58C)));
    c.drawRect(castle, _ol);
    final roof = Path()
      ..moveTo(28, 52)
      ..lineTo(41, 36)
      ..lineTo(54, 52)
      ..close();
    c.drawPath(roof, _fill(const Color(0xFFF0B85A)));
    c.drawPath(roof, _ol);
    c.drawLine(const Offset(41, 36), const Offset(41, 24), _line(2));
    final flag = Path()
      ..moveTo(41, 24)
      ..lineTo(51, 27)
      ..lineTo(41, 31)
      ..close();
    c.drawPath(flag, _fill(const Color(0xFFF26B5E)));
    c.drawRect(
      const Rect.fromLTWH(38, 63, 6, 11),
      _fill(const Color(0xFFC98A1E)),
    );
    // 양동이와 삽
    final bucket = Path()
      ..moveTo(60, 62)
      ..lineTo(76, 62)
      ..lineTo(73, 80)
      ..lineTo(63, 80)
      ..close();
    c.drawPath(bucket, _fill(const Color(0xFF6FB7E8)));
    c.drawPath(bucket, _ol);
    c.drawArc(const Rect.fromLTWH(60, 52, 16, 18), pi, pi, false, _line(1.8));
    c.drawLine(const Offset(20, 82), const Offset(30, 66), _line(2.6));
    c.drawOval(
      const Rect.fromLTWH(14, 78, 10, 8),
      _fill(const Color(0xFF8ED6B5)),
    );
    // 별 모양 모래틀
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final r = i.isEven ? 6.0 : 3.0;
      final p = Offset(80 + cos(a) * r, 80 + sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    c.drawPath(star, _fill(const Color(0xFFFFCF4D)));
    c.drawPath(star, _line(1.6));
  }

  void _seesaw(Canvas c) {
    // 받침
    final base = Path()
      ..moveTo(50, 62)
      ..lineTo(62, 92)
      ..lineTo(38, 92)
      ..close();
    c.drawPath(base, _fill(const Color(0xFF8ED6B5)));
    c.drawPath(base, _ol);
    // 기울어진 판
    c.save();
    c.translate(50, 62);
    c.rotate(-.2);
    final plank = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-46, -4, 92, 8),
      const Radius.circular(4),
    );
    c.drawRRect(plank, _fill(const Color(0xFFF26B5E)));
    c.drawRRect(plank, _ol);
    // 손잡이
    for (final x in [-34.0, 34.0]) {
      c.drawLine(Offset(x, -4), Offset(x, -14), _line(3));
      c.drawLine(Offset(x - 4, -14), Offset(x + 4, -14), _line(3));
    }
    // 큰 공 (내려간 쪽) / 작은 공 (올라간 쪽)
    c.drawCircle(const Offset(-42, -16), 12, _fill(const Color(0xFFFFCF4D)));
    c.drawCircle(const Offset(-42, -16), 12, _ol);
    c.drawCircle(const Offset(44, -10), 6, _fill(const Color(0xFF6FB7E8)));
    c.drawCircle(const Offset(44, -10), 6, _ol);
    c.restore();
    c.drawCircle(const Offset(50, 62), 3.2, _fill(Palette.outline));
  }

  void _carousel(Canvas c) {
    // 기둥
    c.drawLine(const Offset(50, 20), const Offset(50, 86), _line(4));
    // 받침 원판
    c.drawOval(
      const Rect.fromLTWH(6, 80, 88, 14),
      _fill(const Color(0xFFC6B5E8)),
    );
    c.drawOval(const Rect.fromLTWH(6, 80, 88, 14), _ol);
    // 말 두 마리 (기둥에 꽂힌 둥근 말)
    for (final (x, y, body, flip) in [
      (24.0, 58.0, const Color(0xFFFFFFFF), false),
      (76.0, 52.0, const Color(0xFFFFD9E3), true),
    ]) {
      c.drawLine(Offset(x, 24), Offset(x, 84), _line(2.2));
      c.save();
      c.translate(x, y);
      if (flip) c.scale(-1, 1);
      final b = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -6, 24, 13),
        const Radius.circular(6),
      );
      c.drawRRect(b, _fill(body));
      c.drawRRect(b, _line(2));
      // 목과 머리
      final head = Path()
        ..moveTo(6, -4)
        ..lineTo(12, -15)
        ..lineTo(19, -12)
        ..lineTo(14, -2)
        ..close();
      c.drawPath(head, _fill(body));
      c.drawPath(head, _line(2));
      c.drawCircle(const Offset(14, -11), 1.2, _fill(Palette.outline));
      // 다리
      for (final lx in [-8.0, 7.0]) {
        c.drawLine(Offset(lx, 6), Offset(lx - 2, 13), _line(2));
      }
      // 꼬리
      c.drawLine(const Offset(-12, -2), const Offset(-17, 4), _line(2.4));
      c.restore();
    }
    // 지붕 (줄무늬 고깔 + 물결 테두리)
    final roof = Path()
      ..moveTo(50, 2)
      ..lineTo(94, 24)
      ..lineTo(6, 24)
      ..close();
    c.drawPath(roof, _fill(const Color(0xFFF59AB5)));
    c.save();
    c.clipPath(roof);
    for (var i = -2; i < 6; i += 2) {
      final stripe = Path()
        ..moveTo(50, 2)
        ..lineTo(6 + i * 11.0 + 11, 24)
        ..lineTo(6 + i * 11.0 + 22, 24)
        ..close();
      c.drawPath(stripe, _fill(Colors.white));
    }
    c.restore();
    c.drawPath(roof, _ol);
    for (var i = 0; i < 8; i++) {
      final r = Rect.fromLTWH(6 + i * 11.0, 19, 11, 10);
      c.drawArc(r, 0, pi, true, _fill(const Color(0xFFFFCF4D)));
      c.drawArc(r, 0, pi, false, _line(1.8));
    }
    c.drawCircle(const Offset(50, 2), 3, _fill(const Color(0xFFFFCF4D)));
  }

  @override
  bool shouldRepaint(EquipmentPainter old) => old.kind != kind;
}

/// 이름표에 들어가는 작은 그림 (글자를 모르는 아이도 알아보게)
class GameBadgePainter extends CustomPainter {
  const GameBadgePainter(this.kind);
  final GameKind kind;

  @override
  void paint(Canvas c, Size s) {
    final u = min(s.width, s.height) / 40;
    c.save();
    c.translate((s.width - 40 * u) / 2, (s.height - 40 * u) / 2);
    c.scale(u);
    final ol = _line(1.6);
    switch (kind) {
      case GameKind.number:
        // 주사위 세 점
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 6, 28, 28),
          const Radius.circular(6),
        );
        c.drawRRect(r, _fill(Colors.white));
        c.drawRRect(r, ol);
        for (final p in const [
          Offset(13, 13),
          Offset(20, 20),
          Offset(27, 27),
        ]) {
          c.drawCircle(p, 3, _fill(const Color(0xFFE0607E)));
        }
      case GameKind.color:
        for (final (x, y, col) in const [
          (13.0, 15.0, Color(0xFFF26B5E)),
          (27.0, 15.0, Color(0xFF6FB7E8)),
          (20.0, 27.0, Color(0xFFFFCF4D)),
        ]) {
          c.drawCircle(Offset(x, y), 8, _fill(col));
          c.drawCircle(Offset(x, y), 8, ol);
        }
      case GameKind.shape:
        final tri = Path()
          ..moveTo(10, 4)
          ..lineTo(18, 18)
          ..lineTo(2, 18)
          ..close();
        c.drawPath(tri, _fill(const Color(0xFFF26B5E)));
        c.drawPath(tri, ol);
        c.drawCircle(const Offset(29, 11), 7, _fill(const Color(0xFF6FB7E8)));
        c.drawCircle(const Offset(29, 11), 7, ol);
        const sq = Rect.fromLTWH(13, 22, 14, 14);
        c.drawRect(sq, _fill(const Color(0xFFFFCF4D)));
        c.drawRect(sq, ol);
      case GameKind.size:
        c.drawCircle(const Offset(14, 22), 11, _fill(const Color(0xFF8ED6B5)));
        c.drawCircle(const Offset(14, 22), 11, ol);
        c.drawCircle(const Offset(32, 28), 5, _fill(const Color(0xFF8ED6B5)));
        c.drawCircle(const Offset(32, 28), 5, ol);
      case GameKind.match:
        for (final x in const [4.0, 22.0]) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 8, 14, 22),
            const Radius.circular(3),
          );
          c.drawRRect(r, _fill(Colors.white));
          c.drawRRect(r, ol);
          final heart = Path()
            ..moveTo(x + 7, 24)
            ..cubicTo(x - 1, 18, x + 3, 11, x + 7, 15)
            ..cubicTo(x + 11, 11, x + 15, 18, x + 7, 24)
            ..close();
          c.drawPath(heart, _fill(Palette.pink));
        }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(GameBadgePainter old) => old.kind != kind;
}

/// 여러 동그라미로 만든 경로를 하나로 합친다 (겹친 안쪽 선 없이 외곽선만)
Path _union(Path p) {
  final parts = p
      .computeMetrics()
      .map((m) => m.extractPath(0, m.length))
      .toList();
  if (parts.isEmpty) return p;
  var out = parts.first..close();
  for (final q in parts.skip(1)) {
    out = Path.combine(PathOperation.union, out, q..close());
  }
  return out;
}
