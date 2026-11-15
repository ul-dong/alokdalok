import 'package:flutter/material.dart';

/// 잠긴 단계의 큰 자물쇠 (외곽선 없는 납작한 면: 고리 + 몸통 + 열쇠 구멍)
class BigLock extends StatelessWidget {
  const BigLock({super.key});

  @override
  Widget build(BuildContext context) => const AspectRatio(
    aspectRatio: .82,
    child: CustomPaint(painter: _LockPainter()),
  );
}

class _LockPainter extends CustomPainter {
  const _LockPainter();

  static const body = Color(0xFFB9AC9B);
  static const shackle = Color(0xFFCFC4B4);
  static const hole = Color(0xFF8A7C6B);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // 고리: 두꺼운 둥근 띠 (면으로 그린다)
    final ring = Path()
      ..addRRect(
        RRect.fromLTRBR(w * .2, 0, w * .8, h * .62, Radius.circular(w * .3)),
      )
      ..addRRect(
        RRect.fromLTRBR(
          w * .34,
          h * .14,
          w * .66,
          h * .7,
          Radius.circular(w * .16),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    c.drawPath(ring, Paint()..color = shackle);
    // 몸통
    c.drawRRect(
      RRect.fromLTRBR(0, h * .4, w, h, Radius.circular(w * .2)),
      Paint()..color = body,
    );
    // 열쇠 구멍
    final kp = Paint()..color = hole;
    c.drawCircle(Offset(w / 2, h * .64), w * .1, kp);
    c.drawRRect(
      RRect.fromLTRBR(
        w * .45,
        h * .66,
        w * .55,
        h * .84,
        Radius.circular(w * .05),
      ),
      kp,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
