import 'dart:math';

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

  Color get _skin =>
      zodiac == Zodiac.sheep ? zodiac.look.accent : zodiac.look.fur;
  Color get _tip => _hooves ? const Color(0xFF8A817C) : _skin;
  Color get _sleeve => items[ItemSlot.outfit]?.colors.first ?? _skin;
  Color? get _shoe => items[ItemSlot.shoes]?.colors.first;

  static Color _dim(Color c) => Color.lerp(c, const Color(0xFF3A2A22), .14)!;

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
    AnimalPainter(
      zodiac: zodiac,
      items: items,
      mood: mood,
      phase: phase,
      drawLegs: false,
      drawArms: false,
      sideways: true,
    ).paint(c, AnimalPainter.design);
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
    if (legs && !_noLimbs) _leg(c, g.hipN, g.kneeN, g.footN, scale);
    if (!_wings && !_noLimbs) _arm(c, g.shoulderN, g.handN, scale);
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

  void _limb(Canvas c, List<Offset> pts, double w, double t, Color color) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, AnimalPainter.stroke(w + t * 2));
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
    final t = AnimalPainter.lineWidth * scale;
    final skin = far ? _dim(_skin) : _skin;
    _limb(c, [hip, knee, foot], legWidth * scale, t, skin);
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
    c.drawOval(r, AnimalPainter.stroke(t));
  }

  void _arm(
    Canvas c,
    Offset shoulder,
    Offset hand,
    double scale, {
    bool far = false,
  }) {
    final t = AnimalPainter.lineWidth * scale;
    final w = armWidth * scale;
    _limb(c, [shoulder, hand], w, t, far ? _dim(_sleeve) : _sleeve);
    c.drawCircle(hand, w * .58, Paint()..color = far ? _dim(_tip) : _tip);
    c.drawCircle(hand, w * .58, AnimalPainter.stroke(t));
  }

  /// 손잡이 위에 손을 한 번 더 그려 꼭 잡은 것처럼 보이게 (날개·뱀 친구는 없음)
  void grip(Canvas c, Offset at, double scale) {
    if (_wings || _noLimbs) return;
    final r = armWidth * scale * .58;
    c.drawCircle(at, r, Paint()..color = _tip);
    c.drawCircle(at, r, AnimalPainter.stroke(AnimalPainter.lineWidth * scale));
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
