import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../data/vehicles.dart';
import '../games/common/scene_game.dart';
import '../services/audio_service.dart';
import '../character/animal_painter.dart';
import '../services/game_state.dart';
import '../shop/item_widgets.dart';
import '../shop/shop_screen.dart';
import '../widgets/common.dart';
import 'ride_view.dart';
import 'sticker_art.dart';
import 'vehicle_painter.dart';

/// 탈것 꾸미기: 산 탈것에 스티커를 톡톡 붙이고(지우개로 떼기), 코인으로 산 색을 칠한다.
/// 정밀한 드래그 없이 "고르고 → 누르기"만으로 할 수 있게 만들었다.
class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> with ScreenMusic {
  @override
  String get musicTrack => 'shop';

  String? vehicleId;
  StickerKind kind = StickerKind.star;
  Color color = Vehicles.stickerColors.first;
  bool eraser = false;
  bool painting = false;
  int cheer = 0;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    final mine = Vehicles.all.where((v) => state.ownsVehicle(v.id)).toList();
    vehicleId =
        widget.vehicleId ?? state.ride ?? (mine.isEmpty ? null : mine.first.id);
  }

  Future<void> _tap(Offset local, Size box, Vehicle v) async {
    final state = AppScope.read(context);
    // 위젯 좌표 → 탈것 설계 좌표 (VehiclePainter와 같은 맞춤 방식)
    final s = min(
      box.width / VehiclePainter.design.width,
      box.height / VehiclePainter.design.height,
    );
    final dx = (box.width - VehiclePainter.design.width * s) / 2;
    final dy = (box.height - VehiclePainter.design.height * s) / 2;
    final p = Offset((local.dx - dx) / s, (local.dy - dy) / s);

    if (eraser) {
      final list = state.stickersOf(v.id);
      var best = -1;
      var bestDist = 30.0; // 손가락이 조금 빗나가도 떼어지게
      for (var i = 0; i < list.length; i++) {
        final d =
            (Offset(
                      list[i].x * VehiclePainter.design.width,
                      list[i].y * VehiclePainter.design.height,
                    ) -
                    p)
                .distance;
        if (d < bestDist) {
          bestDist = d;
          best = i;
        }
      }
      if (best >= 0) {
        await state.removeSticker(v.id, best);
        state.audio.play(Sfx.tap);
      }
      return;
    }

    final pos = VehiclePainter.toSticker(v.kind, p);
    if (pos == null) return; // 차체 밖
    final ok = await state.addSticker(
      v.id,
      PlacedSticker(kind: kind, color: color.toARGB32(), x: pos.dx, y: pos.dy),
    );
    if (ok) {
      state.audio.play(Sfx.tap);
    } else {
      state.audio.say('스티커가 가득 찼어요. 지우개로 떼어 볼까요?');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = Vehicles.all.where((v) => state.ownsVehicle(v.id)).toList();
    final v = vehicleId == null ? null : Vehicles.byId(vehicleId!);

    return LandscapePage(
      background: const SceneBackground(groundLevel: .9),
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
              const FitBox(
                child: Text(
                  '탈것 꾸미기',
                  style: TextStyle(fontSize: 28, color: Palette.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pressable(
                            onTap: () => setState(() => vehicleId = m.id),
                            semanticLabel: m.name,
                            child: Container(
                              width: 84,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Palette.cream,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: m.id == vehicleId
                                      ? Palette.yellow
                                      : Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: CustomPaint(
                                painter: VehiclePainter(
                                  vehicle: m,
                                  paint: state.paintOf(m.id),
                                  stickers: state.stickersOf(m.id),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: v == null
                ? Center(
                    child: CreamCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '상점에서 탈것을 사면\n스티커를 붙이고 색칠할 수 있어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Palette.textSoft,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PillButton(
                            color: Palette.yellow,
                            edge: Palette.coinDeep,
                            onTap: () => Navigator.of(context).pushReplacement(
                              softRoute(
                                const ShopScreen(startWithVehicles: true),
                              ),
                            ),
                            semanticLabel: '상점 가기',
                            child: const Text(
                              '상점 가기',
                              style: TextStyle(
                                fontSize: 22,
                                color: Palette.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // 왼쪽: 탈것 (누르면 스티커가 붙는다)
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  final w = min(c.maxWidth, c.maxHeight * 1.5);
                                  return Center(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (d) => painting
                                          ? null
                                          : _tap(
                                              d.localPosition,
                                              Size(w, w * 2 / 3),
                                              v,
                                            ),
                                      child: Semantics(
                                        label: '${v.name}, 눌러서 스티커 붙이기',
                                        child: RideView(
                                          width: w,
                                          cheer: cheer,
                                          vehicleId: v.id,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Text(
                              painting
                                  ? '오른쪽에서 색을 골라요'
                                  : eraser
                                  ? '지울 스티커를 눌러요'
                                  : '탈것을 눌러서 붙여요',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Palette.textSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 오른쪽: 스티커·색·도구
                      Expanded(flex: 4, child: _panel(state, v)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panel(GameState state, Vehicle v) => Column(
    children: [
      Row(
        children: [
          for (final (paintMode, label) in const [(false, '스티커'), (true, '색칠')])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: PillButton(
                  height: 48,
                  color: painting == paintMode ? Palette.pink : Colors.white,
                  edge: painting == paintMode
                      ? const Color(0xFFD9718F)
                      : Palette.creamDeep,
                  semanticLabel: label,
                  onTap: () => setState(() {
                    painting = paintMode;
                    eraser = false;
                  }),
                  child: FitBox(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 22,
                        color: painting == paintMode
                            ? Colors.white
                            : Palette.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      Expanded(
        child: painting ? _paintPanel(state, v) : _stickerPanel(state, v),
      ),
    ],
  );

  /// 색칠: 한 번 산 색은 가진 모든 탈것에 칠할 수 있다. 처음 색은 공짜.
  Widget _paintPanel(GameState state, Vehicle v) {
    final current = state.paintOf(v.id).id;
    return CreamCard(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, c) {
          const cols = 3, rows = 3, gap = 8.0;
          final cell = min(
            (c.maxWidth - gap * (cols - 1)) / cols,
            (c.maxHeight - gap * (rows - 1)) / rows,
          );
          return Center(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in Vehicles.paints)
                  _PaintChip(
                    paint: p,
                    size: cell,
                    selected: p.id == current,
                    usable: state.canPaint(v.id, p.id),
                    onTap: () => _choosePaint(state, v, p),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _choosePaint(GameState state, Vehicle v, VehiclePaint p) async {
    if (state.canPaint(v.id, p.id)) {
      await state.setPaint(v.id, p.id);
      state.audio.play(Sfx.tap);
      state.audio.say('${p.name}으로 칠했어요!');
      if (mounted) setState(() => cheer++);
      return;
    }
    if (state.coins < Vehicles.paintPrice) {
      state.audio.say(
        '${p.name}은 코인 ${Vehicles.paintPrice}개가 필요해요. 놀이하면서 모아 볼까요?',
      );
      return;
    }
    state.audio.say(p.name);
    final yes = await confirmBuy(
      context,
      p.name,
      Vehicles.paintPrice,
      SizedBox(
        width: 165,
        height: 110,
        child: CustomPaint(
          painter: VehiclePainter(vehicle: v, paint: p, stickers: const []),
        ),
      ),
    );
    if (!yes || !mounted) return;
    if (await state.buyPaint(v.id, p.id) == PurchaseResult.ok) {
      await state.setPaint(v.id, p.id);
      state.audio.play(Sfx.buy);
      state.audio.say('${p.name}으로 칠했어요!');
      if (mounted) setState(() => cheer++);
    }
  }

  Widget _stickerPanel(GameState state, Vehicle v) => CreamCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const cols = 5, rows = 2, gap = 6.0;
              // 아이 손가락으로 누르기 좋게 최소 52. 자리가 모자라면 위아래로 밀어서 본다.
              final cell = max(
                52.0,
                min(
                  (c.maxWidth - gap * (cols - 1)) / cols,
                  (c.maxHeight - gap) / rows,
                ),
              );
              return SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final k in StickerKind.values)
                      Pressable(
                        onTap: () => setState(() {
                          kind = k;
                          eraser = false;
                        }),
                        semanticLabel: '스티커',
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !eraser && k == kind
                                  ? Palette.pink
                                  : Palette.creamDeep,
                              width: !eraser && k == kind ? 4 : 2,
                            ),
                          ),
                          child: StickerIcon(
                            kind: k,
                            color: color,
                            size: cell * .9,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final n = Vehicles.stickerColors.length;
            final d = max(48.0, min(56.0, (c.maxWidth / n) - 6));
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final col in Vehicles.stickerColors)
                    Pressable(
                      onTap: () => setState(() {
                        color = col;
                        eraser = false;
                      }),
                      semanticLabel: '색',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          width: d,
                          height: d,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: col == color && !eraser
                                  ? Palette.text
                                  : Colors.white,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PillButton(
                height: 56,
                glow: eraser,
                onTap: () => setState(() => eraser = !eraser),
                semanticLabel: '지우개',
                child: const FitBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_fix_normal_rounded,
                        size: 28,
                        color: Palette.text,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '지우개',
                        style: TextStyle(fontSize: 20, color: Palette.text),
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
                // 지금 고른 탈것에 안 타고 있으면 노랗게 반짝이며 "탑승"을 눌러 보라고 알려 준다
                color: state.ride == v.id ? Palette.mint : Palette.yellow,
                edge: state.ride == v.id
                    ? const Color(0xFF6DB894)
                    : Palette.coinDeep,
                glow: state.ride != v.id,
                onTap: () {
                  state.setRide(state.ride == v.id ? null : v.id);
                  if (state.ride == v.id) state.audio.say('출발!');
                  setState(() => cheer++);
                },
                semanticLabel: state.ride == v.id ? '내리기' : '탑승',
                child: FitBox(
                  child: Text(
                    state.ride == v.id ? '타는 중' : '탑승!',
                    style: TextStyle(
                      fontSize: 20,
                      color: state.ride == v.id ? Colors.white : Palette.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PaintChip extends StatelessWidget {
  const _PaintChip({
    required this.paint,
    required this.size,
    required this.selected,
    required this.usable,
    required this.onTap,
  });

  final VehiclePaint paint;
  final double size;
  final bool selected;
  final bool usable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: usable
        ? paint.name
        : '${paint.name}, 코인 ${Vehicles.paintPrice}개',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? Palette.pink : Palette.creamDeep,
          width: selected ? 4 : 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 물감 방울
          Container(
            width: size * .6,
            height: size * .6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AnimalPainter.ink, width: 3),
              gradient: RadialGradient(
                center: const Alignment(-.35, -.4),
                radius: .9,
                colors: [
                  Color.lerp(paint.body, Colors.white, .55)!,
                  paint.body,
                ],
              ),
            ),
          ),
          if (!usable)
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Palette.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoinIcon(size: size * .2),
                    const SizedBox(width: 2),
                    Text(
                      '${Vehicles.paintPrice}',
                      style: TextStyle(
                        fontSize: size * .17,
                        color: Palette.coinDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 3,
              right: 3,
              child: Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF5CBF8A),
                size: size * .26,
              ),
            ),
        ],
      ),
    ),
  );
}
