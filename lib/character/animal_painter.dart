import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import 'item_art.dart';
import 'zodiac.dart';

enum CharMood { normal, happy, think }

/// 친구 그리기 (12지신 + 공룡).
///
/// 도형을 붙인 느낌이 나지 않도록 머리와 몸을 하나의 부드러운 곡선(찹쌀떡 머리, 서양배 몸)으로 그리고,
/// 가는 외곽선, 밝은 배 무늬, 뭉툭한 팔·발로 그림책 같은 느낌을 낸다. 200 x 240 좌표계.
///
/// 모든 친구가 같은 몸 틀(머리 중심, 몸통, 팔·발 위치)을 공유해서 꾸미기 아이템이 누구에게나 맞는다.
/// 그리는 순서(레이어)는 고정:
///   그림자 → 등 장식 → 등판(돛·골판) → 꼬리 → 발 → 몸 → 팔 → 옷 → 신발 → 가방끈 → 목걸이
///   → 귀·뿔·볏(뒤) → 머리 → 무늬·주둥이·뿔 → 얼굴 → 늘어진 귀 → 안경·리본 → 모자
class AnimalPainter extends CustomPainter {
  AnimalPainter({
    required this.zodiac,
    required this.items,
    this.mood = CharMood.normal,
    this.phase = 0,
    this.drawLegs = true,
    this.drawArms = true,
  });

  /// 탈것에 탈 때는 팔다리를 탈것 그림에서 따로 그린다 (손잡이 잡기·페달 밟기)
  final bool drawLegs;
  final bool drawArms;

  final Zodiac zodiac;
  final Map<ItemSlot, Item> items;
  final CharMood mood;

  /// 0~1 반복 값 (꼬리 흔들기, 눈 깜빡임)
  final double phase;

  static const Size design = Size(200, 240);

  /// 외곽선 색 (아이템·탈것 그림도 같은 색을 쓴다)
  static const Color ink = Color(0xFF4A3A31);
  static const double lineWidth = 3.8;

  /// 몸통 (서양배 모양). 옷 그림도 이 모양을 그대로 쓴다.
  static final Path torsoPath = Path()
    ..moveTo(100, 138)
    ..cubicTo(121, 138, 132, 150, 134, 170)
    ..cubicTo(137, 194, 133, 212, 112, 213)
    ..lineTo(88, 213)
    ..cubicTo(67, 212, 63, 194, 66, 170)
    ..cubicTo(68, 150, 79, 138, 100, 138)
    ..close();

  /// 예전 코드 호환용 (몸통을 감싸는 사각형)
  static final RRect torso = RRect.fromRectAndRadius(
    const Rect.fromLTRB(66, 140, 134, 212),
    const Radius.circular(24),
  );

  static const Offset headCenter = Offset(100, 92);
  static const Size headSize = Size(140, 112);

  static Paint stroke([double width = lineWidth, Color color = ink]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static void fillStroke(
    Canvas c,
    Path p,
    Color fill, {
    double width = lineWidth,
  }) {
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, stroke(width));
  }

  /// 팔 자세: 평소에는 몸 옆으로 살짝 벌리고, 기쁠 때는 만세
  static (Offset, double) armPose(bool left, bool happy) {
    if (happy) {
      return left
          ? (const Offset(60, 146), 0.9)
          : (const Offset(140, 146), -0.9);
    }
    return left
        ? (const Offset(68, 170), 0.38)
        : (const Offset(132, 170), -0.38);
  }

  ZodiacLook get look => zodiac.look;
  Color get fur => look.fur;
  bool get _dino => zodiac.isDino;

  /// 다리 대신 몸으로 서 있는지 (뱀)
  bool get _noLegs => zodiac == Zodiac.snake;
  bool get _hooves => const {
    Zodiac.ox,
    Zodiac.horse,
    Zodiac.sheep,
    Zodiac.pig,
  }.contains(zodiac);

  /// 날개가 팔인 친구
  bool get hasWings => _wings;
  bool get _wings => zodiac == Zodiac.rooster || zodiac == Zodiac.pteranodon;

  /// 합치기(Path.combine)는 계산이 무거워서 한 번 만든 모양은 기억해 둔다 (발열 줄이기)
  static final Map<String, Path> _pathCache = {};
  static Path _cached(String key, Path Function() build) =>
      _pathCache[key] ??= build();

  void _fs(Canvas c, Path p, Color fill, {double w = lineWidth}) =>
      fillStroke(c, p, fill, width: w);

  static Color _shade(Color c, [double t = .12]) =>
      Color.lerp(c, const Color(0xFF3A2A22), t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / design.width, size.height / design.height);
    canvas.save();
    canvas.translate(
      (size.width - design.width * s) / 2,
      (size.height - design.height * s) / 2,
    );
    canvas.scale(s);
    final art = ItemArt(canvas)..sleeves = drawArms;
    final happy = mood == CharMood.happy;

    if (drawLegs) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(100, 232), width: 100, height: 11),
        Paint()..color = const Color(0x1C3E2A20),
      );
    }

    final back = items[ItemSlot.back];
    if (back != null) art.backBehind(back);

    _backDecor(canvas);
    _tail(canvas);
    final legsOn = drawLegs && items[ItemSlot.shoes] == null && !_noLegs;
    if (zodiac == Zodiac.sheep) {
      // 양: 구름 털 몸에 색이 다른 발·팔을 따로 붙인다
      if (legsOn) _legs(canvas);
      _body(canvas);
      if (drawArms) _arms(canvas, happy);
    } else {
      if (legsOn && _wings) _legs(canvas); // 새 다리 (가는 다리)
      // 몸·팔·발을 하나의 실루엣으로 그려 이음매 없이 자연스럽게
      _softBody(
        canvas,
        happy,
        feet: legsOn && !_wings,
        arms: drawArms && !_wings && !_noLegs,
      );
      if (_wings) _arms(canvas, happy);
    }

    final outfit = items[ItemSlot.outfit];
    if (outfit != null) art.outfit(outfit, happy: happy);
    final shoes = items[ItemSlot.shoes];
    if (shoes != null && drawLegs) art.shoes(shoes);
    if (back != null) art.backFront(back);

    final acc = items[ItemSlot.accessory];
    if (acc != null && acc.isNecklace) art.accessory(acc);

    _earsBehind(canvas);
    _head(canvas);
    _headDetails(canvas);
    _face(canvas, happy);
    _earsFront(canvas);

    if (acc != null && !acc.isNecklace) art.accessory(acc);
    final head = items[ItemSlot.head];
    if (head != null) art.head(head);

    canvas.restore();
  }

  Offset _m(double m, double dx, double y) => Offset(100 + m * dx, y);

  // ================= 등판 (공룡) =================
  void _backDecor(Canvas c) {
    switch (zodiac) {
      case Zodiac.stegosaurus:
        // 등에 솟은 골판이 머리 뒤로 부채처럼 보인다
        for (final (o, r, rot) in const [
          (Offset(46, 84), 18.0, -1.2),
          (Offset(60, 48), 20.0, -.7),
          (Offset(100, 30), 22.0, 0.0),
          (Offset(140, 48), 20.0, .7),
          (Offset(154, 84), 18.0, 1.2),
          (Offset(40, 130), 15.0, -1.6),
          (Offset(160, 130), 15.0, 1.6),
        ]) {
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(rot);
          final plate = Path()
            ..moveTo(-r * .7, r * .7)
            ..lineTo(-r * .8, -r * .1)
            ..lineTo(0, -r * 1.1)
            ..lineTo(r * .8, -r * .1)
            ..lineTo(r * .7, r * .7)
            ..close();
          _fs(c, plate, look.accent);
          c.restore();
        }
      case Zodiac.spinosaurus:
        // 등 돛 (부채처럼 뼈가 보이는)
        final sail = Path()
          ..moveTo(62, 176)
          ..cubicTo(10, 120, 40, 4, 100, 8)
          ..cubicTo(160, 4, 190, 120, 138, 176)
          ..close();
        c.drawPath(sail, Paint()..color = look.accent);
        c.save();
        c.clipPath(sail);
        for (var i = 0; i < 9; i++) {
          final a = pi * (1.08 + i * .105);
          c.drawLine(
            const Offset(100, 170),
            const Offset(100, 170) + Offset(cos(a), sin(a)) * 170,
            stroke(2.4, _shade(look.accent, .2)),
          );
        }
        c.restore();
        c.drawPath(sail, stroke());
      default:
        break;
    }
  }

  // ================= 꼬리 =================
  void _tail(Canvas c) {
    final sway = sin(phase * 2 * pi) * 5;
    if (_dino && zodiac != Zodiac.pteranodon) {
      // 굵게 뻗었다가 가늘어지는 공룡 꼬리
      final tip = Offset(186 + sway * .6, 214 - sway * .3);
      final tail = Path()
        ..moveTo(122, 168)
        ..cubicTo(150, 172, 170, 188, tip.dx, tip.dy)
        ..cubicTo(166, 216, 146, 212, 124, 206)
        ..close();
      _fs(c, tail, fur);
      switch (zodiac) {
        case Zodiac.stegosaurus:
          for (final (d, a) in const [
            (Offset(-6, -6), -.9),
            (Offset(-18, -10), -1.1),
          ]) {
            c.save();
            c.translate(tip.dx + d.dx, tip.dy + d.dy);
            c.rotate(a);
            final spike = Path()
              ..moveTo(-4, 0)
              ..lineTo(0, -16)
              ..lineTo(4, 0)
              ..close();
            _fs(c, spike, look.light, w: 3);
            c.restore();
          }
        case Zodiac.ankylosaurus:
          // 꼬리 곤봉
          _fs(
            c,
            Path()..addOval(
              Rect.fromCenter(
                center: tip + const Offset(-4, -2),
                width: 30,
                height: 22,
              ),
            ),
            look.accent,
          );
        case Zodiac.velociraptor:
          // 꼬리 깃털
          for (var i = 0; i < 3; i++) {
            final o = tip + Offset(-6.0 - i * 9, -4.0 - i * 2);
            final f = Path()
              ..moveTo(o.dx, o.dy)
              ..quadraticBezierTo(o.dx + 4, o.dy - 14, o.dx + 10, o.dy - 6)
              ..close();
            _fs(c, f, look.accent, w: 2.6);
          }
        default:
          // 등줄 무늬
          for (final t in [.35, .6]) {
            final x = 122 + (tip.dx - 122) * t;
            final y = 172 + (tip.dy - 172) * t * .95;
            c.drawLine(
              Offset(x - 2, y - 6),
              Offset(x + 4, y + 2),
              stroke(2.6, _shade(fur, .25)),
            );
          }
      }
      return;
    }
    switch (zodiac) {
      case Zodiac.rat:
        final p = Path()
          ..moveTo(128, 200)
          ..cubicTo(156, 206, 168, 196, 166 + sway, 182);
        c.drawPath(p, stroke(8));
        c.drawPath(p, stroke(3.6, const Color(0xFFF2B8C6)));
      case Zodiac.ox:
        final p = Path()
          ..moveTo(128, 196)
          ..quadraticBezierTo(152, 198, 154 + sway, 182);
        c.drawPath(p, stroke(8));
        c.drawPath(p, stroke(3.6, fur));
        _fs(
          c,
          Path()..addOval(
            Rect.fromCircle(center: Offset(155 + sway, 177), radius: 7),
          ),
          look.accent,
        );
      case Zodiac.tiger:
      case Zodiac.dog:
        final p = Path()
          ..moveTo(128, 198)
          ..quadraticBezierTo(160, 200, 156 + sway, 172);
        c.drawPath(p, stroke(16));
        c.drawPath(p, stroke(9, fur));
        if (zodiac == Zodiac.tiger) {
          c.drawLine(
            Offset(148 + sway * .5, 194),
            Offset(156 + sway * .5, 190),
            stroke(3.4),
          );
          c.drawLine(
            Offset(152 + sway * .8, 182),
            Offset(161 + sway * .8, 182),
            stroke(3.4),
          );
        } else {
          c.drawCircle(Offset(156 + sway, 174), 4, Paint()..color = look.light);
        }
      case Zodiac.rabbit:
        _fs(c, _cloud(Offset(134 + sway * .2, 200), 12, 6), Colors.white, w: 3);
      case Zodiac.dragon:
        final p = Path()
          ..moveTo(126, 202)
          ..quadraticBezierTo(160, 206, 168 + sway, 186);
        c.drawPath(p, stroke(16));
        c.drawPath(p, stroke(9, fur));
        final tip = Path()
          ..moveTo(166 + sway, 190)
          ..quadraticBezierTo(178 + sway, 176, 186 + sway, 184)
          ..quadraticBezierTo(178 + sway, 194, 166 + sway, 190)
          ..close();
        _fs(c, tip, look.accent, w: 3);
      case Zodiac.snake:
        final body = Path()
          ..moveTo(84, 196)
          ..cubicTo(60, 196, 40, 214, 52, 226)
          ..cubicTo(64, 236, 150, 232, 160, 222)
          ..cubicTo(170, 212, 162, 200, 148, 202);
        c.drawPath(body, stroke(28));
        c.drawPath(body, stroke(20.4, fur));
        // 배 비늘 줄
        final belly = Path()
          ..moveTo(62, 222)
          ..cubicTo(80, 230, 140, 228, 156, 220);
        c.drawPath(belly, stroke(4, look.light));
      case Zodiac.horse:
        final p = Path()
          ..moveTo(128, 186)
          ..cubicTo(152, 184, 158 + sway, 206, 150 + sway, 216)
          ..cubicTo(144, 204, 138, 198, 128, 198)
          ..close();
        _fs(c, p, look.accent, w: 3);
      case Zodiac.sheep:
        _fs(c, _cloud(Offset(134 + sway * .2, 196), 11, 6), look.light, w: 3);
      case Zodiac.monkey:
        final p = Path()
          ..moveTo(128, 200)
          ..cubicTo(160, 204, 168, 176, 156 + sway, 168)
          ..cubicTo(148 + sway, 164, 146, 176, 154 + sway, 178);
        c.drawPath(p, stroke(10));
        c.drawPath(p, stroke(4.4, fur));
      case Zodiac.rooster:
        for (var i = 0; i < 3; i++) {
          c.save();
          c.translate(128, 188);
          c.rotate(-0.75 + i * .35 + sway * .01);
          final f = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(14, -14, 32, -6)
            ..quadraticBezierTo(16, 6, 0, 0)
            ..close();
          _fs(
            c,
            f,
            i == 1 ? const Color(0xFF6C8FD8) : const Color(0xFF4F9E7A),
            w: 3,
          );
          c.restore();
        }
      case Zodiac.pig:
        final p = Path()
          ..moveTo(128, 196)
          ..cubicTo(146, 196, 150 + sway * .4, 182, 142, 180)
          ..cubicTo(134, 178, 138, 192, 150 + sway * .3, 188);
        c.drawPath(p, stroke(3.4));
      default:
        break;
    }
  }

  /// 몽실몽실 구름 모양 (양털, 토끼 꼬리)
  Path _cloud(Offset o, double r, int bumps) =>
      _cached('cloud|$o|$r|$bumps', () => _cloudBuild(o, r, bumps));

  Path _cloudBuild(Offset o, double r, int bumps) {
    var p = Path()..addOval(Rect.fromCircle(center: o, radius: r * .75));
    for (var i = 0; i < bumps; i++) {
      final a = i * 2 * pi / bumps;
      p = Path.combine(
        PathOperation.union,
        p,
        Path()..addOval(
          Rect.fromCircle(
            center: o + Offset(cos(a), sin(a)) * r * .6,
            radius: r * .5,
          ),
        ),
      );
    }
    return p;
  }

  // ================= 발 =================
  void _legs(Canvas c) {
    for (final x in [86.0, 114.0]) {
      if (zodiac == Zodiac.rooster || zodiac == Zodiac.pteranodon) {
        final leg = Path()
          ..moveTo(x, 206)
          ..lineTo(x, 222)
          ..moveTo(x - 8, 227)
          ..lineTo(x, 222)
          ..lineTo(x + 8, 227)
          ..moveTo(x, 222)
          ..lineTo(x, 228);
        c.drawPath(leg, stroke(8));
        c.drawPath(leg, stroke(4, const Color(0xFFFFC94D)));
        continue;
      }
      // 뭉툭한 발: 아래가 조금 넓고 바닥이 평평
      final foot = Path()
        ..moveTo(x - 10, 198)
        ..lineTo(x - 11.5, 219)
        ..quadraticBezierTo(x - 13, 229, x - 3, 229)
        ..lineTo(x + 3, 229)
        ..quadraticBezierTo(x + 13, 229, x + 11.5, 219)
        ..lineTo(x + 10, 198)
        ..close();
      final color = zodiac == Zodiac.sheep ? look.accent : fur;
      _fs(c, foot, color);
      if (_hooves) {
        c.save();
        c.clipPath(foot);
        c.drawRect(
          Rect.fromLTWH(x - 14, 221, 28, 10),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
        c.drawPath(foot, stroke());
      } else if (_dino) {
        // 발톱 세 개
        for (final dx in [-6.0, 0.0, 6.0]) {
          c.drawOval(
            Rect.fromCenter(center: Offset(x + dx, 227), width: 5, height: 4),
            Paint()
              ..color = zodiac == Zodiac.triceratops ? look.accent : look.light,
          );
        }
      }
    }
  }

  // ================= 몸 =================
  void _body(Canvas c) {
    if (zodiac == Zodiac.sheep) {
      _fs(c, _cloud(const Offset(100, 176), 40, 9), look.light);
      return;
    }
    final body = torsoPath;
    c.drawPath(body, Paint()..color = fur);
    _bodyMarks(c);
    c.drawPath(body, stroke());
  }

  /// 몸통 안쪽 무늬 (몸통 모양으로 잘라서 그린다)
  void _bodyMarks(Canvas c) {
    final body = torsoPath;
    c.save();
    c.clipPath(body);
    // 옆구리 살짝 그늘 (입체감)
    c.drawOval(
      const Rect.fromLTRB(118, 140, 150, 220),
      Paint()..color = _shade(fur, .07),
    );
    // 밝은 배 무늬
    final belly = Rect.fromCenter(
      center: const Offset(100, 186),
      width: 46,
      height: 50,
    );
    switch (zodiac) {
      case Zodiac.ox:
        c.drawOval(
          Rect.fromCenter(
            center: const Offset(126, 196),
            width: 34,
            height: 28,
          ),
          Paint()..color = const Color(0xFF3F3330),
        );
      case Zodiac.tiger:
        c.drawOval(belly, Paint()..color = look.light);
        for (final y in [160.0, 178.0, 196.0]) {
          c.drawLine(Offset(62, y), Offset(74, y - 2), stroke(3.6));
          c.drawLine(Offset(138, y), Offset(126, y - 2), stroke(3.6));
        }
      case Zodiac.dragon:
        final plate = RRect.fromLTRBR(
          84,
          152,
          116,
          196,
          const Radius.circular(10),
        );
        c.drawRRect(plate, Paint()..color = look.light);
        for (final y in [166.0, 181.0]) {
          c.drawLine(
            Offset(86, y),
            Offset(114, y),
            stroke(2.4, _shade(look.light, .2)),
          );
        }
      case Zodiac.rabbit:
      case Zodiac.rooster:
        break;
      case Zodiac.ankylosaurus:
        // 등껍질 갑옷 (몸 위쪽을 덮는다)
        c.drawOval(belly, Paint()..color = look.light);
        final shell = Path()
          ..moveTo(60, 182)
          ..cubicTo(60, 146, 140, 146, 140, 182)
          ..close();
        c.drawPath(shell, Paint()..color = look.accent);
        for (final o in const [
          Offset(80, 166),
          Offset(100, 160),
          Offset(120, 166),
          Offset(90, 176),
          Offset(110, 176),
        ]) {
          c.drawCircle(o, 4.2, Paint()..color = _shade(look.accent, .2));
        }
        c.drawPath(shell, stroke(3));
      default:
        c.drawOval(belly, Paint()..color = look.light);
        if (_dino) {
          for (final y in [174.0, 186.0, 198.0]) {
            c.drawLine(
              Offset(84, y),
              Offset(116, y),
              stroke(2, _shade(look.light, .12)),
            );
          }
        }
    }
    c.restore();
  }

  /// 발 모양 (아래가 조금 넓고 바닥이 평평)
  static Path _footShape(double x) => Path()
    ..moveTo(x - 10, 196)
    ..lineTo(x - 11.5, 219)
    ..quadraticBezierTo(x - 13, 229, x - 3, 229)
    ..lineTo(x + 3, 229)
    ..quadraticBezierTo(x + 13, 229, x + 11.5, 219)
    ..lineTo(x + 10, 196)
    ..close();

  /// 팔을 몸 좌표로 옮긴 모양
  Path _armAt(bool left, bool happy) {
    final (center, rot) = armPose(left, happy);
    final small = zodiac == Zodiac.trex;
    final cs = cos(rot), sn = sin(rot);
    // 회전 후 (0,-5) 만큼 어깨 쪽으로 (티라노의 짧은 팔)
    final tx = center.dx + (small ? 5 * sn : 0);
    final ty = center.dy + (small ? -5 * cs : 0);
    final m = Float64List.fromList([
      cs, sn, 0, 0, //
      -sn, cs, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    ]);
    return _armShape(small ? .72 : 1).transform(m);
  }

  /// 몸통 + 팔 + 발을 하나로 합친 몸.
  /// 한 번에 칠하고 바깥 외곽선만 그어서 "도형을 붙인" 이음매가 없다.
  /// 팔이 몸 앞에 겹치는 곳만 가늘고 옅은 선으로 살짝 표시한다.
  void _softBody(
    Canvas c,
    bool happy, {
    required bool feet,
    required bool arms,
  }) {
    final armPaths = arms
        ? [_armAt(true, happy), _armAt(false, happy)]
        : const <Path>[];
    final footPaths = feet ? [_footShape(86), _footShape(114)] : const <Path>[];
    final sil = _cached('sil|${zodiac.name}|$happy|$feet|$arms', () {
      var out = Path.from(torsoPath);
      for (final p in [...footPaths, ...armPaths]) {
        out = Path.combine(PathOperation.union, out, p);
      }
      return out;
    });
    c.drawPath(sil, Paint()..color = fur);

    // 몸통 무늬 (배, 줄무늬 등)
    _bodyMarks(c);

    // 팔이 몸 앞으로 지나가는 자리: 옅은 안쪽 선
    final soft = stroke(2.4, ink.withValues(alpha: .55));
    if (armPaths.isNotEmpty) {
      for (final a in armPaths) {
        c.save();
        c.clipPath(torsoPath);
        // 어깨는 몸에 녹아들고, 손 쪽에만 옅은 선이 보이게
        final b = a.getBounds();
        c.clipRect(Rect.fromLTRB(0, b.top + b.height * .45, 200, 240));
        // 팔 안쪽은 몸 색으로 다시 칠해서 배 무늬 위로 팔이 오도록
        c.drawPath(a, Paint()..color = fur);
        c.drawPath(a, soft);
        c.restore();
      }
    }
    // 두 발 사이 살짝 갈라진 선
    if (footPaths.isNotEmpty) {
      c.drawLine(const Offset(100, 228), const Offset(100, 216), soft);
    }

    // 발굽·발톱
    for (final f in footPaths) {
      final x = f.getBounds().center.dx;
      if (_hooves) {
        c.save();
        c.clipPath(f);
        c.drawRect(
          Rect.fromLTWH(x - 14, 221, 28, 10),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
      } else if (_dino) {
        for (final dx in [-6.0, 0.0, 6.0]) {
          c.drawOval(
            Rect.fromCenter(center: Offset(x + dx, 227), width: 5, height: 4),
            Paint()
              ..color = zodiac == Zodiac.triceratops ? look.accent : look.light,
          );
        }
      } else {
        // 발가락 두 줄
        for (final dx in [-4.0, 4.0]) {
          c.drawLine(Offset(x + dx, 229), Offset(x + dx, 224), soft);
        }
      }
    }
    if (_hooves) {
      for (final left in [true, false]) {
        if (!arms) break;
        final (center, rot) = armPose(left, happy);
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(rot);
        final arm = _armShape(1);
        c.clipPath(arm);
        c.drawRect(
          const Rect.fromLTWH(-12, 8, 24, 12),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
      }
    }

    c.drawPath(sil, stroke());

    // 팔 장식 (외곽선 위)
    if (arms) {
      for (final left in [true, false]) {
        final (center, rot) = armPose(left, happy);
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(rot);
        if (zodiac == Zodiac.iguanodon) {
          final spike = Path()
            ..moveTo(-3, 13)
            ..lineTo(-12, 20)
            ..lineTo(1, 17)
            ..close();
          _fs(c, spike, look.light, w: 2.6);
        }
        if (zodiac == Zodiac.velociraptor) {
          final f = Path()
            ..moveTo(-6, -8)
            ..quadraticBezierTo(-18, 0, -12, 12)
            ..quadraticBezierTo(-6, 4, -6, -8)
            ..close();
          _fs(c, f, look.accent, w: 2.6);
        }
        c.restore();
      }
    }
  }

  /// 뭉툭한 팔 (어깨에서 손까지 살짝 둥글게)
  static Path _armShape(double scale) => Path()
    ..moveTo(-7 * scale, -15 * scale)
    ..cubicTo(
      -10 * scale,
      -2 * scale,
      -10 * scale,
      8 * scale,
      -5 * scale,
      14 * scale,
    )
    ..cubicTo(
      -1 * scale,
      19 * scale,
      7 * scale,
      17 * scale,
      8 * scale,
      11 * scale,
    )
    ..cubicTo(
      9 * scale,
      2 * scale,
      8 * scale,
      -7 * scale,
      6 * scale,
      -15 * scale,
    )
    ..close();

  void _arms(Canvas c, bool happy) {
    if (_noLegs) return;
    for (final left in [true, false]) {
      final (center, rot) = armPose(left, happy);
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(rot);
      if (_wings) {
        final big = zodiac == Zodiac.pteranodon;
        final w = Path()
          ..moveTo(0, -16)
          ..quadraticBezierTo(big ? 22 : 13, -6, big ? 14 : 8, big ? 22 : 15)
          ..lineTo(4, big ? 14 : 10)
          ..lineTo(0, big ? 20 : 16)
          ..lineTo(-4, big ? 14 : 10)
          ..lineTo(big ? -14 : -8, big ? 22 : 15)
          ..quadraticBezierTo(big ? -22 : -13, -6, 0, -16)
          ..close();
        _fs(c, w, big ? look.light : Colors.white);
      } else {
        final small = zodiac == Zodiac.trex;
        final arm = _armShape(small ? .72 : 1);
        if (small) c.translate(0, -5);
        _fs(c, arm, zodiac == Zodiac.sheep ? look.accent : fur);
        if (_hooves) {
          c.save();
          c.clipPath(arm);
          c.drawRect(
            const Rect.fromLTWH(-12, 8, 24, 12),
            Paint()..color = const Color(0xFF8A817C),
          );
          c.restore();
          c.drawPath(arm, stroke());
        }
        if (zodiac == Zodiac.iguanodon) {
          // 엄지 가시
          final spike = Path()
            ..moveTo(-3, 13)
            ..lineTo(-12, 20)
            ..lineTo(1, 17)
            ..close();
          _fs(c, spike, look.light, w: 2.6);
        }
        if (zodiac == Zodiac.velociraptor) {
          final f = Path()
            ..moveTo(-6, -8)
            ..quadraticBezierTo(-18, 0, -12, 12)
            ..quadraticBezierTo(-6, 4, -6, -8)
            ..close();
          _fs(c, f, look.accent, w: 2.6);
        }
      }
      c.restore();
    }
  }

  // ================= 귀·뿔·볏 (머리 뒤) =================
  void _earsBehind(Canvas c) {
    if (zodiac == Zodiac.triceratops) {
      // 커다란 목 프릴 (가장자리가 물결)
      final frill = _cached('frill', () {
        var f = Path()
          ..addOval(Rect.fromCircle(center: const Offset(100, 82), radius: 74));
        for (var i = 0; i < 9; i++) {
          final a = pi + i * pi / 8;
          f = Path.combine(
            PathOperation.union,
            f,
            Path()..addOval(
              Rect.fromCircle(
                center: const Offset(100, 82) + Offset(cos(a), sin(a)) * 72,
                radius: 11,
              ),
            ),
          );
        }
        return f;
      });
      // 프릴은 몸과 같은 빨강(조금 진하게), 가장자리 혹은 크림색
      _fs(c, frill, _shade(fur, .06));
      for (var i = 0; i < 9; i++) {
        final a = pi + i * pi / 8;
        final o = const Offset(100, 82) + Offset(cos(a), sin(a)) * 72;
        c.drawCircle(o, 7, Paint()..color = look.accent);
        c.drawCircle(o, 7, stroke(2.6));
      }
    }
    if (zodiac == Zodiac.parasaurolophus) {
      // 뒤로 길게 휜 관 볏
      final crest = Path()
        ..moveTo(108, 52)
        ..cubicTo(130, 26, 160, 18, 182, 22);
      c.drawPath(crest, stroke(22));
      c.drawPath(crest, stroke(14.4, look.accent));
    }
    if (zodiac == Zodiac.pteranodon) {
      final crest = Path()
        ..moveTo(110, 56)
        ..lineTo(186, 26)
        ..lineTo(124, 72)
        ..close();
      _fs(c, crest, look.accent);
    }
    if (zodiac == Zodiac.dilophosaurus) {
      for (final m in [-1.0, 1.0]) {
        final crest = Path()
          ..moveTo(100 + m * 6, 50)
          ..cubicTo(100 + m * 4, 10, 100 + m * 40, 14, 100 + m * 34, 50)
          ..close();
        _fs(c, crest, look.accent);
        c.drawLine(
          Offset(100 + m * 12, 44),
          Offset(100 + m * 24, 26),
          stroke(2.2, _shade(look.accent, .25)),
        );
      }
    }
    for (final m in [-1.0, 1.0]) {
      switch (zodiac) {
        case Zodiac.rat:
          _fs(
            c,
            Path()..addOval(Rect.fromCircle(center: _m(m, 54, 46), radius: 28)),
            fur,
          );
          c.drawOval(
            Rect.fromCircle(center: _m(m, 54, 48), radius: 17),
            Paint()..color = const Color(0xFFF5B8C4),
          );
        case Zodiac.ox:
          final horn = Path()
            ..moveTo(_m(m, 34, 50).dx, 50)
            ..quadraticBezierTo(_m(m, 48, 22).dx, 22, _m(m, 44, 14).dx, 14)
            ..quadraticBezierTo(_m(m, 58, 22).dx, 22, _m(m, 52, 52).dx, 52)
            ..close();
          _fs(c, horn, const Color(0xFFF6D98A));
        case Zodiac.tiger:
        case Zodiac.monkey:
          final r = zodiac == Zodiac.tiger ? 19.0 : 21.0;
          final o = zodiac == Zodiac.tiger ? _m(m, 50, 46) : _m(m, 70, 94);
          _fs(c, Path()..addOval(Rect.fromCircle(center: o, radius: r)), fur);
          c.drawOval(
            Rect.fromCircle(
              center: o + Offset(0, zodiac == Zodiac.tiger ? 3 : 0),
              radius: r * .52,
            ),
            Paint()
              ..color = zodiac == Zodiac.tiger
                  ? const Color(0xFF6B4A35)
                  : look.light,
          );
        case Zodiac.rabbit:
          c.save();
          c.translate(_m(m, 22, 52).dx, 52);
          c.rotate(m * .16);
          // 위가 살짝 넓어지는 자연스러운 귀
          final ear = Path()
            ..moveTo(-9, 6)
            ..cubicTo(-18, -24, -16, -62, 0, -64)
            ..cubicTo(16, -62, 18, -24, 9, 6)
            ..close();
          _fs(c, ear, fur);
          final inner = Path()
            ..moveTo(-4, 0)
            ..cubicTo(-9, -24, -8, -52, 0, -54)
            ..cubicTo(8, -52, 9, -24, 4, 0)
            ..close();
          c.drawPath(inner, Paint()..color = const Color(0xFFF5B8C4));
          c.restore();
        case Zodiac.dragon:
          final horn = Path()
            ..moveTo(_m(m, 30, 48).dx, 48)
            ..lineTo(_m(m, 40, 16).dx, 16)
            ..lineTo(_m(m, 46, 32).dx, 32)
            ..lineTo(_m(m, 54, 24).dx, 24)
            ..lineTo(_m(m, 50, 42).dx, 42)
            ..lineTo(_m(m, 44, 52).dx, 52)
            ..close();
          _fs(c, horn, look.accent, w: 3.2);
          final ear = Path()
            ..moveTo(_m(m, 60, 68).dx, 68)
            ..quadraticBezierTo(_m(m, 92, 58).dx, 58, _m(m, 86, 82).dx, 82)
            ..quadraticBezierTo(_m(m, 74, 86).dx, 86, _m(m, 62, 82).dx, 82)
            ..close();
          _fs(c, ear, fur);
        case Zodiac.horse:
          final ear = Path()
            ..moveTo(_m(m, 30, 52).dx, 52)
            ..quadraticBezierTo(_m(m, 40, 16).dx, 16, _m(m, 54, 24).dx, 24)
            ..quadraticBezierTo(_m(m, 58, 42).dx, 42, _m(m, 52, 58).dx, 58)
            ..close();
          _fs(c, ear, fur);
        case Zodiac.sheep:
          final o = _m(m, 64, 72);
          _fs(
            c,
            Path()..addOval(Rect.fromCircle(center: o, radius: 19)),
            const Color(0xFFD9B98A),
          );
          c.drawArc(
            Rect.fromCircle(center: o, radius: 9),
            0,
            pi * 1.6,
            false,
            stroke(3.2),
          );
        case Zodiac.dog:
          final ear = Path()
            ..moveTo(_m(m, 26, 54).dx, 54)
            ..quadraticBezierTo(_m(m, 34, 22).dx, 22, _m(m, 46, 16).dx, 16)
            ..quadraticBezierTo(_m(m, 60, 30).dx, 30, _m(m, 62, 58).dx, 58)
            ..close();
          _fs(c, ear, fur);
          final inner = Path()
            ..moveTo(_m(m, 36, 50).dx, 50)
            ..quadraticBezierTo(_m(m, 40, 30).dx, 30, _m(m, 46, 26).dx, 26)
            ..quadraticBezierTo(_m(m, 54, 36).dx, 36, _m(m, 54, 52).dx, 52)
            ..close();
          c.drawPath(inner, Paint()..color = look.light);
        case Zodiac.pig:
          final ear = Path()
            ..moveTo(_m(m, 28, 50).dx, 50)
            ..quadraticBezierTo(_m(m, 40, 24).dx, 24, _m(m, 54, 18).dx, 18)
            ..quadraticBezierTo(_m(m, 62, 34).dx, 34, _m(m, 62, 52).dx, 52)
            ..close();
          _fs(c, ear, fur);
        default:
          break;
      }
    }
    if (zodiac == Zodiac.sheep) {
      _fs(c, _cloud(const Offset(100, 50), 44, 8), look.light);
    }
  }

  void _earsFront(Canvas c) {
    if (zodiac == Zodiac.ox) {
      for (final m in [-1.0, 1.0]) {
        c.save();
        c.translate(_m(m, 72, 72).dx, 72);
        c.rotate(m * .35);
        final ear = Path()
          ..addOval(
            Rect.fromCenter(center: Offset.zero, width: 32, height: 17),
          );
        _fs(c, ear, fur);
        c.drawOval(
          Rect.fromCenter(center: Offset(m * 3, 0), width: 17, height: 7),
          Paint()..color = const Color(0xFFF5B8C4),
        );
        c.restore();
      }
    }
  }

  // ================= 머리 =================
  /// 찹쌀떡 머리: 위는 둥글고 볼 쪽이 살짝 넓다
  static Path headPath({
    double dx = 0,
    double dy = 0,
    double sx = 1,
    double sy = 1,
  }) {
    Offset p(double x, double y) =>
        Offset(100 + (x - 100) * sx + dx, 92 + (y - 92) * sy + dy);
    final a = p(100, 37);
    final b = p(170, 97);
    final d = p(100, 148);
    final e = p(30, 97);
    final c1 = p(142, 37), c2 = p(170, 62);
    final c3 = p(171, 130), c4 = p(140, 148);
    final c5 = p(60, 148), c6 = p(29, 130);
    final c7 = p(30, 62), c8 = p(58, 37);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.dx, b.dy)
      ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, d.dx, d.dy)
      ..cubicTo(c5.dx, c5.dy, c6.dx, c6.dy, e.dx, e.dy)
      ..cubicTo(c7.dx, c7.dy, c8.dx, c8.dy, a.dx, a.dy)
      ..close();
  }

  Path get _headShape => switch (zodiac) {
    Zodiac.snake => headPath(dy: 6, sx: .92, sy: .92),
    Zodiac.horse => headPath(dy: 4, sx: .9, sy: 1.06),
    Zodiac.sheep => headPath(dy: 8, sx: .84, sy: .88),
    Zodiac.velociraptor || Zodiac.pteranodon => headPath(sx: .94),
    _ => headPath(),
  };

  void _head(Canvas c) {
    switch (zodiac) {
      case Zodiac.rooster:
        final comb = Path();
        for (final o in const [
          Offset(86, 42),
          Offset(100, 33),
          Offset(114, 42),
        ]) {
          comb.addOval(Rect.fromCircle(center: o, radius: 12));
        }
        _fs(
          c,
          Path.combine(
            PathOperation.union,
            comb,
            Path()..addRect(const Rect.fromLTRB(80, 40, 120, 50)),
          ),
          look.accent,
        );
        _fs(c, _headShape, Colors.white);
      case Zodiac.horse:
        _fs(c, _headShape, fur);
        final mane = Path()
          ..moveTo(78, 46)
          ..cubicTo(86, 24, 118, 22, 124, 42)
          ..cubicTo(114, 38, 108, 52, 100, 58)
          ..cubicTo(96, 48, 88, 44, 78, 46)
          ..close();
        _fs(c, mane, look.accent, w: 3);
      case Zodiac.sheep:
        _fs(c, _headShape, const Color(0xFFFCE3CF));
      case Zodiac.pachycephalosaurus:
        _fs(c, _headShape, fur);
        // 두꺼운 돔 머리 + 작은 혹
        final dome = Path()
          ..moveTo(44, 70)
          ..cubicTo(44, 22, 156, 22, 156, 70)
          ..cubicTo(130, 60, 70, 60, 44, 70)
          ..close();
        _fs(c, dome, look.accent);
        for (var i = 0; i < 6; i++) {
          final x = 46.0 + i * 21.6;
          c.drawCircle(
            Offset(x, 70 - (i == 0 || i == 5 ? 0 : 4)),
            4.4,
            Paint()..color = look.light,
          );
        }
      default:
        _fs(c, _headShape, fur);
    }
  }

  void _headDetails(Canvas c) {
    final clip = _headShape;
    switch (zodiac) {
      case Zodiac.ox:
        c.save();
        c.clipPath(clip);
        final spot = Path()
          ..moveTo(28, 40)
          ..quadraticBezierTo(80, 30, 96, 54)
          ..quadraticBezierTo(80, 74, 28, 82)
          ..close();
        c.drawPath(spot, Paint()..color = const Color(0xFF3F3330));
        c.restore();
        c.drawPath(clip, stroke());
        _muzzle(
          c,
          const Offset(100, 122),
          80,
          40,
          const Color(0xFFF7B7C0),
          nostrils: true,
        );
      case Zodiac.tiger:
        c.drawLine(const Offset(92, 44), const Offset(108, 44), stroke(3.6));
        c.drawLine(const Offset(100, 40), const Offset(100, 56), stroke(3.6));
        c.drawLine(const Offset(90, 52), const Offset(110, 52), stroke(3.6));
        for (final m in [-1.0, 1.0]) {
          c.drawLine(_m(m, 70, 88), _m(m, 58, 90), stroke(3.6));
          c.drawLine(_m(m, 70, 102), _m(m, 60, 100), stroke(3.6));
        }
        _muzzle(c, const Offset(100, 120), 46, 34, Colors.white, outline: true);
      case Zodiac.dragon:
        _muzzle(
          c,
          const Offset(100, 118),
          46,
          30,
          const Color(0xFFA9D98B),
          nostrils: true,
          outline: true,
        );
        for (final m in [-1.0, 1.0]) {
          final w = Path()
            ..moveTo(_m(m, 24, 122).dx, 122)
            ..cubicTo(
              _m(m, 52, 118).dx,
              118,
              _m(m, 60, 134).dx,
              134,
              _m(m, 80, 128).dx,
              128,
            );
          c.drawPath(w, stroke(2.6));
        }
      case Zodiac.horse:
        _muzzle(
          c,
          const Offset(100, 128),
          68,
          40,
          look.light,
          nostrils: true,
          outline: true,
        );
      case Zodiac.monkey:
        final face = Path()
          ..moveTo(100, 142)
          ..cubicTo(58, 134, 52, 86, 76, 76)
          ..cubicTo(90, 70, 96, 78, 100, 84)
          ..cubicTo(104, 78, 110, 70, 124, 76)
          ..cubicTo(148, 86, 142, 134, 100, 142)
          ..close();
        _fs(c, face, look.light, w: 3);
      case Zodiac.rooster:
        final wattle = Path()
          ..moveTo(94, 128)
          ..quadraticBezierTo(90, 144, 100, 146)
          ..quadraticBezierTo(110, 144, 106, 128)
          ..close();
        _fs(c, wattle, look.accent, w: 3);
      case Zodiac.dog:
        final mask = Path()
          ..moveTo(50, 106)
          ..quadraticBezierTo(70, 86, 100, 102)
          ..quadraticBezierTo(130, 86, 150, 106)
          ..quadraticBezierTo(142, 150, 100, 150)
          ..quadraticBezierTo(58, 150, 50, 106)
          ..close();
        c.save();
        c.clipPath(clip);
        c.drawPath(mask, Paint()..color = look.light);
        c.restore();
        c.drawPath(clip, stroke());
        for (final m in [-1.0, 1.0]) {
          c.drawOval(
            Rect.fromCenter(center: _m(m, 22, 80), width: 11, height: 6),
            Paint()..color = look.light,
          );
        }
      case Zodiac.pig:
        _muzzle(
          c,
          const Offset(100, 116),
          42,
          28,
          const Color(0xFFF7A1B5),
          nostrils: true,
          outline: true,
        );
      case Zodiac.rat:
      case Zodiac.rabbit:
        // 동그란 주둥이 (곰 인형처럼)
        _muzzle(c, const Offset(100, 116), 40, 28, look.light);
      // ---------- 공룡 ----------
      case Zodiac.triceratops:
        // 이마 뿔 두 개 + 코뿔 + 부리
        for (final m in [-1.0, 1.0]) {
          final horn = Path()
            ..moveTo(_m(m, 18, 62).dx, 62)
            ..quadraticBezierTo(_m(m, 26, 30).dx, 30, _m(m, 36, 18).dx, 18)
            ..quadraticBezierTo(_m(m, 38, 40).dx, 40, _m(m, 34, 64).dx, 64)
            ..close();
          _fs(c, horn, look.accent);
        }
        _muzzle(c, const Offset(100, 122), 50, 30, look.light, outline: true);
        final nose = Path()
          ..moveTo(92, 110)
          ..quadraticBezierTo(100, 90, 104, 86)
          ..quadraticBezierTo(108, 98, 108, 110)
          ..close();
        _fs(c, nose, look.accent, w: 3);
      case Zodiac.trex:
        // 눈 위 볼록한 눈두덩
        for (final m in [-1.0, 1.0]) {
          c.drawArc(
            Rect.fromCenter(center: _m(m, 26, 86), width: 26, height: 14),
            pi * 1.1,
            pi * .8,
            false,
            stroke(3.2, _shade(fur, .3)),
          );
        }
      case Zodiac.brachiosaurus:
        // 이마의 볼록 볏과 점무늬
        final bump = Path()
          ..moveTo(78, 44)
          ..cubicTo(80, 18, 120, 18, 122, 44)
          ..close();
        _fs(c, bump, fur);
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(56, 70),
          Offset(146, 66),
          Offset(62, 124),
          Offset(140, 120),
        ]) {
          c.drawCircle(
            o,
            6,
            Paint()..color = look.accent.withValues(alpha: .55),
          );
        }
        c.restore();
      case Zodiac.ankylosaurus:
        for (final m in [-1.0, 1.0]) {
          final spike = Path()
            ..moveTo(_m(m, 62, 104).dx, 104)
            ..lineTo(_m(m, 84, 96).dx, 96)
            ..lineTo(_m(m, 66, 120).dx, 120)
            ..close();
          _fs(c, spike, look.accent, w: 3);
        }
      case Zodiac.pteranodon:
        break; // 부리는 얼굴에서
      case Zodiac.velociraptor:
        // 머리 깃털 세 가닥
        for (var i = 0; i < 3; i++) {
          final x = 88.0 + i * 12;
          final f = Path()
            ..moveTo(x - 5, 42)
            ..quadraticBezierTo(x - 2, 16 - i * 2.0, x + 6, 22)
            ..quadraticBezierTo(x + 2, 32, x + 5, 42)
            ..close();
          _fs(c, f, look.accent, w: 2.6);
        }
      case Zodiac.spinosaurus:
      case Zodiac.iguanodon:
      case Zodiac.parasaurolophus:
      case Zodiac.dilophosaurus:
      case Zodiac.stegosaurus:
      case Zodiac.pachycephalosaurus:
        // 볼에 작은 비늘 점
        for (final m in [-1.0, 1.0]) {
          for (final (dx, y) in const [
            (58.0, 72.0),
            (66.0, 64.0),
            (50.0, 66.0),
          ]) {
            c.drawCircle(_m(m, dx, y), 2.6, Paint()..color = _shade(fur, .18));
          }
        }
      case Zodiac.snake:
      case Zodiac.sheep:
        break;
    }
  }

  void _muzzle(
    Canvas c,
    Offset o,
    double w,
    double h,
    Color color, {
    bool nostrils = false,
    bool outline = false,
  }) {
    final r = Rect.fromCenter(center: o, width: w, height: h);
    c.drawOval(r, Paint()..color = color);
    if (outline) c.drawOval(r, stroke(3));
    if (nostrils) {
      final dx = w * .2;
      final nc = Paint()..color = const Color(0xFF6B4A3C);
      for (final s in [-1.0, 1.0]) {
        c.drawOval(
          Rect.fromCenter(
            center: o + Offset(s * dx, 0),
            width: w * .1,
            height: h * .22,
          ),
          nc,
        );
      }
    }
  }

  // ================= 얼굴 =================
  void _face(Canvas c, bool happy) {
    final blink = mood == CharMood.normal && phase > .94;
    final ey = switch (zodiac) {
      Zodiac.horse || Zodiac.ox => 90.0,
      Zodiac.sheep => 98.0,
      Zodiac.pachycephalosaurus => 98.0,
      _ => 96.0,
    };
    final eyeDx = zodiac == Zodiac.sheep ? 22.0 : 25.0;
    final eye = Paint()..color = ink;

    for (final m in [-1.0, 1.0]) {
      final x = 100 + m * eyeDx;
      if (happy) {
        final p = Path()
          ..moveTo(x - 6, ey + 2)
          ..quadraticBezierTo(x, ey - 7, x + 6, ey + 2);
        c.drawPath(p, stroke(3.6));
      } else if (blink) {
        c.drawLine(Offset(x - 5, ey), Offset(x + 5, ey), stroke(3.6));
      } else {
        // 작고 동그란 눈 + 반짝
        c.drawOval(
          Rect.fromCenter(center: Offset(x, ey), width: 9.5, height: 12.5),
          eye,
        );
        c.drawCircle(Offset(x - 1.6, ey - 3), 2, Paint()..color = Colors.white);
      }
    }

    // 볼터치
    for (final m in [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(100 + m * 44, ey + 16),
          width: 17,
          height: 9,
        ),
        Paint()..color = const Color(0xFFF7A9B8).withValues(alpha: .5),
      );
    }

    if (zodiac == Zodiac.rooster) {
      final beak = Path()
        ..moveTo(91, 110)
        ..quadraticBezierTo(100, 106, 109, 110)
        ..lineTo(100, 123)
        ..close();
      _fs(c, beak, const Color(0xFFFFC94D), w: 3);
      return;
    }
    if (zodiac == Zodiac.pteranodon) {
      final beak = Path()
        ..moveTo(86, 108)
        ..quadraticBezierTo(100, 102, 114, 108)
        ..lineTo(100, 136)
        ..close();
      _fs(c, beak, look.accent, w: 3);
      return;
    }

    final hasSnout = const {
      Zodiac.ox,
      Zodiac.horse,
      Zodiac.pig,
      Zodiac.dragon,
    }.contains(zodiac);
    final my = switch (zodiac) {
      Zodiac.ox => 136.0,
      Zodiac.horse => 142.0,
      Zodiac.pig => 132.0,
      Zodiac.dragon => 134.0,
      Zodiac.tiger => 122.0,
      Zodiac.rat || Zodiac.rabbit => 121.0,
      Zodiac.triceratops => 128.0,
      _ => 116.0,
    };
    if (!hasSnout && zodiac != Zodiac.triceratops) {
      if (_dino) {
        // 콧구멍 두 점
        for (final m in [-1.0, 1.0]) {
          c.drawCircle(
            _m(m, 6, my - 10),
            1.8,
            Paint()..color = _shade(fur, .45),
          );
        }
      } else {
        // 동그스름한 세모 코
        final ny = zodiac == Zodiac.tiger ? 112.0 : my - 9;
        final nose = Path()
          ..moveTo(95, ny - 3)
          ..quadraticBezierTo(100, ny - 5, 105, ny - 3)
          ..quadraticBezierTo(104, ny + 3, 100, ny + 4)
          ..quadraticBezierTo(96, ny + 3, 95, ny - 3)
          ..close();
        c.drawPath(
          nose,
          Paint()
            ..color = zodiac == Zodiac.snake ? const Color(0xFF4F7F3A) : ink,
        );
      }
    }
    final mouth = Path();
    final wide = zodiac == Zodiac.trex || zodiac == Zodiac.spinosaurus;
    final mw = wide ? 14.0 : 7.0;
    if (happy) {
      mouth
        ..moveTo(100 - mw - 1, my - 2)
        ..quadraticBezierTo(100, my + 12, 100 + mw + 1, my - 2)
        ..close();
      c.drawPath(mouth, Paint()..color = const Color(0xFFE77C83));
      c.drawPath(mouth, stroke(3));
    } else if (!_dino && !hasSnout && zodiac != Zodiac.snake) {
      // 고양이 입 "ω"
      mouth
        ..moveTo(100, my - 5)
        ..lineTo(100, my - 1)
        ..moveTo(93, my - 2)
        ..quadraticBezierTo(96.5, my + 3, 100, my - 1)
        ..quadraticBezierTo(103.5, my + 3, 107, my - 2);
      c.drawPath(mouth, stroke(2.8));
    } else {
      mouth
        ..moveTo(100 - mw, my - 2)
        ..quadraticBezierTo(100, my + 6, 100 + mw, my - 2);
      c.drawPath(mouth, stroke(3));
    }
    if (zodiac == Zodiac.trex) {
      // 귀여운 이빨 두 개
      for (final m in [-1.0, 1.0]) {
        final tooth = Path()
          ..moveTo(_m(m, 6, my).dx - 2.5, my + 1)
          ..lineTo(_m(m, 6, my).dx + 2.5, my + 1)
          ..lineTo(_m(m, 6, my).dx, my + 6)
          ..close();
        c.drawPath(tooth, Paint()..color = Colors.white);
        c.drawPath(tooth, stroke(1.6));
      }
    }

    if (zodiac == Zodiac.rat) {
      for (final m in [-1.0, 1.0]) {
        c.drawLine(_m(m, 30, 108), _m(m, 54, 104), stroke(2));
        c.drawLine(_m(m, 30, 114), _m(m, 54, 116), stroke(2));
      }
    }
  }

  @override
  bool shouldRepaint(AnimalPainter old) =>
      old.zodiac != zodiac ||
      old.items != items ||
      old.mood != mood ||
      old.phase != phase ||
      old.drawLegs != drawLegs ||
      old.drawArms != drawArms;
}
