import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('zodiac', (t) async {
    t.view.physicalSize = const Size(1200, 1000);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFFF4F4F6),
          child: Wrap(children: [
            for (final z in Zodiac.values)
              SizedBox(width: 150, height: 180, child: CustomPaint(painter: AnimalPainter(zodiac: z, items: const {}))),
            for (final (z, th) in [(Zodiac.rabbit, OutfitTheme.ballet), (Zodiac.triceratops, OutfitTheme.astronaut), (Zodiac.tiger, OutfitTheme.fire), (Zodiac.trex, OutfitTheme.hero)])
              SizedBox(width: 150, height: 180, child: CustomPaint(painter: AnimalPainter(zodiac: z, mood: CharMood.happy, items: {for (final i in ItemCatalog.byTheme(th)) i.slot: i}))),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('zodiac.png'));
  });

  // 크게 보기: 24마리를 원래 크기(200 x 240)로
  testWidgets('zodiac big', (t) async {
    t.view.physicalSize = const Size(1200, 960);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: RepaintBoundary(
        child: Container(
          color: Colors.white,
          child: Wrap(children: [
            for (final z in Zodiac.values)
              SizedBox(width: 200, height: 240, child: CustomPaint(painter: AnimalPainter(zodiac: z, items: const {}))),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('shots/zodiac_big.png'));
  });
}
