import 'dart:math';

import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
import '../character/rider_pose.dart';
import '../character/zodiac.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import 'sticker_art.dart';

/// 탈것 그림 (300 x 200 좌표계). 친구 그림과 같은 외곽선 없는 납작한(flat) 그림체:
/// 단순하고 둥근 도형을 색이 다른 면으로만 나누고, 그림자·반사광은 쓰지 않는다.
/// 차체는 고른 원색, 유리·바퀴·의자 같은 부품은 부드러운 파스텔로 칠한다.
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
  static const _tire = Color(0xFF5E5560);
  static const _metal = Color(0xFFDDE4EB);
  static const _metalDark = Color(0xFFA7B1BD);
  static const _glass = Color(0xFFCDEBFA);
  static const _lampColor = Color(0xFFFFE89A);
  static const _leather = Color(0xFFA9765C);
  static const _rubber = Color(0xFF6F6672);

  Color get _body => color.body;
  Color get _trim => color.trim;
  static Color _shade(Color c, [double t = .22]) =>
      Color.lerp(c, const Color(0xFF3A2A22), t)!;

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

  static Paint _fill(Color c) => Paint()..color = c;

  /// 부품 선 (외곽선이 아니라 손잡이·막대 같은 가는 부품)
  static Paint _line(Color c, double w) => AnimalPainter.stroke(w, c);

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
    c.drawLine(o + const Offset(12, 14), o, _line(_metalDark, 4));
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(-.5);
    final ring = Rect.fromCenter(center: Offset.zero, width: 9, height: 28);
    c.drawOval(ring, _line(_rubber, 4.5));
    c.restore();
    _grip(c, hand, scale);
  }

  /// 손잡이 위에 손을 한 번 더 그려 꼭 잡은 것처럼
  void _grip(Canvas c, Offset at, double scale) => _pose?.grip(c, at, scale);

  void _shadow(Canvas c, Rect r) =>
      c.drawOval(r, _fill(const Color(0x18000000)));

  /// 차체를 한 가지 색으로 칠하고 스티커를 붙인다 (외곽선·그늘 없음)
  void _paintBody(Canvas c, Path body, {bool stickersOn = true}) {
    c.drawPath(body, _fill(_body));
    if (stickersOn) _stickers(c, body);
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

  /// 통통한 타이어 + 둥근 휠 (굴러가면 볼트가 돈다)
  void _wheel(
    Canvas c,
    Offset o,
    double r, {
    Color? hub,
    int bolts = 5,
    double rim = .55,
  }) {
    c.drawCircle(o, r, _fill(_tire));
    c.drawCircle(o, r * rim, _fill(_metal));
    c.drawCircle(o, r * .22, _fill(hub ?? _trim));
    for (var i = 0; i < bolts; i++) {
      final a = _spin + i * 2 * pi / bolts;
      c.drawCircle(
        o + Offset(cos(a), sin(a)) * r * .38,
        max(1.6, r * .06),
        _fill(_metalDark),
      );
    }
  }

  /// 오토바이 바퀴: 둥근 타이어 고리와 가는 바퀴살
  void _spokeWheel(Canvas c, Offset o, double r, {int spokes = 12}) {
    c.drawCircle(o, r, _line(_tire, 11));
    c.drawCircle(o, r - 6.5, _line(_metal, 2.4));
    final spoke = Paint()
      ..color = _metalDark
      ..strokeWidth = 1.8;
    for (var i = 0; i < spokes; i++) {
      final a = _spin + i * pi / spokes * 2;
      c.drawLine(
        o + Offset(cos(a), sin(a)) * 5,
        o + Offset(cos(a), sin(a)) * (r - 6),
        spoke,
      );
    }
    c.drawCircle(o, 7, _fill(_trim));
  }

  /// 굵은 막대 (끝이 둥근 면 하나)
  void _tube(Canvas c, Offset a, Offset b, double w, Color col) =>
      c.drawLine(a, b, _line(col, w + 1));

  void _lamp(Canvas c, Offset o, double r) {
    if (moving) c.drawCircle(o, r * 1.9, _fill(const Color(0x33FFF4B8)));
    c.drawCircle(o, r, _fill(_lampColor));
  }

  /// 달릴 때 뒤로 퐁퐁 나오는 연기
  void _puffs(Canvas c, Offset from) {
    if (!moving) return;
    for (var i = 0; i < 3; i++) {
      final t = (phase * 2 + i / 3) % 1.0;
      c.drawCircle(
        from + Offset(-t * 34, -t * 10),
        4 + t * 7,
        _fill(Colors.white.withValues(alpha: .75 * (1 - t))),
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
    c.drawRRect(
      RRect.fromLTRBR(94, 66, 124, 104, const Radius.circular(12)),
      _fill(_leather),
    );
    // 친구 (옆을 보고 앉아 운전대를 잡는다. 다리는 차 안이라 안 보인다)
    const carHand = Offset(177, 79);
    _ride(c, const Offset(140, 120), .58, hand: carHand);
    _steering(c, const Offset(181, 85), carHand, .58);
    // 앞유리
    final glass = Path()
      ..moveTo(176, 100)
      ..lineTo(193, 62)
      ..quadraticBezierTo(196, 58, 201, 60)
      ..quadraticBezierTo(206, 62, 205, 66)
      ..lineTo(194, 100)
      ..close();
    c.drawPath(glass, _fill(_glass.withValues(alpha: .85)));
    c.drawLine(
      const Offset(187, 90),
      const Offset(197, 69),
      _line(Colors.white.withValues(alpha: .9), 3),
    );
    // 사이드 미러
    c.drawRRect(
      RRect.fromLTRBR(206, 86, 222, 98, const Radius.circular(6)),
      _fill(_trim),
    );
    // 배기구 + 연기
    c.drawRRect(
      RRect.fromLTRBR(12, 150, 32, 159, const Radius.circular(4.5)),
      _fill(_metalDark),
    );
    _puffs(c, const Offset(10, 152));
    // 차체
    final body = _carBody();
    c.drawPath(body, _fill(_body));
    c.save();
    c.clipPath(body);
    // 바퀴 집 (한 단 진한 면)
    for (final x in [82.0, 224.0]) {
      c.drawCircle(Offset(x, 162), 33, _fill(_shade(_body, .28)));
    }
    // 옆줄 무늬
    c.drawRRect(
      RRect.fromLTRBR(20, 124, 290, 132, const Radius.circular(4)),
      _fill(_trim),
    );
    c.restore();
    _stickers(c, body);
    // 문 틈, 손잡이
    c.drawLine(
      const Offset(150, 104),
      const Offset(150, 150),
      _line(_shade(_body, .18), 2.5),
    );
    c.drawLine(
      const Offset(160, 114),
      const Offset(172, 114),
      _line(_shade(_body, .26), 4),
    );
    // 범퍼
    for (final r in [
      RRect.fromLTRBR(252, 148, 286, 158, const Radius.circular(5)),
      RRect.fromLTRBR(18, 148, 46, 158, const Radius.circular(5)),
    ]) {
      c.drawRRect(r, _fill(_metal));
    }
    // 전조등, 미등
    _lamp(c, const Offset(266, 130), 8);
    c.drawRRect(
      RRect.fromLTRBR(25, 116, 36, 134, const Radius.circular(5)),
      _fill(const Color(0xFFFF8A80)),
    );
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
      (46.0, const Color(0xFFFF8A6E)),
      (34.0, const Color(0xFFFFB85C)),
      (20.0, const Color(0xFFFFE88A)),
    ]) {
      final f = Path()
        ..moveTo(36, 118 - w / 2)
        ..quadraticBezierTo(-6 - flick + (46 - w), 118, 36, 118 + w / 2)
        ..close();
      c.drawPath(f, _fill(col));
    }
    c.drawRRect(
      RRect.fromLTRBR(28, 98, 50, 138, const Radius.circular(6)),
      _fill(_metalDark),
    );
    // 날개 (위·아래): 둥근 지느러미
    for (final up in [true, false]) {
      final y = up ? 78.0 : 158.0;
      final d = up ? -1.0 : 1.0;
      final fin = Path()
        ..moveTo(78, y)
        ..quadraticBezierTo(56, y + d * 16, 52, y + d * 34)
        ..quadraticBezierTo(52, y + d * 40, 60, y + d * 38)
        ..quadraticBezierTo(96, y + d * 22, 120, y + d * 2)
        ..close();
      c.drawPath(fin, _fill(_trim));
    }
    // 조종석 유리 돔 안의 친구
    final dome = Path()..addOval(const Rect.fromLTRB(116, 6, 214, 100));
    c.drawPath(dome, _fill(_glass));
    c.save();
    c.clipPath(dome);
    // 친구 (옆을 보고 앉아 조종간을 잡는다)
    const lever = Offset(192, 71);
    _ride(c, const Offset(158, 111), .52, hand: lever);
    c.drawLine(const Offset(202, 92), lever, _line(_metalDark, 4));
    _grip(c, lever, .52);
    c.drawCircle(
      lever + const Offset(-1, -6),
      4,
      _fill(const Color(0xFFFF6F61)),
    );
    c.restore();
    c.drawPath(dome, _fill(const Color(0x26FFFFFF)));
    c.drawArc(
      const Rect.fromLTRB(128, 16, 202, 90),
      pi * 1.12,
      pi * .3,
      false,
      _line(Colors.white.withValues(alpha: .9), 5),
    );
    // 몸체
    final body = _rocketBody();
    c.drawPath(body, _fill(_body));
    c.save();
    c.clipPath(body);
    // 띠 장식
    c.drawRect(const Rect.fromLTRB(198, 60, 212, 170), _fill(_trim));
    c.restore();
    _stickers(c, body);
    // 동그란 창
    for (final o in [const Offset(84, 118), const Offset(240, 118)]) {
      c.drawCircle(o, 10.5, _fill(_metal));
      c.drawCircle(o, 6.5, _fill(const Color(0xFF9ED8F5)));
    }
    // 코 끝
    final nose = Path()
      ..moveTo(258, 92)
      ..quadraticBezierTo(284, 104, 290, 118)
      ..quadraticBezierTo(284, 132, 258, 144)
      ..quadraticBezierTo(266, 118, 258, 92)
      ..close();
    c.drawPath(nose, _fill(_trim));
    // 안테나
    c.drawLine(
      const Offset(150, 12),
      const Offset(141, 2),
      _line(_metalDark, 3),
    );
    c.drawCircle(const Offset(140, 2), 4.5, _fill(_trim));
  }

  // ---------------- 탱크 ----------------

  void _tank(Canvas c) {
    _shadow(c, const Rect.fromLTRB(24, 180, 278, 196));
    // 열린 뚜껑
    c.drawOval(const Rect.fromLTRB(108, 56, 140, 70), _fill(_shade(_body, .3)));
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
    c.drawRRect(
      RRect.fromLTRBR(198, 88, 280, 100, const Radius.circular(6)),
      _fill(_shade(_body, .14)),
    );
    c.drawRRect(
      RRect.fromLTRBR(274, 84, 292, 104, const Radius.circular(6)),
      _fill(_shade(_body, .28)),
    );
    // 포탑 + 차체 (한 색)
    final turret = _tankTurret();
    final hull = _tankHull();
    final all = _union(hull, turret);
    c.drawPath(all, _fill(_body));
    // 얼룩무늬 (진한 면)
    c.save();
    c.clipPath(all);
    for (final r in const [
      Rect.fromLTRB(110, 84, 136, 98),
      Rect.fromLTRB(168, 96, 196, 110),
      Rect.fromLTRB(60, 120, 92, 134),
      Rect.fromLTRB(150, 126, 186, 140),
      Rect.fromLTRB(220, 118, 248, 132),
    ]) {
      c.drawOval(r, _fill(_shade(_body, .14)));
    }
    c.restore();
    _stickers(c, all);
    _grip(c, tankHand, .48);
    // 해치 테두리
    c.drawLine(
      const Offset(126, 78),
      const Offset(178, 78),
      _line(_shade(_body, .3), 4),
    );
    // 무한궤도
    final track = RRect.fromLTRBR(24, 140, 276, 188, const Radius.circular(24));
    c.drawRRect(track, _fill(_tire));
    c.save();
    c.clipRRect(track);
    final lug = Paint()
      ..color = _rubber
      ..strokeWidth = 4;
    final off = moving ? (phase * 3 % 1.0) * 14 : 0.0;
    for (var x = 18.0 + off; x < 286; x += 14) {
      c.drawLine(Offset(x, 140), Offset(x, 146), lug);
      c.drawLine(Offset(x - off * 2, 182), Offset(x - off * 2, 188), lug);
    }
    c.restore();
    // 바퀴들
    for (final x in [50.0, 90.0, 130.0, 170.0, 210.0, 250.0]) {
      final r = (x == 50 || x == 250) ? 13.0 : 15.0;
      c.drawCircle(Offset(x, 164), r, _fill(_metal));
      c.drawCircle(Offset(x, 164), r * .42, _fill(_shade(_body, .1)));
      final a = _spin + x;
      c.drawCircle(
        Offset(x, 164) + Offset(cos(a), sin(a)) * r * .68,
        1.8,
        _fill(_metalDark),
      );
    }
    _puffs(c, const Offset(28, 130));
  }

  // ---------------- 오토바이 ----------------

  /// 앉는 자리·손잡이·발판 (친구 팔다리가 정확히 여기에 닿는다)
  static const Offset motoSeat = Offset(136, 100),
      motoHand = Offset(176, 78),
      motoFoot = Offset(166, 113);

  void _motorcycle(Canvas c) {
    _shadow(c, const Rect.fromLTRB(32, 180, 270, 194));
    _speedLines(c, 30, [96, 116]);
    // 뒷바퀴, 앞바퀴
    _spokeWheel(c, const Offset(66, 156), 30, spokes: 10);
    _spokeWheel(c, const Offset(236, 156), 30, spokes: 10);
    // 뒷 흙받이
    c.drawPath(
      Path()
        ..addArc(const Rect.fromLTRB(30, 116, 102, 188), pi * 1.05, pi * .7),
      _line(_body, 10),
    );
    // 뒤 팔, 앞 포크
    _tube(c, const Offset(66, 156), const Offset(132, 140), 7, _metalDark);
    _tube(c, const Offset(236, 156), const Offset(214, 86), 7, _metal);
    // 친구: 뒤쪽 팔다리와 몸 (앞쪽 다리·팔은 차체 위에 그린다)
    _pose?.paintBack(
      c,
      seatAt: motoSeat,
      scale: .52,
      hand: motoHand,
      foot: motoFoot,
    );
    // 안장 (엉덩이 아래를 살짝 덮어 앉은 것처럼)
    c.drawRRect(
      RRect.fromLTRBR(84, 96, 162, 110, const Radius.circular(7)),
      _fill(_leather),
    );
    // 엔진
    c.drawRRect(
      RRect.fromLTRBR(116, 134, 172, 166, const Radius.circular(10)),
      _fill(_metalDark),
    );
    for (var y = 142.0; y <= 158; y += 8) {
      c.drawLine(Offset(124, y), Offset(164, y), _line(_metal, 3));
    }
    // 배기관
    c.drawRRect(
      RRect.fromLTRBR(26, 142, 124, 154, const Radius.circular(6)),
      _fill(_metal),
    );
    _puffs(c, const Offset(24, 146));
    // 차체 (연료통·덮개)
    _paintBody(c, _motoBody());
    // 줄무늬
    c.drawLine(const Offset(120, 120), const Offset(202, 113), _line(_trim, 5));
    // 앞 흙받이
    c.drawPath(
      Path()
        ..addArc(const Rect.fromLTRB(200, 118, 272, 190), pi * 1.2, pi * .55),
      _line(_trim, 10),
    );
    // 발판
    c.drawRRect(
      RRect.fromLTRBR(158, 118, 180, 124, const Radius.circular(3)),
      _fill(_rubber),
    );
    // 핸들 (뒤로 휜 손잡이), 거울 막대
    _tube(c, const Offset(214, 88), const Offset(184, 79), 5, _metalDark);
    c.drawLine(
      const Offset(212, 82),
      const Offset(206, 62),
      _line(_metalDark, 3),
    );
    c.drawOval(const Rect.fromLTRB(198, 54, 214, 64), _fill(_metal));
    c.drawRRect(
      RRect.fromLTRBR(168, 73, 186, 83, const Radius.circular(5)),
      _fill(_rubber),
    );
    // 앞쪽 다리·팔, 손잡이를 잡은 손
    _pose?.paintFront(
      c,
      seatAt: motoSeat,
      scale: .52,
      hand: motoHand,
      foot: motoFoot,
    );
    _grip(c, motoHand, .52);
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
      _fill(const Color(0xFFC9A786)),
    );
    // 연기 (굴뚝에서 뒤로 퐁퐁)
    if (moving) {
      for (var i = 0; i < 3; i++) {
        final t = (phase * 2 + i / 3) % 1.0;
        c.drawCircle(
          Offset(236 - t * 60, 34 - t * 26),
          6 + t * 10,
          _fill(Colors.white.withValues(alpha: .85 * (1 - t))),
        );
      }
    }
    _speedLines(c, 22, [96, 124]);
    // 굴뚝
    final stack = Path()
      ..moveTo(228, 92)
      ..lineTo(230, 56)
      ..lineTo(248, 56)
      ..lineTo(250, 92)
      ..close();
    c.drawPath(stack, _fill(_tire));
    c.drawRRect(
      RRect.fromLTRBR(220, 42, 256, 58, const Radius.circular(6)),
      _fill(_trim),
    );
    // 증기 돔 (보일러 위 둥근 혹)
    c.drawPath(
      Path()
        ..moveTo(170, 94)
        ..quadraticBezierTo(170, 72, 186, 72)
        ..quadraticBezierTo(202, 72, 202, 94)
        ..close(),
      _fill(_trim),
    );
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
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        _fill(_shade(_body, .12)),
      );
    }
    c.drawPath(
      Path()
        ..moveTo(18, 54)
        ..quadraticBezierTo(80, 26, 142, 54)
        ..quadraticBezierTo(142, 60, 136, 60)
        ..lineTo(24, 60)
        ..quadraticBezierTo(18, 60, 18, 54)
        ..close(),
      _fill(_trim),
    );
    // 아래 받침(차대)
    c.drawRRect(
      RRect.fromLTRBR(26, 146, 272, 162, const Radius.circular(8)),
      _fill(_tire),
    );
    // 기관실 판 + 보일러 (스티커 자리)
    final cab = _trainCab();
    final boiler = _trainBoiler();
    final both = _union(cab, boiler);
    c.drawPath(both, _fill(_body));
    _stickers(c, both);
    // 보일러 띠
    for (final x in [158.0, 212.0]) {
      c.drawLine(Offset(x, 95), Offset(x, 143), _line(_trim, 5));
    }
    // 창틀을 잡은 손
    _grip(c, cabHand, .44);
    // 앞 등
    _lamp(c, const Offset(258, 82), 8);
    // 장애물 막이 (앞쪽 아래 세모)
    c.drawPath(
      Path()
        ..moveTo(262, 150)
        ..lineTo(288, 178)
        ..quadraticBezierTo(290, 182, 285, 182)
        ..lineTo(256, 182)
        ..close(),
      _fill(_trim),
    );
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
      _line(_metalDark, 5),
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
        final cloud = _fill(Colors.white.withValues(alpha: .8));
        for (final (dx, r) in const [(-12.0, 8.0), (0.0, 11.0), (12.0, 8.0)]) {
          c.drawCircle(o + Offset(dx, 0), r, cloud);
        }
      }
    }
    // 줄 (뒤쪽 두 가닥)
    final rope = _line(const Color(0xFFB8957A), 2.6);
    c.drawLine(const Offset(132, 94), const Offset(106, 150), rope);
    c.drawLine(const Offset(168, 94), const Offset(194, 150), rope);
    // 풍선
    final env = _balloonEnvelope();
    c.drawPath(env, _fill(_body));
    c.save();
    c.clipPath(env);
    // 세로 줄무늬 두 줄 (포인트 색)
    c.drawOval(const Rect.fromLTRB(96, -40, 204, 128), _fill(_trim));
    c.drawOval(const Rect.fromLTRB(124, -40, 176, 128), _fill(_body));
    c.restore();
    _stickers(c, env);
    // 풍선 아래 치마
    c.drawRRect(
      RRect.fromLTRBR(128, 86, 172, 95, const Radius.circular(4.5)),
      _fill(_shade(_trim, .18)),
    );
    // 불꽃 (날 때)
    if (moving) {
      final f = 1 + sin(phase * 2 * pi * 6) * .25;
      for (final (w, col) in [
        (12.0, const Color(0xFFFFB85C)),
        (6.0, const Color(0xFFFFE88A)),
      ]) {
        c.drawOval(
          Rect.fromCenter(
            center: const Offset(150, 87),
            width: w,
            height: w * 1.8 * f,
          ),
          _fill(col),
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
      ..lineTo(194, 186)
      ..quadraticBezierTo(192, 194, 184, 194)
      ..lineTo(116, 194)
      ..quadraticBezierTo(108, 194, 106, 186)
      ..close();
    const wicker = Color(0xFFF0C27E);
    c.drawPath(basket, _fill(wicker));
    c.save();
    c.clipPath(basket);
    final weave = _line(_shade(wicker, .14), 3);
    for (var y = 164.0; y < 194; y += 10) {
      c.drawLine(Offset(100, y), Offset(200, y), weave);
    }
    c.restore();
    // 바구니 테두리
    c.drawRRect(
      RRect.fromLTRBR(94, 144, 206, 156, const Radius.circular(6)),
      _fill(_leather),
    );
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
    c.drawOval(
      const Rect.fromLTRB(20, 108, 92, 126),
      _fill(_shade(_trim, .12)),
    );
    // 친구 (조종석에서 옆을 보고, 손은 조종석 가장자리에)
    const planeHand = Offset(177, 92);
    _ride(
      c,
      const Offset(150, 115),
      .48,
      hand: planeHand,
      clip: const Rect.fromLTRB(0, 0, 300, 100),
    );
    // 꼬리 날개 + 몸통 (한 색)
    final fin = _planeFin();
    final body = _planeBody();
    final all = _union(body, fin);
    c.drawPath(all, _fill(_body));
    c.save();
    c.clipPath(all);
    // 옆줄, 꼬리 장식 줄
    c.drawRect(const Rect.fromLTRB(30, 118, 290, 126), _fill(_trim));
    c.drawRect(const Rect.fromLTRB(20, 40, 100, 56), _fill(_trim));
    c.restore();
    _stickers(c, all);
    // 조종석 테두리 + 앞유리
    c.drawArc(
      const Rect.fromLTRB(118, 82, 186, 106),
      pi,
      pi,
      false,
      _line(_shade(_body, .3), 5),
    );
    final shield = Path()
      ..moveTo(178, 94)
      ..lineTo(189, 71)
      ..quadraticBezierTo(191, 68, 196, 69)
      ..quadraticBezierTo(201, 70, 200, 74)
      ..lineTo(196, 94)
      ..close();
    c.drawPath(shield, _fill(_glass.withValues(alpha: .9)));
    _grip(c, planeHand, .48);
    // 창문
    for (final x in [214.0, 240.0]) {
      c.drawCircle(Offset(x, 108), 7.5, _fill(_metal));
      c.drawCircle(Offset(x, 108), 5, _fill(const Color(0xFF9ED8F5)));
    }
    // 주 날개 (앞쪽)
    final wing = Path()
      ..moveTo(110, 124)
      ..lineTo(212, 122)
      ..quadraticBezierTo(228, 132, 212, 142)
      ..lineTo(100, 146)
      ..quadraticBezierTo(92, 134, 110, 124)
      ..close();
    c.drawPath(wing, _fill(_trim));
    StickerArt.draw(c, StickerKind.star, _body, const Offset(166, 133), 7);
    // 프로펠러
    c.drawPath(
      Path()
        ..moveTo(272, 104)
        ..quadraticBezierTo(296, 120, 272, 136)
        ..close(),
      _fill(_trim),
    );
    if (moving) {
      c.drawOval(
        const Rect.fromLTRB(280, 66, 296, 174),
        _fill(Colors.white.withValues(alpha: .55)),
      );
    } else {
      for (final r in [
        RRect.fromLTRBR(283, 72, 293, 116, const Radius.circular(5)),
        RRect.fromLTRBR(283, 124, 293, 168, const Radius.circular(5)),
      ]) {
        c.drawRRect(r, _fill(const Color(0xFFB58363)));
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
