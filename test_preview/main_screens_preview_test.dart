// ignore_for_file: invalid_use_of_visible_for_testing_member
// 통합 확인용 주요 화면 미리보기 (shots/main_<화면>_<폭>.png)
// 다른 미리보기에 없는 화면: 결과, 내 캐릭터(옷), 상점(옷), 눈 보호 덮개
// 실행: flutter test test_preview/main_screens_preview_test.dart --update-goldens
import 'package:alokdalok/app.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/games/common/game_frame.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> rich({EyeGuard? eye}) async {
  final storage = MemoryStorage();
  final d = SaveData.decode(null)
    ..coins = 120
    ..owned = {
      for (final i in ItemCatalog.all)
        if (i.price <= 20) i.id,
    };
  storage.raw = d.encode();
  final s = GameState(storage: storage, audio: RecordingAudio(), eyeGuard: eye);
  await s.load();
  await s.setNickname('별이');
  return s;
}

Future<void> _pump(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'Jua'),
    home: home,
  ),
);

void main() {
  for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
    final w = size.width.toInt();

    testWidgets('character outfits $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final s = await rich();
      await t.pumpWidget(_app(s, const CharacterScreen()));
      await _pump(t);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/main_character_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('shop outfits $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final s = await rich();
      await t.pumpWidget(_app(s, const ShopScreen()));
      await _pump(t);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/main_shop_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('result $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final s = await rich();
      await t.pumpWidget(
        _app(
          s,
          GameFrame(
            done: 5,
            card: const SizedBox(),
            cheer: 1,
            bubble: null,
            onReady: (_) {},
            result: const SessionSummary(
              coins: 9,
              stars: 4,
              reward: SessionReward(
                complete: 3,
                firstPlay: 5,
                newStage: 5,
                unlockedStage: 2,
              ),
            ),
            onReplay: () {},
            onNext: () {},
          ),
        ),
      );
      await _pump(t, 25);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/main_result_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('eye guard overlay $w', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      var now = DateTime(2026, 10, 22, 9);
      final eye = EyeGuard(now: () => now);
      final s = await rich(eye: eye);
      await t.pumpWidget(AlokdalokApp(state: s));
      await _pump(t);
      // 아주 가까운 얼굴이 3초 이어진다
      for (var i = 0; i < 4; i++) {
        eye.feed(const FaceReading(size: .9, yaw: 0, pitch: 0, roll: 0));
        now = now.add(const Duration(seconds: 1));
      }
      eye.feed(const FaceReading(size: .9, yaw: 0, pitch: 0, roll: 0));
      await _pump(t, 6);
      expect(eye.alert, EyeAlert.tooClose);
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('shots/main_eye_guard_$w.png'),
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 9));
    });
  }
}
