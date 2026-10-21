import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('outfits', (t) async {
    t.view.physicalSize = const Size(1200, 720);
    t.view.devicePixelRatio = 1;
    final themes = OutfitTheme.values.skip(6).toList();
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFFE6F4FC),
          child: Wrap(children: [
            for (final th in themes)
              SizedBox(
                width: 200,
                height: 240,
                child: CustomPaint(
                  painter: AnimalPainter(
                    zodiac: Zodiac.values[themes.indexOf(th) % 12],
                    items: {for (final i in ItemCatalog.byTheme(th)) i.slot: i},
                  ),
                ),
              ),
            SizedBox(
              width: 200,
              height: 240,
              child: CustomPaint(
                painter: AnimalPainter(
                  zodiac: Zodiac.rabbit,
                  mood: CharMood.happy,
                  items: {for (final i in ItemCatalog.byTheme(OutfitTheme.hero)) i.slot: i},
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('outfits.png'));
  });
}
