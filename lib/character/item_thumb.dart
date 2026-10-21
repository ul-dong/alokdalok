import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import 'animal_painter.dart';
import 'zodiac.dart';

/// 아이템 칸에 보여 주는 미리보기: 해당 아이템만 입은 작은 캐릭터를 부위 중심으로 확대.
class ItemThumb extends StatelessWidget {
  const ItemThumb({
    super.key,
    required this.item,
    this.size = 84,
    this.faded = false,
    this.zodiac,
  });

  final Zodiac? zodiac;

  final Item item;
  final double size;
  final bool faded;

  /// 부위별로 보여 줄 영역 (200 x 240 좌표계)
  static Rect focus(ItemSlot slot) => switch (slot) {
    ItemSlot.head => const Rect.fromLTWH(20, 0, 160, 150),
    ItemSlot.outfit => const Rect.fromLTWH(10, 70, 180, 170),
    ItemSlot.shoes => const Rect.fromLTWH(40, 150, 120, 90),
    ItemSlot.accessory => const Rect.fromLTWH(20, 20, 160, 160),
    ItemSlot.back => const Rect.fromLTWH(0, 60, 200, 180),
  };

  @override
  Widget build(BuildContext context) {
    final r = focus(item.slot);
    final scale = size / (r.width > r.height ? r.width : r.height);
    final paint = SizedBox(
      width: AnimalPainter.design.width * scale,
      height: AnimalPainter.design.height * scale,
      child: CustomPaint(
        painter: AnimalPainter(
          zodiac: zodiac ?? AppScope.of(context).zodiac,
          items: {item.slot: item},
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(
              -r.left * scale + (size - r.width * scale) / 2,
              -r.top * scale + (size - r.height * scale) / 2,
            ),
            child: Opacity(opacity: faded ? .45 : 1, child: paint),
          ),
        ),
      ),
    );
  }
}
