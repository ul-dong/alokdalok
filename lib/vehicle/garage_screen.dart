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
import '../widgets/paged_grid.dart';
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

  /// 좁은 화면에서 스티커 색을 고르는 판을 열었는지 (색 칸을 60px 이상으로 따로 보여 준다)
  bool choosingColor = false;
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

  /// 색칠에서 코인이 모자란 색을 눌렀을 때 (모으자는 안내와 진행 막대를 보여 준다)
  VehiclePaint? wanted;

  void _pickVehicle(GameState state, Vehicle v) {
    setState(() {
      vehicleId = v.id;
      wanted = null;
    });
    state.audio.say(v.name);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = Vehicles.all.where((v) => state.ownsVehicle(v.id)).toList();
    final v = vehicleId == null ? null : Vehicles.byId(vehicleId!);

    return LandscapePage(
      background: const SceneBackground(groundLevel: .9),
      child: LayoutBuilder(
        builder: (context, page) {
          // 좁은 화면에서는 꾸미기 판을 넓게 (스티커 칸이 너무 작아지지 않게)
          final narrow = page.maxWidth < 700;
          return Column(
            children: [
              SizedBox(
                height: 60,
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.home_rounded,
                      label: '집으로',
                      size: 60,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    if (!narrow) ...[
                      const FitBox(child: TitleChip('탈것 꾸미기')),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: _chooser(state, mine)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: v == null
                    ? _noVehicle()
                    : Row(
                        children: [
                          // 왼쪽: 탈것 (누르면 스티커가 붙는다) + 탑승
                          Expanded(
                            flex: narrow ? 7 : 6,
                            child: Column(
                              children: [
                                Expanded(child: _vehicleView(v)),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 56,
                                  child: _bottomBar(state, v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 오른쪽: 스티커·색
                          Expanded(
                            flex: narrow ? 13 : 4,
                            child: _panel(state, v),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 가진 탈것 고르기. 모두 들어가면 한 줄로, 아니면 큰 화살표로 하나씩 넘긴다 (밀어서 보기 없음).
  Widget _chooser(GameState state, List<Vehicle> mine) {
    if (mine.isEmpty) return const SizedBox();
    // 모두 들어가면 한 줄로, 아니면 공용 큰 화살표(PagedGrid)로 쪽을 넘긴다
    return PagedGrid(
      itemCount: mine.length,
      initialIndex: max(0, mine.indexWhere((m) => m.id == vehicleId)),
      minCellWidth: 76,
      minCellHeight: 56,
      maxCellWidth: 84,
      maxCellHeight: 56,
      maxRows: 1,
      gap: 8,
      arrowSize: 56,
      itemBuilder: (context, i) {
        final m = mine[i];
        return Pressable(
          onTap: () => _pickVehicle(state, m),
          semanticLabel: m.name,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: m.id == vehicleId ? Palette.yellow : Colors.white,
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
        );
      },
    );
  }

  Widget _noVehicle() => Center(
    child: CreamCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '상점에서 탈것을 사면\n스티커를 붙이고 색칠할 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TextSizes.label,
              color: Palette.textSoft,
            ),
          ),
          const SizedBox(height: 12),
          PillButton(
            color: Palette.yellow,
            edge: Palette.coinDeep,
            onTap: () => Navigator.of(context).pushReplacement(
              softRoute(const ShopScreen(startWithVehicles: true)),
            ),
            semanticLabel: '상점 가기',
            child: const Text(
              '상점 가기',
              style: TextStyle(fontSize: TextSizes.label, color: Palette.text),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _vehicleView(Vehicle v) => LayoutBuilder(
    builder: (context, c) {
      final w = min(c.maxWidth, c.maxHeight * 1.5);
      return Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              painting ? null : _tap(d.localPosition, Size(w, w * 2 / 3), v),
          child: Semantics(
            label: '${v.name}, 눌러서 스티커 붙이기',
            child: RideView(width: w, cheer: cheer, vehicleId: v.id),
          ),
        ),
      );
    },
  );

  /// 탈것 아래: 지우개(스티커) 또는 코인 안내(색칠) + 탑승 버튼
  Widget _bottomBar(GameState state, Vehicle v) {
    final riding = state.ride == v.id;
    final short =
        painting && wanted != null && state.coins < Vehicles.paintPrice;
    return Row(
      children: [
        Expanded(
          flex: short ? 3 : 1,
          child: short
              ? _NeedCoins(coins: state.coins, price: Vehicles.paintPrice)
              : painting
              ? const Center(
                  child: FitBox(
                    child: Text(
                      '오른쪽에서 색을 골라요',
                      style: TextStyle(
                        fontSize: TextSizes.body,
                        color: Palette.textSoft,
                      ),
                    ),
                  ),
                )
              : PillButton(
                  height: 52,
                  glow: eraser,
                  onTap: () => setState(() => eraser = !eraser),
                  semanticLabel: '지우개',
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          style: TextStyle(
                            fontSize: TextSizes.button,
                            color: Palette.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: short ? 2 : 1,
          child: PillButton(
            height: 52,
            // 지금 고른 탈것에 안 타고 있으면 노랗게 반짝이며 "탑승"을 눌러 보라고 알려 준다
            color: riding ? Palette.mint : Palette.yellow,
            edge: riding ? const Color(0xFF6DB894) : Palette.coinDeep,
            glow: !riding,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onTap: () {
              state.setRide(riding ? null : v.id);
              if (!riding) state.audio.say('출발!');
              setState(() => cheer++);
            },
            semanticLabel: riding ? '내리기' : '탑승',
            child: FitBox(
              child: Text(
                riding ? '타는 중' : '탑승!',
                style: TextStyle(
                  fontSize: TextSizes.button,
                  color: riding ? Colors.white : Palette.text,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 꾸미기 판 안쪽 크기 (위 탭 줄과 CreamCard 여백을 뺀 크기)
  static Size _inner(BoxConstraints c) =>
      Size(c.maxWidth - 12, max(0.0, c.maxHeight - _tabsH - 12));

  static const _tabsH = 54.0;
  static const _gap = 6.0;

  /// 터치 칸 최소 크기 (사양: 60~72px 이상)
  static const minCell = 60.0;

  /// 스티커 10종 + 색 6가지를 한 판에 함께 놓을 때 칸 크기.
  /// 넓은 판: 스티커 5칸 두 줄 + 색 6칸 한 줄. 키 큰 판: 스티커 3칸 네 줄 + 색 3칸 두 줄.
  static ({double cell, int cols}) _together(Size a) {
    final n = Vehicles.stickerColors.length;
    final wide = min(
      min((a.width - _gap * 4) / 5, (a.width - _gap * (n - 1)) / n),
      (a.height - _gap * 2) / 3,
    );
    final tall = min((a.width - _gap * 2) / 3, (a.height - _gap * 5) / 6);
    return tall > wide * 1.15
        ? (cell: tall.clamp(20.0, 110.0), cols: 3)
        : (cell: wide.clamp(20.0, 110.0), cols: 5);
  }

  /// 함께 놓으면 칸이 60px보다 작아지는 판인지.
  /// 그러면 스티커와 색을 탭으로 나눠 각각 크게 보여 준다 (쪽 넘기기 없이).
  static bool splitColors(Size inner) => _together(inner).cell < minCell;

  Widget _panel(GameState state, Vehicle v) => LayoutBuilder(
    builder: (context, c) {
      final split = splitColors(_inner(c));
      final picking = split && choosingColor && !painting;
      final tabs = <(String, bool, VoidCallback)>[
        (
          '스티커',
          !painting && !picking,
          () => setState(() {
            painting = false;
            choosingColor = false;
            eraser = false;
            wanted = null;
          }),
        ),
        if (split)
          (
            '물감',
            picking,
            () => setState(() {
              painting = false;
              choosingColor = true;
              eraser = false;
              wanted = null;
            }),
          ),
        (
          '색칠',
          painting,
          () => setState(() {
            painting = true;
            choosingColor = false;
            eraser = false;
            wanted = null;
          }),
        ),
      ];
      return Column(
        children: [
          Row(
            children: [
              for (final (label, on, onTap) in tabs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: PillButton(
                      height: 48,
                      color: on ? Palette.pink : Colors.white,
                      edge: on ? const Color(0xFFD9718F) : Palette.creamDeep,
                      semanticLabel: label,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onTap: onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 물감 탭에는 지금 고른 색을 작은 동그라미로
                          if (label == '물감') ...[
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: FitBox(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: TextSizes.label,
                                  color: on ? Colors.white : Palette.text,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: painting
                ? _paintPanel(state, v)
                : picking
                ? _colorPanel()
                : _stickerPanel(split: split),
          ),
        ],
      );
    },
  );

  /// 색칠: 탈것마다 색을 따로 산다 (한 색 10코인). 처음 색은 공짜.
  Widget _paintPanel(GameState state, Vehicle v) {
    final current = state.paintOf(v.id).id;
    return CreamCard(
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(
        builder: (context, c) {
          // 9가지 색을 가장 크게 놓는 줄·칸 수 (좁은 판은 5칸 두 줄)
          const gap = _gap;
          final g = TileGrid.fit(
            Vehicles.paints.length,
            c.biggest,
            gap: gap,
            maxTile: 140,
          );
          final cols = g.cols;
          final cell = g.tile;
          return Center(
            child: SizedBox(
              width: cell * cols + gap * (cols - 1),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _choosePaint(GameState state, Vehicle v, VehiclePaint p) async {
    if (state.canPaint(v.id, p.id)) {
      setState(() => wanted = null);
      await state.setPaint(v.id, p.id);
      state.audio.play(Sfx.tap);
      state.audio.say('${p.name}으로 칠했어요!');
      if (mounted) setState(() => cheer++);
      return;
    }
    if (state.coins < Vehicles.paintPrice) {
      // 결제 화면 대신 놀이로 모으자고 안내한다 (탈것 아래에 진행 막대)
      setState(() => wanted = p);
      state.audio.say(
        '${p.name}은 코인 ${Vehicles.paintPrice}개가 필요해요. 놀이하면서 모아 볼까요?',
      );
      return;
    }
    setState(() => wanted = null);
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

  Widget _stickerTile(StickerKind k, double cell) => Pressable(
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
        borderRadius: BorderRadius.circular(cell * .25),
        border: Border.all(
          color: !eraser && k == kind ? Palette.pink : Palette.creamDeep,
          width: !eraser && k == kind ? 4 : 2,
        ),
      ),
      child: StickerIcon(kind: k, color: color, size: cell * .9),
    ),
  );

  /// 색 하나: 누르는 칸은 [cell] 크기 그대로, 동그라미는 조금 작게
  Widget _colorDot(Color col, double cell, {VoidCallback? then}) => Pressable(
    onTap: () {
      setState(() {
        color = col;
        eraser = false;
      });
      then?.call();
    },
    semanticLabel: '색',
    child: SizedBox.square(
      dimension: cell,
      child: Center(
        child: Container(
          width: cell * .86,
          height: cell * .86,
          decoration: BoxDecoration(
            color: col,
            shape: BoxShape.circle,
            border: Border.all(
              color: col == color && !eraser ? Palette.text : Colors.white,
              width: 3,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _cells(int count, double cell, int cols, Widget Function(int) item) =>
      GridRows(
        last: count,
        cols: cols,
        cellWidth: cell,
        cellHeight: cell,
        gap: _gap,
        itemBuilder: item,
      );

  /// 스티커 10종과 색 6가지. 밀어서 보기 없이 칸 크기를 맞춘다.
  /// [split]이면(좁은 판) 스티커만 크게 놓고, 색은 '물감' 탭에서 고른다.
  Widget _stickerPanel({required bool split}) => CreamCard(
    padding: const EdgeInsets.all(6),
    child: LayoutBuilder(
      builder: (context, c) {
        final kinds = StickerKind.values;
        if (split) {
          final g = TileGrid.fit(
            kinds.length,
            c.biggest,
            gap: _gap,
            maxTile: 110,
          );
          return Center(
            child: _cells(
              kinds.length,
              g.tile,
              g.cols,
              (i) => _stickerTile(kinds[i], g.tile),
            ),
          );
        }
        final t = _together(c.biggest);
        final cols = t.cols, cell = t.cell;
        final colors = Vehicles.stickerColors;
        final perRow = cols == 3 ? colors.length ~/ 2 : colors.length;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cells(
                kinds.length,
                cell,
                cols,
                (i) => _stickerTile(kinds[i], cell),
              ),
              const SizedBox(height: _gap),
              _cells(
                colors.length,
                cell,
                perRow,
                (i) => _colorDot(colors[i], cell),
              ),
            ],
          ),
        );
      },
    ),
  );

  /// 좁은 판의 '물감' 탭: 색 6가지를 크게. 고르면 바로 스티커 탭으로 돌아간다.
  Widget _colorPanel() => CreamCard(
    padding: const EdgeInsets.all(6),
    child: LayoutBuilder(
      builder: (context, c) {
        final colors = Vehicles.stickerColors;
        final g = TileGrid.fit(
          colors.length,
          c.biggest,
          gap: _gap,
          maxTile: 110,
        );
        return Center(
          child: _cells(
            colors.length,
            g.tile,
            g.cols,
            (i) => _colorDot(
              colors[i],
              g.tile,
              then: () => setState(() => choosingColor = false),
            ),
          ),
        );
      },
    ),
  );
}

/// 코인이 모자랄 때: "놀이하면서 코인을 모아요" + 진행 막대 (결제 화면으로 보내지 않는다)
class _NeedCoins extends StatelessWidget {
  const _NeedCoins({required this.coins, required this.price});
  final int coins;
  final int price;

  @override
  Widget build(BuildContext context) => CreamCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    radius: 26,
    child: Row(
      children: [
        const CoinIcon(size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: FitBox(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '놀이하면서 코인을 모아요 ($coins/$price)',
                    style: const TextStyle(
                      fontSize: TextSizes.small,
                      color: Palette.textSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (coins / price).clamp(0.0, 1.0),
                  minHeight: 10,
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
