import 'dart:math';

import 'package:flutter/material.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import 'animal_painter.dart';
import 'item_art.dart';
import 'zodiac.dart';

/// 아이템 칸에 보여 주는 미리보기: 해당 아이템만 입은 캐릭터를 아이템 부위에 맞춰 크게 보여 준다.
/// - 모자: 머리 부분 확대 (모자 + 얼굴, 아래는 부드럽게 흐려진다)
/// - 안경·목걸이 같은 장식: 장식 둘레를 확대 (얼굴·가슴이 조금 보여 어디에 하는지 안다)
/// - 옷·가방·망토: 몸통 부분 확대
/// - 신발: 친구 없이 신발 한 켤레만 크게
/// 아이템은 칸 안에 잘리지 않고 온전히 보인다 ([bounds] 표, 테스트가 실제 그림과 맞는지 확인).
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

  /// 아이템 그림이 차지하는 영역 (200 x 240 캐릭터 좌표계).
  /// item_art.dart의 그림이 바뀌면 `test/screens_test.dart`의 확인 테스트가 새 값을 알려 준다.
  static const Map<String, Rect> bounds = {
    'helmet_robot': Rect.fromLTRB(34, -1, 166, 76),
    'suit_robot': Rect.fromLTRB(62, 140, 138, 210),
    'boots_robot': Rect.fromLTRB(73, 200, 127, 230),
    'visor_robot': Rect.fromLTRB(52, 82, 148, 106),
    'jetpack_robot': Rect.fromLTRB(35, 125, 165, 209),
    'crown_gold': Rect.fromLTRB(66, 8, 134, 50),
    'dress_princess': Rect.fromLTRB(45, 140, 155, 225),
    'shoes_magic': Rect.fromLTRB(73, 212, 127, 230),
    'ribbon_pink': Rect.fromLTRB(40, 34, 84, 53),
    'wings_fairy': Rect.fromLTRB(7, 120, 193, 182),
    'helmet_fire': Rect.fromLTRB(15, 15, 185, 79),
    'suit_fire': Rect.fromLTRB(63, 136, 137, 217),
    'boots_fire': Rect.fromLTRB(72, 196, 128, 230),
    'tank_fire': Rect.fromLTRB(35, 122, 165, 198),
    'cap_police': Rect.fromLTRB(40, 27, 160, 70),
    'suit_police': Rect.fromLTRB(63, 136, 137, 217),
    'shoes_police': Rect.fromLTRB(73, 212, 127, 230),
    'badge_police': Rect.fromLTRB(69, 153, 91, 173),
    'helmet_army': Rect.fromLTRB(30, 13, 170, 76),
    'suit_army': Rect.fromLTRB(63, 136, 137, 217),
    'boots_army': Rect.fromLTRB(72, 196, 128, 230),
    'dogtag_army': Rect.fromLTRB(76, 140, 124, 174),
    'bag_army': Rect.fromLTRB(42, 140, 158, 204),
    'bone_head': Rect.fromLTRB(27, 10, 173, 78),
    'suit_cave': Rect.fromLTRB(64, 140, 136, 216),
    'sandal_cave': Rect.fromLTRB(73, 206, 127, 230),
    'tooth_necklace': Rect.fromLTRB(74, 140, 126, 183),
    'club_cave': Rect.fromLTRB(121, 114, 177, 197),
    'astro_helmet': Rect.fromLTRB(16, 4, 184, 160),
    'astro_suit': Rect.fromLTRB(63, 136, 137, 217),
    'astro_boots': Rect.fromLTRB(73, 200, 127, 230),
    'astro_pack': Rect.fromLTRB(35, 125, 165, 209),
    'doc_mirror': Rect.fromLTRB(26, 15, 174, 78),
    'doc_coat': Rect.fromLTRB(59, 138, 141, 218),
    'doc_stetho': Rect.fromLTRB(77, 137, 123, 208),
    'doc_shoes': Rect.fromLTRB(73, 212, 127, 230),
    'chef_hat': Rect.fromLTRB(49, -10, 151, 68),
    'chef_coat': Rect.fromLTRB(63, 136, 137, 217),
    'chef_spatula': Rect.fromLTRB(124, 100, 184, 198),
    'chef_shoes': Rect.fromLTRB(73, 212, 127, 230),
    'farm_hat': Rect.fromLTRB(7, 15, 193, 76),
    'farm_overall': Rect.fromLTRB(60, 136, 140, 217),
    'farm_boots': Rect.fromLTRB(72, 196, 128, 230),
    'farm_basket': Rect.fromLTRB(40, 100, 160, 200),
    'train_cap': Rect.fromLTRB(49, 18, 151, 74),
    'train_suit': Rect.fromLTRB(63, 136, 137, 217),
    'train_whistle': Rect.fromLTRB(76, 140, 124, 176),
    'train_boots': Rect.fromLTRB(72, 196, 128, 230),
    'pirate_hat': Rect.fromLTRB(22, 19, 178, 66),
    'pirate_shirt': Rect.fromLTRB(63, 136, 137, 217),
    'pirate_patch': Rect.fromLTRB(37, 64, 162, 110),
    'pirate_scope': Rect.fromLTRB(116, 95, 189, 199),
    'wizard_hat': Rect.fromLTRB(14, -5, 186, 73),
    'wizard_robe': Rect.fromLTRB(44, 142, 156, 230),
    'wizard_wand': Rect.fromLTRB(128, 88, 190, 197),
    'wizard_shoes': Rect.fromLTRB(73, 212, 127, 230),
    'dino_hood': Rect.fromLTRB(26, -22, 174, 112),
    'dino_suit': Rect.fromLTRB(63, 136, 137, 217),
    'dino_tail': Rect.fromLTRB(8, 184, 86, 226),
    'dino_feet': Rect.fromLTRB(71, 204, 129, 238),
    'hero_mask': Rect.fromLTRB(44, 79, 156, 111),
    'hero_suit': Rect.fromLTRB(63, 136, 137, 217),
    'hero_cape': Rect.fromLTRB(32, 140, 168, 231),
    'hero_boots': Rect.fromLTRB(72, 196, 128, 230),
    'soccer_band': Rect.fromLTRB(32, 52, 168, 70),
    'soccer_jersey': Rect.fromLTRB(60, 136, 140, 217),
    'soccer_shoes': Rect.fromLTRB(73, 210, 127, 236),
    'soccer_ball': Rect.fromLTRB(139, 195, 173, 229),
    'ballet_tiara': Rect.fromLTRB(68, 16, 132, 52),
    'ballet_tutu': Rect.fromLTRB(20, 136, 180, 217),
    'ballet_shoes': Rect.fromLTRB(74, 194, 126, 230),
  };

  /// 부위별로 함께 보여 줄 친구 몸 (어디에 입는지 알 수 있게).
  /// 장식은 얼굴에 하는 것(안경·가면·리본)과 가슴에 거는 것(목걸이·배지)을 나눈다.
  static Rect bodyPart(ItemSlot slot, {Rect? item}) => switch (slot) {
    ItemSlot.head => const Rect.fromLTRB(56, 70, 144, 132), // 눈·코·입
    ItemSlot.accessory when (item?.center.dy ?? 0) > 130 => const Rect.fromLTRB(
      60,
      120,
      140,
      184,
    ), // 턱·가슴
    ItemSlot.accessory => const Rect.fromLTRB(56, 70, 144, 132), // 얼굴
    // 옷·등: 눈 아래부터 발까지 (얼굴이 보여야 머리 없는 몸처럼 보이지 않는다)
    ItemSlot.outfit => const Rect.fromLTRB(26, 70, 174, 238),
    ItemSlot.back => const Rect.fromLTRB(26, 70, 174, 238),
    ItemSlot.shoes => const Rect.fromLTRB(70, 200, 130, 236), // 발
  };

  /// 신발은 너무 크게 키우지 않는다 (가장 작은 보기 영역)
  static const double _minSide = 84;

  /// 아이템을 보여 줄 정사각형 영역 (200 x 240 좌표계)
  static Rect focus(Item item) {
    final b = bounds[item.id] ?? const Rect.fromLTWH(0, 0, 200, 240);
    final r = b.expandToInclude(bodyPart(item.slot, item: b));
    final side = max(_minSide, max(r.width, r.height) * 1.1);
    return Rect.fromCenter(center: r.center, width: side, height: side);
  }

  /// 잘리는 쪽을 부드럽게 흐리게 (위쪽 0~1, 아래쪽 0~1 비율)
  static (double, double) _fade(ItemSlot slot) => switch (slot) {
    ItemSlot.head => (0, .12),
    ItemSlot.accessory => (.08, .14),
    ItemSlot.outfit || ItemSlot.back => (.1, 0),
    ItemSlot.shoes => (0, 0),
  };

  @override
  Widget build(BuildContext context) {
    final r = focus(item);
    final scale = size / r.width;
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
