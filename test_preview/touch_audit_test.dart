import 'dart:math';

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
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/vehicle/sticker_art.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/core/app_theme.dart';
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
      await t.pumpWidget(e.key == 'home' ? AlokdalokApp(state: s) : AppScope(state: s, child: MaterialApp(theme: buildAppTheme(), home: e.value())));
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

  // 탈것 꾸미기: 스티커·색·색칠 칸은 세 화면 크기 모두 60px 이상 (사양 60~72px)
  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    testWidgets('audit garage cells ${size.width.toInt()}', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      await s.setNickname('별이');
      for (var i = 0; i < 80; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      for (final v in Vehicles.all) {
        await s.buyVehicle(v.id);
      }
      await t.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(theme: buildAppTheme(), home: const GarageScreen()),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      Finder labeled(bool Function(String) ok) => find.byWidgetPredicate(
        (w) => w is Pressable && ok(w.semanticLabel ?? ''),
      );
      Future<void> tapLabel(String l) async {
        await t.tap(labeled((x) => x == l));
        for (var i = 0; i < 3; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      String measure(String what, Finder f, int count) {
        final rects = [
          for (final e in f.evaluate()) t.getRect(find.byWidget(e.widget)),
        ];
        expect(rects.length, count, reason: what);
        final w = rects.map((r) => r.width).reduce(min);
        final h = rects.map((r) => r.height).reduce(min);
        expect(w >= 60 && h >= 60, isTrue, reason: '$what ${w}x$h');
        return '$what ${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)}';
      }

      final out = <String>[
        measure(
          '스티커',
          find.ancestor(
            of: find.byType(StickerIcon),
            matching: labeled((x) => x == '스티커'),
          ),
          StickerKind.values.length,
        ),
      ];
      if (labeled((x) => x == '물감').evaluate().isNotEmpty) {
        await tapLabel('물감');
      }
      out.add(measure('색', labeled((x) => x == '색'), 6));
      await tapLabel('색칠');
      out.add(
        measure(
          '색칠',
          labeled((x) => Vehicles.paints.any((p) => x.startsWith(p.name))),
          Vehicles.paints.length,
        ),
      );
      // ignore: avoid_print
      print('garage ${size.width.toInt()}: ${out.join(' | ')}');
      await t.pumpWidget(const SizedBox());
    });
  }
}
