import 'dart:math';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import 'animal_painter.dart';

/// 꾸미기 아이템 그림 (캐릭터와 같은 플랫 만화풍).
/// 아이템 데이터의 style로 모양을 고르고 colors로 색을 칠한다.
/// 새 모양을 추가할 때는 해당 부위 switch에 style 하나를 더하면 된다.
class ItemArt {
  ItemArt(this.c);

  final Canvas c;

  static const _ink = AnimalPainter.ink;
  static const _metal = Color(0xFFC9D1DA);
  static const _gold = Color(0xFFFFCF4D);

  Color _col(Item item, int i) => item.colors[min(i, item.colors.length - 1)];

  void _fs(Path p, Color fill, {double width = 3.6}) =>
      AnimalPainter.fillStroke(c, p, fill, width: width);

  Paint _line(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Path _star(Offset center, double r, {double inner = .45}) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * inner;
      final pt = center + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// 머리 위를 덮는 반원 모자 모양
  Path _dome(double left, double right, double baseY, double topY) => Path()
    ..moveTo(left, baseY)
    ..cubicTo(left, topY, right, topY, right, baseY)
    ..close();

  // ================= 머리 =================
  void head(Item item) {
    switch (item.style) {
      case 'robothelmet':
        _fs(_dome(36, 164, 72, 0), _col(item, 0));
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(34, 62, 166, 76, const Radius.circular(7)),
          ),
          _col(item, 1),
        );
        // 볼트와 안테나
        for (final x in [52.0, 148.0]) {
          c.drawCircle(Offset(x, 69), 3.5, Paint()..color = _ink);
        }
        c.drawLine(const Offset(100, 22), const Offset(100, 6), _line(_ink, 4));
        _fs(
          Path()
            ..addOval(Rect.fromCircle(center: const Offset(100, 6), radius: 7)),
          _col(item, 2),
          width: 3.5,
        );
        c.drawArc(
          const Rect.fromLTRB(60, 26, 100, 60),
          pi * 1.15,
          pi * .3,
          false,
          _line(Colors.white.withValues(alpha: .7), 4),
        );
      case 'crown':
        final crown = Path()
          ..moveTo(70, 50)
          ..lineTo(66, 16)
          ..lineTo(84, 32)
          ..lineTo(100, 8)
          ..lineTo(116, 32)
          ..lineTo(134, 16)
          ..lineTo(130, 50)
          ..close();
        _fs(crown, _col(item, 0));
        c.drawCircle(const Offset(100, 36), 6, Paint()..color = _col(item, 1));
        c.drawCircle(const Offset(80, 42), 4, Paint()..color = _col(item, 2));
        c.drawCircle(const Offset(120, 42), 4, Paint()..color = _col(item, 2));
      case 'firehelmet':
        // 뒤로 길게 내려오는 챙
        _fs(
          Path()..addOval(
            Rect.fromCenter(
              center: const Offset(100, 64),
              width: 170,
              height: 30,
            ),
          ),
          Color.lerp(_col(item, 0), Colors.black, .12)!,
        );
        _fs(_dome(42, 158, 64, 2), _col(item, 0));
        c.drawLine(
          const Offset(100, 18),
          const Offset(100, 60),
          _line(Color.lerp(_col(item, 0), Colors.black, .2)!, 6),
        );
        // 앞 방패 휘장
        final shield = Path()
          ..moveTo(84, 30)
          ..lineTo(116, 30)
          ..lineTo(114, 50)
          ..quadraticBezierTo(100, 62, 86, 50)
          ..close();
        _fs(shield, _col(item, 1), width: 4);
        c.drawPath(
          _star(const Offset(100, 42), 7),
          Paint()..color = _col(item, 0),
        );
      case 'policecap':
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(40, 54, 160, 70, const Radius.circular(8)),
          ),
          _ink,
        );
        final top = Path()
          ..moveTo(44, 56)
          ..cubicTo(40, 18, 160, 18, 156, 56)
          ..close();
        _fs(top, _col(item, 0));
        c.drawRect(
          const Rect.fromLTRB(46, 46, 154, 54),
          Paint()..color = _col(item, 1),
        );
        _fs(_star(const Offset(100, 38), 10), _gold, width: 3);
      case 'armyhelmet':
        final dome = _dome(34, 166, 70, -6);
        _fs(dome, _col(item, 0));
        c.save();
        c.clipPath(dome);
        for (final o in const [
          Offset(64, 40),
          Offset(110, 24),
          Offset(140, 52),
          Offset(92, 56),
        ]) {
          c.drawOval(
            Rect.fromCenter(center: o, width: 26, height: 14),
            Paint()..color = _col(item, 1),
          );
        }
        c.restore();
        c.drawPath(dome, _line(_ink, 3.6));
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(30, 64, 170, 76, const Radius.circular(6)),
          ),
          Color.lerp(_col(item, 0), Colors.black, .15)!,
        );
      case 'bonehead':
        // 머리띠 + 뼈다귀
        c.drawArc(
          const Rect.fromLTRB(32, 30, 168, 130),
          pi * 1.05,
          pi * .9,
          false,
          _line(_ink, 13),
        );
        c.drawArc(
          const Rect.fromLTRB(32, 30, 168, 130),
          pi * 1.05,
          pi * .9,
          false,
          _line(_col(item, 1), 7),
        );
        var merged = Path()
          ..addRRect(
            RRect.fromLTRBR(74, 18, 126, 30, const Radius.circular(6)),
          );
        for (final o in const [
          Offset(72, 18),
          Offset(72, 30),
          Offset(128, 18),
          Offset(128, 30),
        ]) {
          merged = Path.combine(
            PathOperation.union,
            merged,
            Path()..addOval(Rect.fromCircle(center: o, radius: 8)),
          );
        }
        _fs(merged, _col(item, 0), width: 4);
      default:
        _headMore(item);
    }
  }

  // ================= 옷 =================
  void outfit(Item item, {required bool happy}) {
    final torsoPath = AnimalPainter.torsoPath;
    switch (item.style) {
      case 'robot':
        final body = Path()
          ..addRRect(
            RRect.fromLTRBR(62, 140, 138, 210, const Radius.circular(14)),
          );
        _fs(body, _col(item, 0));
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(80, 156, 120, 186, const Radius.circular(6)),
          ),
          _col(item, 1),
          width: 3.2,
        );
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            Offset(90 + i * 10.0, 171),
            3.5,
            Paint()..color = i == 1 ? _col(item, 2) : Colors.white,
          );
        }
        for (final o in const [
          Offset(70, 150),
          Offset(130, 150),
          Offset(70, 200),
          Offset(130, 200),
        ]) {
          c.drawCircle(o, 3, Paint()..color = _ink);
        }
        _sleeves(happy, _col(item, 0), square: true);
      case 'dress':
        final skirt = Path()
          ..moveTo(70, 176)
          ..lineTo(130, 176)
          ..quadraticBezierTo(146, 196, 152, 220)
          ..quadraticBezierTo(100, 228, 48, 220)
          ..quadraticBezierTo(54, 196, 70, 176)
          ..close();
        _fs(skirt, _col(item, 0));
        final frill = Path();
        for (var x = 52.0; x <= 148; x += 12) {
          frill.addOval(
            Rect.fromCenter(center: Offset(x, 220), width: 14, height: 9),
          );
        }
        _fs(frill, _col(item, 1), width: 3);
        final bodice = Path()
          ..addRRect(
            RRect.fromLTRBAndCorners(
              66,
              140,
              134,
              180,
              topLeft: const Radius.circular(26),
              topRight: const Radius.circular(26),
            ),
          );
        _fs(bodice, _col(item, 0));
        final bow = Path()
          ..moveTo(100, 178)
          ..lineTo(87, 170)
          ..lineTo(87, 186)
          ..close()
          ..moveTo(100, 178)
          ..lineTo(113, 170)
          ..lineTo(113, 186)
          ..close();
        _fs(bow, _col(item, 2), width: 3);
        _sleeves(happy, _col(item, 1), puff: true);
      case 'firesuit':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        for (final y in [176.0, 196.0]) {
          c.drawRect(
            Rect.fromLTWH(60, y, 80, 8),
            Paint()..color = _col(item, 1),
          );
          c.drawRect(
            Rect.fromLTWH(60, y + 2.5, 80, 3),
            Paint()..color = Colors.white.withValues(alpha: .8),
          );
        }
        c.drawLine(
          const Offset(100, 140),
          const Offset(100, 212),
          _line(_ink, 3),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        // 옷깃
        final collar = Path()
          ..moveTo(82, 142)
          ..lineTo(100, 158)
          ..lineTo(118, 142)
          ..close();
        _fs(collar, Color.lerp(_col(item, 0), Colors.black, .15)!, width: 3.5);
        _sleeves(happy, _col(item, 0), stripe: _col(item, 1));
      case 'police':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        // 넥타이와 단추
        final tie = Path()
          ..moveTo(96, 146)
          ..lineTo(104, 146)
          ..lineTo(106, 176)
          ..lineTo(100, 182)
          ..lineTo(94, 176)
          ..close();
        c.drawPath(tie, Paint()..color = _col(item, 1));
        c.drawRect(const Rect.fromLTWH(60, 196, 80, 8), Paint()..color = _ink);
        c.drawRect(
          const Rect.fromLTWH(94, 195, 12, 10),
          Paint()..color = _gold,
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        for (final m in [-1.0, 1.0]) {
          final collar = Path()
            ..moveTo(100 + m * 2, 142)
            ..lineTo(100 + m * 18, 142)
            ..lineTo(100 + m * 10, 158)
            ..close();
          _fs(collar, Colors.white, width: 3);
          // 가슴 주머니
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                100 + m * 26 - 9,
                160,
                100 + m * 26 + 9,
                174,
                const Radius.circular(3),
              ),
            ),
            Color.lerp(_col(item, 0), Colors.white, .15)!,
            width: 3,
          );
        }
        _sleeves(happy, _col(item, 0));
      case 'camo':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        for (final (o, color) in [
          (const Offset(74, 152), _col(item, 1)),
          (const Offset(118, 160), _col(item, 2)),
          (const Offset(90, 184), _col(item, 1)),
          (const Offset(128, 196), _col(item, 2)),
          (const Offset(70, 200), _col(item, 2)),
        ]) {
          c.drawOval(
            Rect.fromCenter(center: o, width: 30, height: 16),
            Paint()..color = color,
          );
        }
        c.drawRect(
          const Rect.fromLTWH(60, 194, 80, 8),
          Paint()..color = const Color(0xFF5C4A32),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        for (final m in [-1.0, 1.0]) {
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                100 + m * 20 - 10,
                156,
                100 + m * 20 + 10,
                172,
                const Radius.circular(3),
              ),
            ),
            _col(item, 0),
            width: 3,
          );
        }
        _sleeves(happy, _col(item, 0), stripe: _col(item, 1));
      case 'caveman':
        // 한쪽 어깨 표범 무늬 옷 (아래가 들쭉날쭉)
        final tunic = Path()
          ..moveTo(70, 150)
          ..lineTo(118, 140)
          ..lineTo(136, 160)
          ..lineTo(136, 204)
          ..lineTo(126, 214)
          ..lineTo(116, 204)
          ..lineTo(106, 216)
          ..lineTo(96, 204)
          ..lineTo(86, 216)
          ..lineTo(76, 204)
          ..lineTo(64, 212)
          ..lineTo(64, 168)
          ..close();
        _fs(tunic, _col(item, 0));
        c.save();
        c.clipPath(tunic);
        for (final o in const [
          Offset(84, 166),
          Offset(110, 158),
          Offset(122, 186),
          Offset(92, 192),
          Offset(74, 184),
          Offset(112, 204),
        ]) {
          c.drawOval(
            Rect.fromCenter(center: o, width: 10, height: 8),
            Paint()..color = _col(item, 1),
          );
        }
        c.restore();
        c.drawPath(tunic, _line(_ink, 3.6));
      default:
        _outfitMore(item, happy: happy, torsoPath: torsoPath);
    }
  }

  /// 팔 윗부분을 덮는 소매 (팔 자세와 맞춰 회전)
  /// 팔을 탈것 그림에서 따로 그릴 때는 소매도 그리지 않는다
  bool sleeves = true;

  void _sleeves(
    bool happy,
    Color color, {
    Color? stripe,
    bool puff = false,
    bool square = false,
  }) {
    if (!sleeves) return;
    for (final left in [true, false]) {
      final (center, rot) = AnimalPainter.armPose(left, happy);
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(rot);
      if (puff) {
        _fs(
          Path()..addOval(
            Rect.fromCenter(
              center: const Offset(0, -12),
              width: 28,
              height: 20,
            ),
          ),
          color,
          width: 3.5,
        );
      } else {
        final r = square ? 4.0 : 9.0;
        _fs(
          Path()
            ..addRRect(RRect.fromLTRBR(-11, -19, 11, 4, Radius.circular(r))),
          color,
          width: 3.2,
        );
        if (stripe != null) {
          c.drawLine(
            const Offset(-8, -3),
            const Offset(8, -3),
            _line(stripe, 4),
          );
        }
      }
      c.restore();
    }
  }

  // ================= 신발 =================
  void shoes(Item item) {
    for (final x in [86.0, 114.0]) {
      switch (item.style) {
        case 'robotboots':
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                x - 13,
                200,
                x + 13,
                230,
                const Radius.circular(5),
              ),
            ),
            _col(item, 0),
          );
          c.drawLine(
            Offset(x - 10, 214),
            Offset(x + 10, 214),
            _line(_col(item, 1), 4),
          );
        case 'boots':
          final boot = Path()
            ..addRRect(
              RRect.fromLTRBAndCorners(
                x - 12,
                198,
                x + 12,
                230,
                topLeft: const Radius.circular(4),
                topRight: const Radius.circular(4),
                bottomLeft: const Radius.circular(10),
                bottomRight: const Radius.circular(10),
              ),
            );
          _fs(boot, _col(item, 0));
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                x - 14,
                196,
                x + 14,
                204,
                const Radius.circular(4),
              ),
            ),
            _col(item, 1),
            width: 3.5,
          );
        case 'magic': // 유리 구두
          final shoe = Path()
            ..addRRect(
              RRect.fromLTRBR(
                x - 13,
                212,
                x + 13,
                230,
                const Radius.circular(9),
              ),
            );
          c.drawPath(
            shoe,
            Paint()..color = _col(item, 0).withValues(alpha: .85),
          );
          c.drawPath(shoe, _line(_ink, 4));
          c.drawPath(_star(Offset(x, 221), 5), Paint()..color = _col(item, 1));
          c.drawLine(
            Offset(x - 7, 216),
            Offset(x - 2, 216),
            _line(Colors.white, 2.5),
          );
        case 'loafer':
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                x - 13,
                212,
                x + 13,
                230,
                const Radius.circular(9),
              ),
            ),
            _col(item, 0),
          );
          c.drawLine(
            Offset(x - 6, 217),
            Offset(x + 6, 217),
            _line(Colors.white.withValues(alpha: .5), 2.5),
          );
        case 'sandal':
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                x - 13,
                206,
                x + 13,
                230,
                const Radius.circular(10),
              ),
            ),
            _col(item, 0),
          );
          c.drawLine(
            Offset(x - 11, 213),
            Offset(x + 11, 219),
            _line(_col(item, 1), 4),
          );
          c.drawLine(
            Offset(x - 11, 222),
            Offset(x + 11, 216),
            _line(_col(item, 1), 4),
          );
        default:
          _shoeMore(item, x);
      }
    }
  }

  // ================= 장식 =================
  void accessory(Item item) {
    switch (item.style) {
      case 'visor':
        final band = Path()
          ..addRRect(
            RRect.fromLTRBR(52, 82, 148, 106, const Radius.circular(12)),
          );
        c.drawPath(band, Paint()..color = _col(item, 0).withValues(alpha: .7));
        c.drawPath(band, _line(_ink, 4));
        c.drawLine(
          const Offset(62, 90),
          const Offset(84, 90),
          _line(Colors.white.withValues(alpha: .8), 3),
        );
      case 'ribbon':
        const o = Offset(62, 44);
        final bow = Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx - 22, o.dy - 20, o.dx - 22, o.dy + 2)
          ..quadraticBezierTo(o.dx - 20, o.dy + 16, o.dx, o.dy)
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx + 22, o.dy - 20, o.dx + 22, o.dy + 2)
          ..quadraticBezierTo(o.dx + 20, o.dy + 16, o.dx, o.dy);
        _fs(bow, _col(item, 0), width: 3.5);
        _fs(
          Path()..addOval(Rect.fromCircle(center: o, radius: 6)),
          _col(item, 1),
          width: 3,
        );
      case 'badge':
        _fs(_star(const Offset(80, 164), 11), _col(item, 0), width: 3);
        c.drawCircle(
          const Offset(80, 165),
          3.5,
          Paint()..color = _col(item, 1),
        );
      case 'dogtag':
        c.drawPath(
          Path()
            ..moveTo(78, 142)
            ..quadraticBezierTo(100, 168, 122, 142),
          _line(_col(item, 0), 2.5),
        );
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(92, 154, 104, 172, const Radius.circular(4)),
          ),
          _col(item, 1),
          width: 3,
        );
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(100, 156, 112, 174, const Radius.circular(4)),
          ),
          _col(item, 1),
          width: 3,
        );
      case 'tooth':
        c.drawPath(
          Path()
            ..moveTo(76, 142)
            ..quadraticBezierTo(100, 170, 124, 142),
          _line(_col(item, 1), 3),
        );
        for (final t in [.25, .5, .75]) {
          final x = 76 + 48 * t;
          final y = 142 + 4 * t * (1 - t) * 28;
          final tooth = Path()
            ..moveTo(x - 5, y)
            ..lineTo(x + 5, y)
            ..lineTo(x, y + 13)
            ..close();
          _fs(tooth, _col(item, 0), width: 3);
        }
      case 'necklace':
        _fs(_star(const Offset(100, 162), 10), _col(item, 0), width: 3);
      default:
        _accessoryMore(item);
    }
  }

  // ================= 등 =================
  void backBehind(Item item) {
    switch (item.style) {
      case 'wings':
        for (final m in [-1.0, 1.0]) {
          Offset o(double dx, double dy) => Offset(100 + m * dx, dy);
          final wing = Path()
            ..moveTo(o(30, 160).dx, o(30, 160).dy)
            ..cubicTo(
              o(66, 104).dx,
              o(66, 104).dy,
              o(100, 114).dx,
              o(100, 114).dy,
              o(90, 146).dx,
              o(90, 146).dy,
            )
            ..cubicTo(
              o(100, 168).dx,
              o(100, 168).dy,
              o(76, 194).dx,
              o(76, 194).dy,
              o(30, 176).dx,
              o(30, 176).dy,
            )
            ..close();
          _fs(wing, _col(item, 0));
          c.drawPath(
            Path()
              ..moveTo(o(42, 160).dx, o(42, 160).dy)
              ..quadraticBezierTo(
                o(74, 124).dx,
                o(74, 124).dy,
                o(86, 142).dx,
                o(86, 142).dy,
              ),
            _line(_col(item, 1), 5),
          );
        }
      case 'jetpack':
      case 'firetank':
        for (final x in [48.0, 152.0]) {
          if (item.style == 'jetpack') {
            final flame = Path()
              ..moveTo(x - 8, 196)
              ..quadraticBezierTo(x, 222, x + 8, 196)
              ..close();
            _fs(flame, _col(item, 2), width: 3);
          }
          _fs(
            Path()..addRRect(
              RRect.fromLTRBR(
                x - 13,
                134,
                x + 13,
                198,
                const Radius.circular(12),
              ),
            ),
            _col(item, 0),
          );
          if (item.style == 'jetpack') {
            final cone = Path()
              ..moveTo(x - 13, 140)
              ..quadraticBezierTo(x, 110, x + 13, 140)
              ..close();
            _fs(cone, _col(item, 1));
          } else {
            _fs(
              Path()..addRRect(
                RRect.fromLTRBR(
                  x - 6,
                  124,
                  x + 6,
                  136,
                  const Radius.circular(3),
                ),
              ),
              _metal,
              width: 3.5,
            );
            c.drawLine(
              Offset(x - 9, 176),
              Offset(x + 9, 176),
              _line(_col(item, 1), 4),
            );
          }
        }
      case 'backpack':
        _fs(
          Path()..addRRect(
            RRect.fromLTRBR(42, 140, 158, 204, const Radius.circular(20)),
          ),
          _col(item, 0),
        );
        c.drawLine(
          const Offset(48, 186),
          const Offset(62, 186),
          _line(_col(item, 1), 5),
        );
        c.drawLine(
          const Offset(138, 186),
          const Offset(152, 186),
          _line(_col(item, 1), 5),
        );
      case 'club':
        c.save();
        c.translate(150, 150);
        c.rotate(.5);
        final club = Path()
          ..moveTo(-6, 50)
          ..lineTo(6, 50)
          ..lineTo(14, -30)
          ..quadraticBezierTo(0, -48, -14, -30)
          ..close();
        _fs(club, _col(item, 0));
        for (final o in const [
          Offset(-4, -24),
          Offset(6, -12),
          Offset(-2, 0),
        ]) {
          c.drawCircle(o, 2.5, Paint()..color = _col(item, 1));
        }
        c.restore();
      default:
        _backMore(item);
    }
  }

  /// 몸 앞에 오는 부분 (가방끈, 벨트, 호스)
  void backFront(Item item) {
    switch (item.style) {
      case 'backpack':
        final strap = _line(Color.lerp(_col(item, 0), Colors.black, .2)!, 7);
        c.drawLine(const Offset(78, 144), const Offset(82, 196), strap);
        c.drawLine(const Offset(122, 144), const Offset(118, 196), strap);
      case 'jetpack':
        c.drawLine(
          const Offset(68, 158),
          const Offset(132, 158),
          _line(Color.lerp(_col(item, 0), Colors.black, .25)!, 6),
        );
      case 'firetank':
        final hose = Path()
          ..moveTo(146, 134)
          ..quadraticBezierTo(150, 112, 124, 150)
          ..quadraticBezierTo(110, 168, 116, 180);
        c.drawPath(hose, _line(_ink, 8));
        c.drawPath(hose, _line(const Color(0xFF6E6E6E), 4));
      case 'veggiebasket':
        final strap = _line(Color.lerp(_col(item, 0), Colors.black, .3)!, 6);
        c.drawLine(const Offset(78, 144), const Offset(82, 196), strap);
        c.drawLine(const Offset(122, 144), const Offset(118, 196), strap);
      case 'cape':
        // 망토 끈과 단추
        c.drawLine(
          const Offset(70, 146),
          const Offset(130, 146),
          _line(_col(item, 0), 5),
        );
        for (final x in [72.0, 128.0]) {
          _fs(
            Path()..addOval(Rect.fromCircle(center: Offset(x, 146), radius: 6)),
            _col(item, 1),
            width: 3,
          );
        }
    }
  }

  // ================= 추가 테마 (우주비행사·의사·요리사·농부·기관사·해적·마법사·공룡·히어로·축구·발레) =================

  Color _dark(Color c, [double t = .2]) => Color.lerp(c, Colors.black, t)!;
  Color _light(Color c, [double t = .4]) => Color.lerp(c, Colors.white, t)!;

  Path _rr(double l, double t, double r, double b, double rad) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

  void _headMore(Item item) {
    switch (item.style) {
      case 'spacehelmet':
        // 투명한 유리 헬멧 + 목 링
        const bubble = Rect.fromLTRB(16, 4, 184, 160);
        c.drawOval(
          bubble,
          Paint()..color = _col(item, 0).withValues(alpha: .22),
        );
        c.drawArc(
          bubble.deflate(14),
          pi * 1.08,
          pi * .32,
          false,
          _line(Colors.white.withValues(alpha: .9), 7),
        );
        c.drawArc(
          bubble.deflate(14),
          pi * 1.47,
          pi * .05,
          false,
          _line(Colors.white.withValues(alpha: .9), 7),
        );
        c.drawOval(bubble, _line(_ink, 3.6));
        _fs(_rr(50, 140, 150, 158, 9), _col(item, 1));
        for (final x in [66.0, 100.0, 134.0]) {
          c.drawCircle(
            Offset(x, 149),
            3,
            Paint()..color = _dark(_col(item, 1), .35),
          );
        }
      case 'doctorcap':
        // 머리띠 + 동그란 머리거울
        c.drawArc(
          const Rect.fromLTRB(30, 30, 170, 132),
          pi * 1.05,
          pi * .9,
          false,
          _line(_ink, 12),
        );
        c.drawArc(
          const Rect.fromLTRB(30, 30, 170, 132),
          pi * 1.05,
          pi * .9,
          false,
          _line(_col(item, 0), 6),
        );
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(100, 34), radius: 19),
          ),
          _col(item, 1),
        );
        c.drawCircle(
          const Offset(100, 34),
          10,
          Paint()..color = _light(_col(item, 1), .7),
        );
        c.drawCircle(const Offset(96, 30), 3.5, Paint()..color = Colors.white);
      case 'chefhat':
        var puff = Path()
          ..addRRect(
            RRect.fromLTRBR(62, 30, 138, 66, const Radius.circular(6)),
          );
        for (final (o, r) in const [
          (Offset(70, 28), 21.0),
          (Offset(100, 16), 26.0),
          (Offset(130, 28), 21.0),
        ]) {
          puff = Path.combine(
            PathOperation.union,
            puff,
            Path()..addOval(Rect.fromCircle(center: o, radius: r)),
          );
        }
        _fs(puff, _col(item, 0));
        c.drawLine(
          const Offset(84, 22),
          const Offset(86, 40),
          _line(_col(item, 1), 3),
        );
        c.drawLine(
          const Offset(116, 22),
          const Offset(114, 40),
          _line(_col(item, 1), 3),
        );
        _fs(_rr(60, 52, 140, 68, 5), _col(item, 0), width: 4);
        c.drawLine(
          const Offset(64, 60),
          const Offset(136, 60),
          _line(_col(item, 1), 2.5),
        );
      case 'strawhat':
        final brim = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 58),
              width: 186,
              height: 36,
            ),
          );
        _fs(brim, _col(item, 0));
        final crown = _dome(58, 142, 60, 0);
        _fs(crown, _col(item, 0));
        c.save();
        c.clipPath(crown);
        for (var y = 18.0; y < 60; y += 9) {
          c.drawLine(
            Offset(50, y),
            Offset(150, y + 4),
            _line(_dark(_col(item, 0), .15), 2),
          );
        }
        c.drawRect(
          const Rect.fromLTRB(50, 40, 150, 52),
          Paint()..color = _col(item, 1),
        );
        c.restore();
        c.drawPath(crown, _line(_ink, 3.6));
        c.drawArc(
          const Rect.fromLTRB(20, 46, 180, 72),
          pi * .15,
          pi * .7,
          false,
          _line(_dark(_col(item, 0), .15), 2.5),
        );
      case 'conductorcap':
        final crown = Path()
          ..moveTo(50, 64)
          ..cubicTo(44, 12, 156, 12, 150, 64)
          ..close();
        _fs(crown, _col(item, 0));
        c.save();
        c.clipPath(crown);
        for (var x = 54.0; x < 150; x += 12) {
          c.drawLine(Offset(x, 10), Offset(x, 66), _line(_col(item, 1), 4));
        }
        c.restore();
        c.drawPath(crown, _line(_ink, 3.6));
        final peak = Path()
          ..moveTo(56, 62)
          ..quadraticBezierTo(100, 86, 144, 62)
          ..close();
        _fs(peak, _dark(_col(item, 0), .25), width: 4);
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(100, 24), radius: 6),
          ),
          _col(item, 0),
          width: 3,
        );
      case 'piratehat':
        final hat = Path()
          ..moveTo(22, 66)
          ..cubicTo(34, 4, 166, 4, 178, 66)
          ..quadraticBezierTo(100, 46, 22, 66)
          ..close();
        _fs(hat, _col(item, 0));
        c.drawPath(
          Path()
            ..moveTo(30, 60)
            ..quadraticBezierTo(100, 42, 170, 60),
          _line(_col(item, 1), 4),
        );
        // 뼈다귀 X + 동그란 얼굴 (귀엽게)
        for (final a in [.6, -.6]) {
          c.save();
          c.translate(100, 34);
          c.rotate(a);
          _fs(_rr(-14, -3, 14, 3, 3), _col(item, 2), width: 2.5);
          c.restore();
        }
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(100, 28), radius: 8),
          ),
          _col(item, 2),
          width: 2.5,
        );
        c.drawCircle(const Offset(97, 27), 1.6, Paint()..color = _ink);
        c.drawCircle(const Offset(103, 27), 1.6, Paint()..color = _ink);
      case 'wizardhat':
        final brim = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 60),
              width: 172,
              height: 26,
            ),
          );
        _fs(brim, _col(item, 0));
        final cone = Path()
          ..moveTo(60, 60)
          ..lineTo(92, 8)
          ..quadraticBezierTo(108, -10, 134, -2)
          ..lineTo(116, 12)
          ..lineTo(140, 60)
          ..close();
        _fs(cone, _col(item, 0));
        c.save();
        c.clipPath(cone);
        c.drawRect(
          const Rect.fromLTRB(50, 44, 150, 56),
          Paint()..color = _col(item, 1),
        );
        c.restore();
        c.drawPath(cone, _line(_ink, 3.6));
        _fs(_star(const Offset(96, 30), 8), _col(item, 1), width: 2.5);
        _fs(_star(const Offset(118, 40), 5), _col(item, 1), width: 2);
        c.drawCircle(const Offset(80, 44), 3, Paint()..color = _col(item, 1));
      case 'dinohood':
        // 얼굴이 보이는 공룡 모자 (등에 뿔)
        final outer = _dome(26, 174, 112, -6);
        final hole = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 104),
              width: 126,
              height: 96,
            ),
          );
        final hood = Path.combine(PathOperation.difference, outer, hole);
        for (var i = 0; i < 5; i++) {
          final t = .2 + i * .15;
          final x = 26 + 148 * t;
          final y = 112 - 4 * t * (1 - t) * 118 - 2;
          final spike = Path()
            ..moveTo(x - 9, y + 4)
            ..lineTo(x, y - 14)
            ..lineTo(x + 9, y + 4)
            ..close();
          _fs(spike, _col(item, 1), width: 3);
        }
        _fs(hood, _col(item, 0));
        for (final x in [74.0, 126.0]) {
          _fs(
            Path()..addOval(Rect.fromCircle(center: Offset(x, 26), radius: 10)),
            Colors.white,
            width: 3,
          );
          c.drawCircle(Offset(x + 1, 27), 4.5, Paint()..color = _ink);
        }
        c.drawArc(
          const Rect.fromLTRB(84, 34, 116, 50),
          .2,
          pi - .4,
          false,
          _line(_ink, 3),
        );
      case 'headband':
        _fs(_rr(32, 52, 168, 70, 8), _col(item, 0));
        c.drawLine(
          const Offset(38, 61),
          const Offset(162, 61),
          _line(_col(item, 1), 4),
        );
      case 'tiara':
        final tiara = Path()
          ..moveTo(68, 52)
          ..quadraticBezierTo(100, 42, 132, 52)
          ..lineTo(126, 32)
          ..lineTo(114, 40)
          ..lineTo(100, 16)
          ..lineTo(86, 40)
          ..lineTo(74, 32)
          ..close();
        _fs(tiara, _col(item, 0), width: 4);
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(100, 36), radius: 6),
          ),
          _col(item, 1),
          width: 2.5,
        );
        for (final x in [80.0, 120.0]) {
          c.drawCircle(Offset(x, 44), 3.2, Paint()..color = _col(item, 1));
        }
        c.drawCircle(const Offset(98, 33), 2, Paint()..color = Colors.white);
    }
  }

  void _outfitMore(Item item, {required bool happy, required Path torsoPath}) {
    switch (item.style) {
      case 'spacesuit':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        c.drawRect(
          const Rect.fromLTWH(60, 194, 80, 9),
          Paint()..color = _col(item, 2),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        _fs(_rr(80, 154, 120, 182, 6), _col(item, 1), width: 3.5);
        for (final (i, col) in const [
          (0, Color(0xFFF26B5E)),
          (1, Color(0xFFFFCF4D)),
          (2, Color(0xFF5B9BE6)),
        ]) {
          c.drawCircle(Offset(90 + i * 10.0, 163), 3.5, Paint()..color = col);
        }
        c.drawLine(
          const Offset(86, 174),
          const Offset(114, 174),
          _line(_dark(_col(item, 1), .3), 3),
        );
        // 어깨 깃발 패치
        _fs(_rr(66, 150, 78, 158, 2), _col(item, 2), width: 2.5);
        _sleeves(happy, _col(item, 0), stripe: _col(item, 2));
      case 'doctorcoat':
        _fs(torsoPath, _col(item, 1));
        for (final m in [-1.0, 1.0]) {
          final panel = Path()
            ..moveTo(100 + m * 4, 144)
            ..lineTo(100 + m * 36, 142)
            ..quadraticBezierTo(100 + m * 40, 180, 100 + m * 38, 218)
            ..lineTo(100 + m * 6, 218)
            ..close();
          _fs(panel, _col(item, 0), width: 4);
          // 옷깃
          final lapel = Path()
            ..moveTo(100 + m * 4, 144)
            ..lineTo(100 + m * 20, 142)
            ..lineTo(100 + m * 12, 166)
            ..close();
          _fs(lapel, _dark(_col(item, 0), .06), width: 3);
          // 주머니
          _fs(
            _rr(100 + m * 26 - 9, 188, 100 + m * 26 + 9, 202, 3),
            _col(item, 0),
            width: 3,
          );
        }
        // 펜
        c.drawLine(
          const Offset(122, 182),
          const Offset(122, 192),
          _line(_col(item, 2), 4),
        );
        _sleeves(happy, _col(item, 0));
      case 'chefcoat':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        c.drawLine(
          const Offset(84, 146),
          const Offset(118, 212),
          _line(_dark(_col(item, 0), .12), 3),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        for (final x in [88.0, 112.0]) {
          for (final y in [166.0, 182.0, 198.0]) {
            c.drawCircle(Offset(x, y), 3.3, Paint()..color = _col(item, 2));
          }
        }
        // 목 스카프
        final scarf = Path()
          ..moveTo(80, 142)
          ..lineTo(120, 142)
          ..lineTo(104, 160)
          ..lineTo(100, 158)
          ..close();
        _fs(scarf, _col(item, 1), width: 3.5);
        _sleeves(happy, _col(item, 0));
      case 'overalls':
        // 체크 셔츠
        _fs(torsoPath, _col(item, 1));
        c.save();
        c.clipPath(torsoPath);
        final check = Paint()
          ..color = _col(item, 2).withValues(alpha: .45)
          ..strokeWidth = 3;
        for (var x = 64.0; x < 140; x += 10) {
          c.drawLine(Offset(x, 140), Offset(x, 212), check);
        }
        for (var y = 144.0; y < 212; y += 10) {
          c.drawLine(Offset(60, y), Offset(140, y), check);
        }
        // 멜빵바지
        final denim = _col(item, 0);
        c.drawRect(
          const Rect.fromLTRB(60, 186, 140, 214),
          Paint()..color = denim,
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        _fs(_rr(78, 156, 122, 192, 6), denim, width: 4);
        c.drawLine(
          const Offset(62, 188),
          const Offset(78, 188),
          _line(_ink, 3.5),
        );
        c.drawLine(
          const Offset(122, 188),
          const Offset(138, 188),
          _line(_ink, 3.5),
        );
        _fs(_rr(90, 164, 110, 178, 3), _light(denim, .15), width: 2.5);
        for (final (a, b) in const [
          (Offset(72, 142), Offset(82, 160)),
          (Offset(128, 142), Offset(118, 160)),
        ]) {
          c.drawLine(a, b, _line(_ink, 10));
          c.drawLine(a, b, _line(denim, 5));
          c.drawCircle(b, 3.5, Paint()..color = const Color(0xFFFFCF4D));
        }
        _sleeves(happy, _col(item, 1));
      case 'conductor':
        _fs(torsoPath, _col(item, 1));
        c.save();
        c.clipPath(torsoPath);
        for (var x = 66.0; x < 140; x += 12) {
          c.drawLine(Offset(x, 140), Offset(x, 212), _line(_col(item, 0), 4));
        }
        c.drawRect(
          const Rect.fromLTWH(60, 196, 80, 8),
          Paint()..color = _dark(_col(item, 0), .3),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        // 빨간 목수건
        final scarf = Path()
          ..moveTo(78, 142)
          ..lineTo(122, 142)
          ..lineTo(100, 166)
          ..close();
        _fs(scarf, _col(item, 2), width: 3.5);
        c.drawCircle(
          const Offset(100, 146),
          5,
          Paint()..color = _dark(_col(item, 2), .2),
        );
        for (final y in [176.0, 188.0]) {
          c.drawCircle(
            Offset(100, y),
            3,
            Paint()..color = const Color(0xFFFFCF4D),
          );
        }
        _sleeves(happy, _col(item, 0));
      case 'pirate':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        for (var y = 150.0; y < 212; y += 12) {
          c.drawRect(
            Rect.fromLTWH(60, y, 80, 5),
            Paint()..color = _col(item, 1),
          );
        }
        // 조끼
        for (final m in [-1.0, 1.0]) {
          final vest = Path()
            ..moveTo(100 + m * 12, 140)
            ..lineTo(100 + m * 42, 140)
            ..lineTo(100 + m * 42, 214)
            ..lineTo(100 + m * 18, 214)
            ..close();
          c.drawPath(vest, Paint()..color = _col(item, 2));
          c.drawPath(vest, _line(_ink, 3));
        }
        c.drawRect(const Rect.fromLTWH(60, 192, 80, 9), Paint()..color = _ink);
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        _fs(_rr(92, 190, 108, 203, 3), const Color(0xFFFFCF4D), width: 3);
        _sleeves(happy, _col(item, 0), stripe: _col(item, 1));
      case 'robe':
        final robe = Path()
          ..moveTo(68, 142)
          ..lineTo(132, 142)
          ..quadraticBezierTo(150, 186, 156, 226)
          ..quadraticBezierTo(100, 234, 44, 226)
          ..quadraticBezierTo(50, 186, 68, 142)
          ..close();
        _fs(robe, _col(item, 0));
        c.save();
        c.clipPath(robe);
        for (final o in const [
          Offset(72, 200),
          Offset(124, 172),
          Offset(132, 214),
          Offset(88, 222),
          Offset(78, 166),
        ]) {
          c.drawPath(_star(o, 5.5), Paint()..color = _col(item, 1));
        }
        c.restore();
        c.drawPath(robe, _line(_ink, 3.6));
        // 허리 끈과 깃
        c.drawLine(
          const Offset(70, 190),
          const Offset(130, 190),
          _line(_col(item, 1), 5),
        );
        final collar = Path()
          ..moveTo(84, 142)
          ..lineTo(100, 162)
          ..lineTo(116, 142)
          ..close();
        _fs(collar, _dark(_col(item, 0), .2), width: 3);
        _sleeves(happy, _col(item, 0), puff: true);
      case 'dinosuit':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        final belly = Rect.fromCenter(
          center: const Offset(100, 184),
          width: 46,
          height: 58,
        );
        c.drawOval(belly, Paint()..color = _col(item, 1));
        for (var y = 166.0; y < 206; y += 10) {
          c.drawLine(
            Offset(84, y),
            Offset(116, y),
            _line(_dark(_col(item, 1), .15), 2.5),
          );
        }
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        _sleeves(happy, _col(item, 0));
      case 'hero':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        c.drawRect(
          const Rect.fromLTWH(60, 194, 80, 9),
          Paint()..color = _col(item, 1),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        _fs(_rr(92, 192, 108, 205, 3), _col(item, 2), width: 3);
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(100, 168), radius: 15),
          ),
          _col(item, 2),
          width: 3.5,
        );
        _fs(_star(const Offset(100, 168), 10), _col(item, 1), width: 2.5);
        _sleeves(happy, _col(item, 0), stripe: _col(item, 1));
      case 'jersey':
        _fs(torsoPath, _col(item, 0));
        c.save();
        c.clipPath(torsoPath);
        for (final x in [62.0, 134.0]) {
          c.drawRect(
            Rect.fromLTWH(x, 140, 4, 60),
            Paint()..color = _col(item, 1),
          );
        }
        // 반바지
        c.drawRect(
          const Rect.fromLTRB(60, 196, 140, 216),
          Paint()..color = _col(item, 2),
        );
        c.drawLine(
          const Offset(100, 200),
          const Offset(100, 216),
          _line(_ink, 3),
        );
        c.restore();
        c.drawPath(torsoPath, _line(_ink, 3.6));
        c.drawLine(
          const Offset(62, 196),
          const Offset(138, 196),
          _line(_ink, 3.5),
        );
        // 등번호 7
        c.drawPath(
          Path()
            ..moveTo(90, 162)
            ..lineTo(110, 162)
            ..lineTo(98, 188),
          _line(_ink, 9),
        );
        c.drawPath(
          Path()
            ..moveTo(90, 162)
            ..lineTo(110, 162)
            ..lineTo(98, 188),
          _line(_col(item, 1), 5),
        );
        final collar = Path()
          ..moveTo(86, 142)
          ..lineTo(100, 154)
          ..lineTo(114, 142);
        c.drawPath(collar, _line(_col(item, 1), 5));
        _sleeves(happy, _col(item, 0), stripe: _col(item, 1));
      case 'tutu':
        _fs(torsoPath, _col(item, 0));
        // 겹겹이 치마
        for (final (w, h, dy, col) in [
          (136.0, 34.0, 196.0, _col(item, 1)),
          (118.0, 28.0, 192.0, _light(_col(item, 0), .3)),
        ]) {
          final skirt = Path();
          for (var i = 0; i < 9; i++) {
            final t = i / 8;
            final x = 100 - w / 2 + w * t;
            skirt.addOval(
              Rect.fromCenter(
                center: Offset(x, dy + 6),
                width: w / 6,
                height: h * .7,
              ),
            );
          }
          skirt.addOval(
            Rect.fromCenter(center: Offset(100, dy), width: w, height: h),
          );
          final merged = Path.combine(
            PathOperation.union,
            skirt,
            Path()..addOval(
              Rect.fromCenter(
                center: Offset(100, dy),
                width: w * .9,
                height: h * .8,
              ),
            ),
          );
          _fs(merged, col, width: 3.5);
        }
        for (final o in const [
          Offset(80, 194),
          Offset(104, 200),
          Offset(124, 190),
        ]) {
          c.drawCircle(o, 2.4, Paint()..color = Colors.white);
        }
        _sleeves(happy, _col(item, 0), puff: true);
    }
  }

  void _shoeMore(Item item, double x) {
    switch (item.style) {
      case 'cleats':
        _fs(_rr(x - 13, 210, x + 13, 230, 9), _col(item, 0));
        c.drawLine(
          Offset(x - 9, 218),
          Offset(x + 9, 214),
          _line(_col(item, 1), 4),
        );
        for (final dx in [-8.0, 0.0, 8.0]) {
          c.drawCircle(Offset(x + dx, 233), 2.6, Paint()..color = _ink);
        }
      case 'ballet':
        // 발목 리본
        c.drawLine(
          Offset(x - 8, 216),
          Offset(x + 6, 196),
          _line(_col(item, 1), 3.5),
        );
        c.drawLine(
          Offset(x + 8, 216),
          Offset(x - 6, 196),
          _line(_col(item, 1), 3.5),
        );
        _fs(_rr(x - 12, 212, x + 12, 230, 9), _col(item, 0));
        c.drawCircle(Offset(x, 214), 3, Paint()..color = _col(item, 1));
      case 'dinofeet':
        _fs(_rr(x - 15, 204, x + 15, 232, 12), _col(item, 0));
        for (final dx in [-9.0, 0.0, 9.0]) {
          final claw = Path()
            ..moveTo(x + dx - 4, 228)
            ..lineTo(x + dx, 238)
            ..lineTo(x + dx + 4, 228)
            ..close();
          _fs(claw, _col(item, 1), width: 2.5);
        }
    }
  }

  void _accessoryMore(Item item) {
    switch (item.style) {
      case 'stethoscope':
        final tube = Path()
          ..moveTo(80, 140)
          ..quadraticBezierTo(82, 176, 100, 180)
          ..quadraticBezierTo(118, 176, 120, 140);
        c.drawPath(tube, _line(_ink, 8));
        c.drawPath(tube, _line(_col(item, 0), 4));
        c.drawLine(
          const Offset(100, 180),
          const Offset(106, 196),
          _line(_ink, 8),
        );
        c.drawLine(
          const Offset(100, 180),
          const Offset(106, 196),
          _line(_col(item, 0), 4),
        );
        _fs(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(108, 200), radius: 8),
          ),
          _col(item, 1),
          width: 3,
        );
        c.drawCircle(
          const Offset(106, 198),
          2.5,
          Paint()..color = Colors.white,
        );
      case 'whistle':
        c.drawPath(
          Path()
            ..moveTo(78, 142)
            ..quadraticBezierTo(100, 176, 122, 142),
          _line(_col(item, 1), 3),
        );
        _fs(_rr(92, 162, 114, 176, 7), _col(item, 0), width: 3);
        _fs(_rr(84, 164, 94, 170, 2), _col(item, 0), width: 2.5);
        c.drawCircle(
          const Offset(104, 169),
          3,
          Paint()..color = _dark(_col(item, 0), .3),
        );
      case 'eyepatch':
        c.drawLine(
          const Offset(40, 66),
          const Offset(160, 108),
          _line(_ink, 4),
        );
        _fs(
          Path()..addOval(
            Rect.fromCenter(
              center: const Offset(126, 94),
              width: 28,
              height: 24,
            ),
          ),
          _col(item, 0),
          width: 3,
        );
      case 'mask':
        final band = Path()
          ..moveTo(44, 86)
          ..quadraticBezierTo(100, 72, 156, 86)
          ..lineTo(150, 106)
          ..quadraticBezierTo(100, 116, 50, 106)
          ..close();
        final holes = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(74, 94),
              width: 22,
              height: 24,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: const Offset(126, 94),
              width: 22,
              height: 24,
            ),
          );
        final mask = Path.combine(PathOperation.difference, band, holes);
        _fs(mask, _col(item, 0), width: 3.5);
    }
  }

  void _backMore(Item item) {
    switch (item.style) {
      case 'spatula':
        c.save();
        c.translate(150, 150);
        c.rotate(.45);
        _fs(_rr(-4, -10, 4, 52, 3), _col(item, 1), width: 3.5);
        final head = _rr(-15, -50, 15, -10, 6);
        _fs(head, _col(item, 0));
        for (final dx in [-6.0, 0.0, 6.0]) {
          c.drawLine(
            Offset(dx, -42),
            Offset(dx, -20),
            _line(_dark(_col(item, 0), .3), 3),
          );
        }
        c.restore();
      case 'telescope':
        c.save();
        c.translate(148, 152);
        c.rotate(.55);
        _fs(_rr(-7, -6, 7, 52, 4), _col(item, 1), width: 4);
        _fs(_rr(-10, -38, 10, -2, 4), _col(item, 0));
        _fs(_rr(-13, -60, 13, -34, 4), _col(item, 0));
        c.drawLine(
          const Offset(-13, -48),
          const Offset(13, -48),
          _line(_col(item, 1), 3),
        );
        c.restore();
      case 'wand':
        c.save();
        c.translate(150, 150);
        c.rotate(.4);
        _fs(_rr(-3.5, -30, 3.5, 50, 3), _col(item, 0), width: 3.5);
        _fs(_star(const Offset(0, -42), 16), _col(item, 1), width: 3.5);
        c.restore();
        for (final o in const [
          Offset(178, 98),
          Offset(150, 92),
          Offset(186, 124),
        ]) {
          c.drawPath(_star(o, 4), Paint()..color = _col(item, 1));
        }
      case 'veggiebasket':
        // 등에 멘 바구니 위로 당근이 쏙
        for (final x in [62.0, 138.0, 100.0]) {
          final carrot = Path()
            ..moveTo(x - 7, 146)
            ..lineTo(x, 112)
            ..lineTo(x + 7, 146)
            ..close();
          for (final a in [-.4, 0.0, .4]) {
            c.drawLine(
              Offset(x, 114),
              Offset(x + sin(a) * 12, 114 - cos(a) * 12),
              _line(_col(item, 2), 4),
            );
          }
          _fs(carrot, _col(item, 1), width: 3);
        }
        final basket = _rr(40, 136, 160, 200, 16);
        _fs(basket, _col(item, 0));
        c.save();
        c.clipPath(basket);
        for (var y = 146.0; y < 200; y += 9) {
          c.drawLine(
            Offset(40, y),
            Offset(160, y),
            _line(_dark(_col(item, 0), .2), 2),
          );
        }
        c.restore();
        c.drawPath(basket, _line(_ink, 3.6));
      case 'dinotail':
        final tail = Path()
          ..moveTo(78, 186)
          ..quadraticBezierTo(40, 196, 8, 226)
          ..quadraticBezierTo(46, 222, 86, 210)
          ..close();
        for (final t in [.3, .55, .8]) {
          final x = 78 - 70 * t;
          final y = 186 + 34 * t;
          final spike = Path()
            ..moveTo(x - 7, y + 2)
            ..lineTo(x - 4, y - 12)
            ..lineTo(x + 6, y)
            ..close();
          _fs(spike, _col(item, 1), width: 2.5);
        }
        _fs(tail, _col(item, 0));
      case 'cape':
        final cape = Path()
          ..moveTo(64, 142)
          ..lineTo(136, 142)
          ..quadraticBezierTo(162, 188, 168, 226)
          ..quadraticBezierTo(100, 236, 32, 226)
          ..quadraticBezierTo(38, 188, 64, 142)
          ..close();
        _fs(cape, _col(item, 0));
        c.save();
        c.clipPath(cape);
        c.drawRect(
          const Rect.fromLTRB(20, 214, 180, 240),
          Paint()..color = _dark(_col(item, 0), .15),
        );
        c.restore();
        c.drawPath(cape, _line(_ink, 3.6));
      case 'ball':
        const o = Offset(156, 212);
        _fs(
          Path()..addOval(Rect.fromCircle(center: o, radius: 17)),
          _col(item, 0),
        );
        final pent = Path();
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          final p = o + Offset(cos(a), sin(a)) * 7;
          i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
        }
        pent.close();
        c.drawPath(pent, Paint()..color = _col(item, 1));
        for (var i = 0; i < 5; i++) {
          final a = -pi / 2 + i * 2 * pi / 5;
          c.drawLine(
            o + Offset(cos(a), sin(a)) * 7,
            o + Offset(cos(a), sin(a)) * 15,
            _line(_col(item, 1), 2.5),
          );
        }
    }
  }
}
