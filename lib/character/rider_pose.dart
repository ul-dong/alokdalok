import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import 'animal_painter.dart';
import 'zodiac.dart';

/// 탈것에 앉은 친구 (옆모습). 24마리 모두 같은 둥근 2등신 몸 틀을 쓰므로
/// 변환 하나로 그린다:
///   1. 얼굴은 가는 쪽(오른쪽)으로 돌리고 꼬리는 등 뒤로 ([AnimalPainter.sideways])
///   2. 엉덩이를 자리에 붙이고, 허벅지는 앞으로 · 정강이는 아래로 접어 앉힌다
///   3. 팔은 손잡이·핸들·난간으로 뻗는다
/// 탈것 그림은 [seatAt](엉덩이 아래 가운데)과 크기, 손·발 위치만 정해 준다.
class RiderPose {
  RiderPose({
    required this.zodiac,
    this.items = const {},
    this.mood = CharMood.normal,
    this.phase = 0,
  });

  final Zodiac zodiac;
  final Map<ItemSlot, Item> items;
  final CharMood mood;
  final double phase;

  /// 캐릭터 좌표(200 x 240)에서 앉는 점: 몸통 아래 가운데
  static const Offset seat = Offset(100, 210);

  /// 어깨·엉덩이 관절 (캐릭터 좌표). 옆모습이라 앞쪽 팔다리는 몸 가운데보다 조금 앞에 있다.
  static const Offset shoulderNear = Offset(114, 162);
  static const Offset shoulderFar = Offset(94, 160);
  static const Offset hipNear = Offset(110, 198);
  static const Offset hipFar = Offset(96, 196);

  /// 팔·다리 굵기 (캐릭터 좌표)
  static const double armWidth = 15, legWidth = 17;

  bool get _wings => zodiac == Zodiac.rooster || zodiac == Zodiac.pteranodon;
  bool get _noLimbs => zodiac == Zodiac.snake;
  bool get _hooves => const {
    Zodiac.ox,
    Zodiac.horse,
    Zodiac.sheep,
    Zodiac.pig,
  }.contains(zodiac);

  /// 팔다리 색: 서 있을 때처럼 몸보다 한 톤 진하게 (외곽선 없이 몸과 구분)
  Color get _skin => AnimalPainter.tone(
    zodiac == Zodiac.sheep ? zodiac.look.accent : zodiac.look.fur,
    .1,
  );
  Color get _tip => _hooves ? const Color(0xFF8A817C) : _skin;
  Color get _sleeve {
    final outfit = items[ItemSlot.outfit]?.colors.first;
    return outfit == null ? _skin : AnimalPainter.tone(outfit, .1);
  }

  Color? get _shoe => items[ItemSlot.shoes]?.colors.first;

  /// 뒤쪽 팔다리는 조금만 진하게 (외곽선 없이 앞뒤를 나눈다)
  static Color _dim(Color c) => AnimalPainter.tone(c, .12);

  /// 탄 친구의 몸과 머리 그림: 팔다리는 탈것 쪽에서 따로, 얼굴은 가는 쪽(오른쪽)으로
  AnimalPainter get body => AnimalPainter(
    zodiac: zodiac,
    items: items,
    mood: mood,
    phase: phase,
    drawLegs: false,
    drawArms: false,
    sideways: true,
  );

  /// 탄 친구의 얼굴 방향 (항상 가는 쪽)
  FaceDirection get faceDirection => body.faceDirection;

  /// 탈것 좌표로 옮긴 몸통 모양 (앞 팔다리 그늘을 몸 위에만 깔 때 쓴다)
  static Path _torsoAt(Offset seatAt, double scale) {
    final o = seatAt - seat * scale;
    return AnimalPainter.torsoPath.transform(
      Float64List.fromList([
        scale, 0, 0, 0, //
        0, scale, 0, 0,
        0, 0, 1, 0,
        o.dx, o.dy, 0, 1,
      ]),
    );
  }

  /// 캐릭터 좌표 → 탈것 좌표
  static Offset map(Offset p, Offset seatAt, double scale) =>
      seatAt + (p - seat) * scale;

  /// 앉은 친구를 그린다.
  /// [seatAt] 엉덩이 아래 가운데(탈것 좌표), [scale] 캐릭터 크기 배율.
  /// [hand] 앞쪽 손이 닿는 곳(없으면 무릎 위에 살짝), [foot] 앞쪽 발이 닿는 곳
  /// (없으면 무릎을 접어 아래로). [legs]가 false면 다리를 그리지 않는다(차체에 가려질 때).
  void paint(
    Canvas c, {
    required Offset seatAt,
    required double scale,
    Offset? hand,
    Offset? foot,
    bool legs = true,
  }) {
    paintBack(
      c,
      seatAt: seatAt,
      scale: scale,
      hand: hand,
      foot: foot,
      legs: legs,
    );
    paintFront(
      c,
      seatAt: seatAt,
      scale: scale,
      hand: hand,
      foot: foot,
      legs: legs,
    );
  }

  /// 뒤쪽 팔다리 + 몸과 머리. 안장·차체를 그 위에 그린 다음 [paintFront]를 부르면
  /// 앞쪽 다리가 차체 옆으로 내려온 모습이 된다.
  void paintBack(
    Canvas c, {
    required Offset seatAt,
    required double scale,
    Offset? hand,
    Offset? foot,
    bool legs = true,
  }) {
    final g = _Geo(seatAt, scale, hand, foot);
    // 뒤쪽 다리·팔 (몸 뒤, 조금 어둡게)
    if (legs && !_noLimbs) _leg(c, g.hipF, g.kneeF, g.footF, scale, far: true);
    if (!_wings && !_noLimbs) _arm(c, g.shoulderF, g.handF, scale, far: true);

    // 몸과 머리 (얼굴은 가는 쪽으로)
    c.save();
    c.translate(seatAt.dx - seat.dx * scale, seatAt.dy - seat.dy * scale);
    c.scale(scale);
    body.paint(c, AnimalPainter.design);
    c.restore();
  }

  /// 앞쪽 다리·팔
  void paintFront(
    Canvas c, {
    required Offset seatAt,
    required double scale,
    Offset? hand,
    Offset? foot,
    bool legs = true,
  }) {
    final g = _Geo(seatAt, scale, hand, foot);
    if (_noLimbs) return;
    // 앞 팔다리가 몸 앞을 지나는 자리: 아래쪽에 아주 연한 그늘 (몸 위에만)
    final drop = Offset(0, 3.5 * scale);
    c.save();
    c.clipPath(_torsoAt(seatAt, scale));
    final shadow = AnimalPainter.softShadow;
    if (legs) {
      _limb(c, [g.hipN + drop, g.kneeN + drop], legWidth * scale, shadow);
    }
    if (!_wings) {
      _limb(c, [g.shoulderN + drop, g.handN + drop], armWidth * scale, shadow);
    }
    c.restore();
    if (legs) _leg(c, g.hipN, g.kneeN, g.footN, scale);
    if (!_wings) _arm(c, g.shoulderN, g.handN, scale);
  }

  /// 허벅지는 앞으로 거의 수평, 정강이는 발 쪽으로. 짧은 다리라 무릎이 너무 멀리 가지 않게 한다.
  static (Offset, Offset) legPoints(Offset hip, Offset? foot, double scale) {
    if (foot == null) {
      final knee = hip + Offset(36 * scale, 2 * scale);
      return (knee, knee + Offset(5 * scale, 24 * scale));
    }
    final thigh = 38 * scale;
    final kx = min(
      hip.dx + thigh,
      max(hip.dx + 18 * scale, foot.dx + 4 * scale),
    );
    final knee = Offset(kx, hip.dy + 3 * scale);
    return (knee, foot);
  }

  /// 팔·다리 한 줄기: 외곽선 없이 끝이 둥근 굵은 면 하나.
  /// 어깨·엉덩이 끝은 몸 안쪽에서 시작해서 몸과 이음새 없이 붙는다.
  void _limb(Canvas c, List<Offset> pts, double w, Color color) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 3) {
      // 무릎은 둥글게 굽힌다 (꺾인 선이 보이지 않게)
      path.quadraticBezierTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy);
    } else {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    c.drawPath(path, AnimalPainter.stroke(w, color));
  }

  void _leg(
    Canvas c,
    Offset hip,
    Offset knee,
    Offset foot,
    double scale, {
    bool far = false,
  }) {
    final skin = far ? _dim(_skin) : _skin;
    _limb(c, [hip, knee, foot], legWidth * scale, skin);
    // 발: 앞을 향한 둥근 발 (신발을 신었으면 신발 색)
    final shoe = _shoe;
    final footColor = shoe ?? _tip;
    final r = Rect.fromCenter(
      center: foot + Offset(5 * scale, 2 * scale),
      width: 27 * scale,
      height: 16 * scale,
    );
    c.drawOval(r, Paint()..color = far ? _dim(footColor) : footColor);
    if (shoe == null && _hooves) {
      // 발굽 위쪽은 털색
      c.save();
      c.clipRect(
        Rect.fromLTRB(r.left - 2, r.top - 2, r.right + 2, r.center.dy - 1),
      );
      c.drawOval(r, Paint()..color = far ? _dim(_skin) : _skin);
      c.restore();
    }
    if (zodiac == Zodiac.velociraptor && shoe == null && !far) {
      // 갈고리 발톱 (발 위로 휘어 오른)
      final o = r.topCenter + Offset(2 * scale, 2 * scale);
      final claw = Path()
        ..moveTo(o.dx - 4 * scale, o.dy + 2 * scale)
        ..cubicTo(
          o.dx - 2 * scale,
          o.dy - 10 * scale,
          o.dx + 8 * scale,
          o.dy - 14 * scale,
          o.dx + 14 * scale,
          o.dy - 10 * scale,
        )
        ..cubicTo(
          o.dx + 8 * scale,
          o.dy - 8 * scale,
          o.dx + 4 * scale,
          o.dy - 4 * scale,
          o.dx + 4 * scale,
          o.dy + 2 * scale,
        )
        ..close();
      c.drawPath(claw, Paint()..color = AnimalPainter.ivory);
    } else if (zodiac.isDino && shoe == null && !far) {
      // 발끝 발톱 세 개
      for (final dx in [-1.0, 0.0, 1.0]) {
        c.drawCircle(
          Offset(r.right - 4 * scale, r.center.dy + dx * 4.5 * scale),
          2 * scale,
          Paint()..color = AnimalPainter.ivory,
        );
      }
    }
  }

  void _arm(
    Canvas c,
    Offset shoulder,
    Offset hand,
    double scale, {
    bool far = false,
  }) {
    // 티라노는 작은 팔: 가늘게
    final w = armWidth * scale * (zodiac == Zodiac.trex ? .72 : 1);
    if (zodiac == Zodiac.velociraptor && items[ItemSlot.outfit] == null) {
      // 팔 뒤쪽 깃털
      final d = hand - shoulder;
      final n = Offset(d.dy, -d.dx) / d.distance;
      for (final k in [.3, .55, .8]) {
        final base = shoulder + d * k;
        final f = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            base.dx + n.dx * 14 * scale - d.dx * .12,
            base.dy + n.dy * 14 * scale - d.dy * .12,
            base.dx - d.dx * .22 + n.dx * 4 * scale,
            base.dy - d.dy * .22 + n.dy * 4 * scale,
          )
          ..close();
        final col = zodiac.look.accent;
        c.drawPath(f, Paint()..color = far ? _dim(col) : col);
      }
    }
    _limb(c, [shoulder, hand], w, far ? _dim(_sleeve) : _sleeve);
    c.drawCircle(hand, w * .6, Paint()..color = far ? _dim(_tip) : _tip);
    if (zodiac == Zodiac.iguanodon && !far) {
      // 엄지 가시 (손 위로 솟은 뿔)
      final spike = Path()
        ..moveTo(hand.dx - 4 * scale, hand.dy - 5 * scale)
        ..lineTo(hand.dx - 1 * scale, hand.dy - 20 * scale)
        ..lineTo(hand.dx + 4 * scale, hand.dy - 5 * scale)
        ..close();
      c.drawPath(spike, Paint()..color = AnimalPainter.ivory);
    }
  }

  /// 손잡이 위에 손을 한 번 더 그려 꼭 잡은 것처럼 보이게 (날개·뱀 친구는 없음).
  /// 손은 팔 끝과 같은 크기·같은 색이라 팔에서 손잡이까지 한 덩어리로 이어진다.
  void grip(Canvas c, Offset at, double scale) {
    if (_wings || _noLimbs) return;
    final w = armWidth * scale * (zodiac == Zodiac.trex ? .72 : 1);
    c.drawCircle(at, w * .6, Paint()..color = _tip);
  }
}

/// 앉은 자세의 관절 위치 (탈것 좌표)
class _Geo {
  factory _Geo(Offset seatAt, double scale, Offset? hand, Offset? foot) {
    Offset tr(Offset p) => RiderPose.map(p, seatAt, scale);
    final shoulderN = tr(RiderPose.shoulderNear);
    final handN = hand ?? tr(RiderPose.shoulderNear + const Offset(30, 26));
    final hipN = tr(RiderPose.hipNear), hipF = tr(RiderPose.hipFar);
    final (kneeN, footN) = RiderPose.legPoints(hipN, foot, scale);
    // 뒤쪽 손·발은 앞쪽 바로 뒤에 (옆모습이라 거의 겹친다)
    final (kneeF, footF) = RiderPose.legPoints(
      hipF,
      foot == null ? null : foot + Offset(-7 * scale, -2 * scale),
      scale,
    );
    return _Geo._(
      shoulderN: shoulderN,
      shoulderF: tr(RiderPose.shoulderFar),
      handN: handN,
      handF: handN + Offset(-6 * scale, -3 * scale),
      hipN: hipN,
      hipF: hipF,
      kneeN: kneeN,
      kneeF: kneeF,
      footN: footN,
      footF: footF,
    );
  }

  const _Geo._({
    required this.shoulderN,
    required this.shoulderF,
    required this.handN,
    required this.handF,
    required this.hipN,
    required this.hipF,
    required this.kneeN,
    required this.kneeF,
    required this.footN,
    required this.footF,
  });

  final Offset shoulderN, shoulderF, handN, handF;
  final Offset hipN, hipF, kneeN, kneeF, footN, footF;
}
