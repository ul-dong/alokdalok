import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/game_state.dart';

/// 놀이터 그림 (모두 직접 그린 오리지널 그림).
/// 누르는 그림은 놀이 내용물: 1·2·3 계단 미끄럼틀=숫자, 풍선 다발=색깔, 도형 블록=모양,
/// 큰 공·작은 공=크기, 양말 한 켤레=짝 맞추기.

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

/// 놀이터에서 누르는 놀이 그림: 기구 모양이 아니라 그 놀이의 내용물을 그린다
/// (글을 못 읽는 아이가 그림만 보고 무슨 놀이인지 알 수 있게).
/// 숫자 = 계단에 1·2·3이 적힌 미끄럼틀, 색깔 = 색색 풍선 다발, 모양 = 도형 블록,
/// 크기 = 큰 공과 작은 공, 짝 맞추기 = 짝이 맞는 양말 두 짝.
/// 100×100 칸 좌표로 그린 뒤 크기에 맞추고, 칸 아래쪽(땅)에 붙인다.
class PlayItemPainter extends CustomPainter {
  const PlayItemPainter(this.kind);
  final GameKind kind;

  static const _red = Color(0xFFF26B5E);
  static const _yellow = Color(0xFFFFCF4D);
  static const _blue = Color(0xFF6FB7E8);
  static const _green = Color(0xFF7CCB5B);
  static const _purple = Color(0xFFB08AE0);

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
        _numberSlide(c);
      case GameKind.color:
        _balloons(c);
      case GameKind.shape:
        _blocks(c);
      case GameKind.size:
        _balls(c);
      case GameKind.match:
        _socks(c);
    }
    c.restore();
  }

  static final _ol = _line(2.6);

  /// 흰 글씨 + 갈색 테두리 숫자 (계단 칸에 크게)
  static void _digit(Canvas c, String d, Offset center, double size) {
    TextPainter tp(Paint fg) => TextPainter(
      text: TextSpan(
        text: d,
        style: TextStyle(
          fontFamily: 'Jua',
          fontSize: size,
          height: 1,
          foreground: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final stroke = tp(_line(size * .2));
    final fill = tp(_fill(Colors.white));
    final at = center - Offset(fill.width / 2, fill.height / 2);
    stroke.paint(c, at);
    fill.paint(c, at);
  }

  /// 숫자: 1·2·3이 적힌 계단을 올라가서 내려오는 미끄럼틀
  void _numberSlide(Canvas c) {
    // 미끄럼판 (계단 뒤에서 오른쪽 아래로)
    final chute = Path()
      ..moveTo(50, 30)
      ..cubicTo(70, 34, 76, 80, 97, 84)
      ..lineTo(97, 93)
      ..cubicTo(72, 90, 64, 46, 50, 41)
      ..close();
    c.drawPath(chute, _fill(Palette.pink));
    c.drawPath(chute, _ol);
    final shine = Path()
      ..moveTo(55, 34)
      ..cubicTo(70, 40, 76, 78, 93, 85);
    c.drawPath(shine, _line(2.2, Colors.white.withValues(alpha: .8)));
    // 계단 세 칸: 낮은 칸부터 1, 2, 3
    for (final (i, top, color) in [
      (0, 72.0, _red),
      (1, 52.0, _yellow),
      (2, 32.0, _blue),
    ]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(4 + i * 17.0, top, 22 + i * 17.0, 94),
        const Radius.circular(4),
      );
      c.drawRRect(r, _fill(color));
      c.drawRRect(r, _ol);
      _digit(c, '${i + 1}', Offset(13 + i * 17.0, top + 11), 17);
    }
    // 꼭대기 둥근 손잡이
    final rail = Path()
      ..moveTo(41, 32)
      ..cubicTo(40, 16, 54, 14, 54, 31);
    c.drawPath(rail, _line(5.4));
    c.drawPath(rail, _line(2.6, const Color(0xFFFFCF4D)));
  }

  /// 색깔: 색색 풍선 다발 (줄이 한 매듭으로 모인다)
  void _balloons(Canvas c) {
    const knot = Offset(50, 84);
    const balloons = [
      (Offset(28, 30), _red),
      (Offset(72, 30), _blue),
      (Offset(50, 20), _yellow),
      (Offset(36, 52), _green),
      (Offset(64, 52), _purple),
    ];
    for (final (o, _) in balloons) {
      final bottom = o + const Offset(0, 15);
      final string = Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..quadraticBezierTo(
          (bottom.dx + knot.dx) / 2 + (bottom.dx < knot.dx ? 4 : -4),
          (bottom.dy + knot.dy) / 2,
          knot.dx,
          knot.dy,
        );
      c.drawPath(string, _line(1.4));
    }
    for (final (o, color) in balloons) {
      final body = Rect.fromCenter(center: o, width: 26, height: 30);
      c.drawOval(body, _fill(color));
      c.drawOval(body, _ol);
      final tie = Path()
        ..moveTo(o.dx, o.dy + 14)
        ..lineTo(o.dx + 3.5, o.dy + 19)
        ..lineTo(o.dx - 3.5, o.dy + 19)
        ..close();
      c.drawPath(tie, _fill(color));
      c.drawPath(tie, _line(1.6));
      c.drawOval(
        Rect.fromCenter(center: o + const Offset(-5, -6), width: 6, height: 9),
        _fill(Colors.white.withValues(alpha: .75)),
      );
    }
    // 매듭 리본
    for (final dx in [-1.0, 1.0]) {
      final bow = Path()
        ..moveTo(knot.dx, knot.dy)
        ..lineTo(knot.dx + 8 * dx, knot.dy - 4)
        ..lineTo(knot.dx + 8 * dx, knot.dy + 4)
        ..close();
      c.drawPath(bow, _fill(Palette.pink));
      c.drawPath(bow, _line(1.6));
    }
    c.drawLine(knot, knot + const Offset(-3, 8), _line(1.4));
    c.drawLine(knot, knot + const Offset(3, 8), _line(1.4));
  }

  /// 모양: 네모 위에 세모, 옆에 동그라미와 별 블록
  void _blocks(Canvas c) {
    const sq = Rect.fromLTRB(4, 60, 36, 92);
    c.drawRect(sq, _fill(_blue));
    c.drawRect(sq, _ol);
    final tri = Path()
      ..moveTo(4, 60)
      ..lineTo(36, 60)
      ..lineTo(20, 32)
      ..close();
    c.drawPath(tri, _fill(_red));
    c.drawPath(tri, _ol);
    const ring = Offset(55, 78);
    c.drawCircle(ring, 14, _fill(_yellow));
    c.drawCircle(ring, 14, _ol);
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final r = i.isEven ? 15.0 : 7.0;
      final p = Offset(84 + cos(a) * r, 78 + sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    c.drawPath(star, _fill(_green));
    c.drawPath(star, _ol);
  }

  /// 크기: 같은 무늬의 큰 공과 작은 공
  void _balls(Canvas c) {
    _ball(c, const Offset(36, 62), 29);
    _ball(c, const Offset(84, 82), 10);
  }

  static void _ball(Canvas c, Offset o, double r) {
    final circle = Rect.fromCircle(center: o, radius: r);
    c.save();
    c.clipPath(Path()..addOval(circle));
    c.drawOval(circle, _fill(_red));
    c.drawOval(
      Rect.fromCenter(center: o, width: r * 1.15, height: r * 2.2),
      _fill(_yellow),
    );
    c.drawOval(
      Rect.fromCenter(center: o, width: r * .45, height: r * 2.2),
      _fill(_blue),
    );
    c.restore();
    c.drawOval(circle, _line(r > 15 ? 2.6 : 2));
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(-r * .45, -r * .45),
        width: r * .32,
        height: r * .42,
      ),
      _fill(Colors.white.withValues(alpha: .8)),
    );
  }

  /// 짝 맞추기: 무늬가 똑같은 양말 두 짝
  void _socks(Canvas c) {
    for (final (dx, dy, turn) in [(12.0, 30.0, -.1), (52.0, 32.0, .08)]) {
      c.save();
      c.translate(dx, dy);
      c.rotate(turn);
      _sock(c);
      c.restore();
    }
  }

  static void _sock(Canvas c) {
    final sock = Path()
      ..moveTo(0, 0)
      ..lineTo(19, 0)
      ..lineTo(19, 34)
      ..lineTo(28, 36)
      ..arcToPoint(const Offset(28, 56), radius: const Radius.circular(10))
      ..lineTo(9, 56)
      ..arcToPoint(const Offset(0, 44), radius: const Radius.circular(11))
      ..close();
    c.drawPath(sock, _fill(_blue));
    c.save();
    c.clipPath(sock);
    // 입구 고무단 (흰색), 다리 줄무늬 (빨강), 발끝·뒤꿈치 (노랑)
    c.drawRect(const Rect.fromLTWH(-2, -2, 24, 10), _fill(Colors.white));
    for (final y in [14.0, 23.0]) {
      c.drawRect(Rect.fromLTWH(-2, y, 24, 4.5), _fill(_red));
    }
    c.drawCircle(const Offset(32, 46), 9, _fill(_yellow));
    c.drawCircle(const Offset(1, 55), 9, _fill(_yellow));
    c.restore();
    c.drawLine(const Offset(0, 8), const Offset(19, 8), _line(1.6));
    c.drawPath(sock, _ol);
  }

  @override
  bool shouldRepaint(PlayItemPainter old) => old.kind != kind;
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
