import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import 'item_art.dart';
import 'zodiac.dart';

enum CharMood { normal, happy, think }

/// 얼굴이 보는 쪽: 서 있을 때는 정면, 탈것에 타면 가는 쪽(오른쪽)
enum FaceDirection { front, right }

/// 주둥이 종류 (얼굴 아래쪽 모양). 같은 머리 틀 위에 이것만 바꿔도 동물이 달라 보인다.
enum Snout {
  /// 작은 세모 코 + "ω" 입 (쥐·토끼·호랑이·개·원숭이·양)
  cat,

  /// 콧구멍 있는 둥근 주둥이 (소·말·돼지·용)
  muzzle,

  /// 새 부리 (닭·프테라노돈)
  beak,

  /// 갈라진 혀 (뱀)
  snake,

  /// 크고 넓은 턱 + 이빨 (티라노·스피노)
  jaw,

  /// 짧고 단단한 부리 주둥이 (트리케라톱스·스테고·안킬로·이구아노돈·파키)
  dinoBeak,

  /// 넓적한 오리 주둥이 (파라사우롤로푸스)
  duck,

  /// 뾰족한 주둥이 + 작은 이빨 (벨로시랩터·딜로포)
  pointy,

  /// 순한 둥근 주둥이 (브라키오)
  gentle,
}

/// 친구 그리기 (12지신 + 공룡).
///
/// 그림체 (2026-10-22 사용자 결정): 외곽선 없는 납작한(flat) 파스텔 그림.
/// 머리·몸·팔·발은 같은 색 면이 하나의 실루엣으로 이어지고(이음새 선 없음),
/// 얼굴은 점 눈·작은 코와 입·연한 볼로 단순하게. 그라데이션 없이 색이 다른 면으로 무늬를 나누고,
/// 팔·다리는 한 톤 진하게, 팔 아래·턱 아래·몸 아래에는 아주 연한 단색 그늘 면을 깔아 부위를 구분한다.
///
/// 모든 친구가 같은 몸 틀(머리 크기와 위치, 몸통, 팔·발 위치)을 공유해서 꾸미기 아이템이 누구에게나 맞는다.
/// 종마다 다른 점은 머리 모양·귀·뿔·볏·주둥이와 무늬·색·꼬리·등판·날개로만 표현한다. 200 x 240 좌표계.
/// 그리는 순서(레이어)는 고정:
///   그림자 → 등 장식 → 등판(돛·골판·갑옷) → 꼬리 → 발 → 몸 → 팔 → 옷 → 신발 → 가방끈 → 목걸이
///   → 귀·뿔·볏(뒤) → 머리 → 무늬·주둥이·뿔 → 얼굴 → 늘어진 귀 → 안경·리본 → 모자
class AnimalPainter extends CustomPainter {
  AnimalPainter({
    required this.zodiac,
    required this.items,
    this.mood = CharMood.normal,
    this.phase = 0,
    this.drawLegs = true,
    this.drawArms = true,
    this.sideways = false,
  });

  /// 탈것에 탔을 때: 가는 쪽(오른쪽)을 보도록 얼굴을 돌린다.
  /// 24마리 모두 같은 머리 틀이라 [turnFace] 변환 하나로 처리한다 (꼬리·뒤로 뻗은 볏은 뒤쪽으로).
  final bool sideways;

  /// 얼굴이 보는 쪽
  FaceDirection get faceDirection =>
      sideways ? FaceDirection.right : FaceDirection.front;

  /// 옆을 볼 때 얼굴(눈·볼·무늬)을 오른쪽으로 옮기고 가로로 줄이는 값.
  /// 코·입·부리는 머리 오른쪽 밖으로 살짝 나온 옆 주둥이에 따로 그린다.
  static const double turnShift = 28, turnSquash = .66;

  /// 주둥이가 머리 밖으로 길게 나오는 공룡은 눈이 주둥이에 가리지 않게 덜 돌린다
  static const double dinoTurnShift = 22, dinoTurnSquash = .76;

  /// 옆을 볼 때 귀·뿔·볏은 뒤쪽(왼쪽)으로 옮긴다 (얼굴과 반대쪽)
  static const double earShift = -10, earSquash = .86;

  /// 옆을 볼 때 모자는 얼굴 쪽으로 아주 조금만
  static const double hatShift = 6, hatSquash = .96;

  double get _faceShift => _sideSnout ? dinoTurnShift : turnShift;
  double get _faceSquash => _sideSnout ? dinoTurnSquash : turnSquash;

  /// 옆얼굴에서 코(콧구멍·부리 끝)가 놓이는 곳 (캐릭터 좌표). 정면이면 얼굴 가운데.
  static Offset noseAt(Zodiac z, {bool sideways = false}) {
    if (!sideways) return const Offset(100, 110);
    if (_sideSnouts.contains(z)) {
      final (top, bottom, tip) = _dinoSnout(z);
      return Offset(tip - 8, top + (bottom - top) * .26);
    }
    return switch (z) {
      Zodiac.rooster => const Offset(184, 114),
      Zodiac.pteranodon => const Offset(196, 116),
      _ => () {
        final s = _profileSpec(z);
        return Offset(s.tip - 4, s.cy - s.h * .18);
      }(),
    };
  }

  /// 옆을 볼 때 귀·뿔이 옮겨 가는 x (캐릭터 좌표)
  static double earX(double x, {bool sideways = false}) =>
      sideways ? 100 + earShift + (x - 100) * earSquash : x;

  /// 얼굴을 돌리는 공통 변환: x' = 100 + shift + (x - 100) * squash
  static void turnFace(
    Canvas c, {
    double shift = turnShift,
    double squash = turnSquash,
  }) {
    c.translate(100 + shift, 0);
    c.scale(squash, 1);
    c.translate(-100, 0);
  }

  /// 탈것에 탈 때는 팔다리를 탈것 그림에서 따로 그린다 (손잡이 잡기·페달 밟기)
  final bool drawLegs;
  final bool drawArms;

  final Zodiac zodiac;
  final Map<ItemSlot, Item> items;
  final CharMood mood;

  /// 0~1 값 (꼬리 흔들기, 눈 깜빡임)
  final double phase;

  static const Size design = Size(200, 240);

  /// 외곽선 색 (아이템·탈것 그림도 같은 색을 쓴다)
  static const Color ink = Color(0xFF4A3A31);
  static const double lineWidth = 3.8;

  /// 뿔·발톱·이빨 같은 상아색
  static const Color ivory = Color(0xFFFFF4DC);

  /// 눈·코·입처럼 얼굴에 긋는 작은 선과 점의 색 (외곽선이 아니다)
  static const Color feature = Color(0xFF4A3A33);

  /// 호랑이 줄무늬 (진한 주황 면)
  static const Color _tigerStripe = Color(0xFFE88A3C);

  /// 양 끝이 뾰족하고 가운데가 도톰한 줄무늬 한 가닥 ([a]에서 [b]로, 가장 두꺼운 곳 [w])
  static Path _stripe(Offset a, Offset b, double w) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance * w / 2;
    final mid = (a + b) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx + n.dx * 2, mid.dy + n.dy * 2, b.dx, b.dy)
      ..quadraticBezierTo(mid.dx - n.dx * 2, mid.dy - n.dy * 2, a.dx, a.dy)
      ..close();
  }

  /// 몸통 (서양배 모양: 어깨는 좁고 아래는 둥글게, 목은 머리 아래에 숨는다).
  /// 옷 그림도 이 모양을 그대로 쓴다.
  static Path get torsoPath => debugBodyVariant == 0 ? _torso0 : variantTorso();

  static final Path _torso0 = Path()
    ..moveTo(100, 136)
    ..cubicTo(118, 136, 130, 146, 133, 166)
    ..cubicTo(136, 184, 136, 200, 128, 210)
    ..cubicTo(120, 219, 80, 219, 72, 210)
    ..cubicTo(64, 200, 64, 184, 67, 166)
    ..cubicTo(70, 146, 82, 136, 100, 136)
    ..close();

  /// 몸통 + 짧고 둥근 다리 두 개를 한 줄로 그린 실루엣.
  /// 몸통 아랫부분이 둥글게 좁아지며 다리로 이어지고, 가랑이는 둥근 U 홈이다 (가로 이음매 없음).
  static final Path bodyPath = Path()
    ..moveTo(100, 136)
    ..cubicTo(118, 136, 130, 146, 133, 166)
    ..cubicTo(136, 184, 136, 199, 129, 209)
    ..cubicTo(126.5, 213, 127, 219, 126.5, 224)
    ..cubicTo(126, 231, 103.5, 231, 103, 224)
    ..cubicTo(103, 217, 102.5, 211, 100, 211)
    ..cubicTo(97.5, 211, 97, 217, 97, 224)
    ..cubicTo(96.5, 231, 74, 231, 73.5, 224)
    ..cubicTo(73, 219, 73.5, 213, 71, 209)
    ..cubicTo(64, 199, 64, 184, 67, 166)
    ..cubicTo(70, 146, 82, 136, 100, 136)
    ..close();

  /// 다리 가운데 x (발·신발 자리)
  static const double legLeft = 85.5, legRight = 114.5;

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

  /// 면 칠하기. 2026-10-22부터 외곽선 없는 납작한(flat) 그림이라 [width]는 쓰지 않는다
  /// (예전 호출부와 맞추려고 남겨 둔다).
  static void fillStroke(
    Canvas c,
    Path p,
    Color fill, {
    double width = lineWidth,
  }) {
    c.drawPath(p, Paint()..color = fill);
  }

  /// 아주 밝은 털(흰 토끼·소·닭·양)은 흰 바탕에서 사라지지 않게
  /// 실루엣 바깥에만 같은 색 계열의 아주 연한 선을 깐다. 나머지 친구는 선이 없다.
  static Color? rimOf(Color fur) => fur.computeLuminance() > .8
      ? Color.lerp(fur, const Color(0xFF9A7A68), .2)
      : null;

  /// 부위를 나누는 한 톤 진한 색 (외곽선 대신 쓰는 납작한 음영).
  /// 흰 친구(토끼·소·닭·양)는 누런 갈색 대신 연회색 쪽으로 어둡게 한다.
  static Color tone(Color c, double t) => c.computeLuminance() > .8
      ? Color.lerp(c, const Color(0xFF8E96A3), t * 1.6)!
      : Color.lerp(c, const Color(0xFF3A2A22), t)!;

  /// 팔·소매가 몸 앞에 올 때 아래·안쪽에 까는 아주 연한 그림자 (어떤 옷 색 위에도 쓴다)
  static const Color softShadow = Color(0x1F3A2A22);

  /// 연한 테두리 그리는 중이면 그 색 ([_fs]가 면 대신 테두리를 그린다)
  Color? _rim;

  /// 팔 자세: 평소에는 몸 옆으로 살짝 벌리고, 기쁠 때는 만세
  static (Offset, double) armPose(bool left, bool happy) {
    if (happy) {
      return left
          ? (const Offset(60, 146), 0.9)
          : (const Offset(140, 146), -0.9);
    }
    return left
        ? (const Offset(74, 170), 0.36)
        : (const Offset(126, 170), -0.36);
  }

  /// 팔 모양 (어깨 쪽이 굵고 손끝으로 갈수록 살짝 가늘어지는 둥근 소시지).
  /// [armPose] 자리에서 위(어깨) 끝은 몸통 안에 파묻히고 아래(손) 끝만 몸 옆으로 나온다.
  static Path armShape([double scale = 1]) {
    final r1 = 9 * scale, r2 = 7.5 * scale;
    final top = -17 * scale, bottom = 15 * scale;
    return Path()
      ..moveTo(-r1, top)
      ..cubicTo(
        -r1,
        top + 12 * scale,
        -r2 - .6 * scale,
        bottom - 8 * scale,
        -r2,
        bottom,
      )
      ..arcToPoint(
        Offset(r2, bottom),
        radius: Radius.circular(r2),
        clockwise: false,
      )
      ..cubicTo(
        r2 + .6 * scale,
        bottom - 8 * scale,
        r1,
        top + 12 * scale,
        r1,
        top,
      )
      ..arcToPoint(
        Offset(-r1, top),
        radius: Radius.circular(r1),
        clockwise: false,
      )
      ..close();
  }

  ZodiacLook get look => zodiac.look;
  Color get fur => look.fur;
  bool get _dino => zodiac.isDino;
  bool get _hatOn => items[ItemSlot.head] != null;

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

  /// 주둥이 종류
  Snout get snout => snoutOf(zodiac);

  static Snout snoutOf(Zodiac z) => switch (z) {
    Zodiac.ox || Zodiac.horse || Zodiac.pig || Zodiac.dragon => Snout.muzzle,
    Zodiac.rooster || Zodiac.pteranodon => Snout.beak,
    Zodiac.snake => Snout.snake,
    Zodiac.trex || Zodiac.spinosaurus => Snout.jaw,
    Zodiac.triceratops ||
    Zodiac.stegosaurus ||
    Zodiac.ankylosaurus ||
    Zodiac.iguanodon ||
    Zodiac.pachycephalosaurus => Snout.dinoBeak,
    Zodiac.parasaurolophus => Snout.duck,
    Zodiac.velociraptor || Zodiac.dilophosaurus => Snout.pointy,
    Zodiac.brachiosaurus => Snout.gentle,
    _ => Snout.cat,
  };

  /// 옆을 볼 때 주둥이가 머리 밖으로 길게 나오는 공룡
  static const Set<Zodiac> _sideSnouts = {
    Zodiac.trex,
    Zodiac.spinosaurus,
    Zodiac.velociraptor,
    Zodiac.parasaurolophus,
    Zodiac.dilophosaurus,
    Zodiac.iguanodon,
    Zodiac.brachiosaurus,
    Zodiac.stegosaurus,
  };
  bool get _sideSnout => sideways && _sideSnouts.contains(zodiac);

  /// 합치기(Path.combine)는 계산이 무거워서 한 번 만든 모양은 기억해 둔다 (발열 줄이기)
  static final Map<String, Path> _pathCache = {};
  static Path _cached(String key, Path Function() build) =>
      _pathCache[key] ??= build();

  void _fs(Canvas c, Path p, Color fill, {double w = lineWidth}) {
    final rim = _rim;
    if (rim != null) {
      c.drawPath(p, stroke(5, rim));
    } else {
      c.drawPath(p, Paint()..color = fill);
    }
  }

  static Color _shade(Color c, [double t = .12]) =>
      Color.lerp(c, const Color(0xFF3A2A22), t)!;
  static Color _tint(Color c, [double t = .4]) =>
      Color.lerp(c, Colors.white, t)!;

  /// 뒤로 뻗는 장식은 옆을 볼 때 등 쪽(왼쪽)으로 뒤집는다
  void _backward(Canvas c, void Function() draw) {
    if (!sideways) return draw();
    c.save();
    c.translate(200, 0);
    c.scale(-1, 1);
    draw();
    c.restore();
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

    final legsOn = drawLegs && items[ItemSlot.shoes] == null && !_noLegs;
    final rim = rimOf(zodiac == Zodiac.sheep ? look.light : fur);
    if (rim != null) _rimPass(canvas, rim, happy, legsOn);

    _backDecor(canvas);
    _backward(canvas, () => _tail(canvas));
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
    if (_variantOn && debugBodyVariant == 2 && drawArms) _variantHands(canvas);
    final shoes = items[ItemSlot.shoes];
    if (shoes != null && drawLegs) art.shoes(shoes);
    if (back != null) art.backFront(back);

    final acc = items[ItemSlot.accessory];
    if (acc != null && acc.isNecklace) art.accessory(acc);

    if (sideways) {
      canvas.save();
      turnFace(canvas, shift: earShift, squash: earSquash);
      _earsBehind(canvas);
      canvas.restore();
      _head(canvas);
      // 얼굴은 머리 안에서만 돌린다 (머리 밖으로 삐져나가지 않게)
      final head = _headShape;
      canvas.save();
      canvas.clipPath(head);
      turnFace(canvas, shift: _faceShift, squash: _faceSquash);
      _headDetails(canvas);
      _face(canvas, happy);
      canvas.restore();
      if (_sideSnout) {
        _profileSnout(canvas, happy);
      } else {
        _profileFace(canvas, happy);
      }
      canvas.save();
      turnFace(canvas, shift: earShift, squash: earSquash);
      _headTop(canvas);
      _earsFront(canvas);
      canvas.restore();
      if (acc != null && !acc.isNecklace) {
        canvas.save();
        turnFace(canvas, shift: _faceShift, squash: _faceSquash);
        art.accessory(acc);
        canvas.restore();
      }
    } else {
      _earsBehind(canvas);
      _head(canvas);
      _headDetails(canvas);
      _face(canvas, happy);
      _headTop(canvas);
      _earsFront(canvas);
      if (acc != null && !acc.isNecklace) art.accessory(acc);
    }
    final head = items[ItemSlot.head];
    if (head != null) {
      // 옆을 볼 때 모자도 얼굴 쪽으로 아주 조금 돌린다 (머리 전체는 계속 덮도록 살짝만)
      canvas.save();
      if (sideways) turnFace(canvas, shift: hatShift, squash: hatSquash);
      art.head(head);
      canvas.restore();
    }

    canvas.restore();
  }

  /// 밝은 친구의 연한 테두리. 실루엣(몸·머리·귀·꼬리) 바깥에만 보이도록
  /// 모든 면보다 먼저 굵게 깔고, 그 위를 면이 덮는다 (안쪽 이음새에는 선이 남지 않는다).
  void _rimPass(Canvas c, Color rim, bool happy, bool legsOn) {
    _rim = rim;
    final p = stroke(5, rim);
    _backward(c, () => _tail(c));
    if (zodiac == Zodiac.sheep) {
      c.drawPath(_cloud(const Offset(100, 176), 40, 9), p);
      if (legsOn) {
        for (final x in [86.0, 114.0]) {
          c.drawPath(_footShape(x), p);
        }
      }
      if (drawArms) _arms(c, happy);
    } else {
      c.drawPath(
        _silhouette(
          happy,
          feet: legsOn && !_wings,
          arms: drawArms && !_wings && !_noLegs,
        ),
        p,
      );
      if (_wings) _arms(c, happy);
    }
    c.save();
    if (sideways) turnFace(c, shift: earShift, squash: earSquash);
    _earsBehind(c);
    if (!sideways) _earsFront(c);
    c.restore();
    _head(c);
    final bump = sideways && !_sideSnout ? _profileBump(zodiac) : null;
    if (bump != null) c.drawPath(bump, p);
    _rim = null;
  }

  Offset _m(double m, double dx, double y) => Offset(100 + m * dx, y);

  /// 끝이 둥근 가시·판 하나 (밑변 가운데 0,0 에서 위로 [h])
  static Path _spike(double w, double h, {double round = .3}) => Path()
    ..moveTo(-w / 2, 0)
    ..quadraticBezierTo(-w * round, -h * .6, 0, -h)
    ..quadraticBezierTo(w * round, -h * .6, w / 2, 0)
    ..close();

  void _at(Canvas c, Offset o, double rot, void Function() draw) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    draw();
    c.restore();
  }

  // ================= 등판 (공룡) =================
  void _backDecor(Canvas c) {
    switch (zodiac) {
      case Zodiac.stegosaurus:
        // 등줄기를 따라 솟은 각진 골판: 머리 위로 한 줄, 어깨 옆으로 작게 (꽃처럼 둥글게 두르지 않는다)
        for (final (o, rot, h, alt) in const [
          (Offset(42, 76), -1.0, 30.0, true),
          (Offset(158, 76), 1.0, 30.0, true),
          (Offset(62, 50), -.55, 36.0, false),
          (Offset(138, 50), .55, 36.0, false),
          (Offset(100, 42), 0.0, 40.0, true),
        ]) {
          _at(c, o, rot, () {
            final plate = Path()
              ..moveTo(-h * .36, 10)
              ..lineTo(-h * .62, -h * .4)
              ..lineTo(0, -h)
              ..lineTo(h * .62, -h * .4)
              ..lineTo(h * .36, 10)
              ..close();
            final color = alt ? const Color(0xFFFFA24C) : look.accent;
            _fs(c, plate, color);
          });
        }
      case Zodiac.spinosaurus:
        // 등에 펼쳐진 커다란 돛 (위가 물결치고 뼈가 보이는)
        final sail = _cached('spino-sail', () {
          final p = Path()..moveTo(58, 176);
          p.cubicTo(18, 140, 14, 70, 34, 40);
          const bumps = 6;
          var prev = const Offset(34, 40);
          for (var i = 1; i <= bumps; i++) {
            final t = i / bumps;
            final a = pi * (1.18 + t * .64);
            final next = Offset(100 + cos(a) * 88, 120 + sin(a) * 112);
            final mid = (prev + next) / 2;
            final out = (mid - const Offset(100, 120));
            final ctl = mid + out / out.distance * 16;
            p.quadraticBezierTo(ctl.dx, ctl.dy, next.dx, next.dy);
            prev = next;
          }
          p.cubicTo(186, 70, 182, 140, 142, 176);
          p.close();
          return p;
        });
        c.drawPath(sail, Paint()..color = look.accent);
        c.save();
        c.clipPath(sail);
        // 돛의 뼈: 밝은 줄 몇 개만 (그늘 없이)
        for (var i = 0; i < 5; i++) {
          final a = pi * (1.18 + i * .16);
          c.drawLine(
            const Offset(100, 176),
            const Offset(100, 176) + Offset(cos(a), sin(a)) * 180,
            stroke(3.2, _tint(look.accent, .35)),
          );
        }
        c.restore();
      case Zodiac.ankylosaurus:
        // 몸 뒤로 넓게 보이는 등딱지 갑옷 + 옆으로 뻗은 가시
        for (final m in [-1.0, 1.0]) {
          for (final (y, len) in const [(150.0, 18.0), (172.0, 20.0)]) {
            _at(c, Offset(100 + m * 48, y), m * pi / 2 + m * .1, () {
              _fs(c, _spike(16, len), ivory, w: 3);
            });
          }
        }
        final shell = Path()
          ..addRRect(
            RRect.fromLTRBR(46, 138, 154, 200, const Radius.circular(34)),
          );
        c.drawPath(shell, Paint()..color = look.accent);
        c.save();
        c.clipPath(shell);
        for (var row = 0; row < 3; row++) {
          for (var i = 0; i < 6; i++) {
            final o = Offset(
              52.0 + i * 20 + (row.isOdd ? 10 : 0),
              148.0 + row * 18,
            );
            c.drawCircle(o, 6, Paint()..color = _shade(look.accent, .14));
          }
        }
        c.restore();
      default:
        break;
    }
  }

  // ================= 꼬리 =================
  void _tail(Canvas c) {
    final sway = sin(phase * 2 * pi) * 5;
    if (_dino && zodiac != Zodiac.pteranodon) {
      _dinoTail(c, sway);
      return;
    }
    switch (zodiac) {
      case Zodiac.pteranodon:
        break;
      case Zodiac.rat:
        final p = Path()
          ..moveTo(128, 200)
          ..cubicTo(156, 206, 168, 196, 166 + sway, 182);
        c.drawPath(p, stroke(5.5, const Color(0xFFF2B8C6)));
      case Zodiac.ox:
        final p = Path()
          ..moveTo(128, 196)
          ..quadraticBezierTo(152, 198, 154 + sway, 182);
        c.drawPath(p, stroke(5.5, fur));
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
        c.drawPath(p, stroke(13.5, fur));
        if (zodiac == Zodiac.tiger) {
          c.drawLine(
            Offset(148 + sway * .5, 194),
            Offset(156 + sway * .5, 190),
            stroke(3.6, _tigerStripe),
          );
          c.drawLine(
            Offset(152 + sway * .8, 182),
            Offset(161 + sway * .8, 182),
            stroke(3.6, _tigerStripe),
          );
        } else {
          c.drawCircle(Offset(156 + sway, 174), 4, Paint()..color = look.light);
        }
      case Zodiac.rabbit:
        _fs(c, _cloud(Offset(134 + sway * .2, 200), 12, 6), Colors.white, w: 3);
      case Zodiac.dragon:
        // 굽이치는 긴 꼬리 + 끝의 불꽃 털
        final p = Path()
          ..moveTo(124, 204)
          ..cubicTo(156, 214, 168, 196, 158 + sway, 182)
          ..cubicTo(150, 170, 170, 160, 178 + sway, 168);
        c.drawPath(p, stroke(13.5, fur));
        for (final (o, a) in [
          (Offset(178 + sway, 168), -.5),
          (Offset(178 + sway, 168), .3),
          (Offset(176 + sway, 168), -1.3),
        ]) {
          _at(c, o, a, () => _fs(c, _spike(12, 20), look.accent, w: 3));
        }
        // 등줄 가시
        for (final (o, a) in const [
          (Offset(146, 208), -.3),
          (Offset(162, 196), -1.2),
        ]) {
          _at(c, o, a, () => _fs(c, _spike(9, 10), look.accent, w: 2.6));
        }
      case Zodiac.snake:
        // 똬리 두 겹 + 위로 말린 꼬리 끝
        final tailTip = Path()
          ..moveTo(150, 214)
          ..cubicTo(178, 206, 182, 186, 170 + sway * .5, 176);
        c.drawPath(tailTip, stroke(13.5, fur));
        final body = Path()
          ..moveTo(84, 196)
          ..cubicTo(52, 196, 36, 214, 50, 226)
          ..cubicTo(64, 238, 150, 236, 162, 222)
          ..cubicTo(172, 210, 160, 200, 140, 202);
        c.drawPath(body, stroke(27.5, fur));
        // 등 무늬 (마름모)
        for (final o in const [
          Offset(52, 216),
          Offset(78, 230),
          Offset(110, 231),
          Offset(142, 228),
          Offset(162, 214),
        ]) {
          _diamond(c, o, 7, look.accent);
        }
      case Zodiac.horse:
        final p = Path()
          ..moveTo(128, 186)
          ..cubicTo(156, 182, 162 + sway, 210, 150 + sway, 220)
          ..cubicTo(146, 206, 138, 198, 128, 198)
          ..close();
        _fs(c, p, look.accent, w: 3);
      case Zodiac.sheep:
        _fs(c, _cloud(Offset(134 + sway * .2, 196), 11, 6), look.light, w: 3);
      case Zodiac.monkey:
        final p = Path()
          ..moveTo(128, 200)
          ..cubicTo(160, 204, 168, 176, 156 + sway, 168)
          ..cubicTo(148 + sway, 164, 146, 176, 154 + sway, 178);
        c.drawPath(p, stroke(7.5, fur));
      case Zodiac.rooster:
        // 크게 휘어 올라간 꽁지깃 (짙은 초록·파랑 + 주황)
        for (final (a, len, color) in const [
          (-1.35, 56.0, Color(0xFF2F7F6A)),
          (-.95, 62.0, Color(0xFF3F6FC4)),
          (-.55, 56.0, Color(0xFF2F7F6A)),
          (-.15, 44.0, Color(0xFFF08A3C)),
        ]) {
          c.save();
          c.translate(126, 184);
          c.rotate(a + sway * .01);
          final f = Path()
            ..moveTo(0, -5)
            ..cubicTo(len * .4, -14, len * .8, -10, len, 2)
            ..cubicTo(len * .7, 6, len * .3, 8, 0, 5)
            ..close();
          _fs(c, f, color, w: 3);
          c.restore();
        }
      case Zodiac.pig:
        final p = Path()
          ..moveTo(128, 196)
          ..cubicTo(146, 196, 150 + sway * .4, 182, 142, 180)
          ..cubicTo(134, 178, 138, 192, 150 + sway * .3, 188);
        c.drawPath(p, stroke(4, _shade(fur, .12)));
      default:
        break;
    }
  }

  void _diamond(Canvas c, Offset o, double r, Color color) {
    final d = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * .8, o.dy)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * .8, o.dy)
      ..close();
    c.drawPath(d, Paint()..color = color);
  }

  /// 공룡 꼬리: 굵게 뻗었다가 가늘어진다. 끝 장식이 종마다 다르다.
  void _dinoTail(Canvas c, double sway) {
    final long = zodiac == Zodiac.brachiosaurus;
    final up = zodiac == Zodiac.brachiosaurus || zodiac == Zodiac.velociraptor;
    final tip = long
        ? Offset(194 + sway * .6, 150 - sway * .3)
        : up
        ? Offset(190 + sway * .6, 180 - sway * .3)
        : Offset(186 + sway * .6, 214 - sway * .3);
    final thick = zodiac == Zodiac.trex || zodiac == Zodiac.spinosaurus;
    final tail = Path()
      ..moveTo(122, thick ? 162 : 168)
      ..cubicTo(
        150,
        long ? 176 : 172,
        long ? 176 : 170,
        long ? 170 : (up ? 174 : 188),
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        long ? 182 : 166,
        long ? 180 : (up ? 196 : 216),
        146,
        212,
        124,
        206,
      )
      ..close();

    if (zodiac == Zodiac.spinosaurus) {
      // 노 같은 꼬리 지느러미
      final fin = Path()
        ..moveTo(136, 170)
        ..quadraticBezierTo(160, 150, 182 + sway * .6, 196)
        ..lineTo(160, 190)
        ..close();
      _fs(c, fin, look.accent, w: 3);
    }
    if (zodiac == Zodiac.stegosaurus) {
      // 꼬리 가시 4개 (두 쌍)
      for (final (d, a, l) in const [
        (Offset(-8, -8), -1.1, 26.0),
        (Offset(-6, -2), -.3, 24.0),
        (Offset(-22, -12), -1.3, 22.0),
        (Offset(-20, -6), -.5, 20.0),
      ]) {
        _at(c, tip + d, a, () => _fs(c, _spike(9, l, round: .15), ivory, w: 3));
      }
    }
    if (zodiac == Zodiac.velociraptor) {
      // 꼬리 끝 깃털 부채
      for (final a in [-1.3, -.8, -.3, .2]) {
        _at(c, tip + const Offset(-4, 2), a + pi / 2 - .4, () {
          final f = Path()
            ..moveTo(-6, 0)
            ..quadraticBezierTo(-8, -18, 0, -26)
            ..quadraticBezierTo(8, -18, 6, 0)
            ..close();
          _fs(c, f, look.accent, w: 2.8);
        });
      }
    }
    _fs(c, tail, fur);
    c.save();
    c.clipPath(tail);
    switch (zodiac) {
      case Zodiac.trex:
      case Zodiac.iguanodon:
      case Zodiac.parasaurolophus:
        for (final t in [.3, .52, .74]) {
          final x = 124 + (tip.dx - 124) * t;
          final y = 168 + (tip.dy - 168) * t;
          c.drawLine(
            Offset(x - 3, y - 12),
            Offset(x + 3, y + 2),
            stroke(4, _shade(fur, .22)),
          );
        }
      case Zodiac.dilophosaurus:
      case Zodiac.brachiosaurus:
      case Zodiac.pachycephalosaurus:
        for (final t in [.3, .55, .78]) {
          final o = Offset(
            124 + (tip.dx - 124) * t,
            170 + (tip.dy - 170) * t - 2,
          );
          c.drawCircle(o, 4.2 - t * 1.6, Paint()..color = _shade(fur, .2));
        }
      default:
        break;
    }
    c.restore();
    if (zodiac == Zodiac.ankylosaurus) {
      // 꼬리 곤봉: 양쪽으로 불룩한 뼈 덩어리
      final club = _cached('anky-club', () {
        var p = Path()
          ..addOval(
            Rect.fromCenter(center: Offset.zero, width: 22, height: 26),
          );
        for (final m in [-1.0, 1.0]) {
          p = Path.combine(
            PathOperation.union,
            p,
            Path()..addOval(
              Rect.fromCenter(center: Offset(m * 11, 2), width: 22, height: 22),
            ),
          );
        }
        return p;
      });
      _at(c, tip + const Offset(-4, -4), -.5, () {
        _fs(c, club, look.accent);
        for (final o in const [
          Offset(-10, -2),
          Offset(10, -2),
          Offset(0, -8),
        ]) {
          c.drawCircle(o, 3, Paint()..color = _shade(look.accent, .25));
        }
      });
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
      if (_wings) {
        final leg = Path()
          ..moveTo(x, 206)
          ..lineTo(x, 222)
          ..moveTo(x - 8, 227)
          ..lineTo(x, 222)
          ..lineTo(x + 8, 227)
          ..moveTo(x, 222)
          ..lineTo(x, 228);
        c.drawPath(
          leg,
          stroke(
            5,
            zodiac == Zodiac.pteranodon
                ? _shade(fur, .1)
                : const Color(0xFFFFC94D),
          ),
        );
        continue;
      }
      // 양: 털 몸 아래로 나온 짧고 둥근 다리 + 발굽
      final foot = _cached(
        'sheep-leg|$x',
        () => Path.combine(
          PathOperation.union,
          Path.combine(
            PathOperation.intersect,
            bodyPath,
            Path()..addRect(
              Rect.fromLTRB(x < 100 ? 0 : 100, 196, x < 100 ? 100 : 200, 240),
            ),
          ),
          _footShape(x),
        ),
      );
      _fs(c, foot, tone(look.accent, .1));
      c.save();
      c.clipPath(foot);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 233), width: 36, height: 16),
        Paint()..color = const Color(0xFF8A817C),
      );
      c.restore();
    }
  }

  // ================= 몸 =================
  void _body(Canvas c) {
    // 양: 구름 털 몸
    final wool = _cloud(const Offset(100, 176), 40, 9);
    if (_rim != null) return _fs(c, wool, look.light);
    // 구름 털 몸: 오른쪽·아래 가장자리 음영 + 턱 그림자
    c.drawPath(wool, Paint()..color = tone(look.light, .07));
    c.save();
    c.clipPath(wool);
    c.drawPath(wool.shift(const Offset(-5, -5)), Paint()..color = look.light);
    c.drawOval(
      Rect.fromCenter(center: const Offset(100, 145), width: 76, height: 18),
      Paint()..color = tone(look.light, .07),
    );
    c.restore();
  }

  /// 몸통 안쪽 무늬 (몸통 모양으로 잘라서 그린다)
  void _bodyMarks(Canvas c) {
    final body = torsoPath;
    c.save();
    c.clipPath(body);
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
        for (final y in [160.0, 180.0]) {
          for (final m in [-1.0, 1.0]) {
            c.drawPath(
              _stripe(_m(m, 36, y), _m(m, 24, y - 2), 7),
              Paint()..color = _tigerStripe,
            );
          }
        }
      case Zodiac.dragon:
      case Zodiac.snake:
        // 가로 비늘 줄이 있는 배
        final plate = RRect.fromLTRBR(
          82,
          146,
          118,
          214,
          const Radius.circular(14),
        );
        c.drawRRect(plate, Paint()..color = look.light);
        for (var y = 160.0; y < 212; y += 12) {
          c.drawLine(
            Offset(84, y),
            Offset(116, y),
            stroke(2.4, _shade(look.light, .22)),
          );
        }
        if (zodiac == Zodiac.snake) {
          for (final o in const [
            Offset(70, 160),
            Offset(130, 160),
            Offset(72, 190),
            Offset(128, 190),
          ]) {
            _diamond(c, o, 7, look.accent);
          }
        }
      case Zodiac.rabbit:
      case Zodiac.rooster:
        break;
      case Zodiac.ankylosaurus:
        c.drawOval(belly, Paint()..color = look.light);
        for (final y in [174.0, 186.0, 198.0]) {
          c.drawLine(
            Offset(84, y),
            Offset(116, y),
            stroke(2, _shade(look.light, .12)),
          );
        }
        // 어깨를 덮는 갑옷 띠
        final band = Path()
          ..moveTo(62, 160)
          ..cubicTo(70, 136, 130, 136, 138, 160)
          ..cubicTo(120, 150, 80, 150, 62, 160)
          ..close();
        c.drawPath(band, Paint()..color = look.accent);
        for (final x in [80.0, 100.0, 120.0]) {
          c.drawCircle(
            Offset(x, 148),
            4,
            Paint()..color = _shade(look.accent, .2),
          );
        }
      case Zodiac.velociraptor:
        c.drawOval(belly, Paint()..color = look.light);
        // 가슴 깃털 (V 모양)
        for (final y in [152.0, 162.0]) {
          final v = Path()
            ..moveTo(84, y)
            ..lineTo(100, y + 8)
            ..lineTo(116, y);
          c.drawPath(v, stroke(2.6, _shade(look.light, .18)));
        }
      case Zodiac.dilophosaurus:
      case Zodiac.brachiosaurus:
        c.drawOval(belly, Paint()..color = look.light);
        for (final o in const [
          Offset(72, 158),
          Offset(128, 160),
          Offset(70, 182),
          Offset(130, 186),
        ]) {
          c.drawCircle(o, 4.6, Paint()..color = _shade(fur, .2));
        }
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

  /// 발 모양: 다리 끝의 둥근 콩 (바깥쪽으로 살짝 길다)
  static Path _footShape(double x) {
    final m = x < 100 ? -1.0 : 1.0;
    final cx = (x < 100 ? legLeft : legRight) + m * 1.5;
    return Path()..addOval(
      Rect.fromCenter(center: Offset(cx, 225.5), width: 28, height: 14),
    );
  }

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
    return armShape(small ? .66 : 1).transform(m);
  }

  // ================= 몸 틀 시안 (미리보기 비교용) =================
  /// 0: 지금 몸 틀, 1: A안(옆구리 작은 혹 팔), 2: B안(팔을 앞으로 모으고 손끝만 살짝),
  /// 3: C안(몸에서 끊김 없이 이어져 살짝 벌어진 짧은 팔). 미리보기에서만 바꾼다.
  static int debugBodyVariant = 0;

  /// 오른쪽 반쪽 곡선 (각 [c1, c2, 끝점])을 왼쪽으로 뒤집어 붙인 좌우 대칭 실루엣
  static Path _mirrored(List<List<Offset>> right) {
    const start = Offset(100, 134);
    Offset m(Offset o) => Offset(200 - o.dx, o.dy);
    final p = Path()..moveTo(start.dx, start.dy);
    for (final s in right) {
      p.cubicTo(s[0].dx, s[0].dy, s[1].dx, s[1].dy, s[2].dx, s[2].dy);
    }
    for (var i = right.length - 1; i >= 0; i--) {
      final from = i == 0 ? start : right[i - 1][2];
      final a = m(right[i][1]), b = m(right[i][0]), e = m(from);
      p.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }
    return p..close();
  }

  static const _shoulder = [
    [Offset(116, 134), Offset(128, 137), Offset(129, 148)],
  ];
  static const _sideC = [
    [Offset(116, 134), Offset(127, 137), Offset(130, 146)],
  ];
  static const _legs2 = [
    [Offset(130.5, 224), Offset(128, 231), Offset(116, 231)],
    [Offset(106, 231), Offset(103.5, 227), Offset(103.5, 222)],
    [Offset(103.5, 218), Offset(101.5, 216.5), Offset(100, 216.5)],
  ];
  static const _closed = [
    [Offset(128, 222), Offset(112, 224), Offset(100, 224)],
  ];

  static List<List<Offset>> _variantArmCurves(int v) => switch (v) {
    1 => const [
      [Offset(134, 154), Offset(138, 170), Offset(137, 186)],
      [Offset(136, 195), Offset(129, 197), Offset(128.5, 191)],
      [Offset(129.5, 198), Offset(130.5, 205), Offset(130, 212)],
    ],
    2 => const [
      [Offset(132, 156), Offset(134, 172), Offset(133, 184)],
      [Offset(132.5, 190), Offset(130, 191), Offset(130, 193)],
      [Offset(130.5, 200), Offset(130.5, 206), Offset(130, 212)],
    ],
    _ => const [
      [Offset(137, 156), Offset(143, 176), Offset(145, 192)],
      [Offset(146, 201), Offset(137, 203), Offset(135, 195)],
      [Offset(134, 186), Offset(133, 177), Offset(131, 170)],
      [Offset(131, 186), Offset(131, 202), Offset(130, 212)],
    ],
  };

  static final Map<String, Path> _variantCache = {};

  /// 시안 몸통 (팔·다리 없이, 옷이 이 모양을 채운다)
  static Path variantTorso() =>
      _variantCache['torso$debugBodyVariant'] ??= _mirrored([
        ...(debugBodyVariant == 3 ? _sideC : _shoulder),
        [
          const Offset(131, 165),
          const Offset(132, 195),
          const Offset(130, 212),
        ],
        ..._closed,
      ]);

  /// 시안 실루엣: 팔·몸·다리를 path 하나로
  static Path variantSil({required bool feet, required bool arms}) {
    final v = debugBodyVariant;
    return _variantCache['sil$v|$feet|$arms'] ??= _mirrored([
      ...(v == 3 ? _sideC : _shoulder),
      ...(arms
          ? _variantArmCurves(v)
          : [
              [
                const Offset(131, 165),
                const Offset(132, 195),
                const Offset(130, 212),
              ],
            ]),
      ...(feet ? _legs2 : _closed),
    ]);
  }

  /// 시안 팔 부분 (소매 칠하기용): 실루엣에서 몸통을 뺀 곳
  static Path variantArms() =>
      _variantCache['arms$debugBodyVariant'] ??= Path.combine(
        PathOperation.difference,
        variantSil(feet: false, arms: true),
        variantTorso(),
      );

  /// 시안 소매가 끝나는 높이 (그 아래는 손)
  static double get variantCuffY => switch (debugBodyVariant) {
    1 => 184,
    3 => 187,
    _ => 240,
  };

  /// B안: 몸 앞에 모은 손끝 (아주 연한 같은 계열 색)
  void _variantHands(Canvas c) {
    for (final x in [82.0, 118.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 192), width: 17, height: 13),
        Paint()..color = tone(fur, .06),
      );
    }
  }

  bool get _variantOn =>
      debugBodyVariant != 0 && !_wings && !_noLegs && zodiac != Zodiac.sheep;

  void _variantBody(Canvas c, {required bool feet, required bool arms}) {
    final sil = variantSil(feet: feet, arms: arms);
    c.drawPath(sil, Paint()..color = fur);
    _bodyMarks(c);
    if (!feet) return;
    for (final x in [84.5, 115.5]) {
      if (_hooves) {
        c.save();
        c.clipPath(sil);
        c.drawOval(
          Rect.fromCenter(center: Offset(x, 234), width: 34, height: 16),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
      } else if (_dino) {
        for (final dx in [-6.0, 6.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(x + dx, 229),
              width: 5.5,
              height: 4.5,
            ),
            Paint()..color = ivory,
          );
        }
      }
    }
  }

  /// 몸통 + 팔 + 발을 합친 하나의 Path (같은 색 면은 한 번에 칠한다)
  Path _silhouette(bool happy, {required bool feet, required bool arms}) =>
      _variantOn
      ? variantSil(feet: feet, arms: arms)
      : _cached('sil|${zodiac == Zodiac.trex}|$happy|$feet|$arms', () {
          var out = Path.from(feet ? bodyPath : torsoPath);
          for (final p in [
            if (feet) ...[_footShape(86), _footShape(114)],
            if (arms) ...[_armAt(true, happy), _armAt(false, happy)],
          ]) {
            out = Path.combine(PathOperation.union, out, p);
          }
          return out;
        });

  /// 몸통 + 팔 + 발을 하나로 합친 몸.
  /// 한 번에 칠하고 외곽선이 없어서 "도형을 붙인" 이음매가 보이지 않는다.
  void _softBody(
    Canvas c,
    bool happy, {
    required bool feet,
    required bool arms,
  }) {
    if (_variantOn) return _variantBody(c, feet: feet, arms: arms);
    final armPaths = arms
        ? [_armAt(true, happy), _armAt(false, happy)]
        : const <Path>[];
    final footPaths = feet ? [_footShape(86), _footShape(114)] : const <Path>[];

    // 팔 뒤로 붙는 깃털 (벨로시랩터)
    if (arms && zodiac == Zodiac.velociraptor) {
      for (final left in [true, false]) {
        final (center, rot) = armPose(left, happy);
        _at(c, center, rot, () {
          final m = left ? -1.0 : 1.0;
          for (final (y, l) in const [
            (-6.0, 18.0),
            (4.0, 20.0),
            (13.0, 16.0),
          ]) {
            final f = Path()
              ..moveTo(m * 4, y - 6)
              ..quadraticBezierTo(m * (l + 4), y - 4, m * (l + 2), y + 6)
              ..quadraticBezierTo(m * 10, y + 6, m * 4, y + 4)
              ..close();
            _fs(c, f, look.accent, w: 2.8);
          }
        });
      }
    }

    // 몸통·다리·발은 한 덩어리 (같은 색 면 하나). 외곽선 대신 아주 연한 음영으로만 입체감:
    // 오른쪽·아래 가장자리와 가랑이 안쪽에 얇은 그늘이 생긴다.
    final body = _cached(
      'body|$feet',
      () => feet
          ? Path.combine(
              PathOperation.union,
              bodyPath,
              Path.combine(PathOperation.union, footPaths[0], footPaths[1]),
            )
          : torsoPath,
    );
    c.drawPath(body, Paint()..color = tone(fur, .06));
    c.save();
    c.clipPath(body);
    c.drawPath(body.shift(const Offset(-4, -3)), Paint()..color = fur);
    c.restore();

    // 몸통 무늬 (배, 줄무늬 등)
    _bodyMarks(c);

    // 턱 그림자: 머리 바로 아래 몸통 위의 얇고 부드러운 반달
    c.save();
    c.clipPath(torsoPath);
    c.drawOval(
      Rect.fromCenter(center: const Offset(100, 146), width: 84, height: 20),
      Paint()..color = tone(fur, .09),
    );
    c.restore();

    // 팔: 몸과 같은 색. 몸 앞에 겹치는 안쪽 가장자리에만 얇은 그늘을 깔아 구분한다
    for (final (i, a) in armPaths.indexed) {
      final m = i == 0 ? -1.0 : 1.0;
      c.save();
      c.clipPath(torsoPath);
      c.drawPath(
        a.shift(Offset(-m * 2.6, 1.6)),
        Paint()..color = tone(fur, .11),
      );
      c.restore();
      c.drawPath(a, Paint()..color = fur);
    }

    // 발굽·발톱
    for (final f in footPaths) {
      final x = f.getBounds().center.dx;
      if (_hooves) {
        c.save();
        c.clipPath(f);
        c.drawOval(
          Rect.fromCenter(center: Offset(x, 233), width: 36, height: 16),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
      } else if (_dino) {
        for (final dx in [-6.0, 6.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(x + dx, 229),
              width: 5.5,
              height: 4.5,
            ),
            Paint()..color = ivory,
          );
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
        final arm = armShape();
        c.clipPath(arm);
        c.drawOval(
          Rect.fromCenter(center: const Offset(0, 21), width: 24, height: 18),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
      }
    }

    // 벨로시랩터: 발 안쪽의 커다란 갈고리 발톱
    if (feet && zodiac == Zodiac.velociraptor) {
      for (final m in [-1.0, 1.0]) {
        final x = 100 + m * 22;
        final claw = Path()
          ..moveTo(x - m * 4, 220)
          ..cubicTo(x, 204, x + m * 12, 200, x + m * 18, 206)
          ..cubicTo(x + m * 10, 206, x + m * 6, 212, x + m * 4, 224)
          ..close();
        _fs(c, claw, ivory, w: 3);
      }
    }

    // 팔 장식 (외곽선 위)
    if (arms) {
      for (final left in [true, false]) {
        final (center, rot) = armPose(left, happy);
        final m = left ? -1.0 : 1.0;
        _at(c, center, rot, () {
          switch (zodiac) {
            case Zodiac.iguanodon:
              // 엄지 가시: 손 안쪽에서 위로 솟은 큰 뿔
              _at(c, Offset(m * 8, 8), m * .5, () {
                _fs(c, _spike(12, 22, round: .2), ivory, w: 3);
              });
            case Zodiac.velociraptor:
            case Zodiac.trex:
            case Zodiac.dilophosaurus:
            case Zodiac.spinosaurus:
              // 손끝 작은 발톱
              final s = zodiac == Zodiac.trex ? .66 : 1.0;
              for (final dx in [-3.5, 3.5]) {
                _at(c, Offset(dx * s, 17 * s), pi, () {
                  _fs(c, _spike(4.5, 6, round: .2), ivory, w: 2);
                });
              }
            default:
              break;
          }
        });
      }
    }
  }

  void _arms(Canvas c, bool happy) {
    if (_noLegs) return;
    if (_wings) {
      _wingArms(c, happy);
      return;
    }
    // 양: 털 몸 옆에 얼굴색 팔 + 발굽
    for (final left in [true, false]) {
      final (center, rot) = armPose(left, happy);
      _at(c, center, rot, () {
        final arm = armShape();
        _fs(c, arm, tone(look.accent, .1));
        c.save();
        c.clipPath(arm);
        c.drawOval(
          Rect.fromCenter(center: const Offset(0, 21), width: 24, height: 18),
          Paint()..color = const Color(0xFF8A817C),
        );
        c.restore();
        // 어깨는 털 뭉치 속에 파묻힌다 (팔 윗부분 끝이 보이지 않게)
        _fs(
          c,
          Path()..addOval(
            Rect.fromCenter(
              center: const Offset(0, -13),
              width: 30,
              height: 30,
            ),
          ),
          look.light,
        );
      });
    }
  }

  /// 날개 팔. 닭은 깃털 날개, 프테라노돈은 손가락 끝까지 펼친 큰 막 날개.
  void _wingArms(Canvas c, bool happy) {
    final ptero = zodiac == Zodiac.pteranodon;
    for (final m in [-1.0, 1.0]) {
      c.save();
      if (m > 0) {
        c.translate(200, 0);
        c.scale(-1, 1);
      }
      if (ptero && sideways) {
        // 탈것에 탔을 때: 날개를 접어 몸 옆에 붙인다
        _at(c, const Offset(70, 160), .5, () {
          final w = Path()
            ..moveTo(0, -20)
            ..quadraticBezierTo(18, -4, 8, 28)
            ..lineTo(0, 18)
            ..lineTo(-8, 26)
            ..quadraticBezierTo(-14, -4, 0, -20)
            ..close();
          _fs(c, w, look.light);
        });
      } else if (ptero) {
        // 왼쪽 날개 (오른쪽은 뒤집어서). 어깨 (78,150)
        final tip = happy ? const Offset(14, 104) : const Offset(16, 150);
        final wing = Path()
          ..moveTo(80, 146)
          ..quadraticBezierTo(48, 124 + (happy ? -20 : 0), tip.dx, tip.dy)
          ..quadraticBezierTo(30, happy ? 136 : 172, 44, happy ? 148 : 182)
          ..quadraticBezierTo(54, happy ? 150 : 176, 62, happy ? 168 : 196)
          ..quadraticBezierTo(70, 180, 80, 196)
          ..close();
        _fs(c, wing, look.light);
        // 날개 뼈(팔)와 손가락 발톱
        final bone = Path()
          ..moveTo(80, 148)
          ..quadraticBezierTo(
            48,
            126 + (happy ? -20 : 0),
            tip.dx + 2,
            tip.dy + 1,
          );
        c.drawPath(bone, stroke(5, fur));
        final knuckle = happy ? const Offset(40, 114) : const Offset(42, 134);
        _at(
          c,
          knuckle,
          -.6,
          () => _fs(c, _spike(5, 9, round: .2), ivory, w: 2.2),
        );
      } else {
        final (center, rot) = armPose(true, happy);
        _at(c, center, rot, () {
          final w = Path()
            ..moveTo(0, -18)
            ..quadraticBezierTo(16, -6, 10, 18)
            ..lineTo(5, 12)
            ..lineTo(0, 20)
            ..lineTo(-5, 12)
            ..lineTo(-10, 18)
            ..quadraticBezierTo(-16, -6, 0, -18)
            ..close();
          _fs(c, w, tone(Colors.white, .1));
        });
      }
      c.restore();
    }
  }

  // ================= 귀·뿔·볏 (머리 뒤) =================
  void _earsBehind(Canvas c) {
    switch (zodiac) {
      case Zodiac.triceratops:
        _frill(c);
      case Zodiac.parasaurolophus:
        // 뒤로 길게 휜 관 볏 (굵은 관 + 밝은 줄)
        _backward(c, () {
          final crest = Path()
            ..moveTo(104, 60)
            ..cubicTo(112, 26, 150, 8, 184, 14);
          c.drawPath(crest, stroke(27.5, look.accent));
          final hi = Path()
            ..moveTo(116, 42)
            ..cubicTo(128, 26, 150, 18, 176, 18);
          c.drawPath(hi, stroke(5, _tint(look.accent, .45)));
        });
      case Zodiac.pteranodon:
        // 뒤로 길게 뻗은 뾰족 볏
        _backward(c, () {
          final crest = Path()
            ..moveTo(96, 48)
            ..cubicTo(130, 30, 164, 14, 196, 8)
            ..cubicTo(176, 30, 150, 50, 132, 70)
            ..close();
          _fs(c, crest, look.accent);
          c.drawLine(
            const Offset(116, 50),
            const Offset(176, 18),
            stroke(2.4, _shade(look.accent, .2)),
          );
        });
      case Zodiac.dilophosaurus:
        // 머리 위 나란히 선 두 개의 반달 볏
        for (final m in [-1.0, 1.0]) {
          final x = 100 + m * 17;
          _at(c, Offset(x, 52), m * .2, () {
            final crest = Path()
              ..moveTo(-9, 10)
              ..cubicTo(-14, -26, 8, -46, 14, -40)
              ..cubicTo(18, -24, 12, -4, 9, 10)
              ..close();
            _fs(c, crest, look.accent);
            for (final (a, b) in const [
              (Offset(-4, 2), Offset(2, -28)),
              (Offset(4, 4), Offset(10, -24)),
            ]) {
              c.drawLine(a, b, stroke(2.6, _tint(look.accent, .5)));
            }
          });
        }
      case Zodiac.dragon:
        _dragonMane(c);
      default:
        break;
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
          // 사슴뿔처럼 갈라진 금빛 뿔
          final horn = Path()
            ..moveTo(_m(m, 26, 52).dx, 52)
            ..lineTo(_m(m, 34, 14).dx, 14)
            ..moveTo(_m(m, 31, 32).dx, 32)
            ..lineTo(_m(m, 48, 20).dx, 20)
            ..moveTo(_m(m, 33, 22).dx, 22)
            ..lineTo(_m(m, 22, 10).dx, 10);
          c.drawPath(horn, stroke(9.5, const Color(0xFFFFD34D)));
        case Zodiac.horse:
          final ear = Path()
            ..moveTo(_m(m, 30, 52).dx, 52)
            ..quadraticBezierTo(_m(m, 40, 16).dx, 16, _m(m, 54, 24).dx, 24)
            ..quadraticBezierTo(_m(m, 58, 42).dx, 42, _m(m, 52, 58).dx, 58)
            ..close();
          _fs(c, ear, fur);
          c.drawPath(
            Path()
              ..moveTo(_m(m, 38, 48).dx, 48)
              ..quadraticBezierTo(_m(m, 42, 30).dx, 30, _m(m, 50, 30).dx, 30),
            stroke(4, _tint(look.accent, .5)),
          );
        case Zodiac.sheep:
          // 크게 말린 뿔
          final o = _m(m, 62, 66);
          _fs(
            c,
            Path()..addOval(Rect.fromCircle(center: o, radius: 22)),
            const Color(0xFFD9B07A),
          );
          final spiral = Path()..moveTo(o.dx, o.dy);
          for (var i = 0; i <= 24; i++) {
            final t = i / 24;
            final a = m * (t * pi * 3.2) - pi / 2;
            final r = 3 + t * 13;
            spiral.lineTo(o.dx + cos(a) * r, o.dy + sin(a) * r);
          }
          c.drawPath(spiral, stroke(3, _shade(const Color(0xFFD9B07A), .4)));
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
        case Zodiac.ankylosaurus:
          // 뺨 뒤로 뻗은 뿔 가시
          for (final (y, a, l) in const [
            (78.0, 1.0, 22.0),
            (118.0, 1.9, 26.0),
          ]) {
            _at(c, _m(m, 66, y), m * a, () {
              _fs(c, _spike(20, l, round: .25), ivory, w: 3.2);
            });
          }
        default:
          break;
      }
    }
    if (zodiac == Zodiac.sheep) {
      // 양: 늘어진 귀 (털 모자 아래 옆으로)
      for (final m in [-1.0, 1.0]) {
        _at(c, _m(m, 66, 92), m * .35, () {
          final ear = Path()
            ..addOval(
              Rect.fromCenter(center: Offset(m * 10, 0), width: 34, height: 16),
            );
          _fs(c, ear, look.accent);
          c.drawOval(
            Rect.fromCenter(center: Offset(m * 12, 0), width: 18, height: 6),
            Paint()..color = const Color(0xFFF5A9B8),
          );
        });
      }
    }
  }

  /// 트리케라톱스의 커다란 목 프릴 (가장자리 물결 + 혹)
  void _frill(Canvas c) {
    const o = Offset(100, 84);
    final frill = _cached('frill', () {
      var f = Path()..addOval(Rect.fromCircle(center: o, radius: 76));
      for (var i = 0; i < 9; i++) {
        final a = pi + i * pi / 8;
        f = Path.combine(
          PathOperation.union,
          f,
          Path()..addOval(
            Rect.fromCircle(
              center: o + Offset(cos(a), sin(a)) * 74,
              radius: 11,
            ),
          ),
        );
      }
      return f;
    });
    _fs(c, frill, _shade(fur, .08));
    c.drawCircle(o, 58, Paint()..color = _tint(fur, .25));
    for (var i = 0; i < 9; i++) {
      final a = pi + i * pi / 8;
      final p = o + Offset(cos(a), sin(a)) * 74;
      c.drawCircle(p, 7, Paint()..color = look.accent);
    }
  }

  /// 용의 갈기: 머리 뒤로 불꽃처럼 뻗은 털
  void _dragonMane(Canvas c) {
    final mane = _cached('dragon-mane', () {
      var p = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100, 100),
            width: 138,
            height: 100,
          ),
        );
      for (final (deg, l) in const [
        (-150.0, 34.0),
        (-30.0, 34.0),
        (-175.0, 30.0),
        (-5.0, 30.0),
        (160.0, 24.0),
        (20.0, 24.0),
      ]) {
        final a = deg * pi / 180;
        final base = const Offset(100, 96) + Offset(cos(a) * 66, sin(a) * 54);
        final tip = base + Offset(cos(a), sin(a)) * l;
        final side = Offset(-sin(a), cos(a)) * 12;
        p = Path.combine(
          PathOperation.union,
          p,
          Path()
            ..moveTo(base.dx - side.dx, base.dy - side.dy)
            ..quadraticBezierTo(
              tip.dx - side.dx * .2,
              tip.dy - side.dy * .2,
              tip.dx + side.dx * .6,
              tip.dy + side.dy * .6,
            )
            ..lineTo(base.dx + side.dx, base.dy + side.dy)
            ..close(),
        );
      }
      return p;
    });
    _fs(c, mane, const Color(0xFFFF8E4A));
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

  /// 브라키오사우루스: 머리 위로 목처럼 높이 솟은 콧등 (모자를 쓰면 낮춘다)
  Path get _brachioHead => _cached('brachio-head|$_hatOn', () {
    final top = _hatOn ? 30.0 : 4.0;
    final tower = Path()
      ..moveTo(70, 70)
      ..cubicTo(66, top + 30, 74, top, 100, top)
      ..cubicTo(126, top, 134, top + 30, 130, 70)
      ..close();
    return Path.combine(PathOperation.union, headPath(), tower);
  });

  /// 파키케팔로사우루스: 위로 두껍게 솟은 둥근 돔 머리 (모자를 쓰면 낮춘다)
  Path get _pachyHead => _cached('pachy-head|$_hatOn', () {
    final top = _hatOn ? 34.0 : 8.0;
    final dome = Path()
      ..moveTo(38, 84)
      ..cubicTo(34, top + 12, 72, top, 100, top)
      ..cubicTo(128, top, 166, top + 12, 162, 84)
      ..close();
    return Path.combine(PathOperation.union, headPath(), dome);
  });

  Path get _headShape => switch (zodiac) {
    Zodiac.snake => headPath(dy: 10, sx: 1.0, sy: .84),
    Zodiac.horse => headPath(dy: 4, sx: .9, sy: 1.06),
    Zodiac.sheep => headPath(dy: 10, sx: .78, sy: .86),
    Zodiac.trex => headPath(sx: 1.06, dy: 2),
    Zodiac.velociraptor || Zodiac.pteranodon => headPath(sx: .94),
    Zodiac.brachiosaurus => _brachioHead,
    Zodiac.pachycephalosaurus => _pachyHead,
    _ => headPath(),
  };

  void _head(Canvas c) {
    switch (zodiac) {
      case Zodiac.rooster:
        // 크고 붉은 볏 (봉우리 셋)
        final comb = _cached('comb', () {
          var p = Path()..addRect(const Rect.fromLTRB(80, 40, 120, 52));
          for (final (o, r) in const [
            (Offset(82, 38), 12.0),
            (Offset(100, 24), 15.0),
            (Offset(118, 36), 12.0),
          ]) {
            p = Path.combine(
              PathOperation.union,
              p,
              Path()..addOval(Rect.fromCircle(center: o, radius: r)),
            );
          }
          return p;
        });
        c.save();
        if (sideways) turnFace(c, shift: earShift, squash: earSquash);
        _fs(c, comb, look.accent);
        c.restore();
        _fs(c, _headShape, Colors.white);
      case Zodiac.horse:
        // 뒤로 늘어진 갈기
        final back = Path()
          ..moveTo(60, 50)
          ..cubicTo(26, 60, 22, 110, 34, 140)
          ..cubicTo(44, 120, 50, 90, 70, 70)
          ..close();
        _fs(c, back, look.accent, w: 3);
        _fs(c, _headShape, fur);
      case Zodiac.sheep:
        // 털 모자 뒤쪽 (얼굴 둘레)
        _fs(c, _cloud(const Offset(100, 74), 58, 10), look.light);
        _fs(c, _headShape, look.accent);
      default:
        _fs(c, _headShape, fur);
    }
  }

  /// 머리 맨 위에 얹히는 것 (돔·털·볏 등). 옆을 볼 때도 얼굴보다 덜 돌린다.
  void _headTop(Canvas c) {
    switch (zodiac) {
      case Zodiac.horse:
        // 앞머리 갈기
        final mane = Path()
          ..moveTo(76, 48)
          ..cubicTo(80, 22, 120, 18, 126, 40)
          ..cubicTo(116, 36, 112, 50, 102, 60)
          ..cubicTo(98, 48, 88, 44, 76, 48)
          ..close();
        _fs(c, mane, look.accent, w: 3);
      case Zodiac.sheep:
        // 앞이마 털 뭉치
        _fs(c, _cloud(const Offset(100, 50), 30, 7), look.light);
      case Zodiac.pachycephalosaurus:
        _pachyDome(c);
      case Zodiac.velociraptor:
        // 머리 깃털 볏 (뒤로 펼쳐진 다섯 가닥)
        for (var i = 0; i < 5; i++) {
          final a = -.75 + i * .3;
          _at(c, Offset(100 + (i - 2) * 9.0, 46), a, () {
            final l = 30.0 - (i - 2).abs() * 5;
            final f = Path()
              ..moveTo(-6, 4)
              ..quadraticBezierTo(-9, -l * .6, 0, -l)
              ..quadraticBezierTo(9, -l * .6, 6, 4)
              ..close();
            _fs(c, f, i.isEven ? look.accent : const Color(0xFFFFB13B), w: 2.8);
          });
        }
      default:
        break;
    }
  }

  /// 파키케팔로사우루스의 두꺼운 돔 머리와 둘레의 혹
  void _pachyDome(Canvas c) {
    // 돔은 머리와 한 덩어리 (조금 밝게 + 반짝), 아래 둘레에 동글동글 혹
    final top = _hatOn ? 34.0 : 8.0;
    final dome = Path()
      ..moveTo(36, 84)
      ..cubicTo(32, top + 12, 72, top, 100, top)
      ..cubicTo(128, top, 168, top + 12, 164, 84)
      ..cubicTo(130, 72, 70, 72, 36, 84)
      ..close();
    c.save();
    c.clipPath(_headShape);
    c.drawPath(dome, Paint()..color = _tint(fur, .3));
    c.restore();
    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      final x = 38 + t * 124;
      final y = 84 - sin(t * pi) * 12;
      c.drawCircle(Offset(x, y), 6, Paint()..color = look.accent);
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
        _muzzle(
          c,
          const Offset(100, 122),
          80,
          40,
          const Color(0xFFF7B7C0),
          nostrils: true,
        );
      case Zodiac.tiger:
        // 이마의 세 줄 + 뺨 줄무늬 (진한 주황 면)
        final band = Paint()..color = _tigerStripe;
        c.drawPath(
          _stripe(const Offset(100, 38), const Offset(100, 56), 7),
          band,
        );
        for (final m in [-1.0, 1.0]) {
          c.drawPath(_stripe(_m(m, 16, 40), _m(m, 13, 52), 6), band);
          c.drawPath(_stripe(_m(m, 71, 86), _m(m, 56, 89), 7), band);
          c.drawPath(_stripe(_m(m, 71, 102), _m(m, 58, 101), 7), band);
        }
        _muzzle(c, const Offset(100, 120), 46, 32, look.light);
      case Zodiac.dragon:
        // 툭 튀어나온 콧등 + 큰 콧구멍
        _muzzle(
          c,
          const Offset(100, 120),
          60,
          36,
          _tint(fur, .35),
          nostrils: true,
          outline: true,
        );
        // 이마 비늘
        for (final o in const [
          Offset(92, 52),
          Offset(108, 52),
          Offset(100, 62),
        ]) {
          c.drawCircle(o, 4, Paint()..color = look.light);
        }
      case Zodiac.horse:
        // 이마의 흰 줄무늬
        final blaze = Path()
          ..moveTo(96, 62)
          ..quadraticBezierTo(100, 58, 104, 62)
          ..lineTo(106, 110)
          ..lineTo(94, 110)
          ..close();
        c.drawPath(blaze, Paint()..color = look.light);
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
        if (sideways) break; // 옆얼굴의 부리 아래에 따로
        final wattle = Path()
          ..moveTo(95, 122)
          ..cubicTo(88, 136, 92, 146, 100, 145)
          ..cubicTo(108, 146, 112, 136, 105, 122)
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
      case Zodiac.snake:
        // 정수리 무늬
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(100, 60),
          Offset(80, 66),
          Offset(120, 66),
        ]) {
          _diamond(c, o, 8, look.accent);
        }
        c.restore();
      case Zodiac.sheep:
        break;
      // ---------- 공룡 ----------
      default:
        _dinoHead(c, clip);
    }
  }

  /// 공룡 머리 무늬와 주둥이
  void _dinoHead(Canvas c, Path clip) {
    // 아래턱 쪽은 밝은 색 (모든 공룡 공통: 파충류다운 얼굴)
    final jawColor = look.light;
    final lowJaw =
        !_sideSnout &&
        const {
          Zodiac.trex,
          Zodiac.spinosaurus,
          Zodiac.velociraptor,
          Zodiac.dilophosaurus,
          Zodiac.brachiosaurus,
        }.contains(zodiac);
    if (lowJaw) {
      c.save();
      c.clipPath(clip);
      c.drawOval(
        Rect.fromCenter(center: const Offset(100, 150), width: 132, height: 64),
        Paint()..color = jawColor,
      );
      c.restore();
    }
    switch (zodiac) {
      case Zodiac.trex:
        // 머리 위 줄무늬 + 두툼한 눈두덩
        c.save();
        c.clipPath(clip);
        for (final (dx, w) in const [
          (0.0, 12.0),
          (-24.0, 10.0),
          (24.0, 10.0),
        ]) {
          c.drawOval(
            Rect.fromCenter(center: Offset(100 + dx, 44), width: w, height: 24),
            Paint()..color = look.accent,
          );
        }
        c.restore();
        for (final m in [-1.0, 1.0]) {
          final brow = Path()
            ..moveTo(_m(m, 16, 80).dx, 80)
            ..quadraticBezierTo(_m(m, 28, 72).dx, 72, _m(m, 40, 80).dx, 80);
          c.drawPath(brow, stroke(6, look.accent));
        }
      case Zodiac.spinosaurus:
        if (!_sideSnout) {
          // 길쭉한 주둥이 끝의 콧등과 콧구멍
          final ridge = Path()
            ..moveTo(88, 120)
            ..cubicTo(86, 98, 114, 98, 112, 120);
          c.drawPath(ridge, stroke(3, _shade(fur, .3)));
          for (final m in [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(center: _m(m, 6, 112), width: 5, height: 6),
              Paint()..color = _shade(fur, .5),
            );
          }
        }
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(54, 70),
          Offset(146, 70),
          Offset(64, 58),
          Offset(136, 58),
        ]) {
          c.drawCircle(o, 4, Paint()..color = _shade(fur, .18));
        }
        c.restore();
      case Zodiac.triceratops:
        // 눈 위의 긴 뿔 둘 + 코뿔 + 부리 (옆얼굴은 [_profileFace]에서)
        if (sideways) break;
        for (final m in [-1.0, 1.0]) {
          final horn = Path()
            ..moveTo(_m(m, 14, 70).dx, 70)
            ..cubicTo(
              _m(m, 18, 40).dx,
              40,
              _m(m, 30, 18).dx,
              18,
              _m(m, 44, 4).dx,
              4,
            )
            ..cubicTo(
              _m(m, 40, 26).dx,
              26,
              _m(m, 38, 50).dx,
              50,
              _m(m, 36, 70).dx,
              70,
            )
            ..close();
          _fs(c, horn, ivory);
        }
        _beak(c, const Offset(100, 124), 52, 34);
        final nose = Path()
          ..moveTo(90, 112)
          ..cubicTo(92, 98, 98, 88, 104, 82)
          ..cubicTo(108, 94, 110, 104, 110, 112)
          ..close();
        _fs(c, nose, ivory, w: 3);
      case Zodiac.stegosaurus:
        if (!_sideSnout) _beak(c, const Offset(100, 124), 48, 28);
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(56, 70),
          Offset(144, 70),
          Offset(66, 60),
          Offset(134, 60),
          Offset(100, 50),
        ]) {
          c.drawCircle(o, 4.6, Paint()..color = _shade(fur, .16));
        }
        c.restore();
      case Zodiac.ankylosaurus:
        // 정수리 갑옷 (육각 비늘)
        c.save();
        c.clipPath(clip);
        final cap = Path()
          ..moveTo(26, 82)
          ..cubicTo(40, 22, 160, 22, 174, 82)
          ..cubicTo(140, 68, 60, 68, 26, 82)
          ..close();
        c.drawPath(cap, Paint()..color = look.accent);
        for (final o in const [
          Offset(70, 54),
          Offset(100, 48),
          Offset(130, 54),
          Offset(54, 70),
          Offset(85, 66),
          Offset(115, 66),
          Offset(146, 70),
        ]) {
          c.drawCircle(o, 6.5, Paint()..color = _shade(look.accent, .14));
        }
        c.restore();
        _beak(c, const Offset(100, 124), 50, 30);
      case Zodiac.iguanodon:
        // 이마의 줄무늬 + 말처럼 긴 부리 주둥이
        c.save();
        c.clipPath(clip);
        for (final dx in [-22.0, 0.0, 22.0]) {
          final v = Path()
            ..moveTo(100 + dx - 8, 42)
            ..lineTo(100 + dx, 56)
            ..lineTo(100 + dx + 8, 42);
          c.drawPath(v, stroke(5, look.accent));
        }
        c.restore();
        if (!_sideSnout) {
          _beak(c, const Offset(100, 124), 56, 34);
        }
      case Zodiac.pachycephalosaurus:
        // 콧등 혹 (옆얼굴은 옆 주둥이 위에)
        if (sideways) break;
        for (final o in const [
          Offset(92, 108),
          Offset(108, 108),
          Offset(100, 102),
        ]) {
          c.drawCircle(o, 3.6, Paint()..color = look.accent);
        }
        _beak(c, const Offset(100, 126), 42, 24);
      case Zodiac.parasaurolophus:
        // 넓적한 오리 주둥이
        if (!_sideSnout) {
          final bill = Path()
            ..addRRect(
              RRect.fromLTRBR(64, 108, 136, 140, const Radius.circular(16)),
            );
          _fs(c, bill, const Color(0xFFFFE3A8), w: 3.2);
          for (final m in [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(center: _m(m, 10, 116), width: 6, height: 4),
              Paint()..color = _shade(const Color(0xFFFFE3A8), .5),
            );
          }
        }
        c.save();
        c.clipPath(clip);
        for (final o in const [Offset(56, 72), Offset(144, 72)]) {
          c.drawCircle(o, 4.4, Paint()..color = _shade(fur, .18));
        }
        c.restore();
      case Zodiac.brachiosaurus:
        // 솟은 콧등 꼭대기의 콧구멍과 점무늬
        if (!_hatOn) {
          for (final m in [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(center: _m(m, 8, 18), width: 6, height: 8),
              Paint()..color = _shade(fur, .45),
            );
          }
        }
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(86, 44),
          Offset(114, 52),
          Offset(56, 74),
          Offset(146, 74),
        ]) {
          c.drawCircle(
            o,
            5,
            Paint()..color = look.accent.withValues(alpha: .6),
          );
        }
        c.restore();
      case Zodiac.dilophosaurus:
        c.save();
        c.clipPath(clip);
        for (final o in const [
          Offset(56, 70),
          Offset(144, 70),
          Offset(48, 84),
          Offset(152, 84),
        ]) {
          c.drawCircle(o, 4.2, Paint()..color = _shade(fur, .2));
        }
        c.restore();
        if (!_sideSnout) {
          for (final m in [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(center: _m(m, 7, 112), width: 5, height: 4),
              Paint()..color = _shade(fur, .5),
            );
          }
        }
      case Zodiac.velociraptor:
        // 눈가 줄무늬
        c.save();
        c.clipPath(clip);
        for (final m in [-1.0, 1.0]) {
          final s = Path()
            ..moveTo(_m(m, 34, 80).dx, 80)
            ..quadraticBezierTo(_m(m, 54, 82).dx, 82, _m(m, 70, 96).dx, 96);
          c.drawPath(s, stroke(5, _shade(fur, .2)));
        }
        c.restore();
        if (!_sideSnout) {
          for (final m in [-1.0, 1.0]) {
            c.drawOval(
              Rect.fromCenter(center: _m(m, 7, 110), width: 5, height: 4),
              Paint()..color = _shade(fur, .5),
            );
          }
        }
      case Zodiac.pteranodon:
        break; // 부리는 얼굴에서
      default:
        break;
    }
  }

  /// 짧고 단단한 공룡 부리 (아래로 살짝 굽은)
  void _beak(Canvas c, Offset o, double w, double h) {
    if (sideways) return; // 옆얼굴은 주둥이 끝의 옆 부리([_profileFace])로
    final beak = Path()
      ..moveTo(o.dx - w / 2, o.dy - h * .3)
      ..quadraticBezierTo(o.dx, o.dy - h * .62, o.dx + w / 2, o.dy - h * .3)
      ..quadraticBezierTo(o.dx + w * .36, o.dy + h * .4, o.dx, o.dy + h * .5)
      ..quadraticBezierTo(
        o.dx - w * .36,
        o.dy + h * .4,
        o.dx - w / 2,
        o.dy - h * .3,
      )
      ..close();
    _fs(c, beak, const Color(0xFFFFE3A8), w: 3);
    for (final m in [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(
          center: o + Offset(m * w * .16, -h * .18),
          width: 4.5,
          height: 3.6,
        ),
        Paint()..color = const Color(0xFF8A6A4A),
      );
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
    if (sideways) return; // 옆얼굴은 머리 밖으로 나온 옆 주둥이([_profileFace])에
    final r = Rect.fromCenter(center: o, width: w, height: h);
    c.drawOval(r, Paint()..color = color);
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

  /// 옆을 볼 때 머리 오른쪽으로 길게 나온 공룡 주둥이
  static (double, double, double) _dinoSnout(Zodiac z) => switch (z) {
    Zodiac.trex => (86.0, 142.0, 197.0),
    Zodiac.spinosaurus => (98.0, 130.0, 199.0),
    Zodiac.velociraptor => (94.0, 128.0, 194.0),
    Zodiac.parasaurolophus => (100.0, 134.0, 195.0),
    Zodiac.dilophosaurus => (94.0, 130.0, 192.0),
    Zodiac.iguanodon => (94.0, 134.0, 192.0),
    Zodiac.brachiosaurus => (98.0, 134.0, 186.0),
    _ => (100.0, 134.0, 188.0),
  };

  void _profileSnout(Canvas c, bool happy) {
    final (top, bottom, tip) = _dinoSnout(zodiac);
    final h = bottom - top;
    final duck = zodiac == Zodiac.parasaurolophus;
    final p = Path()
      ..moveTo(136, top - 6)
      ..quadraticBezierTo(150, top, tip - h * .45, top + (duck ? 4 : h * .08))
      ..cubicTo(tip - 2, top + h * .14, tip, top + h * .3, tip, top + h * .55)
      ..quadraticBezierTo(tip, bottom, tip - h * .5, bottom)
      ..lineTo(136, bottom + 4)
      ..close();
    // 머리와 주둥이는 같은 색 면 하나로 이어진다
    c.drawPath(p, Paint()..color = fur);
    final mouthY = top + h * .62;
    c.save();
    if (duck) {
      // 넓적한 오리 부리: 끝이 둥근 밝은 면
      c.clipPath(p);
      c.drawRRect(
        RRect.fromLTRBR(
          142,
          top - 2,
          tip + 4,
          bottom + 6,
          const Radius.circular(16),
        ),
        Paint()..color = const Color(0xFFFFE3A8),
      );
    } else {
      // 아래턱은 밝은 색: 뺨 쪽 끝을 둥글게 (머리 안에서 뚝 끊기지 않게)
      c.clipPath(
        _cached(
          'profile|${zodiac.name}|$_hatOn',
          () => Path.combine(PathOperation.union, _headShape, p),
        ),
      );
      c.drawRRect(
        RRect.fromLTRBR(
          120,
          mouthY,
          tip + 6,
          bottom + 30,
          const Radius.circular(18),
        ),
        Paint()..color = look.light,
      );
    }
    c.restore();
    // 입선 + 이빨
    final mouth = Path()
      ..moveTo(150, mouthY - (happy ? 2 : 0))
      ..quadraticBezierTo(
        tip - 14,
        mouthY + (happy ? 8 : 2),
        tip - 4,
        mouthY - 2,
      );
    c.drawPath(mouth, stroke(2.6, feature));
    if (const {
      Zodiac.trex,
      Zodiac.spinosaurus,
      Zodiac.velociraptor,
      Zodiac.dilophosaurus,
    }.contains(zodiac)) {
      final n = zodiac == Zodiac.trex ? 4 : 5;
      for (var i = 0; i < n; i++) {
        final x = 158 + i * (tip - 168) / n;
        final y = mouthY + 1 + (x - 150) / (tip - 150) * -1;
        final t = Path()
          ..moveTo(x - 2.6, y)
          ..lineTo(x + 2.6, y)
          ..lineTo(x, y + 5.5)
          ..close();
        c.drawPath(t, Paint()..color = Colors.white);
      }
    }
    // 콧구멍
    c.drawOval(
      Rect.fromCenter(
        center: Offset(tip - 8, top + h * .26),
        width: 5,
        height: 4,
      ),
      Paint()..color = _shade(duck ? const Color(0xFFFFE3A8) : fur, .5),
    );
  }

  // ================= 옆얼굴 주둥이 (동물·짧은 주둥이 공룡) =================
  /// 옆을 볼 때 머리 오른쪽으로 살짝 나오는 주둥이: 가운데 높이 [cy], 두께 [h],
  /// 끝 x [tip], 길이 [len] (끝에서 머리 안쪽으로). 머리 오른쪽 가장자리는 x 165~170 근처.
  static ({double cy, double h, double tip, double len}) _profileSpec(
    Zodiac z,
  ) => switch (z) {
    Zodiac.rat => (cy: 116.0, h: 24.0, tip: 181.0, len: 38.0),
    Zodiac.rabbit => (cy: 117.0, h: 24.0, tip: 177.0, len: 34.0),
    Zodiac.tiger => (cy: 118.0, h: 30.0, tip: 180.0, len: 42.0),
    Zodiac.ox => (cy: 124.0, h: 38.0, tip: 186.0, len: 50.0),
    Zodiac.horse => (cy: 128.0, h: 40.0, tip: 182.0, len: 52.0),
    Zodiac.dragon => (cy: 120.0, h: 32.0, tip: 188.0, len: 52.0),
    Zodiac.pig => (cy: 115.0, h: 28.0, tip: 182.0, len: 40.0),
    Zodiac.dog => (cy: 120.0, h: 28.0, tip: 184.0, len: 44.0),
    Zodiac.monkey => (cy: 120.0, h: 26.0, tip: 174.0, len: 34.0),
    Zodiac.sheep => (cy: 122.0, h: 24.0, tip: 166.0, len: 32.0),
    Zodiac.snake => (cy: 120.0, h: 24.0, tip: 184.0, len: 42.0),
    _ => (cy: 120.0, h: 30.0, tip: 176.0, len: 40.0), // 짧은 부리 공룡
  };

  /// 옆 주둥이 면 (닭·프테라노돈은 부리만 있어서 없음)
  static Path? _profileBump(Zodiac z) {
    if (z == Zodiac.rooster || z == Zodiac.pteranodon) return null;
    return _cached('bump|${z.name}', () {
      final s = _profileSpec(z);
      return Path()..addRRect(
        RRect.fromLTRBR(
          s.tip - s.len,
          s.cy - s.h / 2,
          s.tip,
          s.cy + s.h / 2,
          Radius.circular(s.h / 2),
        ),
      );
    });
  }

  /// 옆 주둥이 색: 정면 주둥이 색을 그대로 (없으면 털색이라 머리와 한 면으로 이어진다)
  Color get _profileColor => switch (zodiac) {
    Zodiac.ox => const Color(0xFFF7B7C0),
    Zodiac.pig => const Color(0xFFF7A1B5),
    Zodiac.dragon => _tint(fur, .35),
    Zodiac.rat ||
    Zodiac.rabbit ||
    Zodiac.tiger ||
    Zodiac.horse ||
    Zodiac.dog ||
    Zodiac.monkey => look.light,
    Zodiac.sheep => look.accent,
    _ => fur,
  };

  /// 옆을 보는 얼굴의 코·입·부리: 머리 오른쪽으로 살짝 튀어나오게.
  /// 외곽선 없이 색 면으로만, 머리와 주둥이가 하나의 실루엣으로 이어진다.
  void _profileFace(Canvas c, bool happy) {
    const beakYellow = Color(0xFFFFE3A8);
    switch (zodiac) {
      case Zodiac.rooster:
        // 부리 아래 늘어진 볏(육수) + 앞으로 뾰족한 부리
        final wattle = Path()
          ..moveTo(150, 118)
          ..cubicTo(142, 132, 148, 146, 156, 145)
          ..cubicTo(164, 144, 166, 130, 160, 118)
          ..close();
        c.drawPath(wattle, Paint()..color = look.accent);
        final beak = Path()
          ..moveTo(150, 103)
          ..quadraticBezierTo(172, 104, 186, 114)
          ..quadraticBezierTo(170, 122, 150, 125)
          ..close();
        c.drawPath(beak, Paint()..color = const Color(0xFFFFB52E));
        c.drawLine(
          const Offset(156, 114),
          const Offset(176, 114),
          stroke(2, _shade(const Color(0xFFFFB52E), .3)),
        );
        return;
      case Zodiac.pteranodon:
        // 앞으로 길게 뻗은 부리
        final beak = Path()
          ..moveTo(142, 100)
          ..quadraticBezierTo(176, 100, 198, 116)
          ..quadraticBezierTo(174, 125, 142, 128)
          ..close();
        c.drawPath(beak, Paint()..color = const Color(0xFFFFD36B));
        c.drawLine(
          const Offset(150, 115),
          const Offset(190, 116),
          stroke(2.2, const Color(0xFFC99A3A)),
        );
        return;
      default:
        break;
    }
    final s = _profileSpec(zodiac);
    final tip = s.tip, cy = s.cy, h = s.h;
    final top = cy - h / 2, bottom = cy + h / 2;
    final bump = _profileBump(zodiac)!;
    // 머리 실루엣 다시 칠하기: 주둥이 뿌리 쪽을 털색으로 먼저 깔아 머리와 이음새 없이 잇는다
    c.save();
    c.clipPath(bump);
    c.drawPath(
      _headShape,
      Paint()..color = zodiac == Zodiac.sheep ? look.accent : fur,
    );
    c.restore();
    c.drawPath(bump, Paint()..color = _profileColor);

    final my = cy + h * .24;
    void mouth({double w = 18}) {
      if (happy) {
        final m = Path()
          ..moveTo(tip - 4, my - 2)
          ..quadraticBezierTo(tip - w * .55, my + 11, tip - w - 2, my - 1)
          ..close();
        c.drawPath(m, Paint()..color = const Color(0xFFE0707C));
      } else {
        final m = Path()
          ..moveTo(tip - 5, my - 1)
          ..quadraticBezierTo(tip - w * .5, my + 5, tip - w, my - 1);
        c.drawPath(m, stroke(2.4, feature));
      }
    }

    void nostril(Color col, {double dx = 9}) => c.drawOval(
      Rect.fromCenter(
        center: Offset(tip - dx, cy - h * .14),
        width: 5,
        height: 7,
      ),
      Paint()..color = col,
    );

    switch (zodiac) {
      case Zodiac.ox || Zodiac.horse:
        nostril(const Color(0xFF6B4A3C));
        mouth(w: 22);
      case Zodiac.dragon:
        nostril(const Color(0xFF6B4A3C));
        mouth(w: 26);
        // 작은 송곳니 + 앞으로 휘날리는 수염
        final fx = tip - 14;
        c.drawPath(
          Path()
            ..moveTo(fx - 2.5, my + 1)
            ..lineTo(fx + 2.5, my + 1)
            ..lineTo(fx, my + 7)
            ..close(),
          Paint()..color = Colors.white,
        );
        final w = Path()
          ..moveTo(tip - 22, cy - 4)
          ..cubicTo(tip - 6, cy - 16, tip + 8, cy + 2, tip + 14, cy - 10);
        c.drawPath(w, stroke(3.0, const Color(0xFFFFD34D)));
      case Zodiac.pig:
        // 납작한 코 끝 (분홍 원판) + 콧구멍 둘
        final disc = Rect.fromCenter(
          center: Offset(tip - 3, cy),
          width: 12,
          height: h * .96,
        );
        c.drawOval(disc, Paint()..color = _shade(const Color(0xFFF7A1B5), .08));
        for (final dy in [-5.0, 5.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(tip - 2, cy + dy),
              width: 3.6,
              height: 5,
            ),
            Paint()..color = const Color(0xFF6B4A3C),
          );
        }
        mouth(w: 18);
      case Zodiac.snake:
        c.drawCircle(
          Offset(tip - 8, cy - 5),
          2,
          Paint()..color = _shade(fur, .5),
        );
        if (!happy) {
          final tongue = Path()
            ..moveTo(tip - 2, my)
            ..lineTo(tip + 8, my + 1)
            ..lineTo(tip + 13, my - 3)
            ..moveTo(tip + 8, my + 1)
            ..lineTo(tip + 13, my + 5);
          c.drawPath(tongue, stroke(3.0, const Color(0xFFE8433A)));
        }
        mouth(w: 20);
      case Zodiac.triceratops ||
          Zodiac.ankylosaurus ||
          Zodiac.pachycephalosaurus:
        if (zodiac == Zodiac.pachycephalosaurus) {
          // 콧등 혹
          for (final x in [tip - 30, tip - 20]) {
            c.drawCircle(Offset(x, top + 3), 3.6, Paint()..color = look.accent);
          }
        }
        // 주둥이 끝의 단단한 부리 (아래로 살짝 굽은)
        final beak = Path()
          ..moveTo(tip - 18, top + 1)
          ..quadraticBezierTo(tip + 2, top - 1, tip + 8, cy + 5)
          ..quadraticBezierTo(tip - 2, bottom, tip - 18, bottom - 1)
          ..quadraticBezierTo(tip - 22, cy, tip - 18, top + 1)
          ..close();
        c.drawPath(beak, Paint()..color = beakYellow);
        c.drawOval(
          Rect.fromCenter(
            center: Offset(tip - 8, cy - 6),
            width: 4.5,
            height: 3.6,
          ),
          Paint()..color = const Color(0xFF8A6A4A),
        );
        final m = Path()
          ..moveTo(tip + 2, cy + 4)
          ..quadraticBezierTo(
            tip - 14,
            cy + (happy ? 12 : 6),
            tip - 28,
            cy + 3,
          );
        c.drawPath(m, stroke(2.4, feature));
        if (zodiac == Zodiac.triceratops) {
          // 코뿔 (부리 위) + 눈 위의 긴 뿔 둘: 앞쪽으로 휘어 솟는다
          final nose = Path()
            ..moveTo(tip - 22, top + 2)
            ..quadraticBezierTo(tip - 16, top - 14, tip - 6, top - 18)
            ..quadraticBezierTo(tip - 8, top - 6, tip - 8, top + 2)
            ..close();
          c.drawPath(nose, Paint()..color = ivory);
          for (final (bx, l) in const [(118.0, 50.0), (146.0, 58.0)]) {
            final horn = Path()
              ..moveTo(bx - 9, 74)
              ..quadraticBezierTo(bx - 4, 74 - l * .6, bx + 14, 74 - l)
              ..quadraticBezierTo(bx + 6, 74 - l * .45, bx + 9, 74)
              ..close();
            c.drawPath(
              horn,
              Paint()..color = bx < 130 ? _shade(ivory, .1) : ivory,
            );
          }
        }
      default:
        // 작은 둥근 코 + 웃는 입 (쥐·토끼·호랑이·개·원숭이·양)
        final nw = zodiac == Zodiac.dog ? 12.0 : 9.0;
        c.drawOval(
          Rect.fromCenter(
            center: Offset(tip - nw / 2 + 1, cy - h * .18),
            width: nw,
            height: nw * .8,
          ),
          Paint()
            ..color = zodiac == Zodiac.sheep ? const Color(0xFF8A5A4A) : ink,
        );
        mouth(w: 16);
    }
  }

  // ================= 얼굴 =================
  void _face(Canvas c, bool happy) {
    final blink = mood == CharMood.normal && phase > .94;
    final ey = switch (zodiac) {
      Zodiac.horse || Zodiac.ox => 90.0,
      Zodiac.sheep => 100.0,
      Zodiac.pachycephalosaurus => 96.0,
      Zodiac.snake => 102.0,
      Zodiac.spinosaurus || Zodiac.trex => 92.0,
      Zodiac.triceratops ||
      Zodiac.parasaurolophus ||
      Zodiac.iguanodon ||
      Zodiac.stegosaurus => 92.0,
      _ => 96.0,
    };
    final eyeDx = switch (zodiac) {
      Zodiac.sheep => 20.0,
      Zodiac.snake => 30.0,
      Zodiac.spinosaurus => 32.0,
      Zodiac.trex => 27.0,
      _ => 25.0,
    };
    final eye = Paint()..color = feature;

    for (final m in [-1.0, 1.0]) {
      final x = 100 + m * eyeDx;
      if (happy) {
        final p = Path()
          ..moveTo(x - 5, ey + 2)
          ..quadraticBezierTo(x, ey - 5, x + 5, ey + 2);
        c.drawPath(p, stroke(3.2, feature));
      } else if (blink) {
        c.drawLine(Offset(x - 4, ey), Offset(x + 4, ey), stroke(3.2, feature));
      } else {
        // 작은 점 눈
        c.drawOval(
          Rect.fromCenter(center: Offset(x, ey), width: 8.5, height: 10),
          eye,
        );
      }
    }

    // 연한 볼 (옆얼굴은 가까운 볼을 주둥이 뒤쪽 눈 아래로)
    final cheekDx = zodiac == Zodiac.sheep ? 34.0 : 42.0;
    final profile = sideways && !_sideSnout;
    for (final m in [-1.0, 1.0]) {
      final dx = profile && m > 0 ? cheekDx * .68 : cheekDx;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(100 + m * dx, ey + 15),
          width: 15,
          height: 9,
        ),
        Paint()..color = const Color(0xFFF6A3B4).withValues(alpha: .55),
      );
    }
    if (profile) return; // 코·입·부리는 옆 주둥이([_profileFace])에서

    switch (snout) {
      case Snout.beak:
        if (zodiac == Zodiac.rooster) {
          final beak = Path()
            ..moveTo(87, 108)
            ..quadraticBezierTo(100, 100, 113, 108)
            ..quadraticBezierTo(106, 118, 100, 128)
            ..quadraticBezierTo(94, 118, 87, 108)
            ..close();
          _fs(c, beak, const Color(0xFFFFB52E), w: 3);
        } else {
          // 프테라노돈: 아래로 길게 뻗은 부리
          final beak = Path()
            ..moveTo(84, 106)
            ..quadraticBezierTo(100, 98, 116, 106)
            ..quadraticBezierTo(108, 130, 100, 146)
            ..quadraticBezierTo(92, 130, 84, 106)
            ..close();
          _fs(c, beak, const Color(0xFFFFD36B), w: 3);
          c.drawLine(
            const Offset(100, 112),
            const Offset(100, 138),
            stroke(2.2, const Color(0xFFC99A3A)),
          );
        }
        return;
      case Snout.snake:
        // 콧구멍 두 점 + 웃는 입 + 갈라진 혀
        for (final m in [-1.0, 1.0]) {
          c.drawCircle(_m(m, 6, 112), 2, Paint()..color = _shade(fur, .5));
        }
        final my = 124.0;
        if (!happy) {
          final tongue = Path()
            ..moveTo(98, my)
            ..lineTo(98, my + 10)
            ..lineTo(93, my + 16)
            ..moveTo(102, my)
            ..lineTo(102, my + 10)
            ..lineTo(107, my + 16);
          c.drawPath(tongue, stroke(3.0, const Color(0xFFE8433A)));
        }
        _mouth(c, my, 16, happy);
        return;
      default:
        break;
    }
    if (_sideSnout) return; // 주둥이·입은 옆으로 나온 주둥이에서

    final my = switch (zodiac) {
      Zodiac.ox => 136.0,
      Zodiac.horse => 142.0,
      Zodiac.pig => 132.0,
      Zodiac.dragon => 134.0,
      Zodiac.tiger => 122.0,
      Zodiac.rat || Zodiac.rabbit => 121.0,
      Zodiac.triceratops ||
      Zodiac.stegosaurus ||
      Zodiac.ankylosaurus ||
      Zodiac.pachycephalosaurus => 128.0,
      Zodiac.iguanodon => 130.0,
      Zodiac.parasaurolophus => 132.0,
      Zodiac.trex => 122.0,
      Zodiac.spinosaurus => 130.0,
      Zodiac.velociraptor || Zodiac.dilophosaurus => 122.0,
      Zodiac.brachiosaurus => 120.0,
      Zodiac.sheep => 126.0,
      _ => 116.0,
    };
    if (snout == Snout.cat) {
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
        Paint()..color = zodiac == Zodiac.sheep ? const Color(0xFF8A5A4A) : ink,
      );
    }
    switch (snout) {
      case Snout.cat:
        if (happy) {
          _mouth(c, my, 7, true);
        } else {
          // 고양이 입 "ω"
          final mouth = Path()
            ..moveTo(100, my - 5)
            ..lineTo(100, my - 1)
            ..moveTo(93, my - 2)
            ..quadraticBezierTo(96.5, my + 3, 100, my - 1)
            ..quadraticBezierTo(103.5, my + 3, 107, my - 2);
          c.drawPath(mouth, stroke(2.4, feature));
        }
      case Snout.jaw:
        if (zodiac == Zodiac.trex) {
          _toothyGrin(c, my, 36, happy, teeth: 7, big: true);
        } else {
          _toothyGrin(c, my, 24, happy, teeth: 5);
        }
      case Snout.pointy:
        _toothyGrin(c, my, 16, happy, teeth: 4);
      case Snout.duck:
        _mouth(c, my, 24, happy);
      case Snout.dinoBeak:
        _mouth(c, my, zodiac == Zodiac.iguanodon ? 10 : 14, happy, sides: true);
      default:
        _mouth(c, my, 7, happy);
    }

    if (zodiac == Zodiac.dragon) {
      // 길게 늘어진 수염
      for (final m in [-1.0, 1.0]) {
        final w = Path()
          ..moveTo(_m(m, 30, 116).dx, 116)
          ..cubicTo(
            _m(m, 52, 108).dx,
            108,
            _m(m, 60, 132).dx,
            132,
            _m(m, 80, 120).dx,
            120,
          )
          ..quadraticBezierTo(_m(m, 88, 114).dx, 114, _m(m, 86, 106).dx, 106);
        c.drawPath(w, stroke(3.0, const Color(0xFFFFD34D)));
      }
      // 작은 송곳니
      for (final m in [-1.0, 1.0]) {
        final t = Path()
          ..moveTo(_m(m, 6, my).dx - 2.5, my)
          ..lineTo(_m(m, 6, my).dx + 2.5, my)
          ..lineTo(_m(m, 6, my).dx, my + 6)
          ..close();
        c.drawPath(t, Paint()..color = Colors.white);
      }
    }
  }

  /// 웃는 입 (기쁠 때는 벌린 입)
  void _mouth(
    Canvas c,
    double my,
    double mw,
    bool happy, {
    bool sides = false,
  }) {
    final mouth = Path();
    if (happy) {
      mouth
        ..moveTo(100 - mw - 1, my - 2)
        ..quadraticBezierTo(100, my + 12, 100 + mw + 1, my - 2)
        ..close();
      c.drawPath(mouth, Paint()..color = const Color(0xFFE0707C));
    } else {
      mouth
        ..moveTo(100 - mw, my - 2)
        ..quadraticBezierTo(100, my + 5, 100 + mw, my - 2);
      c.drawPath(mouth, stroke(2.6, feature));
    }
    if (sides) {
      for (final m in [-1.0, 1.0]) {
        c.drawLine(
          _m(m, mw, my - 2),
          _m(m, mw + 3, my - 4.5),
          stroke(2.2, feature),
        );
      }
    }
  }

  /// 이빨이 보이는 넓은 웃음 (티라노·스피노·랩터·딜로포)
  void _toothyGrin(
    Canvas c,
    double my,
    double mw,
    bool happy, {
    required int teeth,
    bool big = false,
  }) {
    final open = (happy ? 12.0 : 6.0) + (big ? 4 : 0);
    final mouth = Path()
      ..moveTo(100 - mw, my - 3)
      ..quadraticBezierTo(100, my + 4, 100 + mw, my - 3)
      ..quadraticBezierTo(100, my + 4 + open * 1.4, 100 - mw, my - 3)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFFB04A4A));
    c.save();
    c.clipPath(mouth);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(100, my + 4 + open),
        width: mw * 1.1,
        height: open,
      ),
      Paint()..color = const Color(0xFFF08A90),
    );
    c.restore();
    // 윗니 (뾰족)
    for (var i = 0; i < teeth; i++) {
      final t = (i + .5) / teeth;
      final x = 100 - mw * .82 + t * mw * 1.64;
      final y = my - 3 + (1 - pow((x - 100) / mw, 2)) * 3.5;
      final tooth = Path()
        ..moveTo(x - 3, y - 1)
        ..lineTo(x + 3, y - 1)
        ..lineTo(x, y + 5)
        ..close();
      c.drawPath(tooth, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(AnimalPainter old) =>
      old.zodiac != zodiac ||
      old.items != items ||
      old.mood != mood ||
      old.phase != phase ||
      old.drawLegs != drawLegs ||
      old.drawArms != drawArms ||
      old.sideways != sideways;
}
