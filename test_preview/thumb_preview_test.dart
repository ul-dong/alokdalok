import 'package:alokdalok/character/item_thumb.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 상점·가방 칸의 아이템 미리보기 72개 (흰 칸 위). shots/thumbs.png
void main() {
  testWidgets('item thumbs', (t) async {
    t.view.physicalSize = const Size(1200, 1100);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: RepaintBoundary(
          child: Container(
            color: const Color(0xFFFFF6E6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, item) in ItemCatalog.all.indexed)
                  Container(
                    color: Colors.white,
                    child: ItemThumb(
                      item: item,
                      size: 92,
                      zodiac: Zodiac.values[i % 24],
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
      matchesGoldenFile('shots/thumbs.png'),
    );
  });
}
