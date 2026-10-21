import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈것에 탔을 때처럼 옆(오른쪽)을 보는 24마리 얼굴
void main() {
  testWidgets('side faces', (t) async {
    t.view.physicalSize = const Size(2000, 900);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: RepaintBoundary(
          child: Container(
            color: const Color(0xFFE6F4FC),
            child: Wrap(
              children: [
                for (final z in Zodiac.values)
                  SizedBox(
                    width: 250,
                    height: 300,
                    child: CustomPaint(
                      painter: AnimalPainter(
                        zodiac: z,
                        items: const {},
                        sideways: true,
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
      matchesGoldenFile('shots/side_faces.png'),
    );
  });

  // 머리 아이템·얼굴 장식을 쓴 옆얼굴: 테마마다 한 줄 (쥐·토끼·호랑이·용·티라노·트리케라톱스·프테라노돈·닭)
  testWidgets('side faces with hats', (t) async {
    const friends = [
      Zodiac.rat,
      Zodiac.rabbit,
      Zodiac.tiger,
      Zodiac.dragon,
      Zodiac.trex,
      Zodiac.triceratops,
      Zodiac.pteranodon,
      Zodiac.rooster,
    ];
    final themes = OutfitTheme.values;
    t.view.physicalSize = Size(8 * 200, themes.length * 220.0);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: RepaintBoundary(
          child: Container(
            color: const Color(0xFFE6F4FC),
            child: Wrap(
              children: [
                for (final th in themes)
                  for (final z in friends)
                    SizedBox(
                      width: 200,
                      height: 220,
                      child: CustomPaint(
                        painter: AnimalPainter(
                          zodiac: z,
                          items: {
                            for (final i in ItemCatalog.byTheme(th))
                              if (i.slot == ItemSlot.head ||
                                  i.slot == ItemSlot.accessory)
                                i.slot: i,
                          },
                          sideways: true,
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
      matchesGoldenFile('shots/side_faces_hats.png'),
    );
  });
}
