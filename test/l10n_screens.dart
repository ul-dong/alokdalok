// 다국어 화면 점검용 공용 자료 (테스트 파일 아님): 언어를 정해 화면을 띄우는 틀과 화면 목록.
// test/l10n_en_layout_test.dart(넘침 검사)와 test_preview/l10n_preview_test.dart(그림)가 쓴다.
import 'dart:math';

import 'package:alokdalok/core/app_theme.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/common/game_frame.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/l10n/phrases.dart';
import 'package:alokdalok/screens/bag_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/nickname_screen.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/screens/zodiac_picker_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:flutter/material.dart';

/// 점검하는 세 화면 크기 (CLAUDE.md)
const l10nSizes = [Size(568, 320), Size(844, 390), Size(1280, 800)];

/// 코인·옷·탈것을 조금 가진 상태 (그 언어의 랜덤 이름)
Future<GameState> l10nState(
  String code, {
  EyeGuard? eye,
  DateTime Function()? now,
}) async {
  final storage = MemoryStorage();
  final d = SaveData.decode(null)
    ..coins = 120
    ..language = code
    ..owned = {
      for (final i in ItemCatalog.all)
        if (i.price <= 20) i.id,
    };
  storage.raw = d.encode();
  final s = GameState(
    storage: storage,
    audio: RecordingAudio(),
    eyeGuard: eye,
    now: now,
  );
  await s.load();
  await s.setNickname(Phrases.of(code).randomNames[0]);
  return s;
}

/// [code] 언어로 화면 하나를 띄우는 틀
Widget l10nApp(GameState s, Widget home, String code) {
  L10n.use(Locale(code));
  return AppScope(
    state: s,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(code),
      supportedLocales: AppLanguage.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

/// 화면 하나: 이름, 준비(상태 바꾸기), 화면
class L10nScreen {
  const L10nScreen(
    this.name,
    this.build, {
    this.setup,
    this.wait = 15,
    this.scroll = 0,
  });
  final String name;
  final Widget Function() build;
  final Future<void> Function(GameState s)? setup;

  /// 다 그려질 때까지 100ms씩 넘길 횟수
  final int wait;

  /// 그리기 전에 이만큼 아래로 내린다 (긴 설정 화면)
  final double scroll;
}

final l10nScreens = <L10nScreen>[
  L10nScreen('home', () => const HomeScreen()),
  L10nScreen(
    'home_replay',
    () => const HomeScreen(),
    setup: (s) => s.rememberPlay(GameKind.match, 2),
  ),
  L10nScreen('playground', () => const PlaygroundScreen()),
  for (final g in GameKind.values)
    L10nScreen('stage_${g.name}', () => StagePicker(game: g)),
  L10nScreen(
    'number',
    () => NumberGameScreen(stageId: 6, random: Random(2)),
    wait: 20,
  ),
  L10nScreen('color', () => ColorGameScreen(stageId: 3, random: Random(2))),
  L10nScreen('shape', () => ShapeGameScreen(stageId: 2, random: Random(2))),
  L10nScreen('size', () => SizeGameScreen(stageId: 4, random: Random(2))),
  L10nScreen('match', () => MatchGameScreen(stageId: 5, random: Random(2))),
  L10nScreen(
    'result',
    () => GameFrame(
      done: 5,
      total: 5,
      card: const SizedBox(),
      cheer: 1,
      bubble: null,
      onReady: (_) {},
      result: const SessionSummary(
        coins: 9,
        stars: 4,
        total: 5,
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
    wait: 25,
  ),
  L10nScreen('shop', () => const ShopScreen()),
  L10nScreen('shop_vehicles', () => const ShopScreen(startWithVehicles: true)),
  L10nScreen(
    'character',
    () => const CharacterScreen(),
    setup: (s) async {
      await s.buyVehicle('car');
      await s.setRide('car');
    },
  ),
  L10nScreen('bag', () => const BagScreen()),
  L10nScreen(
    'garage',
    () => const GarageScreen(vehicleId: 'balloon'),
    setup: (s) => s.buyVehicle('balloon'),
  ),
  L10nScreen('settings', () => const SettingsScreen()),
  L10nScreen('settings_sound', () => const SettingsScreen(), scroll: 650),
  L10nScreen('settings_language', () => const SettingsScreen(), scroll: 1150),
  L10nScreen('settings_end', () => const SettingsScreen(), scroll: 5000),
  L10nScreen('nickname', () => const NicknameScreen(onboarding: true)),
  L10nScreen('zodiac', () => const ZodiacPickerScreen(onboarding: true)),
  L10nScreen(
    'gate',
    () => Scaffold(
      backgroundColor: const Color(0x99402A1C),
      body: ParentalGate(onResult: (_) {}, random: Random(1)),
    ),
  ),
];
