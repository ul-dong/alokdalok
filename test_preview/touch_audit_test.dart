import 'package:alokdalok/app.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/screens/bag_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pages = <String, Widget Function()>{
    'home': () => const SizedBox(),
    'stages': () => const StagePicker(game: GameKind.number),
    'number': () => const NumberGameScreen(stageId: 8),
    'color': () => const ColorGameScreen(stageId: 5),
    'garage': () => const GarageScreen(),
    'shop': () => const ShopScreen(),
    'character': () => const CharacterScreen(),
    'bag': () => const BagScreen(),
    'settings': () => const SettingsScreen(),
  };
  for (final e in pages.entries) {
    testWidgets('audit ${e.key}', (t) async {
      t.view.physicalSize = const Size(568, 320);
      t.view.devicePixelRatio = 1;
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      await s.setNickname('별이');
      for (var i = 0; i < 40; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      await s.buyVehicle('car');
      await t.pumpWidget(e.key == 'home' ? AlokdalokApp(state: s) : AppScope(state: s, child: MaterialApp(home: e.value())));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final small = <String>[];
      for (final el in find.byType(Pressable).evaluate()) {
        final box = el.renderObject as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final sz = box.size;
        if (sz.width < 48 || sz.height < 48) {
          small.add('${(el.widget as Pressable).semanticLabel} ${sz.width.toStringAsFixed(0)}x${sz.height.toStringAsFixed(0)}');
        }
      }
      // ignore: avoid_print
      print('${e.key}: ${small.isEmpty ? 'ok' : small.join(' | ')}');
      await t.pumpWidget(const SizedBox());
    });
  }
}
