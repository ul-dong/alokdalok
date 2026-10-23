// 골인 길에서 걸어가는 옆모습 미리보기
// shots/walk_cycle.png  : 24마리 × 걸음 4장면 (0, 1/4, 1/2, 3/4)
// shots/walk_outfits.png: 옷 입은 친구들의 걸음 4장면
// shots/walk_game_844.png: 놀이 화면에서 정답을 맞히고 걸어가는 중
import 'dart:math';

import 'package:alokdalok/character/walk_view.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/games/common/journey_trail.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_preview_test.dart' show st;

const _frames = [0.0, .25, .5, .75];

Widget _cell(Zodiac z, double step, [Map<ItemSlot, Item> items = const {}]) =>
    SizedBox(
      width: 75,
      height: 90,
      child: CustomPaint(
        painter: WalkPainter(zodiac: z, items: items, step: step),
      ),
    );

Widget _sheet(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAppTheme(),
  home: RepaintBoundary(
    child: Container(color: const Color(0xFFF7F1E3), child: child),
  ),
);

void main() {
  testWidgets('walk cycle', (t) async {
    t.view.physicalSize = const Size(1200, 540);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(
      _sheet(
        Wrap(
          children: [
            for (final z in Zodiac.values)
              Container(
                margin: const EdgeInsets.all(0),
                width: 300,
                child: Row(children: [for (final f in _frames) _cell(z, f)]),
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('shots/walk_cycle.png'),
    );
  });

  testWidgets('walk cycle big', (t) async {
    t.view.physicalSize = const Size(1200, 480);
    t.view.devicePixelRatio = 1;
    Widget big(Zodiac z, double f) => SizedBox(
      width: 200,
      height: 240,
      child: CustomPaint(
        painter: WalkPainter(zodiac: z, items: const {}, step: f),
      ),
    );
    await t.pumpWidget(
      _sheet(
        Column(
          children: [
            for (final z in [Zodiac.tiger, Zodiac.trex])
              Row(
                children: [
                  for (final f in [0.0, .125, .25, .5, .625, .75]) big(z, f),
                ],
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('shots/walk_cycle_big.png'),
    );
  });

  testWidgets('walk outfits', (t) async {
    t.view.physicalSize = const Size(1200, 480);
    t.view.devicePixelRatio = 1;
    Map<ItemSlot, Item> theme(OutfitTheme th) => {
      for (final i in ItemCatalog.byTheme(th)) i.slot: i,
    };
    final looks = [
      (Zodiac.tiger, theme(OutfitTheme.fire)),
      (Zodiac.rabbit, theme(OutfitTheme.princess)),
      (Zodiac.trex, theme(OutfitTheme.hero)),
      (Zodiac.monkey, theme(OutfitTheme.chef)),
      (Zodiac.pig, theme(OutfitTheme.police)),
      (Zodiac.triceratops, theme(OutfitTheme.astronaut)),
    ];
    Widget cell(Zodiac z, double f, Map<ItemSlot, Item> items) => SizedBox(
      width: 150,
      height: 160,
      child: CustomPaint(
        painter: WalkPainter(zodiac: z, items: items, step: f),
      ),
    );
    await t.pumpWidget(
      _sheet(
        Wrap(
          children: [
            for (final (z, items) in looks)
              SizedBox(
                width: 600,
                child: Row(
                  children: [for (final f in _frames) cell(z, f, items)],
                ),
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('shots/walk_outfits.png'),
    );
  });

  testWidgets('walk in game 844', (t) async {
    t.view.physicalSize = const Size(844, 390);
    t.view.devicePixelRatio = 1;
    final s = await st();
    await s.setRide(null);
    await t.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: gameScreen(GameKind.shape, 1, random: Random(7)),
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // 정답을 찾아 누른다
    final tiles = find.byType(QuizTile);
    for (var i = 0; i < tiles.evaluate().length; i++) {
      final before = (s.audio as RecordingAudio).played.length;
      await t.tap(tiles.at(i), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
      final played = (s.audio as RecordingAudio).played;
      if (played.length > before && played.last.name == 'correct') break;
    }
    // 걸어가는 중간 (한 깃발에 1.1초)
    for (var i = 0; i < 12; i++) {
      final walker = find.byType(JourneyWalker);
      if (walker.evaluate().isNotEmpty &&
          t.state<JourneyWalkerState>(walker).walking &&
          i > 4) {
        break;
      }
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(WalkView), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('shots/walk_game_844.png'),
    );
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  });
}
