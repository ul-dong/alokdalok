import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈것 화면들 (탈것 7종을 모두 가진 상태): shots/v_<화면>_<너비>.png
Future<GameState> rich({int coins = 400}) async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  for (var i = 0; i < coins ~/ 2; i++) {
    await s.rewardCorrect(firstTry: true);
  }
  for (final v in Vehicles.all) {
    await s.buyVehicle(v.id);
  }
  await s.setRide('train');
  if (coins < 400) {
    // 코인이 모자란 모습: 기차 색을 사서 코인을 10개 아래로
    for (final p in Vehicles.paints) {
      if (await s.buyPaint('train', p.id) == PurchaseResult.notEnoughCoins) {
        break;
      }
    }
    await s.setPaint('train', 'paint_yellow');
  }
  for (final (k, x, y) in [
    (StickerKind.star, .3, .62),
    (StickerKind.heart, .55, .62),
    (StickerKind.flower, .78, .6),
  ]) {
    await s.addSticker(
      'train',
      PlacedSticker(kind: k, color: 0xFFE8352B, x: x, y: y),
    );
  }
  return s;
}

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

void main() {
  final pages =
      <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
        'garage': (() => const GarageScreen(), null),
        'garage_paint': (
          () => const GarageScreen(),
          (t) async {
            await t.tap(pressable('색칠'));
            for (var i = 0; i < 5; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
            await t.tap(pressable('보라색, 코인 10개'));
            for (var i = 0; i < 5; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
          },
        ),
        'character': (
          () => const CharacterScreen(),
          (t) async {
            await t.tap(pressable('탈것'));
            for (var i = 0; i < 5; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
            await t.tap(pressable('열기구'));
            for (var i = 0; i < 5; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
          },
        ),
        'shop': (() => const ShopScreen(startWithVehicles: true), null),
      };
  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    for (final e in pages.entries) {
      testWidgets('${e.key} ${size.width}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        // 색칠 화면은 코인이 모자란 경우를 보여 준다
        final s = await rich(coins: e.key == 'garage_paint' ? 288 : 400);
        await t.pumpWidget(
          AppScope(
            state: s,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: e.value.$1(),
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await e.value.$2?.call(t);
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile('shots/v_${e.key}_${size.width.toInt()}.png'),
        );
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
