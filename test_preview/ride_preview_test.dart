import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/vehicle/vehicle_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈것마다 여러 친구(12지신·공룡·옷 입은 친구)를 태운 그림.
/// shots/ride_<탈것>.png : 한 줄에 4마리씩 6줄 = 24마리 모두.
void main() {
  for (final v in Vehicles.all) {
    testWidgets('ride ${v.id}', (t) async {
      t.view.physicalSize = const Size(1200, 1200);
      t.view.devicePixelRatio = 1;
      final themes = OutfitTheme.values;
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            child: Container(
              color: const Color(0xFFE6F4FC),
              child: Wrap(
                children: [
                  for (final z in Zodiac.values)
                    SizedBox(
                      width: 300,
                      height: 200,
                      child: CustomPaint(
                        painter: VehiclePainter(
                          vehicle: v,
                          stickers: const [],
                          zodiac: z,
                          // 세 마리에 한 번씩 옷을 입힌다
                          items: z.index % 3 == 1
                              ? {
                                  for (final i in ItemCatalog.byTheme(
                                    themes[z.index % themes.length],
                                  ))
                                    i.slot: i,
                                }
                              : const {},
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('shots/ride_${v.id}.png'),
      );
    });
  }

  // 크게 보기: 두 친구(옷 입은 호랑이, 티라노)를 600 x 400으로
  for (final v in Vehicles.all) {
    testWidgets('ride big ${v.id}', (t) async {
      t.view.physicalSize = const Size(1200, 400);
      t.view.devicePixelRatio = 1;
      final fire = {
        for (final i in ItemCatalog.byTheme(OutfitTheme.fire)) i.slot: i,
      };
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            child: Container(
              color: const Color(0xFFE6F4FC),
              child: Row(
                children: [
                  for (final (z, items) in [
                    (Zodiac.tiger, fire),
                    (Zodiac.trex, const <ItemSlot, Item>{}),
                  ])
                    SizedBox(
                      width: 600,
                      height: 400,
                      child: CustomPaint(
                        painter: VehiclePainter(
                          vehicle: v,
                          stickers: const [
                            PlacedSticker(
                              kind: StickerKind.star,
                              color: 0xFFFFCC00,
                              x: .3,
                              y: .62,
                            ),
                            PlacedSticker(
                              kind: StickerKind.heart,
                              color: 0xFFE8352B,
                              x: .6,
                              y: .62,
                            ),
                          ],
                          zodiac: z,
                          items: items,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('shots/ride_big_${v.id}.png'),
      );
    });
  }
}
