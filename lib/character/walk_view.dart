import 'dart:math';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import 'animal_painter.dart';
import 'character_view.dart';
import 'rider_pose.dart';
import 'zodiac.dart';

/// 걸어가는 친구 (옆모습, 가는 쪽 = 오른쪽). 크기는 [CharacterView]와 같다 (size x size*1.2).
/// [step]은 걸음 주기(0~1): 0.5마다 앞뒤 발이 바뀐다. [still]이면 걷기 동작 없이 옆모습만.
class WalkView extends StatelessWidget {
  const WalkView({
    super.key,
    required this.equipped,
    required this.step,
    this.size = 200,
    this.zodiac,
    this.still = false,
  });

  final Map<ItemSlot, String> equipped;
  final double step;
  final double size;
  final Zodiac? zodiac;
  final bool still;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.2,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: WalkPainter(
          zodiac: zodiac ?? AppScope.of(context).zodiac,
          items: CharacterView.resolve(equipped),
          step: step,
          still: still,
        ),
      ),
    ),
  );
}

/// 걷는 옆모습 그림 ([RiderPose.paintWalk]). 캐릭터 좌표 200 x 240을 칸에 맞춘다.
class WalkPainter extends CustomPainter {
  WalkPainter({
    required this.zodiac,
    required this.items,
    required this.step,
    this.still = false,
  });

  final Zodiac zodiac;
  final Map<ItemSlot, Item> items;
  final double step;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final d = AnimalPainter.design;
    final s = min(size.width / d.width, size.height / d.height);
    final top = (size.height - d.height * s) / 2;
    // 그림자는 땅에 그대로 (몸만 출렁인다)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, top + 232 * s),
        width: 84 * s,
        height: 10 * s,
      ),
      Paint()..color = const Color(0x1C3E2A20),
    );
    RiderPose(
      zodiac: zodiac,
      items: items,
      // 꼬리가 걸음에 맞춰 살랑 (눈 깜빡임 구간 0.94~은 피한다)
      phase: (step * .9) % .9,
    ).paintWalk(
      canvas,
      groundAt: Offset(size.width / 2, top + RiderPose.ground.dy * s),
      scale: s,
      step: step,
      still: still,
    );
  }

  @override
  bool shouldRepaint(WalkPainter old) =>
      old.zodiac != zodiac ||
      old.items != items ||
      old.step != step ||
      old.still != still;
}
