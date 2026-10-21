import 'package:flutter/material.dart';

import '../character/item_thumb.dart';
import '../core/palette.dart';
import '../data/item_catalog.dart';
import '../widgets/common.dart';
import '../widgets/paged_grid.dart';

/// 테마 탭 (탈것 + 옷 테마들). null이 탈것 탭.
/// 옆으로 밀기 대신, 다 안 들어가면 큰 화살표로 한 쪽씩 넘긴다.
class ThemeTabs extends StatelessWidget {
  const ThemeTabs({
    super.key,
    required this.selected,
    required this.onSelect,
    this.showVehicles = true,
  });

  final OutfitTheme? selected;
  final ValueChanged<OutfitTheme?> onSelect;
  final bool showVehicles;

  @override
  Widget build(BuildContext context) {
    final tabs = <OutfitTheme?>[if (showVehicles) null, ...OutfitTheme.values];
    return SizedBox(
      height: 78,
      child: PagedGrid(
        itemCount: tabs.length,
        initialIndex: tabs.indexOf(selected).clamp(0, tabs.length - 1),
        minCellWidth: 72,
        minCellHeight: 72,
        maxCellWidth: 92,
        maxRows: 1,
        gap: 5,
        arrowSize: 64,
        itemBuilder: (context, i) {
          final t = tabs[i];
          return Pressable(
            onTap: () => onSelect(t),
            semanticLabel: t?.label ?? '탈것',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: t == selected ? Palette.yellowSoft : Palette.cream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: t == selected ? Palette.yellow : Colors.white,
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(color: Palette.creamDeep, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  Expanded(
                    child: FitBox(
                      child: t == null
                          ? const SizedBox(
                              width: 60,
                              height: 40,
                              child: Icon(
                                Icons.directions_car_rounded,
                                size: 40,
                                color: Color(0xFFF26B5E),
                              ),
                            )
                          : ItemThumb(
                              item: ItemCatalog.byId(t.sampleId)!,
                              size: 46,
                            ),
                    ),
                  ),
                  FitBox(
                    child: Text(
                      t?.label ?? '탈것',
                      style: const TextStyle(fontSize: 15, color: Palette.text),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 아이템 한 칸
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.selected,
    required this.owned,
    required this.equipped,
    required this.onTap,
    this.showPrice = true,
  });

  final Item item;
  final bool selected;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;
  final bool showPrice;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: '${item.name}${owned ? ', 가지고 있음' : ', 코인 ${item.price}개'}',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? Palette.pink : Colors.white,
          width: selected ? 5 : 3,
        ),
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 30),
              child: FitBox(child: ItemThumb(item: item, size: 96)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Center(
              child: owned
                  ? Icon(
                      equipped
                          ? Icons.check_circle_rounded
                          : Icons.favorite_rounded,
                      color: equipped ? const Color(0xFF5CBF8A) : Palette.pink,
                      size: 26,
                    )
                  : showPrice
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinIcon(size: 22),
                        const SizedBox(width: 3),
                        Text(
                          '${item.price}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Palette.coinDeep,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 구매 확인 창을 띄우고, "네"를 누르면 true.
Future<bool> confirmBuy(
  BuildContext context,
  String name,
  int price,
  Widget preview,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => BuyDialog(name: name, price: price, preview: preview),
  );
  return ok == true;
}

/// 구매 확인: 실수 구매 방지. 큰 ✔ / ✖ 그림 버튼.
class BuyDialog extends StatelessWidget {
  const BuyDialog({
    super.key,
    required this.name,
    required this.price,
    required this.preview,
  });
  final String name;
  final int price;
  final Widget preview;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: FitBox(
      child: CreamCard(
        padding: const EdgeInsets.all(22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                preview,
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(fontSize: 24, color: Palette.text),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 28),
                    const SizedBox(width: 6),
                    Text(
                      '$price개로 살까요?',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Palette.textSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 28),
            DialogButton(
              icon: Icons.close_rounded,
              color: const Color(0xFFCFC4B4),
              label: '아니요',
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 18),
            DialogButton(
              icon: Icons.check_rounded,
              color: Palette.mint,
              label: '네',
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

class DialogButton extends StatelessWidget {
  const DialogButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.lerp(color, Colors.black, .15)!,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 60, color: Colors.white),
    ),
  );
}
