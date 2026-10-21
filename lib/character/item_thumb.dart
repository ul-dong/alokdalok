import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import 'animal_painter.dart';
import 'item_art.dart';
import 'zodiac.dart';

/// 아이템 칸에 보여 주는 미리보기: 해당 아이템만 입은 캐릭터를 부위에 맞는 구도로 보여 준다.
/// - 모자·안경·목걸이: 어깨 위 상반신 (아래는 부드럽게 흐려진다)
/// - 옷·가방·망토: 친구 전신
/// - 신발: 친구 없이 신발 한 켤레만 크게
/// 아이템은 칸 안에 잘리지 않고 온전히 보인다.
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

  /// 부위별로 보여 줄 영역 (200 x 240 좌표계, 정사각형)
  static Rect focus(ItemSlot slot) => switch (slot) {
    ItemSlot.head => const Rect.fromLTWH(-4, -18, 208, 208),
    ItemSlot.outfit => const Rect.fromLTWH(-24, -8, 248, 248),
    ItemSlot.shoes => const Rect.fromLTWH(54, 172, 92, 92),
    ItemSlot.accessory => const Rect.fromLTWH(4, 0, 192, 192),
    ItemSlot.back => const Rect.fromLTWH(-26, -6, 252, 252),
  };

  /// 잘리는 쪽을 부드럽게 흐리게 (위쪽 0~1, 아래쪽 0~1 비율)
  static (double, double) _fade(ItemSlot slot) => switch (slot) {
    ItemSlot.head || ItemSlot.accessory => (0, .2),
    _ => (0, 0),
  };

  @override
  Widget build(BuildContext context) {
    final r = focus(item.slot);
    final scale = size / (r.width > r.height ? r.width : r.height);
    final paint = SizedBox(
      width: AnimalPainter.design.width * scale,
      height: AnimalPainter.design.height * scale,
      child: CustomPaint(
        painter: item.slot == ItemSlot.shoes
            ? _ShoesOnly(item)
            : AnimalPainter(
                zodiac: zodiac ?? AppScope.of(context).zodiac,
                items: {item.slot: item},
              ),
      ),
    );
    final box = SizedBox.square(
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
    final (top, bottom) = _fade(item.slot);
    if (top == 0 && bottom == 0) return box;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, top == 0 ? 0 : top, 1 - bottom, 1],
      ).createShader(rect),
      child: box,
    );
  }
}

/// 신발만 그린다 (친구 발 자리 그대로, 200 x 240 좌표계)
class _ShoesOnly extends CustomPainter {
  _ShoesOnly(this.item);
  final Item item;

  @override
  void paint(Canvas canvas, Size size) {
    final d = AnimalPainter.design;
    canvas.save();
    canvas.scale(size.width / d.width, size.height / d.height);
    // 바닥 그림자 (흰 신발도 칸 위에서 보이게)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 233), width: 76, height: 10),
      Paint()..color = const Color(0x263E2A20),
    );
    ItemArt(canvas).shoes(item);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShoesOnly old) => old.item != item;
}
