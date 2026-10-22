import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../character/item_thumb.dart';
import '../core/palette.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import '../services/audio_service.dart';
import '../services/game_state.dart';
import '../vehicle/garage_screen.dart';
import '../vehicle/ride_view.dart';
import '../vehicle/vehicle_painter.dart';
import '../widgets/common.dart';
import '../widgets/paged_grid.dart';
import '../widgets/poke_character.dart';
import 'item_widgets.dart';

/// 꾸미기 상점. 테마(로봇·공주·소방관·경찰·군인·원시인)와 탈것을 고른다.
/// 아이템을 누르면 바로 입혀 보고(미리보기), 게임 코인으로만 산다. 현금 결제·광고·뽑기는 없다.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.startWithVehicles = false});

  final bool startWithVehicles;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with ScreenMusic {
  @override
  String get musicTrack => 'shop';

  late OutfitTheme? theme = widget.startWithVehicles ? null : OutfitTheme.robot;
  Item? selected;
  Vehicle? selectedVehicle;
  int cheer = 0;

  Map<ItemSlot, String> _preview(GameState state) {
    final map = Map<ItemSlot, String>.of(state.equipped);
    if (selected != null) map[selected!.slot] = selected!.id;
    return map;
  }

  void _select(Item item) {
    setState(() => selected = item);
    AppScope.read(context).audio.say(item.name);
  }

  void _selectVehicle(Vehicle v) {
    setState(() => selectedVehicle = v);
    AppScope.read(context).audio.say(v.name);
  }

  Future<bool> _confirm(String name, int price, Widget preview) async {
    final ok = await confirmBuy(context, name, price, preview, flat: true);
    return ok && mounted;
  }

  Future<void> _buy(Item item) async {
    final state = AppScope.read(context);
    final yes = await _confirm(
      item.name,
      item.price,
      ItemThumb(item: item, size: 110),
    );
    if (!yes) return;
    if (await state.purchase(item.id) == PurchaseResult.ok && mounted) {
      state.audio.play(Sfx.buy);
      state.audio.say('${item.name}, 정말 멋져요!');
      setState(() => cheer++);
    }
  }

  Future<void> _buyVehicle(Vehicle v) async {
    final state = AppScope.read(context);
    final preview = SizedBox(
      width: 165,
      height: 110,
      child: CustomPaint(
        painter: VehiclePainter(
          vehicle: v,
          paint: state.paintOf(v.id),
          stickers: const [],
        ),
      ),
    );
    if (!await _confirm(v.name, v.price, preview)) return;
    if (await state.buyVehicle(v.id) == PurchaseResult.ok && mounted) {
      state.audio.play(Sfx.buy);
      // 산 다음 "탑승!"을 눌러야 탄다
      state.audio.say('${v.name}, 정말 멋져요!');
      setState(() => cheer++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vehicleTab = theme == null;
    return LandscapePage(
      // 납작한 파스텔 배경 (외곽선·입체감 없이 단색 면)
      background: const CustomPaint(painter: ShopBackdropPainter()),
      child: Row(
        children: [
          // 왼쪽: 미리 입어 보는 내 친구 + 사기/입기 버튼
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Row(
                  children: [
                    _FlatRoundButton(
                      icon: Icons.home_rounded,
                      label: '집으로',
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    // 제목은 부모님용: 자리가 좁으면 빼고 코인만 둔다.
                    // 코인은 왼쪽 위에 둔다: 오른쪽은 테마 탭과 물건 칸을 크게 쓰도록
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Row(
                          children: [
                            if (c.maxWidth >= 260)
                              const Expanded(
                                child: FitBox(
                                  alignment: Alignment.centerLeft,
                                  child: _FlatChip(
                                    child: Text(
                                      '꾸미기 상점',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: TextSizes.heading,
                                        color: Palette.text,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 0,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: c.maxWidth - 8,
                                ),
                                child: FitBox(
                                  child: _CoinChip(coins: state.coins),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Center(
                      child: vehicleTab
                          ? RideView(
                              width: min(c.maxWidth, c.maxHeight * 1.5),
                              cheer: cheer,
                              vehicleId:
                                  selectedVehicle?.id ?? state.ride ?? 'car',
                            )
                          : PokeCharacter(
                              child: CharacterView(
                                equipped: _preview(state),
                                cheer: cheer,
                                size: (c.maxHeight / 1.2).clamp(60.0, 300.0),
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 72,
                  child: vehicleTab
                      ? _vehicleAction(state)
                      : _itemAction(state),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 오른쪽: 테마 탭 + 아이템
          Expanded(
            flex: 6,
            child: Column(
              children: [
                ThemeTabs(
                  flat: true,
                  selected: theme,
                  onSelect: (t) => setState(() {
                    theme = t;
                    selected = null;
                    selectedVehicle = null;
                  }),
                ),
                const SizedBox(height: 10),
                Expanded(
                  // 칸 영역이 배경 아래 땅(안내 띠) 위에 걸치지 않게 그만큼 비운다
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: ShopBackdropPainter.gridBottomInset(context),
                    ),
                    child: vehicleTab ? _vehicleGrid(state) : _itemGrid(state),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemGrid(GameState state) {
    final items = ItemCatalog.byTheme(theme!);
    // 밀어서 보지 않는다: 한 화면에 맞추고 넘치면 큰 화살표로 쪽 넘기기
    return PagedGrid(
      key: ValueKey('shop-$theme'),
      minCellWidth: ItemTile.minWidth,
      minCellHeight: ItemTile.minHeight,
      maxCellWidth: ItemTile.maxWidth,
      maxCellHeight: ItemTile.maxHeight,
      arrowSize: ItemTile.arrowSize,
      arrowBuilder: FlatPageArrow.new,
      gap: 12,
      cellAspect: ItemTile.aspect,
      itemCount: items.length,
      itemBuilder: (_, i) => ItemTile(
        item: items[i],
        selected: selected?.id == items[i].id,
        owned: state.owns(items[i].id),
        equipped: state.equipped[items[i].slot] == items[i].id,
        onTap: () => _select(items[i]),
        flat: true,
      ),
    );
  }

  // 탈것 7종이 한 화면에 모두 보이게 (밀어서 보기 없음)
  Widget _vehicleGrid(GameState state) => PagedGrid(
    itemCount: Vehicles.all.length,
    minCellWidth: 64,
    // 누르는 칸 60px 이상 (땅 위로 올리느라 높이가 줄면 4칸 2줄로 바뀐다)
    minCellHeight: 60,
    maxCellWidth: 200,
    maxCellHeight: 154,
    arrowBuilder: FlatPageArrow.new,
    itemBuilder: (_, i) {
      final v = Vehicles.all[i];
      final owned = state.ownsVehicle(v.id);
      return Pressable(
        onTap: () => _selectVehicle(v),
        semanticLabel: '${v.name}${owned ? ', 가지고 있음' : ', 코인 ${v.price}개'}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: ShopStyle.tile(selected: selectedVehicle?.id == v.id),
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: VehiclePainter(
                    vehicle: v,
                    paint: state.paintOf(v.id),
                    stickers: state.stickersOf(v.id),
                  ),
                ),
              ),
              // 작은 화면에서는 칸에 맞춰 줄어든다
              Expanded(
                child: FitBox(
                  child: owned
                      ? Icon(
                          state.ride == v.id
                              ? Icons.check_circle_rounded
                              : Icons.favorite_rounded,
                          color: state.ride == v.id
                              ? ShopStyle.mintDeep
                              : ShopStyle.pinkDeep,
                          size: 24,
                        )
                      : PriceTag(price: v.price),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _itemAction(GameState state) {
    final item = selected;
    if (item == null) return const _Hint(text: '입어 보고 싶은 걸 눌러요');
    if (state.owns(item.id)) {
      final wearing = state.equipped[item.slot] == item.id;
      return _ToggleButton(
        on: wearing,
        onLabel: '벗기',
        offLabel: '입기',
        onTap: () => state.toggleEquip(item.id),
      );
    }
    return _PriceButton(
      price: item.price,
      coins: state.coins,
      onBuy: () => _buy(item),
    );
  }

  Widget _vehicleAction(GameState state) {
    final v = selectedVehicle;
    if (v == null) return const _Hint(text: '타고 싶은 걸 눌러요');
    if (state.ownsVehicle(v.id)) {
      return Row(
        children: [
          Expanded(
            child: _ToggleButton(
              on: state.ride == v.id,
              onLabel: '내리기',
              offLabel: '탑승!',
              onTap: () {
                final boarding = state.ride != v.id;
                state.setRide(boarding ? v.id : null);
                if (boarding) state.audio.say('출발!');
                setState(() => cheer++);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FlatPill(
              color: ShopStyle.butter,
              onTap: () =>
                  Navigator.of(context)
                      .push(softRoute(GarageScreen(vehicleId: v.id))),
              semanticLabel: '탈것 꾸미기',
              child: const FitBox(
                child: Text(
                  '꾸미기',
                  style: TextStyle(fontSize: 26, color: Palette.text),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _PriceButton(
      price: v.price,
      coins: state.coins,
      onBuy: () => _buyVehicle(v),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: FitBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.touch_app_rounded,
            size: 40,
            color: Palette.textSoft,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: TextSizes.label,
              color: Palette.textSoft,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.on,
    required this.onLabel,
    required this.offLabel,
    required this.onTap,
  });
  final bool on;
  final String onLabel;
  final String offLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FlatPill(
    color: on ? ShopStyle.surface : ShopStyle.mint,
    onTap: onTap,
    semanticLabel: on ? onLabel : offLabel,
    child: Text(
      on ? onLabel : offLabel,
      style: TextStyle(
        fontSize: TextSizes.heading,
        color: on ? Palette.text : Colors.white,
      ),
    ),
  );
}

/// 사기 버튼. 코인이 모자라면 현금 결제 대신 놀이로 모으자고 안내한다.
class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.price,
    required this.coins,
    required this.onBuy,
  });
  final int price;
  final int coins;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    if (coins < price) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ShopStyle.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            const FlatCoin(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FitBox(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '놀이하면서 코인을 모아요 ($coins/$price)',
                      style: const TextStyle(
                        fontSize: TextSizes.body,
                        color: Palette.textSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (coins / price).clamp(0.0, 1.0),
                      minHeight: 12,
                      color: ShopStyle.coin,
                      backgroundColor: ShopStyle.priceBg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return FlatPill(
      color: ShopStyle.yellow,
      onTap: onBuy,
      semanticLabel: '코인 $price개로 사기',
      child: FitBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlatCoin(size: 40),
            const SizedBox(width: 8),
            Text(
              '$price',
              style: const TextStyle(fontSize: 32, color: Palette.text),
            ),
            const SizedBox(width: 14),
            const Icon(
              Icons.shopping_basket_rounded,
              size: 36,
              color: Palette.text,
            ),
          ],
        ),
      ),
    );
  }
}

/// 상점 위쪽의 납작한 둥근 아이콘 버튼 (집으로)
class _FlatRoundButton extends StatelessWidget {
  const _FlatRoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 60,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: ShopStyle.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * .48, color: Palette.text),
    ),
  );
}

/// 가진 코인 수 (납작한 알약)
class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '코인 $coins',
    child: _FlatChip(
      padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlatCoin(size: 36),
          const SizedBox(width: 8),
          Text(
            '$coins',
            style: const TextStyle(
              fontSize: TextSizes.number,
              color: Palette.text,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 납작한 알약 이름표 (제목·코인 수)
class _FlatChip extends StatelessWidget {
  const _FlatChip({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });
  final Widget child;
  final EdgeInsets padding;

  static const height = 58.0;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: padding,
    alignment: Alignment.center,
    decoration: ShopStyle.pill(ShopStyle.surface, height),
    child: child,
  );
}

/// 상점 배경: 파스텔 하늘, 동그란 구름, 둥근 언덕, 땅 (모두 외곽선 없는 단색 면, 움직이지 않음)
class ShopBackdropPainter extends CustomPainter {
  const ShopBackdropPainter();

  /// 땅(안내 띠)이 시작하는 높이 (화면 높이 대비)
  static const groundTop = .86;

  /// 땅과 칸 사이 틈
  static const groundGap = 6.0;

  /// [LandscapePage] 아래 여백
  static const pageBottomPadding = 12.0;

  /// 오른쪽 칸 영역 아래를 비울 높이: 칸 영역 아래 끝이 땅 위 [groundGap]에서 멈추게
  static double gridBottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final contentBottom = h - mq.padding.bottom - pageBottomPadding;
    return max(0.0, contentBottom - (h * groundTop - groundGap));
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = ShopStyle.sky);
    c.drawRect(
      Rect.fromLTWH(0, h * .45, w, h * .55),
      Paint()..color = ShopStyle.skyLow,
    );
    // 구름: 동그라미 세 개 + 납작한 밑면
    void cloud(double x, double y, double r) {
      final p = Paint()..color = ShopStyle.cloud;
      c.drawCircle(Offset(x - r * .9, y + r * .2), r * .7, p);
      c.drawCircle(Offset(x, y - r * .1), r, p);
      c.drawCircle(Offset(x + r * .95, y + r * .25), r * .65, p);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - r * 1.6, y + r * .2, x + r * 1.6, y + r * .9),
          Radius.circular(r * .35),
        ),
        p,
      );
    }

    cloud(w * .2, h * .12, h * .05);
    cloud(w * .62, h * .2, h * .04);
    // 둥근 언덕 두 겹
    final back = Paint()..color = ShopStyle.hillBack;
    c.drawOval(Rect.fromLTWH(-w * .1, h * .62, w * .6, h * .5), back);
    c.drawOval(Rect.fromLTWH(w * .55, h * .6, w * .6, h * .55), back);
    final front = Paint()..color = ShopStyle.hillFront;
    c.drawOval(Rect.fromLTWH(w * .2, h * .7, w * .7, h * .5), front);
    // 땅
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, h * groundTop, w, h * (1 - groundTop) + 1),
        topLeft: Radius.circular(h * .05),
        topRight: Radius.circular(h * .05),
      ),
      Paint()..color = ShopStyle.ground,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
