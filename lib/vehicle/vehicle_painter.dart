import 'dart:math';

import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
import '../character/rider_pose.dart';
import '../character/zodiac.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import 'sticker_art.dart';

/// 탈것 그림 (300 x 200 좌표계). 동물 그림과 같은 굵은 갈색 외곽선에
/// 그림자·하이라이트·부품(전조등, 볼트, 바퀴살, 배기구 등)을 더해 단조롭지 않게 그린다.
/// 내 친구가 타고 있고, 붙인 스티커는 차체 안쪽에만 보인다.
class VehiclePainter extends CustomPainter {
  VehiclePainter({
    required this.vehicle,
    required this.stickers,
    VehiclePaint? paint,
    this.zodiac,
    this.items = const {},
    this.phase = 0,
    this.moving = false,
    this.mood = CharMood.normal,
  }) : color = paint ?? Vehicles.defaultPaintOf(vehicle);

  final Vehicle vehicle;
  final List<PlacedSticker> stickers;
  final VehiclePaint color;

  /// 타고 있는 친구 (null이면 빈 탈것)
  final Zodiac? zodiac;
  final Map<ItemSlot, Item> items;

  /// 0~1 반복 값 (바퀴·불꽃·프로펠러 움직임)
  final double phase;
  final bool moving;

  /// 탄 친구의 표정 (폴짝 뛸 때 웃는 얼굴)
  final CharMood mood;

  static const Size design = Size(300, 200);
  static const ink = AnimalPainter.ink;
  static const _tire = Color(0xFF4A3F3A);
  static const _metal = Color(0xFFCBD3DC);
  static const _metalDark = Color(0xFF8E98A3);
  static const _glass = Color(0xFFD8F1FF);
  static const _lampColor = Color(0xFFFFF4B8);
  static const _leather = Color(0xFF7A5442);

  Color get _body => color.body;
  Color get _trim => color.trim;
  static Color _shade(Color c, [double t = .22]) =>
      Color.lerp(c, const Color(0xFF3A2A22), t)!;
  static Color _tint(Color c, [double t = .45]) =>
      Color.lerp(c, Colors.white, t)!;

  /// 스티커 크기 (탈것마다 붙일 자리 크기가 다르다)
  static double stickerRadius(VehicleKind kind) => switch (kind) {
    VehicleKind.car || VehicleKind.rocket => 17,
    VehicleKind.tank => 16,
    VehicleKind.airplane => 15,
    VehicleKind.motorcycle => 14,
    VehicleKind.train || VehicleKind.balloon => 17,
  };

  // ---------------- 차체 모양 (스티커를 붙일 수 있는 영역) ----------------

  static Path _carBody() => Path()
    ..moveTo(28, 150)
    ..lineTo(28, 118)
    ..quadraticBezierTo(30, 100, 52, 98)
    ..lineTo(196, 98)
    ..quadraticBezierTo(214, 98, 226, 108)
    ..lineTo(262, 116)
    ..quadraticBezierTo(278, 120, 278, 136)
    ..lineTo(278, 150)
    ..quadraticBezierTo(278, 162, 266, 162)
    ..lineTo(40, 162)
    ..quadraticBezierTo(28, 162, 28, 150)
    ..close();

  static Path _rocketBody() => Path()
    ..moveTo(44, 96)
    ..quadraticBezierTo(44, 76, 74, 74)
    ..lineTo(210, 74)
    ..quadraticBezierTo(270, 78, 290, 118)
    ..quadraticBezierTo(270, 158, 210, 162)
    ..lineTo(74, 162)
    ..quadraticBezierTo(44, 160, 44, 140)
    ..close();

  static Path _tankHull() => Path()
    ..moveTo(34, 144)
    ..lineTo(48, 112)
    ..lineTo(248, 112)
    ..lineTo(272, 132)
    ..lineTo(266, 144)
    ..close();

  static Path _tankTurret() => Path()
    ..addRRect(
      RRect.fromLTRBAndCorners(
        96,
        76,
        206,
        116,
        topLeft: const Radius.circular(26),
        topRight: const Radius.circular(18),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
    );

  static Path _motoBody() => Path()
    ..moveTo(92, 108)
    ..lineTo(164, 102)
    ..quadraticBezierTo(204, 96, 224, 110)
    ..lineTo(216, 138)
    ..quadraticBezierTo(170, 150, 122, 148)
    ..lineTo(96, 132)
    ..close();

  static Path _planeBody() => Path()
    ..moveTo(40, 108)
    ..quadraticBezierTo(46, 92, 80, 92)
    ..lineTo(230, 90)
    ..quadraticBezierTo(272, 92, 276, 120)
    ..quadraticBezierTo(272, 148, 230, 150)
    ..lineTo(90, 148)
    ..quadraticBezierTo(52, 140, 40, 108)
    ..close();

  static Path _planeFin() => Path()
    ..moveTo(46, 104)
    ..lineTo(28, 50)
    ..quadraticBezierTo(28, 40, 40, 44)
    ..lineTo(88, 98)
    ..close();

  // 기차: 뒤쪽 기관실 아래 판 + 앞쪽 보일러 (넓은 스티커 자리 두 곳)
  static Path _trainCab() => Path()
    ..addRRect(RRect.fromLTRBR(30, 106, 128, 150, const Radius.circular(8)));

  static Path _trainBoiler() => Path()
    ..moveTo(126, 92)
    ..lineTo(240, 92)
    ..quadraticBezierTo(264, 92, 264, 119)
    ..quadraticBezierTo(264, 146, 240, 146)
    ..lineTo(126, 146)
    ..close();

  // 열기구: 큰 풍선 전체가 스티커 자리
  static Path _balloonEnvelope() => Path()
    ..moveTo(150, 0)
    ..cubicTo(200, 0, 234, 20, 234, 46)
    ..cubicTo(234, 68, 196, 80, 172, 88)
    ..lineTo(128, 88)
    ..cubicTo(104, 80, 66, 68, 66, 46)
    ..cubicTo(66, 20, 100, 0, 150, 0)
    ..close();

  static Path _union(Path a, Path b) => Path.combine(PathOperation.union, a, b);

  /// 스티커를 붙일 수 있는 차체 영역 (설계 좌표)
  static Path bodyPath(VehicleKind kind) => switch (kind) {
    VehicleKind.car => _carBody(),
    VehicleKind.rocket => _rocketBody(),
    VehicleKind.tank => _union(_tankHull(), _tankTurret()),
    VehicleKind.motorcycle => _motoBody(),
    VehicleKind.train => _union(_trainCab(), _trainBoiler()),
    VehicleKind.balloon => _balloonEnvelope(),
    VehicleKind.airplane => _union(_planeBody(), _planeFin()),
  };

  /// 화면 좌표 → 스티커 비율 좌표. 차체 밖이면 null.
  static Offset? toSticker(VehicleKind kind, Offset designPoint) {
    if (!bodyPath(kind).contains(designPoint)) return null;
    return Offset(
      designPoint.dx / design.width,
      designPoint.dy / design.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / design.width, size.height / design.height);
    canvas.save();
    canvas.translate(
      (size.width - design.width * s) / 2,
      (size.height - design.height * s) / 2,
    );
    canvas.scale(s);
    switch (vehicle.kind) {
      case VehicleKind.car:
        _car(canvas);
      case VehicleKind.rocket:
        _rocket(canvas);
      case VehicleKind.tank:
        _tank(canvas);
      case VehicleKind.motorcycle:
        _motorcycle(canvas);
      case VehicleKind.train:
        _train(canvas);
      case VehicleKind.balloon:
        _balloon(canvas);
      case VehicleKind.airplane:
        _airplane(canvas);
    }
    canvas.restore();
  }

  // ---------------- 공통 부품 ----------------

  double get _spin => moving ? phase * 2 * pi * 3 : 0.0;

  /// 탄 친구 (옆을 보고 앉은 자세, [RiderPose]). 친구가 없으면 null.
  RiderPose? get _pose => zodiac == null
      ? null
      : RiderPose(zodiac: zodiac!, items: items, mood: mood);

  /// [seatAt]에 앉히고 손·발을 [hand]·[foot]로 뻗는다. [clip] 밖은 가린다.
  void _ride(
    Canvas c,
    Offset seatAt,
    double scale, {
    Offset? hand,
    Offset? foot,
    bool legs = false,
    Rect? clip,
  }) {
    final pose = _pose;
    if (pose == null) return;
    c.save();
    if (clip != null) c.clipRect(clip);
    pose.paint(
      c,
      seatAt: seatAt,
      scale: scale,
      hand: hand,
      foot: foot,
      legs: legs,
    );
    c.restore();
  }

  /// 자동차 운전대 (옆에서 본 모습이라 길쭉한 고리) + 잡은 손
  void _steering(Canvas c, Offset o, Offset hand, double scale) {
    c.drawLine(o + const Offset(12, 14), o, AnimalPainter.stroke(6));
    c.drawLine(
      o + const Offset(12, 14),
      o,
      AnimalPainter.stroke(3, _metalDark),
    );
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-.5);
    final ring = Rect.fromCenter(center: Offset.zero, width: 9, height: 28);
    c.drawOval(ring, AnimalPainter.stroke(7));
    c.drawOval(ring, AnimalPainter.stroke(3.5, const Color(0xFF3D3D3D)));
    c.restore();
    _grip(c, hand, scale);
  }

  /// 손잡이 위에 손을 한 번 더 그려 꼭 잡은 것처럼
  void _grip(Canvas c, Offset at, double scale) => _pose?.grip(c, at, scale);

  void _shadow(Canvas c, Rect r) =>
      c.drawOval(r, Paint()..color = const Color(0x22000000));

  /// 차체를 칠하고 아래쪽 그림자·위쪽 반사광·스티커·외곽선까지 한 번에
  void _paintBody(
    Canvas c,
    Path body, {
    double shadeFrom = .8,
    bool stickersOn = true,
  }) {
    final b = body.getBounds();
    c.drawPath(body, Paint()..color = _body);
    c.save();
    c.clipPath(body);
    c.drawRect(
      Rect.fromLTRB(
        b.left,
        b.top + b.height * shadeFrom,
        b.right,
        b.bottom + 2,
      ),
      Paint()..color = _shade(_body, .16),
    );
    c.drawRect(
      Rect.fromLTRB(b.left, b.top - 2, b.right, b.top + b.height * .16),
      Paint()..color = _tint(_body, .35),
    );
    c.restore();
    if (stickersOn) _stickers(c, body);
    c.drawPath(body, AnimalPainter.stroke());
  }

  void _stickers(Canvas c, Path body) {
    if (stickers.isEmpty) return;
    c.save();
    c.clipPath(body);
    final r = stickerRadius(vehicle.kind);
    for (final st in stickers) {
      StickerArt.draw(
        c,
        st.kind,
        Color(st.color),
        Offset(st.x * design.width, st.y * design.height),
        r,
      );
    }
    c.restore();
  }

  /// 고무 타이어 + 휠 + 볼트 (굴러가면 볼트가 돈다)
  void _wheel(
    Canvas c,
    Offset o,
    double r, {
    Color? hub,
    int bolts = 5,
    double rim = .55,
  }) {
    c.drawCircle(o, r, Paint()..color = _tire);
    // 타이어 홈
    final groove = Paint()
      ..color = const Color(0xFF6A5D56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    c.drawCircle(o, r * .82, groove);
    c.drawCircle(o, r, AnimalPainter.stroke());
    c.drawCircle(o, r * rim, Paint()..color = _metal);
    c.drawCircle(
      o + Offset(-r * .12, -r * .12),
      r * rim * .55,
      Paint()..color = _tint(_metal, .6),
    );
    c.drawCircle(o, r * rim, AnimalPainter.stroke(3));
    c.drawCircle(o, r * .2, Paint()..color = hub ?? _trim);
    c.drawCircle(o, r * .2, AnimalPainter.stroke(2.5));
    for (var i = 0; i < bolts; i++) {
      final a = _spin + i * 2 * pi / bolts;
      c.drawCircle(
        o + Offset(cos(a), sin(a)) * r * .36,
        max(1.6, r * .06),
        Paint()..color = _metalDark,
      );
    }
  }

  /// 자전거·오토바이 바퀴: 얇은 타이어와 바퀴살
  void _spokeWheel(Canvas c, Offset o, double r, {int spokes = 12}) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..color = _tire
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    c.drawCircle(o, r + 4.5, AnimalPainter.stroke(3));
    c.drawCircle(o, r - 4.5, AnimalPainter.stroke(2.5));
    final spoke = Paint()
      ..color = _metalDark
      ..strokeWidth = 1.8;
    for (var i = 0; i < spokes; i++) {
      final a = _spin + i * pi / spokes * 2;
      c.drawLine(
        o + Offset(cos(a), sin(a)) * 5,
        o + Offset(cos(a), sin(a)) * (r - 5),
        spoke,
      );
    }
    c.drawCircle(o, 6, Paint()..color = _trim);
    c.drawCircle(o, 6, AnimalPainter.stroke(2.5));
  }

  /// 굵은 파이프(외곽선 + 색)
  void _tube(Canvas c, Offset a, Offset b, double w, Color col) {
    c.drawLine(a, b, AnimalPainter.stroke(w + 5));
    c.drawLine(
      a,
      b,
      Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  void _lamp(Canvas c, Offset o, double r) {
    if (moving) {
      c.drawCircle(o, r * 1.9, Paint()..color = const Color(0x33FFF4B8));
    }
    c.drawCircle(o, r, Paint()..color = _lampColor);
    c.drawCircle(
      o + Offset(-r * .3, -r * .3),
      r * .35,
      Paint()..color = Colors.white,
    );
    c.drawCircle(o, r, AnimalPainter.stroke(3));
  }

  /// 달릴 때 뒤로 퐁퐁 나오는 연기
  void _puffs(Canvas c, Offset from) {
    if (!moving) return;
    for (var i = 0; i < 3; i++) {
      final t = (phase * 2 + i / 3) % 1.0;
      c.drawCircle(
        from + Offset(-t * 34, -t * 10),
        4 + t * 7,
        Paint()..color = Colors.white.withValues(alpha: .75 * (1 - t)),
      );
    }
  }

  /// 달릴 때 뒤쪽 바람 줄
  void _speedLines(Canvas c, double x, List<double> ys) {
    if (!moving) return;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < ys.length; i++) {
      final dx = ((phase * 3 + i * .37) % 1.0) * 14;
      c.drawLine(Offset(x - dx, ys[i]), Offset(x - dx - 18, ys[i]), p);
    }
  }

  // ---------------- 자동차 ----------------

  void _car(Canvas c) {
    _shadow(c, const Rect.fromLTRB(30, 178, 272, 194));
    // 의자 등받이
    final seat = RRect.fromLTRBR(94, 66, 124, 104, const Radius.circular(10));
    c.drawRRect(seat, Paint()..color = _leather);
    c.drawRRect(
      RRect.fromLTRBR(99, 71, 106, 100, const Radius.circular(4)),
      Paint()..color = _tint(_leather, .25),
    );
    c.drawRRect(seat, AnimalPainter.stroke(4));
    // 친구 (옆을 보고 앉아 운전대를 잡는다. 다리는 차 안이라 안 보인다)
    const carHand = Offset(177, 79);
    _ride(c, const Offset(140, 120), .58, hand: carHand);
    _steering(c, const Offset(181, 85), carHand, .58);
    // 앞유리 + 틀
    final glass = Path()
      ..moveTo(176, 100)
      ..lineTo(194, 60)
      ..lineTo(206, 62)
      ..lineTo(194, 100)
      ..close();
    c.drawPath(glass, Paint()..color = _glass.withValues(alpha: .75));
    c.drawLine(
      const Offset(186, 92),
      const Offset(198, 68),
      AnimalPainter.stroke(3, Colors.white),
    );
    c.drawPath(glass, AnimalPainter.stroke(4));
    // 사이드 미러
    final mirror = RRect.fromLTRBR(206, 86, 222, 98, const Radius.circular(5));
    c.drawRRect(mirror, Paint()..color = _trim);
    c.drawRRect(mirror, AnimalPainter.stroke(3));
    // 배기구 + 연기
    final pipe = RRect.fromLTRBR(12, 150, 32, 159, const Radius.circular(4));
    c.drawRRect(pipe, Paint()..color = _metal);
    c.drawRRect(pipe, AnimalPainter.stroke(3));
    _puffs(c, const Offset(10, 152));
    // 차체
    final body = _carBody();
    c.drawPath(body, Paint()..color = _body);
    c.save();
    c.clipPath(body);
    c.drawRect(
      const Rect.fromLTRB(20, 146, 290, 170),
      Paint()..color = _shade(_body, .16),
    );
    c.drawRect(
      const Rect.fromLTRB(20, 96, 290, 106),
      Paint()..color = _tint(_body, .35),
    );
    // 바퀴 집
    for (final x in [82.0, 224.0]) {
      c.drawCircle(Offset(x, 162), 33, Paint()..color = _shade(_body, .38));
    }
    // 옆줄 무늬
    c.drawRect(
      const Rect.fromLTRB(20, 124, 290, 131),
      Paint()..color = _trim.withValues(alpha: .9),
    );
    c.restore();
    _stickers(c, body);
    c.drawPath(body, AnimalPainter.stroke());
    // 문 선, 손잡이
    c.drawLine(
      const Offset(150, 102),
      const Offset(150, 158),
      AnimalPainter.stroke(3.5),
    );
    c.drawLine(
      const Offset(160, 114),
      const Offset(174, 114),
      AnimalPainter.stroke(4),
    );
    // 범퍼
    for (final r in [
      RRect.fromLTRBR(252, 148, 286, 158, const Radius.circular(5)),
      RRect.fromLTRBR(18, 148, 46, 158, const Radius.circular(5)),
    ]) {
      c.drawRRect(r, Paint()..color = _metal);
      c.drawRRect(r, AnimalPainter.stroke(3));
    }
    // 전조등, 미등
    _lamp(c, const Offset(266, 130), 8);
    final tail = RRect.fromLTRBR(25, 116, 36, 134, const Radius.circular(4));
    c.drawRRect(tail, Paint()..color = const Color(0xFFF26B5E));
    c.drawRRect(tail, AnimalPainter.stroke(3));
    _speedLines(c, 20, [104, 122]);
    // 바퀴
    _wheel(c, const Offset(82, 162), 26);
    _wheel(c, const Offset(224, 162), 26);
  }

  // ---------------- 우주선 ----------------

  void _rocket(Canvas c) {
    final flick = moving ? sin(phase * 2 * pi * 4) * 7 : 0.0;
    // 반짝이는 별 (날아갈 때)
    if (moving) {
      for (var i = 0; i < 4; i++) {
        final t = (phase * 2 + i / 4) % 1.0;
        final o = Offset(30 - t * 30, 40 + i * 34.0);
        StickerArt.draw(c, StickerKind.star, const Color(0xFFFFE57A), o, 5);
      }
    }
    // 분사구 + 불꽃 (3겹)
    for (final (w, col) in [
      (46.0, const Color(0xFFF26B5E)),
      (34.0, const Color(0xFFFFB13B)),
      (20.0, const Color(0xFFFFE57A)),
    ]) {
      final f = Path()
        ..moveTo(36, 118 - w / 2)
        ..quadraticBezierTo(-6 - flick + (46 - w), 118, 36, 118 + w / 2)
        ..close();
      c.drawPath(f, Paint()..color = col);
    }
    final nozzle = Path()
      ..moveTo(30, 100)
      ..lineTo(48, 94)
      ..lineTo(48, 142)
      ..lineTo(30, 136)
      ..close();
    AnimalPainter.fillStroke(c, nozzle, _metalDark, width: 4);
    // 날개 (위·아래)
    for (final up in [true, false]) {
      final y = up ? 78.0 : 158.0;
      final d = up ? -1.0 : 1.0;
      final fin = Path()
        ..moveTo(74, y)
        ..quadraticBezierTo(56, y + d * 18, 50, y + d * 38)
        ..lineTo(70, y + d * 36)
        ..lineTo(118, y + d * 2)
        ..close();
      c.drawPath(fin, Paint()..color = _trim);
      c.save();
      c.clipPath(fin);
      c.drawRect(
        Rect.fromLTRB(40, up ? y - 40 : y + 22, 120, up ? y - 22 : y + 40),
        Paint()..color = _shade(_trim, .2),
      );
      c.restore();
      c.drawPath(fin, AnimalPainter.stroke());
    }
    // 조종석 유리 돔 안의 친구
    final dome = Path()..addOval(const Rect.fromLTRB(116, 6, 214, 100));
    c.drawPath(dome, Paint()..color = _glass);
    c.save();
    c.clipPath(dome);
    // 친구 (옆을 보고 앉아 조종간을 잡는다)
    const lever = Offset(192, 71);
    _ride(c, const Offset(158, 111), .52, hand: lever);
    c.drawLine(const Offset(202, 92), lever, AnimalPainter.stroke(5));
    c.drawLine(const Offset(202, 92), lever, AnimalPainter.stroke(2.4, _metal));
    _grip(c, lever, .52);
    c.drawCircle(
      lever + const Offset(-1, -6),
      4,
      Paint()..color = const Color(0xFFF26B5E),
    );
    c.drawCircle(lever + const Offset(-1, -6), 4, AnimalPainter.stroke(2));
    c.restore();
    c.drawPath(dome, Paint()..color = const Color(0x33FFFFFF));
    c.drawArc(
      const Rect.fromLTRB(126, 14, 204, 92),
      pi * 1.1,
      pi * .35,
      false,
      AnimalPainter.stroke(4, Colors.white.withValues(alpha: .85)),
    );
    c.drawPath(dome, AnimalPainter.stroke());
    // 몸체
    final body = _rocketBody();
    c.drawPath(body, Paint()..color = _body);
    c.save();
    c.clipPath(body);
    c.drawRect(
      const Rect.fromLTRB(40, 144, 292, 166),
      Paint()..color = _shade(_body, .14),
    );
    c.drawRect(
      const Rect.fromLTRB(40, 72, 292, 84),
      Paint()..color = _tint(_body, .5),
    );
    // 띠 장식
    c.drawRect(const Rect.fromLTRB(198, 60, 212, 170), Paint()..color = _trim);
    c.restore();
    _stickers(c, body);
    c.drawPath(body, AnimalPainter.stroke());
    c.drawLine(
      const Offset(198, 75),
      const Offset(198, 161),
      AnimalPainter.stroke(3),
    );
    c.drawLine(
      const Offset(212, 75),
      const Offset(212, 161),
      AnimalPainter.stroke(3),
    );
    // 리벳
    for (var y = 86.0; y <= 152; y += 13) {
      c.drawCircle(Offset(205, y), 2.2, Paint()..color = _shade(_trim, .4));
    }
    // 동그란 창
    for (final o in [const Offset(84, 118), const Offset(240, 118)]) {
      c.drawCircle(o, 10, Paint()..color = _metal);
      c.drawCircle(o, 6.5, Paint()..color = const Color(0xFF8FD3F5));
      c.drawCircle(o + const Offset(-2, -2), 2, Paint()..color = Colors.white);
      c.drawCircle(o, 10, AnimalPainter.stroke(3));
    }
    // 코 끝
    final nose = Path()
      ..moveTo(258, 92)
      ..quadraticBezierTo(284, 104, 290, 118)
      ..quadraticBezierTo(284, 132, 258, 144)
      ..quadraticBezierTo(266, 118, 258, 92)
      ..close();
    AnimalPainter.fillStroke(c, nose, _trim, width: 4);
    // 안테나
    c.drawLine(
      const Offset(150, 12),
      const Offset(140, 0),
      AnimalPainter.stroke(3),
    );
    c.drawCircle(const Offset(140, 2), 4, Paint()..color = _trim);
  }

  // ---------------- 탱크 ----------------

  void _tank(Canvas c) {
    _shadow(c, const Rect.fromLTRB(24, 180, 278, 196));
    // 열린 뚜껑
    final lid = Path()..addOval(const Rect.fromLTRB(108, 56, 140, 70));
    AnimalPainter.fillStroke(c, lid, _shade(_body, .3), width: 3.5);
    // 친구 (포탑 해치에서 옆을 보고, 손은 포탑 가장자리에)
    const tankHand = Offset(176, 78);
    _ride(
      c,
      const Offset(150, 107),
      .48,
      hand: tankHand,
      clip: const Rect.fromLTRB(0, 0, 300, 92),
    );
    // 포신
    final barrel = RRect.fromLTRBR(198, 88, 280, 100, const Radius.circular(4));
    c.drawRRect(barrel, Paint()..color = _shade(_body, .12));
    c.drawRRect(
      RRect.fromLTRBR(200, 89, 278, 93, const Radius.circular(2)),
      Paint()..color = _tint(_body, .35),
    );
    c.drawRRect(barrel, AnimalPainter.stroke(4));
    final muzzle = RRect.fromLTRBR(274, 84, 292, 104, const Radius.circular(4));
    c.drawRRect(muzzle, Paint()..color = _shade(_body, .25));
    c.drawRRect(muzzle, AnimalPainter.stroke(4));
    // 포탑
    final turret = _tankTurret();
    _paintBody(c, turret, stickersOn: false);
    // 차체
    final hull = _tankHull();
    _paintBody(c, hull, stickersOn: false);
    // 얼룩무늬
    final spots = Paint()..color = _shade(_body, .2).withValues(alpha: .55);
    final all = _union(hull, turret);
    c.save();
    c.clipPath(all);
    for (final r in const [
      Rect.fromLTRB(110, 84, 136, 98),
      Rect.fromLTRB(168, 96, 196, 110),
      Rect.fromLTRB(60, 120, 92, 134),
      Rect.fromLTRB(150, 126, 186, 140),
      Rect.fromLTRB(220, 118, 248, 132),
    ]) {
      c.drawOval(r, spots);
    }
    c.restore();
    _stickers(c, all);
    c.drawPath(turret, AnimalPainter.stroke());
    c.drawPath(hull, AnimalPainter.stroke());
    _grip(c, tankHand, .48);
    // 해치 테두리
    c.drawLine(
      const Offset(126, 78),
      const Offset(178, 78),
      AnimalPainter.stroke(4),
    );
    // 리벳
    for (var x = 60.0; x <= 240; x += 22) {
      c.drawCircle(Offset(x, 118), 2.2, Paint()..color = _shade(_body, .4));
    }
    // 무한궤도
    final track = RRect.fromLTRBR(24, 140, 276, 188, const Radius.circular(24));
    c.drawRRect(track, Paint()..color = const Color(0xFF55504C));
    c.save();
    c.clipRRect(track);
    final lug = Paint()
      ..color = const Color(0xFF3B3633)
      ..strokeWidth = 4;
    final off = moving ? (phase * 3 % 1.0) * 14 : 0.0;
    for (var x = 18.0 + off; x < 286; x += 14) {
      c.drawLine(Offset(x, 140), Offset(x, 147), lug);
      c.drawLine(Offset(x - off * 2, 181), Offset(x - off * 2, 188), lug);
    }
    c.restore();
    c.drawRRect(track, AnimalPainter.stroke());
    // 바퀴들
    for (final x in [50.0, 90.0, 130.0, 170.0, 210.0, 250.0]) {
      final r = (x == 50 || x == 250) ? 13.0 : 15.0;
      _wheel(c, Offset(x, 164), r, hub: _shade(_body, .2), bolts: 4, rim: .62);
    }
    _puffs(c, const Offset(28, 130));
  }

  // ---------------- 오토바이 ----------------

  void _motorcycle(Canvas c) {
    _shadow(c, const Rect.fromLTRB(32, 180, 270, 194));
    _speedLines(c, 30, [96, 116]);
    // 뒷바퀴, 앞바퀴
    _spokeWheel(c, const Offset(66, 156), 30, spokes: 10);
    _spokeWheel(c, const Offset(236, 156), 30, spokes: 10);
    // 뒷 흙받이
    final rearFender = Path()
      ..addArc(const Rect.fromLTRB(30, 116, 102, 188), pi * 1.05, pi * .7);
    c.drawPath(rearFender, AnimalPainter.stroke(13));
    c.drawPath(
      rearFender,
      Paint()
        ..color = _body
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    // 뒤 팔
    _tube(c, const Offset(66, 156), const Offset(132, 140), 7, _metalDark);
    // 앞 포크
    _tube(c, const Offset(236, 156), const Offset(214, 86), 7, _metal);
    // 친구 (안장에 앉아 옆을 보고, 손은 손잡이·발은 발판에). 앞쪽 다리는 차체 위에 그린다.
    const motoSeat = Offset(136, 100), motoHand = Offset(176, 78);
    const motoFoot = Offset(166, 113);
    _pose?.paintBack(
      c,
      seatAt: motoSeat,
      scale: .52,
      hand: motoHand,
      foot: motoFoot,
    );
    // 안장
    final seat = RRect.fromLTRBR(84, 96, 162, 110, const Radius.circular(7));
    c.drawRRect(seat, Paint()..color = _leather);
    c.drawRRect(
      RRect.fromLTRBR(90, 98, 150, 102, const Radius.circular(3)),
      Paint()..color = _tint(_leather, .3),
    );
    c.drawRRect(seat, AnimalPainter.stroke(4));
    // 엔진
    final engine = RRect.fromLTRBR(
      116,
      134,
      172,
      166,
      const Radius.circular(8),
    );
    c.drawRRect(engine, Paint()..color = _metalDark);
    for (var y = 140.0; y <= 160; y += 6) {
      c.drawLine(
        Offset(122, y),
        Offset(166, y),
        Paint()
          ..color = _metal
          ..strokeWidth = 2.5,
      );
    }
    c.drawRRect(engine, AnimalPainter.stroke(4));
    // 배기관
    final pipe = RRect.fromLTRBR(26, 142, 124, 154, const Radius.circular(6));
    c.drawRRect(pipe, Paint()..color = _metal);
    c.drawRRect(
      RRect.fromLTRBR(32, 144, 118, 147, const Radius.circular(2)),
      Paint()..color = Colors.white,
    );
    c.drawRRect(pipe, AnimalPainter.stroke(3.5));
    _puffs(c, const Offset(24, 146));
    // 차체 (연료통·덮개)
    final body = _motoBody();
    _paintBody(c, body, shadeFrom: .7);
    // 줄무늬
    c.drawLine(
      const Offset(118, 118),
      const Offset(204, 112),
      AnimalPainter.stroke(5, _trim),
    );
    // 앞 흙받이
    final fender = Path()
      ..addArc(const Rect.fromLTRB(200, 118, 272, 190), pi * 1.2, pi * .55);
    c.drawPath(fender, AnimalPainter.stroke(13));
    c.drawPath(
      fender,
      Paint()
        ..color = _trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    // 발판
    final pegR = RRect.fromLTRBR(158, 118, 180, 124, const Radius.circular(3));
    c.drawRRect(pegR, Paint()..color = const Color(0xFF3D3D3D));
    c.drawRRect(pegR, AnimalPainter.stroke(2.5));
    // 핸들 (뒤로 휜 손잡이), 거울, 전조등
    _tube(c, const Offset(214, 88), const Offset(184, 79), 5, _metalDark);
    final mgrip = RRect.fromLTRBR(168, 73, 186, 83, const Radius.circular(4));
    c.drawRRect(mgrip, Paint()..color = const Color(0xFF3D3D3D));
    c.drawRRect(mgrip, AnimalPainter.stroke(2.5));
    // 앞쪽 다리·팔, 손잡이를 잡은 손
    _pose?.paintFront(
      c,
      seatAt: motoSeat,
      scale: .52,
      hand: motoHand,
      foot: motoFoot,
    );
    _grip(c, motoHand, .52);
    c.drawLine(
      const Offset(212, 82),
      const Offset(206, 62),
      AnimalPainter.stroke(3),
    );
    final mirror = Path()..addOval(const Rect.fromLTRB(198, 54, 214, 64));
    AnimalPainter.fillStroke(c, mirror, _metal, width: 3);
    _lamp(c, const Offset(232, 100), 11);
  }

  // ---------------- 기차 ----------------

  /// 장난감 증기 기관차: 뒤쪽 기관실(친구가 창으로 내다본다) + 앞쪽 둥근 보일러.
  /// 다리는 기관실 안이라 보이지 않고, 스티커 자리는 기관실 판과 보일러 두 곳으로 넓다.
  void _train(Canvas c) {
    _shadow(c, const Rect.fromLTRB(24, 182, 284, 196));
    // 선로
    c.drawRRect(
      RRect.fromLTRBR(14, 184, 290, 190, const Radius.circular(3)),
      Paint()..color = const Color(0xFFB08A6A),
    );
    // 연기 (굴뚝에서 뒤로 퐁퐁)
    if (moving) {
      for (var i = 0; i < 3; i++) {
        final t = (phase * 2 + i / 3) % 1.0;
        c.drawCircle(
          Offset(236 - t * 60, 34 - t * 26),
          6 + t * 10,
          Paint()..color = Colors.white.withValues(alpha: .85 * (1 - t)),
        );
      }
    }
    _speedLines(c, 22, [96, 124]);
    // 굴뚝
    final stack = Path()
      ..moveTo(226, 92)
      ..lineTo(229, 56)
      ..lineTo(222, 44)
      ..lineTo(254, 44)
      ..lineTo(247, 56)
      ..lineTo(250, 92)
      ..close();
    AnimalPainter.fillStroke(c, stack, const Color(0xFF4A4250), width: 4);
    c.drawRRect(
      RRect.fromLTRBR(221, 42, 255, 50, const Radius.circular(3)),
      Paint()..color = _trim,
    );
    c.drawRRect(
      RRect.fromLTRBR(221, 42, 255, 50, const Radius.circular(3)),
      AnimalPainter.stroke(3),
    );
    // 증기 돔 (보일러 위 둥근 혹)
    final dome = Path()
      ..moveTo(170, 94)
      ..quadraticBezierTo(170, 72, 186, 72)
      ..quadraticBezierTo(202, 72, 202, 94)
      ..close();
    AnimalPainter.fillStroke(c, dome, _trim, width: 4);
    // 친구 (기관실 창으로 앞을 보고, 손은 창틀에)
    const cabHand = Offset(112, 104);
    _ride(
      c,
      const Offset(80, 138),
      .44,
      hand: cabHand,
      clip: const Rect.fromLTRB(38, 46, 120, 150),
    );
    // 기관실 기둥과 지붕
    for (final r in const [
      Rect.fromLTRB(30, 50, 42, 110),
      Rect.fromLTRB(116, 50, 128, 110),
    ]) {
      final pillar = RRect.fromRectAndRadius(r, const Radius.circular(3));
      c.drawRRect(pillar, Paint()..color = _shade(_body, .12));
      c.drawRRect(pillar, AnimalPainter.stroke(3.5));
    }
    final roof = Path()
      ..moveTo(18, 52)
      ..quadraticBezierTo(80, 28, 142, 52)
      ..lineTo(142, 58)
      ..lineTo(18, 58)
      ..close();
    AnimalPainter.fillStroke(c, roof, _trim);
    // 아래 받침(차대)
    final frame = RRect.fromLTRBR(26, 146, 272, 162, const Radius.circular(6));
    c.drawRRect(frame, Paint()..color = const Color(0xFF4A4250));
    c.drawRRect(frame, AnimalPainter.stroke());
    // 기관실 판 + 보일러 (스티커 자리)
    final cab = _trainCab();
    final boiler = _trainBoiler();
    _paintBody(c, cab, stickersOn: false);
    c.drawPath(boiler, Paint()..color = _body);
    c.save();
    c.clipPath(boiler);
    c.drawRect(
      const Rect.fromLTRB(120, 134, 270, 150),
      Paint()..color = _shade(_body, .16),
    );
    c.drawRect(
      const Rect.fromLTRB(120, 90, 270, 100),
      Paint()..color = _tint(_body, .4),
    );
    c.restore();
    _stickers(c, _union(cab, boiler));
    c.drawPath(boiler, AnimalPainter.stroke());
    c.drawPath(cab, AnimalPainter.stroke());
    // 보일러 띠 (스티커 위에 얇게)
    for (final x in [158.0, 212.0]) {
      c.drawLine(Offset(x, 94), Offset(x, 144), AnimalPainter.stroke(4, _trim));
    }
    // 창틀을 잡은 손
    _grip(c, cabHand, .44);
    // 앞 등과 앞판
    _lamp(c, const Offset(258, 82), 8);
    c.drawLine(
      const Offset(258, 90),
      const Offset(258, 94),
      AnimalPainter.stroke(4),
    );
    // 장애물 막이 (앞쪽 아래 세모)
    final catcher = Path()
      ..moveTo(262, 150)
      ..lineTo(290, 182)
      ..lineTo(256, 182)
      ..close();
    AnimalPainter.fillStroke(c, catcher, _trim);
    for (final x in [266.0, 274.0]) {
      c.drawLine(Offset(x, 158), Offset(x - 4, 182), AnimalPainter.stroke(2.5));
    }
    // 바퀴 (뒤 큰 바퀴 둘, 앞 작은 바퀴) + 연결 막대
    const wheels = [(64.0, 22.0), (112.0, 22.0), (176.0, 18.0), (226.0, 18.0)];
    for (final (x, r) in wheels) {
      _wheel(c, Offset(x, 182 - r), r, hub: _trim, bolts: 6, rim: .66);
    }
    final a = _spin;
    final rod = Offset(cos(a), sin(a)) * 8;
    c.drawLine(
      const Offset(64, 160) + rod,
      const Offset(112, 160) + rod,
      AnimalPainter.stroke(7),
    );
    c.drawLine(
      const Offset(64, 160) + rod,
      const Offset(112, 160) + rod,
      AnimalPainter.stroke(3.5, _metal),
    );
  }

  // ---------------- 열기구 ----------------

  /// 큰 풍선(전체가 스티커 자리) 아래 바구니에 친구가 타고 옆을 본다.
  /// 다리는 바구니 안이라 보이지 않는다.
  void _balloon(Canvas c) {
    // 지나가는 구름 (날 때)
    if (moving) {
      for (var i = 0; i < 2; i++) {
        final t = (phase + i * .5) % 1.0;
        final o = Offset(300 - t * 320, 140 + i * 30.0);
        final cloud = Paint()..color = Colors.white.withValues(alpha: .8);
        for (final (dx, r) in const [(-12.0, 8.0), (0.0, 11.0), (12.0, 8.0)]) {
          c.drawCircle(o + Offset(dx, 0), r, cloud);
        }
      }
    }
    // 줄 (뒤쪽 두 가닥)
    final rope = AnimalPainter.stroke(2.6);
    c.drawLine(const Offset(132, 94), const Offset(106, 150), rope);
    c.drawLine(const Offset(168, 94), const Offset(194, 150), rope);
    // 풍선
    final env = _balloonEnvelope();
    c.drawPath(env, Paint()..color = _body);
    c.save();
    c.clipPath(env);
    // 세로 줄무늬 두 줄 (포인트 색)
    c.drawOval(const Rect.fromLTRB(96, -40, 204, 128), Paint()..color = _trim);
    c.drawOval(const Rect.fromLTRB(124, -40, 176, 128), Paint()..color = _body);
    // 그늘과 반사광
    c.drawOval(
      const Rect.fromLTRB(40, 50, 260, 126),
      Paint()..color = _shade(_body, .14).withValues(alpha: .55),
    );
    c.drawOval(
      const Rect.fromLTRB(92, 8, 126, 30),
      Paint()..color = Colors.white.withValues(alpha: .45),
    );
    c.restore();
    _stickers(c, env);
    c.drawPath(env, AnimalPainter.stroke());
    // 풍선 아래 치마
    final skirt = RRect.fromLTRBR(128, 86, 172, 95, const Radius.circular(4));
    c.drawRRect(skirt, Paint()..color = _shade(_trim, .2));
    c.drawRRect(skirt, AnimalPainter.stroke(3.5));
    // 불꽃 (날 때)
    if (moving) {
      final f = 1 + sin(phase * 2 * pi * 6) * .25;
      for (final (w, col) in [
        (12.0, const Color(0xFFFFB13B)),
        (6.0, const Color(0xFFFFE57A)),
      ]) {
        c.drawOval(
          Rect.fromCenter(
            center: const Offset(150, 87),
            width: w,
            height: w * 1.8 * f,
          ),
          Paint()..color = col,
        );
      }
    }
    // 친구 (바구니 안에서 옆을 본다)
    const basketHand = Offset(170, 150);
    _ride(
      c,
      const Offset(136, 171),
      .42,
      hand: basketHand,
      clip: const Rect.fromLTRB(100, 0, 200, 190),
    );
    // 바구니
    final basket = Path()
      ..moveTo(100, 152)
      ..lineTo(200, 152)
      ..lineTo(193, 192)
      ..quadraticBezierTo(150, 197, 107, 192)
      ..close();
    const wicker = Color(0xFFE8B66A);
    c.drawPath(basket, Paint()..color = wicker);
    c.save();
    c.clipPath(basket);
    final weave = Paint()
      ..color = _shade(wicker, .28)
      ..strokeWidth = 2.2;
    for (var y = 160.0; y < 194; y += 8) {
      c.drawLine(Offset(100, y), Offset(200, y), weave);
    }
    for (var x = 112.0; x < 196; x += 12) {
      c.drawLine(Offset(x, 150), Offset(x + (x - 150) * .08, 194), weave);
    }
    c.restore();
    c.drawPath(basket, AnimalPainter.stroke());
    // 바구니 테두리
    final rim = RRect.fromLTRBR(94, 144, 206, 155, const Radius.circular(5));
    c.drawRRect(rim, Paint()..color = _leather);
    c.drawRRect(
      RRect.fromLTRBR(98, 146, 202, 149, const Radius.circular(2)),
      Paint()..color = _tint(_leather, .3),
    );
    c.drawRRect(rim, AnimalPainter.stroke(3.5));
    // 테두리를 잡은 손
    _grip(c, basketHand, .4);
  }

  // ---------------- 비행기 ----------------

  void _airplane(Canvas c) {
    _shadow(c, const Rect.fromLTRB(70, 184, 250, 196));
    // 바람 줄
    _speedLines(c, 24, [70, 132, 150]);
    // 착륙 바퀴
    _tube(c, const Offset(140, 146), const Offset(132, 172), 5, _metalDark);
    _tube(c, const Offset(200, 146), const Offset(206, 172), 5, _metalDark);
    _wheel(c, const Offset(132, 174), 11, bolts: 3);
    _wheel(c, const Offset(206, 174), 11, bolts: 3);
    // 꼬리 수평 날개 (뒤쪽)
    final tailWing = Path()..addOval(const Rect.fromLTRB(20, 108, 92, 126));
    AnimalPainter.fillStroke(c, tailWing, _shade(_trim, .12));
    // 친구 (조종석)
    // 친구 (조종석에서 옆을 보고, 손은 조종석 가장자리에)
    const planeHand = Offset(177, 92);
    _ride(
      c,
      const Offset(150, 115),
      .48,
      hand: planeHand,
      clip: const Rect.fromLTRB(0, 0, 300, 100),
    );
    // 꼬리 날개 + 몸통
    final fin = _planeFin();
    final body = _planeBody();
    _paintBody(c, fin, stickersOn: false);
    c.drawPath(body, Paint()..color = _body);
    c.save();
    c.clipPath(body);
    c.drawRect(
      const Rect.fromLTRB(30, 136, 290, 156),
      Paint()..color = _shade(_body, .15),
    );
    c.drawRect(
      const Rect.fromLTRB(30, 88, 290, 99),
      Paint()..color = _tint(_body, .4),
    );
    // 옆줄
    c.drawRect(const Rect.fromLTRB(30, 118, 290, 125), Paint()..color = _trim);
    c.restore();
    _stickers(c, _union(body, fin));
    c.drawPath(body, AnimalPainter.stroke());
    c.drawPath(fin, AnimalPainter.stroke());
    // 꼬리 장식 줄
    c.save();
    c.clipPath(fin);
    c.drawRect(const Rect.fromLTRB(20, 40, 100, 56), Paint()..color = _trim);
    c.restore();
    c.drawPath(fin, AnimalPainter.stroke());
    // 조종석 테두리 + 앞유리
    c.drawArc(
      const Rect.fromLTRB(118, 82, 186, 106),
      pi,
      pi,
      false,
      AnimalPainter.stroke(5, _shade(_body, .45)),
    );
    final shield = Path()
      ..moveTo(178, 94)
      ..lineTo(190, 70)
      ..lineTo(200, 72)
      ..lineTo(196, 94)
      ..close();
    c.drawPath(shield, Paint()..color = _glass.withValues(alpha: .8));
    c.drawPath(shield, AnimalPainter.stroke(3.5));
    _grip(c, planeHand, .48);
    // 창문
    for (final x in [214.0, 240.0]) {
      c.drawCircle(Offset(x, 108), 7, Paint()..color = const Color(0xFF8FD3F5));
      c.drawCircle(Offset(x - 2, 106), 2, Paint()..color = Colors.white);
      c.drawCircle(Offset(x, 108), 7, AnimalPainter.stroke(3));
    }
    // 주 날개 (앞쪽)
    final wing = Path()
      ..moveTo(110, 124)
      ..lineTo(212, 122)
      ..quadraticBezierTo(228, 132, 212, 142)
      ..lineTo(100, 146)
      ..quadraticBezierTo(92, 134, 110, 124)
      ..close();
    c.drawPath(wing, Paint()..color = _trim);
    c.save();
    c.clipPath(wing);
    c.drawRect(
      const Rect.fromLTRB(90, 138, 230, 150),
      Paint()..color = _shade(_trim, .2),
    );
    c.restore();
    c.drawPath(wing, AnimalPainter.stroke());
    StickerArt.draw(c, StickerKind.star, _body, const Offset(166, 133), 7);
    // 프로펠러
    final spinner = Path()
      ..moveTo(272, 104)
      ..quadraticBezierTo(296, 120, 272, 136)
      ..close();
    AnimalPainter.fillStroke(c, spinner, _trim, width: 4);
    if (moving) {
      c.drawOval(
        const Rect.fromLTRB(280, 66, 296, 174),
        Paint()..color = Colors.white.withValues(alpha: .5),
      );
      c.drawOval(
        const Rect.fromLTRB(280, 66, 296, 174),
        AnimalPainter.stroke(2, ink.withValues(alpha: .35)),
      );
    } else {
      for (final r in [
        RRect.fromLTRBR(283, 72, 293, 116, const Radius.circular(5)),
        RRect.fromLTRBR(283, 124, 293, 168, const Radius.circular(5)),
      ]) {
        c.drawRRect(r, Paint()..color = const Color(0xFF8C6346));
        c.drawRRect(r, AnimalPainter.stroke(3));
      }
    }
  }

  @override
  bool shouldRepaint(VehiclePainter old) =>
      old.vehicle != vehicle ||
      old.color != color ||
      old.stickers != stickers ||
      old.zodiac != zodiac ||
      old.items != items ||
      old.phase != phase ||
      old.moving != moving ||
      old.mood != mood;
}
