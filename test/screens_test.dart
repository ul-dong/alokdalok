import 'dart:math';

import 'dart:ui' as ui;

import 'package:alokdalok/app.dart';
import 'package:alokdalok/character/item_art.dart';
import 'package:alokdalok/character/item_thumb.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/games/common/journey_trail.dart';
import 'package:alokdalok/screens/bag_screen.dart';
import 'package:alokdalok/shop/item_widgets.dart';
import 'package:alokdalok/data/game_kinds.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/screens/zodiac_picker_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/hold_button.dart';
import 'package:alokdalok/widgets/listen_again_button.dart';
import 'package:alokdalok/widgets/paged_grid.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:alokdalok/widgets/poke_character.dart';
import 'package:alokdalok/widgets/screen_fit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// 옆으로 미는 스크롤이 화면에 하나라도 있는지
Finder horizontalScrollables() => find.byWidgetPredicate(
  (w) =>
      w is Scrollable &&
      axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
);

const sizes = [Size(568, 320), Size(844, 390), Size(1280, 800)];

String nameOf(Size s) => '${s.width.toInt()}x${s.height.toInt()}';

void main() {
  group('화면에 맞는 격자 (옆으로 밀기 대신 화살표)', () {
    test('넉넉하면 화살표 없이 한 화면에 다 넣는다', () {
      final p = PagedGrid.plan(area: const Size(800, 200), count: 5);
      expect(p.paged, isFalse);
      expect(p.cols * p.rows, greaterThanOrEqualTo(5));
      expect(p.cellWidth, greaterThanOrEqualTo(72));
      expect(p.cellHeight, greaterThanOrEqualTo(72));
    });

    test('칸이 너무 많으면 쪽을 나누고, 칸은 최소 크기를 지킨다', () {
      final p = PagedGrid.plan(
        area: const Size(480, 78),
        count: 18,
        maxRows: 1,
        gap: 5,
      );
      expect(p.paged, isTrue);
      expect(p.rows, 1);
      expect(p.cellWidth, greaterThanOrEqualTo(72));
      expect(p.pagesFor(18), greaterThan(1));
      // 화살표 두 개 + 칸이 폭 안에 들어간다
      expect(
        p.cols * p.cellWidth + (p.cols - 1) * 5 + 2 * (64 + 5),
        lessThanOrEqualTo(480 + .01),
      );
    });

    test('줄 수를 골라 칸을 가장 크게 만든다', () {
      final p = PagedGrid.plan(
        area: const Size(1100, 560),
        count: 8,
        minCellWidth: 120,
        minCellHeight: 120,
        maxRows: 2,
      );
      expect(p.paged, isFalse);
      expect(p.rows, 2);
      expect(p.cols, 4);
    });

    testWidgets('화살표로 넘기면 다음 쪽 칸이 보이고, 끝에서는 화살표가 꺼진다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(
          s,
          Scaffold(
            body: SizedBox(
              width: 400,
              height: 80,
              child: PagedGrid(
                itemCount: 10,
                maxRows: 1,
                itemBuilder: (_, i) => Pressable(
                  onTap: () {},
                  semanticLabel: '칸$i',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(t, 300);
      expect(pressable('칸0'), findsOneWidget);
      expect(pressable('칸9'), findsNothing);
      expect(
        t.widget<PageArrow>(find.byType(PageArrow).first).enabled,
        isFalse,
      );
      for (var i = 0; i < 5; i++) {
        await t.tap(pressable('다음 쪽'));
        await settle(t, 300);
      }
      expect(pressable('칸9'), findsOneWidget);
      expect(pressable('칸0'), findsNothing);
      expect(t.widget<PageArrow>(find.byType(PageArrow).last).enabled, isFalse);
      expect(horizontalScrollables(), findsNothing);
    });

    testWidgets('처음 보일 칸이 있는 쪽을 연다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(
          s,
          Scaffold(
            body: SizedBox(
              width: 400,
              height: 80,
              child: PagedGrid(
                itemCount: 10,
                maxRows: 1,
                initialIndex: 8,
                itemBuilder: (_, i) => Pressable(
                  onTap: () {},
                  semanticLabel: '칸$i',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(t, 300);
      expect(pressable('칸8'), findsOneWidget);
    });
  });

  group('홈 화면', () {
    testWidgets('큰 버튼 세 개와 톱니바퀴만 있고, 누르면 이름을 말한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      final buttons = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Pressable),
          )
          .evaluate()
          .map((e) => (e.widget as Pressable).semanticLabel)
          .toSet();
      expect(buttons, {
        HomeScreen.playgroundLabel,
        HomeScreen.characterLabel,
        HomeScreen.shopLabel,
        HomeScreen.settingsLabel,
      });
      // 내 친구는 버튼이 아니라 콕 누르면 반응하는 캐릭터
      expect(
        find.byWidgetPredicate(
          (w) => w is PokeCharacter && w.semanticLabel == '내 친구 쓰다듬기',
        ),
        findsOneWidget,
      );

      await t.tap(pressable(HomeScreen.playgroundLabel));
      await settle(t, 800);
      expect(audioOf(s).spoken, contains(HomeScreen.playgroundLabel));
      expect(audioOf(s).played, contains(Sfx.tap));
      expect(find.byType(PlaygroundScreen), findsOneWidget);
    });

    testWidgets('톱니바퀴는 부모 확인을 거쳐야 설정으로 간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      // 닫으면 설정으로 가지 않는다
      await t.tap(pressable(HomeScreen.settingsLabel));
      await settle(t, 500);
      expect(find.byType(ParentalGate), findsOneWidget);
      await t.tap(pressable('닫기'));
      await settle(t, 500);
      expect(find.byType(SettingsScreen), findsNothing);
      // 덧셈을 맞히면 설정으로
      await t.tap(pressable(HomeScreen.settingsLabel));
      await settle(t, 500);
      final q = t.widget<Text>(find.byKey(ParentalGate.questionKey)).data!;
      for (final d in '${ParentalGate.answerOf(q)}'.split('')) {
        await t.tap(pressable('숫자 $d'));
        await t.pump(const Duration(milliseconds: 50));
      }
      await settle(t, 1000);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('내 캐릭터·꾸미기 상점 버튼으로 간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      await t.tap(pressable(HomeScreen.characterLabel));
      await settle(t, 800);
      expect(find.byType(CharacterScreen), findsOneWidget);
      Navigator.of(t.element(find.byType(CharacterScreen))).pop();
      await settle(t, 800);
      await t.tap(pressable(HomeScreen.shopLabel));
      await settle(t, 800);
      expect(find.byType(ShopScreen), findsOneWidget);
      expect(audioOf(s).spoken, contains(HomeScreen.shopLabel));
    });
  });

  group('놀이터', () {
    testWidgets('기구 다섯 개, 깬 단계만큼 별, 내 캐릭터가 서 있다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      for (var id = 1; id <= 3; id++) {
        await s.completeSession(GameKind.number, id);
      }
      await s.completeSession(GameKind.color, 1);
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      for (final k in GameKind.values) {
        expect(pressable(k.title), findsOneWidget);
        expect(find.text(k.title), findsOneWidget, reason: '이름표');
      }
      int starsOn(GameKind k) => find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is PlaygroundRide && w.kind == k,
            ),
            matching: find.byType(StarIcon),
          )
          .evaluate()
          .length;
      expect(starsOn(GameKind.number), 3);
      expect(starsOn(GameKind.color), 1);
      expect(starsOn(GameKind.shape), 0);
      expect(find.byType(PokeCharacter), findsOneWidget);
      await settle(t, 400);
      expect(audioOf(s).spoken, contains(PlaygroundScreen.greeting));
    });

    testWidgets('미끄럼틀을 누르면 기구 이름 대신 놀이 이름을 말하고 숫자 단계 고르기로 간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      // 기구 그림(이름표 위쪽)을 누른다
      final ride = find.byWidgetPredicate(
        (w) => w is PlaygroundRide && w.kind == GameKind.number,
      );
      final box = t.getRect(ride);
      await t.tapAt(Offset(box.center.dx, box.top + box.height * .4));
      await settle(t, 800);
      expect(audioOf(s).spoken, contains('숫자 놀이!'));
      expect(audioOf(s).spoken.join(), isNot(contains('미끄럼틀')));
      final picker = t.widget<StagePicker>(find.byType(StagePicker));
      expect(picker.game, GameKind.number);
    });

    for (final k in GameKind.values) {
      testWidgets('놀이터 이름표 "${k.title}"를 눌러도 같은 놀이 이름을 말한다', (t) async {
        await setSize(t, const Size(844, 390));
        final s = await makeState();
        await t.pumpWidget(wrap(s, const PlaygroundScreen()));
        await settle(t);
        audioOf(s).spoken.clear();
        await t.tap(find.text(k.title));
        await t.pump();
        expect(audioOf(s).spoken.first, '${k.title}!');
        expect(audioOf(s).spoken.first, k.invite);
        await settle(t, 800);
        expect(t.widget<StagePicker>(find.byType(StagePicker)).game, k);
      });
    }

    testWidgets('모래놀이터·시소·회전목마는 단계 고르기를 거쳐 실제 놀이로 간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      for (final (k, screen) in [
        (GameKind.shape, ShapeGameScreen),
        (GameKind.size, SizeGameScreen),
        (GameKind.match, MatchGameScreen),
      ]) {
        await t.pumpWidget(wrap(s, const PlaygroundScreen()));
        await settle(t);
        await t.tap(pressable(k.title));
        await settle(t, 800);
        expect(audioOf(s).spoken.last, k.invite);
        expect(t.widget<StagePicker>(find.byType(StagePicker)).game, k);
        expect(pressable('5단계 아직 열리지 않음'), findsOneWidget);
        await t.tap(pressable('1단계'));
        await settle(t, 1200);
        expect(find.byType(screen), findsOneWidget, reason: '$k');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('단계 고르기', () {
    testWidgets('잠긴 단계를 누르면 카드가 흔들리고 앞 단계를 먼저 놀자고 말한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.color)));
      await settle(t);
      final card = pressable('3단계 아직 열리지 않음');
      expect(card, findsOneWidget);
      final before = t.getTopLeft(card);
      await t.tap(card);
      await t.pump(const Duration(milliseconds: 60));
      await t.pump(const Duration(milliseconds: 60));
      final during = t.getTopLeft(card);
      expect(during.dx, isNot(closeTo(before.dx, .5)), reason: '흔들린다');
      expect(audioOf(s).spoken.last, StagePicker.lockedLine);
      await settle(t, 600);
      expect(t.getTopLeft(card).dx, closeTo(before.dx, .5), reason: '제자리로');
      expect(find.byType(StagePicker), findsOneWidget, reason: '시작하지 않는다');
    });

    testWidgets('열린 단계를 누르면 놀이가 시작된다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.number)));
      await settle(t);
      await t.tap(pressable('1단계'));
      await settle(t, 800);
      expect(find.byType(NumberGameScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    test('흔들림은 처음과 끝이 제자리다', () {
      expect(ShakeOnChange.offsetAt(0), 0);
      expect(ShakeOnChange.offsetAt(1).abs(), lessThan(1e-9));
      expect(ShakeOnChange.offsetAt(.08).abs(), greaterThan(1));
    });
  });

  group('옆으로 밀기 없음', () {
    for (final size in sizes) {
      testWidgets('상점·내 캐릭터·친구 고르기·단계 고르기 (${nameOf(size)})', (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (final page in <Widget>[
          const ShopScreen(),
          const CharacterScreen(),
          const ZodiacPickerScreen(),
          const PlaygroundScreen(),
          for (final k in GameKind.values) StagePicker(game: k),
        ]) {
          await t.pumpWidget(wrap(s, page));
          await settle(t, 300);
          expect(horizontalScrollables(), findsNothing, reason: '$page');
          expect(t.takeException(), isNull, reason: '$page');
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  });

  group('화면 크기', () {
    for (final size in sizes) {
      testWidgets('홈·놀이터·단계 고르기가 ${nameOf(size)}에서 넘치지 않는다', (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (var id = 1; id <= 4; id++) {
          await s.completeSession(GameKind.number, id);
        }
        await t.pumpWidget(AlokdalokApp(state: s));
        await settle(t);
        expect(t.takeException(), isNull, reason: 'home');
        for (final page in <Widget>[
          const PlaygroundScreen(),
          for (final k in GameKind.values) StagePicker(game: k),
        ]) {
          await t.pumpWidget(wrap(s, page));
          await settle(t);
          expect(t.takeException(), isNull, reason: '$page');
        }
        // 열린 단계(5단계)가 보이는 쪽이 먼저 열린다
        await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.number)));
        await settle(t);
        expect(pressable('5단계'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('누르는 칸이 ${nameOf(size)}에서 60px 이상 (홈·놀이터·단계 고르기)', (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (final page in <Widget>[
          const HomeScreen(),
          const PlaygroundScreen(),
          const StagePicker(game: GameKind.number),
          const ShopScreen(),
        ]) {
          await t.pumpWidget(wrap(s, page));
          await settle(t);
          for (final el in find.byType(Pressable).evaluate()) {
            final box = el.renderObject as RenderBox;
            final label = (el.widget as Pressable).semanticLabel;
            expect(
              box.size.shortestSide,
              greaterThanOrEqualTo(60),
              reason: '$page $label ${box.size}',
            );
          }
        }
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('높이 340 미만이면 화면 전체를 340 높이로 그려서 줄인다', (t) async {
      await setSize(t, const Size(568, 320));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      final ctx = t.element(find.byType(HomeScreen));
      expect(MediaQuery.sizeOf(ctx).height, 340);
      expect(MediaQuery.sizeOf(ctx).width, closeTo(568 * 340 / 320, .01));
      // 줄여도 화면 밖으로 나가지 않는다
      final r = t.getRect(find.byType(HomeScreen));
      expect(r.bottom, lessThanOrEqualTo(320.01));
      expect(r.right, lessThanOrEqualTo(568.01));
      // 버튼도 그대로 눌린다
      await t.tap(pressable(HomeScreen.playgroundLabel));
      await settle(t, 800);
      expect(find.byType(PlaygroundScreen), findsOneWidget);
    });

    testWidgets('높이 340 이상이면 그대로 그린다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      final ctx = t.element(find.byType(HomeScreen));
      expect(MediaQuery.sizeOf(ctx), const Size(844, 390));
      expect(MinHeightScaler.scaleFor(const Size(1280, 800)), 1);
    });

    testWidgets('화면 전환은 짧은 페이드', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t);
      await t.tap(pressable(HomeScreen.playgroundLabel));
      await t.pump();
      await t.pump(const Duration(milliseconds: 80));
      final fades = find.ancestor(
        of: find.byType(PlaygroundScreen),
        matching: find.byType(FadeTransition),
      );
      expect(fades, findsWidgets);
      expect(
        find.ancestor(
          of: find.byType(PlaygroundScreen),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await settle(t, 400);
      final theme = Theme.of(t.element(find.byType(PlaygroundScreen)));
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadePageTransitionsBuilder>(),
      );
    });
  });

  group('다시 듣기 버튼', () {
    testWidgets('62px 노란 버튼, 6초마다 한 번 통통 튀고 누르면 다시 말한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      var taps = 0;
      await t.pumpWidget(
        wrap(
          s,
          Scaffold(
            body: Center(child: ListenAgainButton(onTap: () => taps++)),
          ),
        ),
      );
      final btn = pressable('다시 듣기');
      expect(t.getSize(btn), const Size(62, 62));
      final rest = t.getTopLeft(btn);
      await t.pump(const Duration(seconds: 3));
      expect(t.getTopLeft(btn), rest, reason: '쉬는 동안은 가만히');
      await t.pump(const Duration(seconds: 3)); // 6초: 튀기 시작
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.getTopLeft(btn).dy, lessThan(rest.dy - 2), reason: '위로 튄다');
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(t.getTopLeft(btn), rest, reason: '다시 제자리');
      await t.tap(btn);
      expect(taps, 1);
      await t.pumpWidget(const SizedBox());
    });

    test('튀는 높이는 0.6초 안에서만 생긴다', () {
      expect(ListenAgainButton.hopOffset(0, 62), 0);
      expect(ListenAgainButton.hopOffset(.2, 62), lessThan(-5));
      expect(ListenAgainButton.hopOffset(.6, 62), 0);
      expect(ListenAgainButton.hopOffset(3, 62), 0);
    });
  });

  group('놀이 중 멈춤', () {
    testWidgets('집으로는 약 1초 꾹 눌러야 나가고, 짧게 누르면 안내만 한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.number)));
      await settle(t);
      await t.tap(pressable('1단계'));
      await settle(t, 1200);
      await t.tap(pressable('잠깐 멈추기'));
      await settle(t, 300);
      final home = find.byType(HoldToConfirm);
      expect(home, findsOneWidget);

      // 짧게 누르면 나가지 않는다
      var g = await t.startGesture(t.getCenter(home));
      await t.pump(const Duration(milliseconds: 300));
      await g.up();
      await settle(t, 400);
      expect(find.byType(NumberGameScreen), findsOneWidget);
      expect(audioOf(s).spoken.last, HoldToConfirm.hint);

      // 누르는 동안 고리가 차오른다
      g = await t.startGesture(t.getCenter(home));
      await t.pump(); // 고리 시계가 이 프레임부터 돈다
      await t.pump(const Duration(milliseconds: 500));
      final ring = t.widget<CustomPaint>(
        find.descendant(
          of: home,
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is HoldRingPainter,
          ),
        ),
      );
      expect(
        (ring.painter! as HoldRingPainter).progress,
        inInclusiveRange(.3, .7),
      );
      await t.pump(const Duration(milliseconds: 600));
      await g.up();
      await settle(t, 800);
      expect(find.byType(NumberGameScreen), findsNothing);
    });

    testWidgets('안드로이드 뒤로가기는 멈춤 화면을 연다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(1))),
      );
      await settle(t, 800);
      expect(find.byType(HoldToConfirm), findsNothing);
      await t.binding.handlePopRoute();
      await settle(t, 300);
      expect(find.byType(HoldToConfirm), findsOneWidget);
      expect(find.byType(NumberGameScreen), findsOneWidget);
      await t.tap(pressable('계속'));
      await settle(t, 300);
      expect(find.byType(HoldToConfirm), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('누르면 이름 말하기', () {
    testWidgets('speak가 있으면 효과음과 함께 이름을 말한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(
          s,
          Scaffold(
            body: Center(
              child: Pressable(
                onTap: () {},
                semanticLabel: '시소',
                speak: '시소!',
                child: const SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      );
      await t.tap(pressable('시소'));
      await t.pump();
      expect(audioOf(s).played.last, Sfx.tap);
      expect(audioOf(s).spoken.last, '시소!');
    });

    testWidgets('내 캐릭터 화면에서 옷을 누르면 옷 이름을 말한다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await s.purchase('ribbon_pink');
      await t.pumpWidget(wrap(s, const CharacterScreen()));
      await settle(t);
      await t.tap(pressable('공주'));
      await settle(t, 300);
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is Pressable && (w.semanticLabel ?? '').startsWith('분홍 리본'),
        ),
      );
      await settle(t, 300);
      expect(audioOf(s).spoken.last, '분홍 리본');
    });

    test('새 화면에서 하는 말은 모두 녹음 조각으로 나뉜다', () {
      final lines = VoiceLines.all();
      final pack = VoicePack({
        for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3',
      });
      for (final text in [
        HomeScreen.playgroundLabel,
        HomeScreen.characterLabel,
        HomeScreen.shopLabel,
        PlaygroundScreen.greeting,
        HoldToConfirm.hint,
        StagePicker.lockedLine,
        '다시 듣기',
        '집으로',
        '뒤로',
        for (final k in GameKind.values) k.invite,
      ]) {
        expect(pack.plan(text), isNotNull, reason: text);
      }
    });
  });

  group('새 놀이 종류', () {
    test('모양·크기·짝 맞추기도 깨면 다음 단계가 열린다', () async {
      final s = await makeState();
      for (final k in [GameKind.shape, GameKind.size, GameKind.match]) {
        expect(s.unlockedStage(k), 1);
        final r = await s.completeSession(k, 1);
        expect(r.unlockedStage, 2);
        expect(s.unlockedStage(k), 2);
        expect(s.clearedStages(k), {1});
      }
      // 숫자·색깔 진행은 그대로
      expect(s.unlockedStage(GameKind.number), 1);
      expect(s.unlockedStage(GameKind.color), 1);
      expect(s.clearedStages(GameKind.color), isEmpty);
    });

    test('놀이터 기구를 누르면 하는 말은 놀이 이름', () {
      expect(GameKind.number.invite, '숫자 놀이!');
      expect(GameKind.color.invite, '색깔 놀이!');
      expect(GameKind.shape.invite, '모양 놀이!');
      expect(GameKind.size.invite, '크기 놀이!');
      expect(GameKind.match.invite, '짝 맞추기!');
      final lines = VoiceLines.all();
      for (final k in GameKind.values) {
        expect(lines, contains(k.invite), reason: '녹음 문장 목록');
      }
      for (final old in ['미끄럼틀!', '그네!', '모래놀이터!', '시소!', '회전목마!']) {
        expect(lines, isNot(contains(old)));
      }
    });
  });

  group('홈 설정 버튼 자리 (집으로를 두 번 눌러도 설정이 뜨지 않게)', () {
    for (final size in sizes) {
      testWidgets('톱니바퀴는 오른쪽 아래, 다른 화면의 왼쪽 위 버튼과 겹치지 않는다 (${nameOf(size)})', (
        t,
      ) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(AlokdalokApp(state: s));
        await settle(t);
        final gear = t.getRect(pressable(HomeScreen.settingsLabel));
        // 아주 낮은 화면은 전체가 축소되므로 축소 전 크기로 잰다
        final k = MinHeightScaler.scaleFor(size);
        expect(gear.width / k, greaterThan(59.9), reason: '누르는 칸 60px');
        expect(gear.height / k, greaterThan(59.9), reason: '누르는 칸 60px');
        expect(gear.center.dx, greaterThan(size.width * .75), reason: '오른쪽');
        expect(gear.center.dy, greaterThan(size.height * .6), reason: '아래쪽');
        // 홈 위에 다른 화면을 올려(같은 화면 배율) 왼쪽 위 버튼 자리를 잰다
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        for (final (page, label) in <(Widget, String)>[
          (const ShopScreen(), '집으로'),
          (const PlaygroundScreen(), '집으로'),
          (const StagePicker(game: GameKind.number), '놀이터로'),
          (const CharacterScreen(), '집으로'),
          (const ZodiacPickerScreen(), '뒤로'),
          (const BagScreen(), '집으로'),
        ]) {
          nav.push(softRoute(page));
          await settle(t, 800);
          final back = t.getRect(pressable(label).last);
          expect(
            back.inflate(12).overlaps(gear),
            isFalse,
            reason: '${page.runtimeType}의 $label',
          );
          nav.pop();
          await settle(t, 800);
        }
        expect(t.takeException(), isNull);
      });
    }
  });

  group('상점 물건 칸 (정사각형, 부위 확대)', () {
    testWidgets('미리보기 영역 표가 실제 아이템 그림과 맞다', (t) async {
      final wrong = <String>[];
      await t.runAsync(() async {
        for (final item in ItemCatalog.all) {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec)..translate(100, 100);
          final art = ItemArt(c);
          switch (item.slot) {
            case ItemSlot.head:
              art.head(item);
            case ItemSlot.shoes:
              art.shoes(item);
            case ItemSlot.accessory:
              art.accessory(item);
            case ItemSlot.outfit:
              art.outfit(item, happy: false);
            case ItemSlot.back:
              art
                ..backBehind(item)
                ..backFront(item);
          }
          final img = await rec.endRecording().toImage(400, 440);
          final bytes = (await img.toByteData())!;
          var l = 999, top = 999, r = -1, b = -1;
          for (var y = 0; y < 440; y++) {
            for (var x = 0; x < 400; x++) {
              if (bytes.getUint8((y * 400 + x) * 4 + 3) > 20) {
                l = min(l, x);
                r = max(r, x);
                top = min(top, y);
                b = max(b, y);
              }
            }
          }
          final drawn = Rect.fromLTRB(
            l - 100.0,
            top - 100.0,
            r - 99.0,
            b - 99.0,
          );
          final table = ItemThumb.bounds[item.id];
          if (table == null ||
              (table.left - drawn.left).abs() > 2 ||
              (table.top - drawn.top).abs() > 2 ||
              (table.right - drawn.right).abs() > 2 ||
              (table.bottom - drawn.bottom).abs() > 2) {
            wrong.add("'${item.id}': $drawn");
          }
        }
      });
      expect(wrong, isEmpty, reason: 'ItemThumb.bounds 값을 고쳐 주세요');
    });

    test('아이템이 칸 안에 온전히 들어가고, 모자·신발은 전신보다 크게 확대된다', () {
      for (final item in ItemCatalog.all) {
        final f = ItemThumb.focus(item);
        expect(f.width, closeTo(f.height, 1e-9), reason: item.id);
        expect(
          f.contains(ItemThumb.bounds[item.id]!.topLeft) &&
              f.contains(
                ItemThumb.bounds[item.id]!.bottomRight - const Offset(.01, .01),
              ),
          isTrue,
          reason: '${item.id} 잘리지 않음',
        );
        // 예전에는 친구 전신·상반신(약 208~252)을 보여 줬다
        if (item.slot == ItemSlot.head || item.slot == ItemSlot.shoes) {
          expect(f.width, lessThan(205), reason: '${item.id} 확대');
        }
      }
      // 작은 왕관은 머리 부분만 크게
      expect(
        ItemThumb.focus(ItemCatalog.byId('crown_gold')!).width,
        lessThan(150),
      );
    });

    for (final size in sizes) {
      testWidgets('상점·내 캐릭터 물건 칸은 정사각형이고 한 쪽에 다 들어간다 (${nameOf(size)})', (
        t,
      ) async {
        await setSize(t, size);
        final s = await makeState();
        for (var i = 0; i < 80; i++) {
          await s.rewardCorrect(firstTry: true);
        }
        for (final i in ItemCatalog.byTheme(OutfitTheme.robot)) {
          await s.purchase(i.id);
        }
        final most = OutfitTheme.values
            .map((th) => ItemCatalog.byTheme(th).length)
            .reduce(max);
        for (final page in const [ShopScreen(), CharacterScreen()]) {
          await t.pumpWidget(wrap(s, page));
          await settle(t);
          expect(t.takeException(), isNull);
          final tiles = find.byType(ItemTile);
          expect(
            tiles,
            findsNWidgets(ItemCatalog.byTheme(OutfitTheme.robot).length),
            reason: '$page',
          );
          for (final e in tiles.evaluate()) {
            final sz = (e.renderObject! as RenderBox).size;
            expect(
              (sz.width - sz.height).abs(),
              lessThan(1.5),
              reason: '정사각형 $sz',
            );
            expect(sz.width, greaterThanOrEqualTo(ItemTile.minWidth));
          }
          // 가장 많은 테마도 화살표 없이 한 쪽에 들어간다
          final grid = find.ancestor(
            of: tiles.first,
            matching: find.byType(PagedGrid),
          );
          final plan = PagedGrid.plan(
            area: t.getSize(grid.first),
            count: most,
            minCellWidth: ItemTile.minWidth,
            minCellHeight: ItemTile.minHeight,
            maxCellWidth: ItemTile.maxWidth,
            maxCellHeight: ItemTile.maxHeight,
            arrowSize: ItemTile.arrowSize,
            gap: 12,
            cellAspect: ItemTile.aspect,
          );
          expect(plan.paged, isFalse, reason: '$page $plan');
          await t.pumpWidget(const SizedBox());
        }
      });
    }

    test('칸 모양을 고정하면 정사각형으로 나온다', () {
      final p = PagedGrid.plan(
        area: const Size(470, 280),
        count: 5,
        minCellWidth: 80,
        minCellHeight: 80,
        cellAspect: 1,
      );
      expect(p.cellWidth, p.cellHeight);
      expect(p.cols * p.rows, greaterThanOrEqualTo(5));
      expect(p.cellWidth, greaterThan(120), reason: '두 줄로 크게');
    });

    testWidgets('상점 테마 탭: 고른 탭은 진한 노랑 둘레와 노랑 면으로 구별된다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const ShopScreen()));
      await settle(t);
      BoxDecoration outer(String label) =>
          t
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: pressable(label),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(outer('로봇').color, ShopStyle.tabOnRing);
      expect(outer('공주').color, ShopStyle.surface);
      await t.tap(pressable('공주'));
      await settle(t, 400);
      expect(outer('공주').color, ShopStyle.tabOnRing);
      expect(outer('로봇').color, ShopStyle.surface);
      // 둘레 안쪽 면도 고른 탭만 노랑
      final faces = find.descendant(
        of: pressable('공주'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == ShopStyle.tabOn,
        ),
      );
      expect(faces, findsOneWidget);
    });
  });

  group('친구 고르기 (한 쪽에 6마리)', () {
    testWidgets('지금 친구가 있는 쪽을 열고, 큰 화살표와 점으로 넘긴다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await s.setZodiac(Zodiac.dog);
      await t.pumpWidget(wrap(s, const ZodiacPickerScreen()));
      await settle(t);
      expect(find.byType(ZodiacTile), findsNWidgets(FriendPager.perPage));
      expect(
        pressable(Zodiac.dog.look.animal),
        findsOneWidget,
        reason: '두 번째 쪽',
      );
      expect(pressable(Zodiac.rat.look.animal), findsNothing);
      final dots = t.widget<PageDots>(find.byType(PageDots));
      expect((dots.count, dots.current), (2, 1));
      for (final label in ['앞 쪽', '다음 쪽']) {
        final sz = t.getSize(pressable(label));
        expect(sz.width, greaterThanOrEqualTo(52), reason: label);
        expect(sz.height, greaterThanOrEqualTo(88), reason: label);
      }
      // 칸 안에는 이름 글씨가 없고, 고른 친구 이름은 왼쪽 이름표에 크게
      expect(
        find.descendant(
          of: find.byType(ZodiacTile),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(ZodiacPickerScreen.namePlateKey),
          matching: find.text(Zodiac.dog.look.animal),
        ),
        findsOneWidget,
      );
      await t.tap(pressable('앞 쪽'));
      await settle(t, 400);
      expect(pressable(Zodiac.rat.look.animal), findsOneWidget);
      expect(t.widget<PageDots>(find.byType(PageDots)).current, 0);
      await t.tap(pressable(Zodiac.rabbit.look.animal));
      await settle(t, 300);
      expect(
        find.descendant(
          of: find.byKey(ZodiacPickerScreen.namePlateKey),
          matching: find.text(Zodiac.rabbit.look.animal),
        ),
        findsOneWidget,
      );
      // 공룡도 같은 방식 (6마리씩 두 쪽)
      await t.tap(pressable('공룡'));
      await settle(t, 400);
      expect(find.byType(ZodiacTile), findsNWidgets(6));
      expect(pressable(Zodiac.trex.look.animal), findsOneWidget);
      await t.tap(pressable('다음 쪽'));
      await settle(t, 400);
      expect(pressable(Zodiac.dilophosaurus.look.animal), findsOneWidget);
      expect(t.widget<PageDots>(find.byType(PageDots)).current, 1);
    });

    for (final size in sizes) {
      for (final onboarding in [true, false]) {
        testWidgets(
          '${onboarding ? '첫 실행' : '친구 바꾸기'}: 얼굴 칸이 크고 넘치지 않는다 (${nameOf(size)})',
          (t) async {
            await setSize(t, size);
            final s = await makeState();
            await s.setZodiac(Zodiac.spinosaurus);
            await t.pumpWidget(
              wrap(s, ZodiacPickerScreen(onboarding: onboarding)),
            );
            await settle(t);
            expect(t.takeException(), isNull);
            expect(find.byType(ZodiacTile), findsNWidgets(6));
            expect(
              pressable(Zodiac.spinosaurus.look.animal),
              findsOneWidget,
              reason: '공룡 탭의 두 번째 쪽을 연다',
            );
            for (final e in find.byType(ZodiacTile).evaluate()) {
              final sz = (e.renderObject! as RenderBox).size;
              expect(sz.width, greaterThanOrEqualTo(70), reason: '$sz');
              expect((sz.width - sz.height).abs(), lessThan(1), reason: '$sz');
            }
          },
        );
      }
    }
  });

  group('단계 고르기 카드', () {
    for (final size in sizes) {
      testWidgets('골인 길은 낮게, 잠긴 카드는 흐리게 + 큰 자물쇠 (${nameOf(size)})', (t) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.color)));
        await settle(t);
        expect(t.takeException(), isNull);
        final trail = t.getSize(find.byType(JourneyTrail)).height / size.height;
        expect(trail, inInclusiveRange(.15, .2), reason: '화면 높이의 15~20%');
        final open = pressable('1단계');
        final locked = pressable('2단계 아직 열리지 않음');
        expect(
          find.descendant(of: open, matching: find.byType(BigLock)),
          findsNothing,
        );
        expect(
          find.descendant(of: locked, matching: find.byType(BigLock)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: locked, matching: find.byType(ColorFiltered)),
          findsOneWidget,
          reason: '잠긴 그림은 회색',
        );
        final lock = t.getSize(
          find.descendant(of: locked, matching: find.byType(BigLock)),
        );
        final card = t.getSize(locked);
        expect(
          max(lock.width / card.width, lock.height / card.height),
          greaterThan(.4),
          reason: '자물쇠가 크다',
        );
        expect(
          t.getSize(open).width,
          greaterThanOrEqualTo(StagePicker.minCardWidth),
        );
      });
    }
  });
}
