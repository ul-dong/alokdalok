import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/vehicle/vehicle_painter.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview', (t) async {
    t.view.physicalSize = const Size(1200, 840);
    t.view.devicePixelRatio = 1;
    const st = [
      PlacedSticker(kind: StickerKind.star, color: 0xFFFFCF4D, x: .3, y: .65),
      PlacedSticker(kind: StickerKind.heart, color: 0xFFF59AB5, x: .55, y: .7),
      PlacedSticker(kind: StickerKind.flower, color: 0xFF5B9BE6, x: .82, y: .6),
      PlacedSticker(kind: StickerKind.paw, color: 0xFFF26B5E, x: .78, y: .48),
    ];
    final items = {for (final i in ItemCatalog.byTheme(OutfitTheme.fire)) i.slot: i};
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFFE6F4FC),
          child: Wrap(children: [
            for (final v in Vehicles.all)
              SizedBox(width: 300, height: 200, child: CustomPaint(painter: VehiclePainter(vehicle: v, stickers: st, zodiac: Zodiac.values[Vehicles.all.indexOf(v) % 12], items: v.id == 'car' ? items : const {}))),
            for (final v in Vehicles.all)
              SizedBox(width: 300, height: 200, child: CustomPaint(painter: VehiclePainter(vehicle: v, paint: Vehicles.paints[(Vehicles.all.indexOf(v) + 4) % 9], stickers: const [], zodiac: Zodiac.values[(Vehicles.all.indexOf(v) + 5) % 12], moving: true, phase: .3))),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('shots/vehicle.png'));
  });
}
