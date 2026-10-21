import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈것에 탔을 때처럼 옆(오른쪽)을 보는 24마리 얼굴
void main() {
  testWidgets('side faces', (t) async {
    t.view.physicalSize = const Size(1200, 540);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        child: Container(
          color: const Color(0xFFE6F4FC),
          child: Wrap(children: [
            for (final z in Zodiac.values)
              SizedBox(
                width: 150,
                height: 180,
                child: CustomPaint(painter: AnimalPainter(zodiac: z, items: const {}, sideways: true)),
              ),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('shots/side_faces.png'));
  });
}
