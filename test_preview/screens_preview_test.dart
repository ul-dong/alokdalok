import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/zodiac_picker_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> st() async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  for (var i = 0; i < 60; i++) {
    await s.rewardCorrect(firstTry: true);
  }
  await s.buyVehicle('car');
  await s.buyVehicle('airplane');
  for (final (k, x, y) in [
    (StickerKind.star, .3, .62),
    (StickerKind.heart, .55, .66),
    (StickerKind.flower, .78, .64),
  ]) {
    await s.addSticker(
      'airplane',
      PlacedSticker(kind: k, color: 0xFFFFCF4D, x: x, y: y),
    );
  }
  for (var id = 1; id <= 4; id++) {
    await s.completeSession(GameKind.number, id);
  }
  for (var id = 1; id <= 2; id++) {
    await s.completeSession(GameKind.color, id);
    await s.completeSession(GameKind.shape, id);
  }
  return s;
}

void main() {
  final pages = <String, Widget Function()>{
    'home': () => const SizedBox(),
    'stages': () => const StagePicker(game: GameKind.number),
    'stages_shape': () => const StagePicker(game: GameKind.shape),
    'stages_match': () => const StagePicker(game: GameKind.match),
    'playground': () => const PlaygroundScreen(),
    'number': () => NumberGameScreen(stageId: 8, random: Random(5)),
    'number5': () => NumberGameScreen(stageId: 5, random: Random(2)),
    'color5': () => const ColorGameScreen(stageId: 5),
    'garage': () => const GarageScreen(),
    'shop': () => const ShopScreen(startWithVehicles: true),
    'settings': () => const SettingsScreen(),
    'picker': () => const ZodiacPickerScreen(),
  };
  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    for (final e in pages.entries) {
      testWidgets('${e.key} ${size.width}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        final s = await st();
        await t.pumpWidget(
          e.key == 'home'
              ? AlokdalokApp(state: s)
              : AppScope(
                  state: s,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: ThemeData(fontFamily: 'Jua'),
                    home: e.value(),
                  ),
                ),
        );
        for (var i = 0; i < 15; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile('shots/${e.key}_${size.width.toInt()}.png'),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
