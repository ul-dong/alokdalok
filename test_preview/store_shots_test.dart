// ignore_for_file: invalid_use_of_visible_for_testing_member
// Google Play 스토어 스크린샷 6장 (1280×800 가로). tool/store_shots.sh 가 돌리고 tool/out/store_shots/ 로 모은다.
// 실행: flutter test test_preview/store_shots_test.dart --update-goldens
//   STORE_DPR=2 이면 같은 화면을 2배(2560×1600)로 그린다 (Play 추천용 1080px 이상이 필요할 때).
import 'dart:io';
import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'main_screens_preview_test.dart' show rich;
import 'screens_preview_test.dart' show st;

const _logical = Size(1280, 800);

double get _dpr =>
    double.tryParse(Platform.environment['STORE_DPR'] ?? '') ?? 1;

Future<void> _pump(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: home,
  ),
);

Future<void> _shot(WidgetTester t, String name) => expectLater(
  find.byType(MaterialApp).first,
  matchesGoldenFile('shots/store/$name.png'),
);

void _size(WidgetTester t) {
  t.view.physicalSize = _logical * _dpr;
  t.view.devicePixelRatio = _dpr;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('store 1 home', (t) async {
    _size(t);
    final s = await st();
    await s.rememberPlay(GameKind.number, 4);
    await t.pumpWidget(AlokdalokApp(state: s));
    await _pump(t);
    await _shot(t, '1_home');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('store 2 number', (t) async {
    _size(t);
    final s = await st();
    await t.pumpWidget(
      _app(s, NumberGameScreen(stageId: 5, random: Random(2))),
    );
    await _pump(t);
    await _shot(t, '2_number');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('store 3 color', (t) async {
    _size(t);
    final s = await st();
    await t.pumpWidget(_app(s, const ColorGameScreen(stageId: 5)));
    await _pump(t);
    await _shot(t, '3_color');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('store 4 shop', (t) async {
    _size(t);
    final s = await rich();
    await t.pumpWidget(_app(s, const ShopScreen()));
    await _pump(t);
    await _shot(t, '4_shop');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('store 5 character', (t) async {
    // 로봇·소방관 옷을 모두 가진 채 소방관 옷을 입고 있다
    _size(t);
    final storage = MemoryStorage();
    storage.raw =
        (SaveData.decode(null)
              ..cameraNoticeSeen = true
              ..coins = 120
              ..owned = {
                for (final i in ItemCatalog.all)
                  if (i.id.endsWith('_robot') || i.id.endsWith('_fire')) i.id,
              })
            .encode();
    final s = GameState(storage: storage, audio: RecordingAudio());
    await s.load();
    await s.setNickname('별이');
    for (final id in ['helmet_fire', 'suit_fire', 'boots_fire', 'tank_fire']) {
      await s.equip(id);
    }
    await t.pumpWidget(_app(s, const CharacterScreen()));
    await _pump(t);
    await _shot(t, '5_character');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('store 6 eye guard', (t) async {
    // 화면이 너무 가까울 때 뜨는 눈 지킴이 안내 (카메라 대신 얼굴 판독을 직접 넣는다)
    _size(t);
    var now = DateTime(2026, 10, 22, 9);
    final eye = EyeGuard(now: () => now);
    final s = await rich(eye: eye);
    await t.pumpWidget(AlokdalokApp(state: s));
    await _pump(t);
    for (var i = 0; i < 5; i++) {
      eye.feed(const FaceReading(size: .9, yaw: 0, pitch: 0, roll: 0));
      now = now.add(const Duration(seconds: 1));
    }
    await _pump(t, 6);
    expect(eye.alert, EyeAlert.tooClose);
    await _shot(t, '6_eye_guard');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 9));
  });
}
