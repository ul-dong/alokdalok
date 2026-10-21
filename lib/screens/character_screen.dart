import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../character/zodiac.dart';
import '../core/palette.dart';
import '../data/item_catalog.dart';
import '../games/common/scene_game.dart';
import '../data/vehicles.dart';
import '../shop/item_widgets.dart';
import '../vehicle/garage_screen.dart';
import '../vehicle/vehicle_painter.dart';
import '../shop/shop_screen.dart';
import '../widgets/common.dart';
import 'nickname_screen.dart';
import 'zodiac_picker_screen.dart';

/// 내 캐릭터 (가로): 왼쪽에 내 친구와 이름·동물 바꾸기, 오른쪽에 가진 아이템 입고 벗기.
class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> with ScreenMusic {
  @override
  String get musicTrack => 'shop';

  OutfitTheme? theme = OutfitTheme.robot;
  int cheer = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vehicleTab = theme == null;
    final mine = vehicleTab
        ? const <Item>[]
        : ItemCatalog.byTheme(theme!).where((i) => state.owns(i.id)).toList();
    final myVehicles = Vehicles.all
        .where((v) => state.ownsVehicle(v.id))
        .toList();
    return LandscapePage(
      background: const SceneBackground(groundLevel: .82),
      child: Row(
        children: [
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
                    const Spacer(),
                    RoundIconButton(
                      icon: Icons.refresh_rounded,
                      label: '처음 모습으로',
                      size: 56,
                      onTap: () {
                        state.resetOutfit();
                        setState(() => cheer++);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Center(
                      child: Pressable(
                        onTap: () => setState(() => cheer++),
                        semanticLabel: '내 친구',
                        child: CharacterView(
                          equipped: state.equipped,
                          cheer: cheer,
                          size: (c.maxHeight / 1.2).clamp(60.0, 220.0),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          height: 56,
                          onTap: () =>
                              Navigator.of(context)
                                  .push(softRoute(const NicknameScreen())),
                          semanticLabel: '닉네임 바꾸기',
                          child: FitBox(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.nickname,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Palette.text,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.edit_rounded,
                                  color: Palette.textSoft,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PillButton(
                          height: 56,
                          color: Palette.yellowSoft,
                          edge: const Color(0xFFF0D88A),
                          onTap: () =>
                              Navigator.of(context)
                                  .push(softRoute(const ZodiacPickerScreen())),
                          semanticLabel: '친구 바꾸기',
                          child: FitBox(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.pets_rounded,
                                  color: Palette.text,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  state.zodiac.look.animal,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Palette.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                ThemeTabs(
                  selected: theme,
                  onSelect: (t) => setState(() => theme = t),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: vehicleTab
                      ? _VehicleShelf(
                          vehicles: myVehicles,
                          onChanged: () => setState(() => cheer++),
                        )
                      : mine.isEmpty
                      ? _Empty(
                          onShop: () => Navigator.of(context)
                              .pushReplacement(softRoute(const ShopScreen())),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 128,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: .95,
                              ),
                          itemCount: mine.length,
                          itemBuilder: (_, i) {
                            final item = mine[i];
                            final on = state.equipped[item.slot] == item.id;
                            return ItemTile(
                              item: item,
                              selected: on,
                              owned: true,
                              equipped: on,
                              onTap: () {
                                state.toggleEquip(item.id);
                                if (!on) setState(() => cheer++);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 내 탈것: 누르면 타고/내리고, 꾸미기 버튼으로 스티커·색칠하러 간다.
class _VehicleShelf extends StatelessWidget {
  const _VehicleShelf({required this.vehicles, required this.onChanged});
  final List<Vehicle> vehicles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (vehicles.isEmpty) {
      return _Empty(
        onShop: () => Navigator.of(
          context,
        ).pushReplacement(softRoute(const ShopScreen(startWithVehicles: true))),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: vehicles.length,
      itemBuilder: (_, i) {
        final v = vehicles[i];
        final riding = state.ride == v.id;
        return Container(
          decoration: BoxDecoration(
            color: Palette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: riding ? const Color(0xFF5CBF8A) : Colors.white,
              width: riding ? 5 : 3,
            ),
            boxShadow: const [
              BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () {
                    state.setRide(riding ? null : v.id);
                    onChanged();
                  },
                  semanticLabel: riding ? '${v.name} 내리기' : '${v.name} 타기',
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: VehiclePainter(
                      vehicle: v,
                      paint: state.paintOf(v.id),
                      stickers: state.stickersOf(v.id),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    riding
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: riding ? const Color(0xFF5CBF8A) : Palette.textSoft,
                    size: 26,
                  ),
                  const Spacer(),
                  PillButton(
                    height: 44,
                    color: Palette.yellowSoft,
                    edge: const Color(0xFFF0D88A),
                    onTap: () =>
                        Navigator.of(context)
                            .push(softRoute(GarageScreen(vehicleId: v.id))),
                    semanticLabel: '탈것 꾸미기',
                    child: const Text(
                      '꾸미기',
                      style: TextStyle(fontSize: 18, color: Palette.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onShop});
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) => Center(
    child: CreamCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '아직 없어요',
            style: TextStyle(fontSize: 24, color: Palette.textSoft),
          ),
          const SizedBox(height: 12),
          PillButton(
            color: Palette.yellow,
            edge: Palette.coinDeep,
            onTap: onShop,
            semanticLabel: '상점 가기',
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checkroom_rounded, size: 32, color: Palette.text),
                SizedBox(width: 8),
                Text(
                  '상점 가기',
                  style: TextStyle(fontSize: 22, color: Palette.text),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
