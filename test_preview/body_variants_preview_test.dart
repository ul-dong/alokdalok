import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/vehicle/vehicle_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 몸 틀 시안 비교 (A/B/C). 실제 앱은 바뀌지 않고 이 그림에서만 시안 몸 틀로 그린다.
/// shots/body_variants.png, shots/body_variants_outfit.png, shots/body_variants_ride.png
void main() {
  const species = [
    Zodiac.tiger,
    Zodiac.rabbit,
    Zodiac.ox,
    Zodiac.monkey,
    Zodiac.trex,
    Zodiac.triceratops,
  ];
  const labels = ['A안\n옆구리 혹', 'B안\n모은 팔', 'C안\n이어진 팔'];

  Map<ItemSlot, Item> theme(OutfitTheme t) => {
    for (final i in ItemCatalog.byTheme(t)) i.slot: i,
  };

  Widget sheet(List<Widget Function(int variant)> cells) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: RepaintBoundary(
      child: Material(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, label) in labels.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    for (final cell in cells) cell(i + 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget animal(int v, Zodiac z, [Map<ItemSlot, Item> items = const {}]) =>
      SizedBox(
        width: 200,
        height: 240,
        child: CustomPaint(
          painter: _Variant(v, AnimalPainter(zodiac: z, items: items)),
        ),
      );

  testWidgets('body variants', (t) async {
    t.view.physicalSize = const Size(1280, 768);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(sheet([for (final z in species) (v) => animal(v, z)]));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('shots/body_variants.png'),
    );
  });

  testWidgets('body variants outfit', (t) async {
    t.view.physicalSize = const Size(1280, 768);
    t.view.devicePixelRatio = 1;
    final fire = theme(OutfitTheme.fire),
        princess = theme(OutfitTheme.princess);
    await t.pumpWidget(
      sheet([
        (v) => animal(v, Zodiac.tiger, fire),
        (v) => animal(v, Zodiac.tiger, princess),
        (v) => animal(v, Zodiac.rabbit, fire),
        (v) => animal(v, Zodiac.rabbit, princess),
        (v) => animal(v, Zodiac.trex, fire),
        (v) => animal(v, Zodiac.triceratops, princess),
      ]),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('shots/body_variants_outfit.png'),
    );
  });

  testWidgets('body variants ride (A안)', (t) async {
    t.view.physicalSize = const Size(1200, 400);
    t.view.devicePixelRatio = 1;
    final moto = Vehicles.all.firstWhere(
      (v) => v.kind == VehicleKind.motorcycle,
    );
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: RepaintBoundary(
          child: Container(
            color: const Color(0xFFE6F4FC),
            child: Row(
              children: [
                for (final z in [Zodiac.tiger, Zodiac.trex])
                  SizedBox(
                    width: 600,
                    height: 400,
                    child: CustomPaint(
                      painter: _Variant(
                        1,
                        VehiclePainter(
                          vehicle: moto,
                          stickers: const [],
                          zodiac: z,
                        ),
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
      matchesGoldenFile('shots/body_variants_ride.png'),
    );
  });
}

/// 그리는 동안에만 시안 몸 틀을 켠다
class _Variant extends CustomPainter {
  _Variant(this.variant, this.inner);
  final int variant;
  final CustomPainter inner;

  @override
  void paint(Canvas canvas, Size size) {
    AnimalPainter.debugBodyVariant = variant;
    try {
      inner.paint(canvas, size);
    } finally {
      AnimalPainter.debugBodyVariant = 0;
    }
  }

  @override
  bool shouldRepaint(_Variant old) => true;
}
