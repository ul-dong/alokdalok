import 'dart:math';

import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
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
    VehicleKind.bicycle => 12,
    VehicleKind.kickboard => 11,
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

  static Path _bikeGuard() => Path()
    ..addRRect(RRect.fromLTRBR(64, 138, 150, 160, const Radius.circular(11)));

  static Path _bikeBasket() => Path()
    ..moveTo(220, 72)
    ..lineTo(284, 72)
    ..lineTo(275, 112)
    ..lineTo(229, 112)
    ..close();

  static Path _kickDeck() => Path()
    ..addRRect(RRect.fromLTRBR(50, 150, 242, 168, const Radius.circular(9)));

  static Path _kickPlate() => Path()
    ..addRRect(RRect.fromLTRBR(203, 118, 231, 158, const Radius.circular(11)));

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

  static Path _union(Path a, Path b) => Path.combine(PathOperation.union, a, b);

  /// 스티커를 붙일 수 있는 차체 영역 (설계 좌표)
  static Path bodyPath(VehicleKind kind) => switch (kind) {
    VehicleKind.car => _carBody(),
    VehicleKind.rocket => _rocketBody(),
    VehicleKind.tank => _union(_tankHull(), _tankTurret()),
    VehicleKind.motorcycle => _motoBody(),
    VehicleKind.bicycle => _union(_bikeGuard(), _bikeBasket()),
    VehicleKind.kickboard => _union(_kickDeck(), _kickPlate()),
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
      case VehicleKind.bicycle:
        _bicycle(canvas);
      case VehicleKind.kickboard:
        _kickboard(canvas);
      case VehicleKind.airplane:
        _airplane(canvas);
    }
    canvas.restore();
  }

  // ---------------- 공통 부품 ----------------

  double get _spin => moving ? phase * 2 * pi * 3 : 0.0;

  void _rider(Canvas c, Offset headAt, double scale, {Rect? clip}) {
    if (zodiac == null) return;
    c.save();
    if (clip != null) c.clipRect(clip);
    c.translate(
      headAt.dx - AnimalPainter.headCenter.dx * scale,
      headAt.dy - AnimalPainter.headCenter.dy * scale,
    );
    c.scale(scale);
    AnimalPainter(zodiac: zodiac!, items: items).paint(c, AnimalPainter.design);
    c.restore();
  }

  /// 탈것 위의 친구: 몸은 그대로 두고, 팔은 손잡이로, 다리는 페달·발판으로 뻗어 그린다.
  /// [hands]·[feet]는 (뒤쪽, 앞쪽) 순서. [feet]가 없으면 서 있는 자세(원래 발).
  void _riderPosed(
    Canvas c,
    Offset headAt,
    double scale, {
    required (Offset, Offset) hands,
    (Offset, Offset)? feet,
  }) {
    final z = zodiac;
    if (z == null) return;
    if (z == Zodiac.snake) {
      _rider(c, headAt, scale);
      return;
    }
    Offset tr(double x, double y) => Offset(
      headAt.dx + (x - AnimalPainter.headCenter.dx) * scale,
      headAt.dy + (y - AnimalPainter.headCenter.dy) * scale,
    );
    final look = z.look;
    final skin = z == Zodiac.sheep ? look.accent : look.fur;
    final hooves = const {
      Zodiac.ox,
      Zodiac.horse,
      Zodiac.sheep,
      Zodiac.pig,
    }.contains(z);
    final tipColor = hooves ? const Color(0xFF8A817C) : skin;
    final sleeve = items[ItemSlot.outfit]?.colors.first ?? skin;
    final shoe = items[ItemSlot.shoes]?.colors.first;
    final wings = z == Zodiac.rooster || z == Zodiac.pteranodon;
    final w = 15 * scale;
    final t = AnimalPainter.lineWidth * scale;

    void limb(List<Offset> pts, Color color, Color tip, double tipR) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path, AnimalPainter.stroke(w + t * 2));
      c.drawPath(path, AnimalPainter.stroke(w, color));
      final end = pts.last;
      c.drawCircle(end, tipR, Paint()..color = tip);
      c.drawCircle(end, tipR, AnimalPainter.stroke(t));
    }

    List<Offset> leg(Offset hip, Offset foot) {
      // 무릎은 앞(오른쪽)·위로 살짝
      final mid = Offset((hip.dx + foot.dx) / 2, (hip.dy + foot.dy) / 2);
      return [hip, mid + Offset(12 * scale * 2, -8 * scale * 2), foot];
    }

    final shoulderFar = tr(72, 158), shoulderNear = tr(128, 158);
    final hipFar = tr(90, 204), hipNear = tr(110, 204);
    // 뒤쪽 팔·다리 (몸 뒤)
    if (feet != null) {
      limb(leg(hipFar, feet.$1), skin, shoe ?? tipColor, w * .62);
    }
    if (!wings) limb([shoulderFar, hands.$1], sleeve, tipColor, w * .58);
    // 몸
    c.save();
    c.translate(
      headAt.dx - AnimalPainter.headCenter.dx * scale,
      headAt.dy - AnimalPainter.headCenter.dy * scale,
    );
    c.scale(scale);
    AnimalPainter(
      zodiac: z,
      items: items,
      drawLegs: feet == null,
      drawArms: false,
    ).paint(c, AnimalPainter.design);
    c.restore();
    // 앞쪽 팔·다리
    if (feet != null) {
      limb(leg(hipNear, feet.$2), skin, shoe ?? tipColor, w * .62);
    }
    if (!wings) limb([shoulderNear, hands.$2], sleeve, tipColor, w * .58);
  }

  /// 손잡이 위에 손을 한 번 더 그려 꼭 잡은 것처럼 보이게
  void _hand(Canvas c, Offset at, double scale) {
    final z = zodiac;
    if (z == null ||
        z == Zodiac.snake ||
        z == Zodiac.rooster ||
        z == Zodiac.pteranodon) {
      return;
    }
    final hooves = const {
      Zodiac.ox,
      Zodiac.horse,
      Zodiac.sheep,
      Zodiac.pig,
    }.contains(z);
    final col = hooves
        ? const Color(0xFF8A817C)
        : (z == Zodiac.sheep ? z.look.accent : z.look.fur);
    final r = 15 * scale * .58;
    c.drawCircle(at, r, Paint()..color = col);
    c.drawCircle(at, r, AnimalPainter.stroke(AnimalPainter.lineWidth * scale));
  }

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
    _rider(c, const Offset(142, 52), .58);
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
    _rider(c, const Offset(165, 50), .52);
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
    _rider(
      c,
      const Offset(152, 50),
      .48,
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
    // 친구 (안장에 앉아 손잡이를 잡고 발판에 발)
    final peg = Offset(146, 146);
    _riderPosed(
      c,
      const Offset(128, 40),
      .52,
      hands: (const Offset(184, 82), const Offset(191, 81)),
      feet: (peg + const Offset(-6, 2), peg),
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
    // 핸들 (뒤로 휜 손잡이), 거울, 전조등
    _tube(c, const Offset(214, 88), const Offset(194, 81), 5, _metalDark);
    final mgrip = RRect.fromLTRBR(180, 76, 196, 86, const Radius.circular(4));
    c.drawRRect(mgrip, Paint()..color = const Color(0xFF3D3D3D));
    c.drawRRect(mgrip, AnimalPainter.stroke(2.5));
    // 손잡이를 잡은 손 (핸들 위에 다시 그린다)
    _hand(c, const Offset(191, 81), .52);
    c.drawLine(
      const Offset(212, 82),
      const Offset(206, 62),
      AnimalPainter.stroke(3),
    );
    final mirror = Path()..addOval(const Rect.fromLTRB(198, 54, 214, 64));
    AnimalPainter.fillStroke(c, mirror, _metal, width: 3);
    _lamp(c, const Offset(232, 100), 11);
  }

  // ---------------- 자전거 ----------------

  void _bicycle(Canvas c) {
    _shadow(c, const Rect.fromLTRB(32, 180, 274, 194));
    const rear = Offset(70, 150), front = Offset(232, 150);
    const bb = Offset(142, 152), seatTop = Offset(118, 112);
    const head = Offset(206, 106), headLow = Offset(214, 122);
    _spokeWheel(c, rear, 34);
    _spokeWheel(c, front, 34);
    // 프레임
    for (final (a, b) in const [
      (rear, bb),
      (rear, seatTop),
      (bb, Offset(118, 114)),
      (Offset(120, 118), head),
      (bb, headLow),
      (headLow, front),
      (head, headLow),
    ]) {
      _tube(c, a, b, 6, _body);
    }
    // 안장
    _tube(c, seatTop, const Offset(117, 104), 4, _metalDark);
    final saddle = RRect.fromLTRBR(98, 98, 136, 108, const Radius.circular(6));
    c.drawRRect(saddle, Paint()..color = _leather);
    c.drawRRect(saddle, AnimalPainter.stroke(3.5));
    // 핸들 (뒤로 휘어 손에 닿게) + 종
    _tube(c, head, const Offset(184, 94), 4, _metalDark);
    final bell = Path()..addOval(const Rect.fromLTRB(196, 90, 206, 99));
    AnimalPainter.fillStroke(c, bell, const Color(0xFFFFCF4D), width: 2.5);
    // 페달 (돈다) — 친구 발이 페달을 밟는다
    final a = _spin;
    final pedalNear = bb + Offset(cos(a), sin(a)) * 16;
    final pedalFar = bb - Offset(cos(a), sin(a)) * 16;
    for (final p in [pedalFar, pedalNear]) {
      c.drawLine(bb, p, AnimalPainter.stroke(5));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 16, height: 6),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF3D3D3D),
      );
    }
    c.drawCircle(bb, 8, Paint()..color = _metal);
    c.drawCircle(bb, 8, AnimalPainter.stroke(3));
    // 친구 (안장에 앉아 페달을 밟는다)
    _riderPosed(
      c,
      const Offset(116, 48),
      .48,
      hands: (const Offset(176, 96), const Offset(183, 94)),
      feet: (pedalFar + const Offset(0, -3), pedalNear + const Offset(0, -3)),
    );
    final grip = RRect.fromLTRBR(172, 89, 186, 99, const Radius.circular(4));
    c.drawRRect(grip, Paint()..color = _trim);
    c.drawRRect(grip, AnimalPainter.stroke(2.5));
    _hand(c, const Offset(183, 94), .48);
    // 체인 덮개 (스티커 자리)
    final guard = _bikeGuard();
    _paintBody(c, guard, shadeFrom: .6);
    // 앞 바구니 (스티커 자리)
    final basket = _bikeBasket();
    const wicker = Color(0xFFE8C07A);
    c.drawPath(basket, Paint()..color = wicker);
    c.save();
    c.clipPath(basket);
    final weave = Paint()
      ..color = _shade(wicker, .25)
      ..strokeWidth = 2;
    for (var y = 80.0; y < 112; y += 8) {
      c.drawLine(Offset(216, y), Offset(288, y), weave);
    }
    for (var x = 226.0; x < 286; x += 10) {
      c.drawLine(Offset(x, 70), Offset(x - 3, 114), weave);
    }
    c.restore();
    _stickers(c, basket);
    c.drawPath(basket, AnimalPainter.stroke(4));
    c.drawLine(
      const Offset(218, 72),
      const Offset(286, 72),
      AnimalPainter.stroke(6, _shade(wicker, .3)),
    );
    _lamp(c, const Offset(222, 120), 6);
    _speedLines(c, 26, [104, 124]);
  }

  // ---------------- 킥보드 ----------------

  void _kickboard(Canvas c) {
    _shadow(c, const Rect.fromLTRB(42, 182, 256, 194));
    _speedLines(c, 40, [110, 132]);
    // 손잡이 기둥 (아이 키에 맞춘 낮은 손잡이)
    _tube(c, const Offset(226, 162), const Offset(198, 104), 9, _metal);
    c.drawLine(
      const Offset(222, 152),
      const Offset(200, 110),
      AnimalPainter.stroke(2.5, Colors.white),
    );
    _tube(c, const Offset(186, 104), const Offset(208, 104), 6, _metalDark);
    // 친구 (발판 위에 서서 손잡이를 잡는다)
    _riderPosed(
      c,
      const Offset(140, 79),
      .52,
      hands: (const Offset(182, 106), const Offset(189, 104)),
    );
    final kgrip = RRect.fromLTRBR(176, 99, 192, 110, const Radius.circular(5));
    c.drawRRect(
      kgrip,
      Paint()..color = _trim == Colors.white ? _shade(_body, .3) : _trim,
    );
    c.drawRRect(kgrip, AnimalPainter.stroke(3));
    _hand(c, const Offset(189, 104), .52);
    // 앞판 (스티커 자리)
    final plate = _kickPlate();
    _paintBody(c, plate, shadeFrom: .75, stickersOn: false);
    _lamp(c, const Offset(215, 128), 5);
    // 발판 (스티커 자리)
    final deck = _kickDeck();
    _paintBody(c, deck, shadeFrom: .6, stickersOn: false);
    // 미끄럼 방지 판
    c.drawRRect(
      RRect.fromLTRBR(64, 153, 200, 158, const Radius.circular(3)),
      Paint()..color = _shade(_body, .35).withValues(alpha: .6),
    );
    _stickers(c, _union(deck, plate));
    c.drawPath(deck, AnimalPainter.stroke());
    c.drawPath(plate, AnimalPainter.stroke());
    // 뒤 브레이크 덮개
    final brake = Path()
      ..addArc(const Rect.fromLTRB(46, 154, 90, 192), pi * 1.0, pi * .62);
    c.drawPath(brake, AnimalPainter.stroke(10));
    c.drawPath(
      brake,
      Paint()
        ..color = _shade(_body, .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    // 바퀴 (작은 바퀴, 빛나는 바퀴)
    for (final x in [68.0, 228.0]) {
      _wheel(c, Offset(x, 174), 14, bolts: 3, rim: .6);
    }
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
    _rider(
      c,
      const Offset(152, 58),
      .48,
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
      old.moving != moving;
}
