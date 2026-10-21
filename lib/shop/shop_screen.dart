import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../character/item_thumb.dart';
import '../core/palette.dart';
import '../data/item_catalog.dart';
import '../data/vehicles.dart';
import '../games/common/scene_game.dart';
import '../services/audio_service.dart';
import '../services/game_state.dart';
import '../vehicle/garage_screen.dart';
import '../vehicle/ride_view.dart';
import '../vehicle/vehicle_painter.dart';
import '../widgets/common.dart';
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
    final ok = await confirmBuy(context, name, price, preview);
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
      state.audio.say('${v.name}, 출발!');
      setState(() => cheer++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vehicleTab = theme == null;
    return LandscapePage(
      background: const SceneBackground(groundLevel: .82),
      child: Row(
        children: [
          // 왼쪽: 미리 입어 보는 내 친구 + 사기/입기 버튼
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.home_rounded,
                      label: '집으로',
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: FitBox(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '꾸미기 상점',
                          style: TextStyle(fontSize: 28, color: Palette.text),
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
                          : CharacterView(
                              equipped: _preview(state),
                              cheer: cheer,
                              size: (c.maxHeight / 1.2).clamp(60.0, 220.0),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CountBadge(
                      icon: const CoinIcon(),
                      value: state.coins,
                      label: '코인',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ThemeTabs(
                  selected: theme,
                  onSelect: (t) => setState(() {
                    theme = t;
                    selected = null;
                    selectedVehicle = null;
                  }),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: vehicleTab ? _vehicleGrid(state) : _itemGrid(state),
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
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 128,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .95,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => ItemTile(
        item: items[i],
        selected: selected?.id == items[i].id,
        owned: state.owns(items[i].id),
        equipped: state.equipped[items[i].slot] == items[i].id,
        onTap: () => _select(items[i]),
      ),
    );
  }

  Widget _vehicleGrid(GameState state) => GridView.builder(
    padding: const EdgeInsets.only(bottom: 8, top: 2),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 200,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
    ),
    itemCount: Vehicles.all.length,
    itemBuilder: (_, i) {
      final v = Vehicles.all[i];
      final owned = state.ownsVehicle(v.id);
      return Pressable(
        onTap: () => _selectVehicle(v),
        semanticLabel: '${v.name}${owned ? ', 가지고 있음' : ', 코인 ${v.price}개'}',
        child: Container(
          decoration: BoxDecoration(
            color: Palette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selectedVehicle?.id == v.id ? Palette.pink : Colors.white,
              width: selectedVehicle?.id == v.id ? 5 : 3,
            ),
            boxShadow: const [
              BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: VehiclePainter(
                    vehicle: v,
                    paint: state.paintOf(v.id),
                    stickers: state.stickersOf(v.id),
                  ),
                ),
              ),
              SizedBox(
                height: 26,
                child: owned
                    ? Icon(
                        state.ride == v.id
                            ? Icons.check_circle_rounded
                            : Icons.favorite_rounded,
                        color: state.ride == v.id
                            ? const Color(0xFF5CBF8A)
                            : Palette.pink,
                        size: 24,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CoinIcon(size: 22),
                          const SizedBox(width: 3),
                          Text(
                            '${v.price}',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Palette.coinDeep,
                            ),
                          ),
                        ],
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
                state.setRide(state.ride == v.id ? null : v.id);
                setState(() => cheer++);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PillButton(
              color: Palette.yellowSoft,
              edge: const Color(0xFFF0D88A),
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
            style: const TextStyle(fontSize: 22, color: Palette.textSoft),
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
  Widget build(BuildContext context) => PillButton(
    width: double.infinity,
    color: on ? Colors.white : Palette.mint,
    edge: on ? Palette.creamDeep : const Color(0xFF6DB894),
    onTap: onTap,
    semanticLabel: on ? onLabel : offLabel,
    child: Text(
      on ? onLabel : offLabel,
      style: TextStyle(fontSize: 28, color: on ? Palette.text : Colors.white),
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
      return CreamCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        radius: 28,
        child: Row(
          children: [
            const CoinIcon(size: 34),
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
                        fontSize: 18,
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
                      color: Palette.coin,
                      backgroundColor: Palette.creamDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return PillButton(
      width: double.infinity,
      color: Palette.yellow,
      edge: Palette.coinDeep,
      onTap: onBuy,
      semanticLabel: '코인 $price개로 사기',
      child: FitBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 40),
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
