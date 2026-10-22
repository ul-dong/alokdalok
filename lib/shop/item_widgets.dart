import 'dart:math';

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
    this.flat = false,
  });

  final OutfitTheme? selected;
  final ValueChanged<OutfitTheme?> onSelect;
  final bool showVehicles;

  /// 상점용 납작한 모양 (외곽선·두께 없이 파스텔 단색 면)
  final bool flat;

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
        maxCellWidth: 104,
        maxRows: 1,
        gap: flat ? 8 : 5,
        arrowSize: 64,
        arrowBuilder: flat ? FlatPageArrow.new : null,
        itemBuilder: (context, i) {
          final t = tabs[i];
          final on = t == selected;
          return Pressable(
            onTap: () => onSelect(t),
            semanticLabel: t?.label ?? '탈것',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // 납작한 탭: 고른 탭은 진한 노랑 면(테두리 자리) 안에 밝은 노랑 면.
              // 외곽선 대신 같은 계열의 진한 색 면이 둘레를 감싼다.
              decoration: flat
                  ? ShopStyle.tab(selected: on)
                  : BoxDecoration(
                      color: t == selected ? Palette.yellowSoft : Palette.cream,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: t == selected ? Palette.yellow : Colors.white,
                        width: 4,
                      ),
                      boxShadow: Depth.flat(
                        t == selected ? Palette.coinDeep : Palette.creamDeep,
                      ),
                    ),
              padding: flat
                  ? const EdgeInsets.all(ShopStyle.tabRing)
                  : const EdgeInsets.symmetric(vertical: 2),
              child: _TabFace(
                flat: flat,
                on: on,
                child: Column(
                  children: [
                    Expanded(
                      child: FitBox(
                        child: t == null
                            ? SizedBox(
                                width: 60,
                                height: 40,
                                child: Icon(
                                  Icons.directions_car_rounded,
                                  size: 40,
                                  color: flat
                                      ? ShopStyle.carIcon
                                      : const Color(0xFFF26B5E),
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
                        style: const TextStyle(
                          fontSize: TextSizes.small,
                          color: Palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 탭 안쪽 면. 납작한 탭에서 고른 탭은 밝은 노랑 면이 진한 노랑 둘레 안에 놓인다.
class _TabFace extends StatelessWidget {
  const _TabFace({required this.flat, required this.on, required this.child});
  final bool flat;
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!flat) return child;
    return Container(
      decoration: BoxDecoration(
        color: on ? ShopStyle.tabOn : ShopStyle.surface,
        borderRadius: BorderRadius.circular(Radii.md - ShopStyle.tabRing / 2),
      ),
      child: child,
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
    this.flat = false,
  });

  final Item item;
  final bool selected;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;
  final bool showPrice;

  /// 상점용 납작한 모양 (외곽선·두께 없이 파스텔 단색 면, 고른 칸은 분홍 면)
  final bool flat;

  /// 격자 칸 크기 (가장 작게 ~ 가장 크게). 칸은 정사각형([aspect])이고,
  /// 큰 화면(1280)에서는 칸이 커져 빈 곳이 줄어든다. 가장 작게도 아이 손가락 기준(60~72px)보다 크다.
  /// 568 상점은 칸 영역을 땅(안내 띠) 위로 올려서 높이가 줄었다: 72로 두 줄을 지킨다.
  static const minWidth = 72.0;
  static const minHeight = 72.0;
  static const maxWidth = 230.0;
  static const maxHeight = 230.0;

  /// 칸 모양 (높이/너비): 정사각형
  static const aspect = 1.0;

  /// 쪽 넘기는 화살표 크기 (좁은 칸에서도 옷이 두 개씩 보이게 조금 작게)
  static const arrowSize = 60.0;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: '${item.name}${owned ? ', 가지고 있음' : ', 코인 ${item.price}개'}',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: flat
          ? ShopStyle.tile(selected: selected)
          : BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: selected ? Palette.pink : Colors.white,
                width: selected ? 5 : 3,
              ),
              boxShadow: const [
                BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
              ],
            ),
      child: LayoutBuilder(
        builder: (context, c) {
          // 그림이 칸을 거의 다 채운다. 가격·하트는 그림 아래쪽에 겹쳐 놓는다
          // (모자·장식 그림은 아래쪽이 흐려지는 자리라 가려지지 않는다).
          final side = c.biggest.shortestSide;
          final badge = (side * .2).clamp(22.0, 34.0);
          final inset = (side * .05).clamp(3.0, 8.0);
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    inset,
                    inset,
                    inset + badge * .45,
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: ItemThumb(
                        item: item,
                        size: max(
                          1.0,
                          min(
                            c.maxWidth - inset * 2,
                            c.maxHeight - inset * 2 - badge * .45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: inset,
                child: Center(child: _badge(badge)),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _badge(double h) {
    if (owned) {
      return Container(
        width: h * 1.25,
        height: h * 1.25,
        decoration: BoxDecoration(
          color: flat ? ShopStyle.surface : Palette.cream,
          shape: BoxShape.circle,
        ),
        child: Icon(
          equipped ? Icons.check_circle_rounded : Icons.favorite_rounded,
          color: equipped
              ? (flat ? ShopStyle.mintDeep : const Color(0xFF5CBF8A))
              : (flat ? ShopStyle.pinkDeep : Palette.pink),
          size: h,
        ),
      );
    }
    if (!showPrice) return const SizedBox.shrink();
    if (flat) return PriceTag(price: item.price, height: h);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: h * .3),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(h / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: h * .85),
          const SizedBox(width: 3),
          Text(
            '${item.price}',
            style: TextStyle(fontSize: h * .8, color: Palette.coinDeep),
          ),
        ],
      ),
    );
  }
}

/// 구매 확인 창을 띄우고, "네"를 누르면 true.
Future<bool> confirmBuy(
  BuildContext context,
  String name,
  int price,
  Widget preview, {
  bool flat = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) =>
        BuyDialog(name: name, price: price, preview: preview, flat: flat),
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
    this.flat = false,
  });
  final String name;
  final int price;
  final Widget preview;

  /// 상점용 납작한 모양
  final bool flat;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: FitBox(
      child: _card(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                preview,
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: TextSizes.title,
                    color: Palette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    flat ? const FlatCoin(size: 28) : const CoinIcon(size: 28),
                    const SizedBox(width: 6),
                    Text(
                      '$price개로 살까요?',
                      style: const TextStyle(
                        fontSize: TextSizes.button,
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
              color: flat ? ShopStyle.no : const Color(0xFFCFC4B4),
              label: '아니요',
              flat: flat,
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 18),
            DialogButton(
              icon: Icons.check_rounded,
              color: flat ? ShopStyle.mint : Palette.mint,
              label: '네',
              flat: flat,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _card(Widget child) => flat
      ? Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: ShopStyle.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
          child: child,
        )
      : CreamCard(padding: const EdgeInsets.all(22), child: child);
}

class DialogButton extends StatelessWidget {
  const DialogButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.flat = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool flat;

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
        boxShadow: flat
            ? null
            : [
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

/// 상점 전용 납작한(flat) 파스텔 모양: 외곽선·두꺼운 아래 그림자 없이 단색 면과 둥근 도형.
/// 공용 토큰(core/palette.dart)은 그대로 두고 상점에서만 쓴다.
class ShopStyle {
  ShopStyle._();

  /// 칸·탭·이름표의 바탕 (따뜻한 흰색)
  static const surface = Color(0xFFFFFCF5);

  /// 고른 테마 탭 (안쪽 면 · 둘레 면)
  static const tabOn = Color(0xFFFFE9A8);
  static const tabOnRing = Color(0xFFF5B92E);

  /// 탭 둘레 두께 (고른 탭은 진한 색, 안 고른 탭은 바탕색이라 보이지 않는다)
  static const tabRing = 4.0;

  /// 테마 탭 바깥 면
  static BoxDecoration tab({required bool selected}) => BoxDecoration(
    color: selected ? tabOnRing : surface,
    borderRadius: BorderRadius.circular(Radii.md),
  );

  /// 고른 아이템 칸
  static const tileOn = Color(0xFFFFDCE7);

  /// 가격 배지 바탕·글자
  static const priceBg = Color(0xFFFFF0C4);
  static const priceText = Color(0xFFC78F2A);

  /// 납작한 동전
  static const coin = Color(0xFFFFCB57);
  static const coinInner = Color(0xFFFFDE8C);
  static const coinMark = Color(0xFFE5A73A);

  /// 화살표·사기 버튼 (파스텔 노랑)
  static const yellow = Color(0xFFFFD66E);

  /// 탑승 버튼 (파스텔 민트)
  static const mint = Color(0xFF9ADBBE);
  static const mintDeep = Color(0xFF5DBE92);

  /// 꾸미기 버튼 (파스텔 크림 노랑)
  static const butter = Color(0xFFFFEDB5);

  static const pinkDeep = Color(0xFFF08AA8);
  static const no = Color(0xFFD9CFC2);
  static const carIcon = Color(0xFFF58C80);

  /// 배경: 하늘·언덕·땅
  static const sky = Color(0xFFDDF0FA);
  static const skyLow = Color(0xFFEAF6FC);
  static const cloud = Color(0xFFFFFFFF);
  static const hillBack = Color(0xFFCDEBC0);
  static const hillFront = Color(0xFFB9E2AB);
  static const ground = Color(0xFFF5E6C8);

  /// 아이템·탈것 칸
  static BoxDecoration tile({required bool selected}) => BoxDecoration(
    color: selected ? tileOn : surface,
    borderRadius: BorderRadius.circular(Radii.lg),
  );

  /// 알약 모양 면
  static BoxDecoration pill(Color color, double height) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(height / 2),
  );
}

/// 외곽선 없는 납작한 동전 (단색 원 두 겹 + 새싹 점)
class FlatCoin extends StatelessWidget {
  const FlatCoin({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _FlatCoinPainter()),
  );
}

class _FlatCoinPainter extends CustomPainter {
  const _FlatCoinPainter();

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    c.drawCircle(o, r, Paint()..color = ShopStyle.coin);
    c.drawCircle(o, r * .68, Paint()..color = ShopStyle.coinInner);
    final mark = Paint()..color = ShopStyle.coinMark;
    // 새싹: 동그란 잎 두 장 + 짧은 줄기 (모두 단색 면)
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: o + Offset(0, r * .18),
          width: r * .16,
          height: r * .5,
        ),
        Radius.circular(r * .08),
      ),
      mark,
    );
    c.drawCircle(o + Offset(-r * .2, -r * .14), r * .17, mark);
    c.drawCircle(o + Offset(r * .2, -r * .18), r * .17, mark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 납작한 가격 배지: 파스텔 알약 + 동전 + 숫자
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price, this.height = 26});
  final int price;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.fromLTRB(height * .14, 0, height * .4, 0),
    decoration: ShopStyle.pill(ShopStyle.priceBg, height),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlatCoin(size: height * .78),
        SizedBox(width: height * .14),
        Text(
          '$price',
          style: TextStyle(
            fontSize: height * .72,
            color: ShopStyle.priceText,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

/// 납작한 쪽 넘기기 화살표 (그림자·두께 없이 파스텔 노란 원). 크기·이름은 [PageArrow]와 같다.
class FlatPageArrow extends StatelessWidget {
  const FlatPageArrow({
    super.key,
    required this.forward,
    required this.onTap,
    this.enabled = true,
    this.size = 64,
  });

  final bool forward;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: enabled ? 1 : .35,
    child: Pressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: forward ? '다음 쪽' : '앞 쪽',
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: ShopStyle.yellow,
          shape: BoxShape.circle,
        ),
        child: Icon(
          forward ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          size: size * .58,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// 납작한 알약 버튼 (탑승!·꾸미기·사기). 눌리면 살짝 작아지는 반응은 [Pressable] 그대로.
class FlatPill extends StatelessWidget {
  const FlatPill({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.height = 72,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: semanticLabel,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: ShopStyle.pill(color, height),
      child: child,
    ),
  );
}
