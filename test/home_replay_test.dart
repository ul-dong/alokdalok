import 'dart:convert';

import 'package:alokdalok/data/game_kinds.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/playground_art.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 "또 하기"와 놀이터 길게 누르기 (2026-11-13 홈·놀이터 진입 개선)

Future<GameState> makeState() async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  return s;
}

Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(home: home),
);

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

RecordingAudio audioOf(GameState s) => s.audio as RecordingAudio;

/// 놀이 화면을 닫고 깨끗이 정리한다 (계절 음악·타이머)
Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 300);
}

void main() {
  group('저장 버전 7: 마지막 놀이·단계', () {
    test('버전 6 저장값은 기록 없이 7로 올라가고 나머지는 그대로', () {
      final json = SaveData.migrate({
        'version': 6,
        'nickname': '보리',
        'coins': 42,
        'numberStageUnlocked': 3,
        'eyeGuardOn': false,
      });
      expect(json['version'], SaveData.currentVersion); // v8(언어)까지 올라간다
      expect(json.containsKey('lastGame'), isFalse);
      final d = SaveData.fromJson(json);
      expect(d.lastGame, isNull);
      expect(d.lastStage, 1);
      expect(d.coins, 42);
      expect(d.numberStageUnlocked, 3);
      expect(d.eyeGuardOn, isFalse, reason: 'v6 설정은 그대로');
    });

    test('아주 예전(버전 0) 저장값도 7까지 차례로 올라간다', () {
      final d = SaveData.decode(jsonEncode({'nickname': '보리', 'coins': 5}));
      expect(d.lastGame, isNull);
      expect(jsonDecode(d.encode())['version'], SaveData.currentVersion);
    });

    test('마지막 놀이·단계를 저장하고 다시 읽는다', () {
      final d = SaveData.initial()
        ..lastGame = 'shape'
        ..lastStage = 4;
      final back = SaveData.decode(d.encode());
      expect(back.lastGame, 'shape');
      expect(back.lastStage, 4);
      // 기록이 없으면 저장값에 넣지 않는다
      expect(SaveData.initial().toJson().containsKey('lastGame'), isFalse);
    });

    test('모르는 놀이는 버리고, 범위 밖 단계는 1단계로', () {
      SaveData read(Object? game, Object? stage) => SaveData.decode(
        jsonEncode({
          'version': SaveData.currentVersion,
          'lastGame': game,
          'lastStage': stage,
        }),
      );
      expect(read('swing', 2).lastGame, isNull);
      expect(read(3, 2).lastGame, isNull);
      expect(read('number', 8).lastStage, 8);
      expect(read('color', 8).lastStage, 1, reason: '색깔은 5단계까지');
      expect(read('match', 'x').lastStage, 1);
    });
  });

  group('GameState 또 하기', () {
    test('처음에는 기록이 없다', () async {
      final s = await makeState();
      expect(s.lastGame, isNull);
    });

    test('rememberPlay: 마지막 놀이·단계를 기억하고 저장한다', () async {
      final storage = MemoryStorage();
      final s = GameState(storage: storage, audio: RecordingAudio());
      await s.load();
      await s.rememberPlay(GameKind.size, 2);
      expect(s.lastGame, GameKind.size);
      expect(s.lastStage, 2);
      final again = GameState(storage: storage, audio: RecordingAudio());
      await again.load();
      expect(again.lastGame, GameKind.size);
      expect(again.lastStage, 2);
    });

    test('replayStage: 마지막 단계, 잠겨 있으면 열린 단계 중 가장 높은 단계', () async {
      final s = await makeState();
      for (var id = 1; id <= 3; id++) {
        await s.completeSession(GameKind.number, id);
      }
      await s.rememberPlay(GameKind.number, 2);
      expect(s.replayStage(GameKind.number), 2);
      // 잠긴 단계가 기록된 경우 (예: 저장값을 옮겨 온 경우)
      await s.rememberPlay(GameKind.number, 7);
      expect(s.unlockedStage(GameKind.number), 4);
      expect(s.replayStage(GameKind.number), 4);
    });
  });

  group('놀이 화면이 열리면 마지막 놀이로 기억한다', () {
    for (final (kind, stage, screen) in [
      (GameKind.number, 1, const NumberGameScreen(stageId: 1) as Widget),
      (GameKind.color, 2, const ColorGameScreen(stageId: 2)),
      (GameKind.shape, 1, const ShapeGameScreen(stageId: 1)),
    ]) {
      testWidgets('${kind.title} $stage단계', (t) async {
        await setSize(t, const Size(844, 390));
        final s = await makeState();
        await t.pumpWidget(wrap(s, screen));
        await settle(t, 300);
        expect(s.lastGame, kind);
        expect(s.lastStage, stage);
        await done(t);
      });
    }
  });

  group('홈 또 하기', () {
    testWidgets('기록이 없으면 큰 자리에 놀이터 가기 (또 하기 없음)', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      expect(pressable(HomeScreen.replayLabel), findsNothing);
      final play = t.getRect(pressable(HomeScreen.playgroundLabel));
      final shop = t.getRect(pressable(HomeScreen.shopLabel));
      expect(play.height, greaterThan(shop.height), reason: '가장 큰 자리');
      await done(t);
    });

    testWidgets('기록이 있으면 맨 위 가장 큰 자리에 또 하기, 그 아래 줄에 나머지 세 개', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await s.rememberPlay(GameKind.color, 2);
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      final replay = t.getRect(pressable(HomeScreen.replayLabel));
      // 내 캐릭터와 그 놀이 그림이 함께 있다
      final tile = pressable(HomeScreen.replayLabel);
      expect(
        find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter is PlayItemPainter &&
                (w.painter as PlayItemPainter).kind == GameKind.color,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text(GameKind.color.title)),
        findsOneWidget,
      );
      for (final label in [
        HomeScreen.playgroundLabel,
        HomeScreen.characterLabel,
        HomeScreen.shopLabel,
      ]) {
        final r = t.getRect(pressable(label));
        expect(r.top, greaterThan(replay.bottom), reason: '$label은 아래 줄');
        expect(r.width * r.height, lessThan(replay.width * replay.height));
      }
      await done(t);
    });

    testWidgets('짧게 누르면 말 없이 단계 고르기를 거치지 않고 그 단계 놀이로 바로', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      for (var id = 1; id <= 3; id++) {
        await s.completeSession(GameKind.number, id);
      }
      await s.rememberPlay(GameKind.number, 3);
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      audioOf(s).spoken.clear();
      await t.tap(pressable(HomeScreen.replayLabel));
      await settle(t, 800);
      // "또 숫자 놀이 할까요?" 같은 말 없이, 놀이가 바로 문제를 읽는다
      for (final line in [
        HomeScreen.replayLabel,
        GameKind.number.title,
        GameKind.number.invite,
        GameKind.number.nameLine,
      ]) {
        expect(audioOf(s).spoken, isNot(contains(line)));
      }
      expect(audioOf(s).spoken.join(), isNot(contains('할까요')));
      expect(find.byType(StagePicker), findsNothing);
      expect(
        t.widget<NumberGameScreen>(find.byType(NumberGameScreen)).stageId,
        3,
      );
      await done(t);
    });

    testWidgets('잠긴 단계가 기록돼 있으면 열린 단계 중 가장 높은 단계로', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await s.completeSession(GameKind.number, 1);
      await s.rememberPlay(GameKind.number, 6);
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      await t.tap(pressable(HomeScreen.replayLabel));
      await settle(t, 800);
      expect(
        t.widget<NumberGameScreen>(find.byType(NumberGameScreen)).stageId,
        2,
      );
      await done(t);
    });

    testWidgets('길게 누르면 놀이 이름만 말하고 들어가지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await s.rememberPlay(GameKind.match, 1);
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      audioOf(s).spoken.clear();
      await t.longPress(pressable(HomeScreen.replayLabel));
      await settle(t, 800);
      expect(audioOf(s).spoken, [GameKind.match.nameLine]);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(StagePicker), findsNothing);
      await done(t);
    });

    testWidgets('놀이터에서 놀이를 시작하고 돌아오면 또 하기 자리가 생긴다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      expect(pressable(HomeScreen.replayLabel), findsNothing);
      await t.tap(pressable(HomeScreen.playgroundLabel));
      await settle(t, 800);
      await t.tap(pressable(GameKind.shape.title));
      await settle(t, 800);
      // 단계 고르기에서 1단계
      Navigator.of(t.element(find.byType(StagePicker)))
          .pushReplacement(softRoute(const ShapeGameScreen(stageId: 1)));
      await settle(t, 800);
      expect(s.lastGame, GameKind.shape);
      Navigator.of(t.element(find.byType(ShapeGameScreen)))
          .popUntil((r) => r.isFirst);
      await settle(t, 800);
      expect(pressable(HomeScreen.replayLabel), findsOneWidget);
      expect(
        find.descendant(
          of: pressable(HomeScreen.replayLabel),
          matching: find.text(GameKind.shape.title),
        ),
        findsOneWidget,
      );
      await done(t);
    });

    for (final size in const [
      Size(568, 320),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      testWidgets('또 하기가 있는 홈: ${size.width.toInt()} 넘침 없고 누르는 칸 60px 이상', (
        t,
      ) async {
        await setSize(t, size);
        final s = await makeState();
        await s.rememberPlay(GameKind.size, 2);
        await t.pumpWidget(wrap(s, const HomeScreen()));
        await settle(t);
        expect(t.takeException(), isNull);
        for (final el in find.byType(Pressable).evaluate()) {
          final box = el.renderObject as RenderBox;
          expect(
            box.size.shortestSide,
            greaterThanOrEqualTo(60),
            reason: '${(el.widget as Pressable).semanticLabel} ${box.size}',
          );
        }
        await done(t);
      });
    }
  });

  group('놀이터 길게 누르기', () {
    test('길게 누르기 시간은 상수 400ms', () {
      expect(LongPress.sayName, const Duration(milliseconds: 400));
    });

    test('놀이 이름 문장 5개: "~야!" 말투, 음성 목록에 있다', () {
      final lines = VoiceLines.all();
      expect(
        [for (final k in GameKind.values) k.nameLine],
        ['숫자 놀이야!', '색깔 놀이야!', '모양 놀이야!', '크기 놀이야!', '짝 맞추기야!'],
      );
      for (final k in GameKind.values) {
        expect(lines, contains(k.nameLine));
      }
    });

    for (final k in GameKind.values) {
      testWidgets('${k.title}: 길게 누르면 이름을 말하고 들어가지 않는다', (t) async {
        await setSize(t, const Size(844, 390));
        final s = await makeState();
        await t.pumpWidget(wrap(s, const PlaygroundScreen()));
        await settle(t);
        audioOf(s).spoken.clear();
        audioOf(s).played.clear();
        final ride = find.byWidgetPredicate(
          (w) => w is PlaygroundRide && w.kind == k,
        );
        final at = t.getRect(ride);
        final g = await t.startGesture(
          Offset(at.center.dx, at.top + at.height * .45),
        );
        // 400ms 전에는 아무 말도 하지 않는다
        await t.pump(const Duration(milliseconds: 300));
        expect(audioOf(s).spoken, isEmpty);
        await t.pump(const Duration(milliseconds: 150));
        expect(audioOf(s).spoken, [k.nameLine]);
        await g.up();
        await settle(t, 800);
        expect(find.byType(StagePicker), findsNothing);
        expect(audioOf(s).played, isNot(contains(Sfx.tap)));
        await done(t);
      });
    }

    testWidgets('짧게 누르면 예전처럼 들어간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      await t.tap(pressable(GameKind.size.title));
      await settle(t, 800);
      expect(
        t.widget<StagePicker>(find.byType(StagePicker)).game,
        GameKind.size,
      );
      expect(audioOf(s).spoken, isNot(contains(GameKind.size.nameLine)));
      await done(t);
    });
  });

  group('놀이터 그림은 놀이 내용물', () {
    testWidgets('놀이마다 내용물 그림(PlayItemPainter)을 그린다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      for (final k in GameKind.values) {
        expect(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is PlaygroundRide && w.kind == k,
            ),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is CustomPaint &&
                  w.painter is PlayItemPainter &&
                  (w.painter as PlayItemPainter).kind == k,
            ),
          ),
          findsOneWidget,
        );
      }
      await done(t);
    });
  });
}
