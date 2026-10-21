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
import '../widgets/paged_grid.dart';
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
                      // 옷이 많아도 밀어서 보지 않는다: 한 화면에 맞추고 넘치면 큰 화살표로 쪽 넘기기
                      : PagedGrid(
                          key: ValueKey('outfits-$theme'),
                          minCellWidth: ItemTile.minWidth,
                          minCellHeight: ItemTile.minHeight,
                          maxCellWidth: ItemTile.maxWidth,
                          maxCellHeight: ItemTile.maxHeight,
                          arrowSize: ItemTile.arrowSize,
                          gap: 12,
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
                                state.audio.say(item.name);
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

/// 내 탈것: 누르면 고르고(이름을 말해 준다), 아래 "탑승!"을 눌러야 탄다.
/// 꾸미기 버튼으로 스티커·색칠하러 간다.
class _VehicleShelf extends StatefulWidget {
  const _VehicleShelf({required this.vehicles, required this.onChanged});
  final List<Vehicle> vehicles;
  final VoidCallback onChanged;

  @override
  State<_VehicleShelf> createState() => _VehicleShelfState();
}

class _VehicleShelfState extends State<_VehicleShelf> {
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = AppScope.read(context).ride;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final vehicles = widget.vehicles;
    if (vehicles.isEmpty) {
      return _Empty(
        onShop: () => Navigator.of(
          context,
        ).pushReplacement(softRoute(const ShopScreen(startWithVehicles: true))),
      );
    }
    final picked = selected == null ? null : Vehicles.byId(selected!);
    return Column(
      children: [
        Expanded(
          // 가진 탈것이 한 화면에 모두 들어가게 (밀어서 보기 없음)
          child: PagedGrid(
            itemCount: vehicles.length,
            minCellWidth: 64,
            minCellHeight: 48,
            maxCellWidth: 220,
            maxCellHeight: 160,
            itemBuilder: (context, i) {
              final v = vehicles[i];
              return _VehicleCard(
                vehicle: v,
                selected: v.id == selected,
                riding: state.ride == v.id,
                onTap: () {
                  setState(() => selected = v.id);
                  state.audio.say(v.name);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: picked == null
              ? const Center(
                  child: FitBox(
                    child: Text(
                      '타고 싶은 걸 눌러요',
                      style: TextStyle(fontSize: 22, color: Palette.textSoft),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        height: 56,
                        color: state.ride == picked.id
                            ? Colors.white
                            : Palette.mint,
                        edge: state.ride == picked.id
                            ? Palette.creamDeep
                            : const Color(0xFF6DB894),
                        glow: state.ride != picked.id,
                        onTap: () {
                          final boarding = state.ride != picked.id;
                          state.setRide(boarding ? picked.id : null);
                          if (boarding) state.audio.say('출발!');
                          widget.onChanged();
                        },
                        semanticLabel: state.ride == picked.id ? '내리기' : '탑승',
                        child: FitBox(
                          child: Text(
                            state.ride == picked.id ? '내리기' : '탑승!',
                            style: TextStyle(
                              fontSize: 24,
                              color: state.ride == picked.id
                                  ? Palette.text
                                  : Colors.white,
                            ),
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
                        onTap: () => Navigator.of(
                          context,
                        ).push(softRoute(GarageScreen(vehicleId: picked.id))),
                        semanticLabel: '탈것 꾸미기',
                        child: const FitBox(
                          child: Text(
                            '꾸미기',
                            style: TextStyle(fontSize: 24, color: Palette.text),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 탈것 한 칸: 고르면 분홍 테두리, 타고 있으면 초록 체크
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.riding,
    required this.onTap,
  });
  final Vehicle vehicle;
  final bool selected;
  final bool riding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: riding ? '${vehicle.name}, 타는 중' : vehicle.name,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Palette.pink : Colors.white,
            width: selected ? 5 : 3,
          ),
          boxShadow: const [
            BoxShadow(color: Palette.creamDeep, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: VehiclePainter(
                  vehicle: vehicle,
                  paint: state.paintOf(vehicle.id),
                  stickers: state.stickersOf(vehicle.id),
                ),
              ),
            ),
            if (riding)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF5CBF8A),
                  size: 26,
                ),
              ),
          ],
        ),
      ),
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
