import 'dart:io';

import 'package:alokdalok/character/character_view.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/games/common/game_frame.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/poke_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> makeState() async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  return s;
}

RecordingAudio audioOf(GameState s) => s.audio as RecordingAudio;

Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(home: home),
);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Widget resultFrame({VoidCallback? onNext}) => GameFrame(
  done: 5,
  card: const SizedBox(),
  cheer: 0,
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
  onNext: onNext,
);

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

void main() {
  group('결과 화면: 왼쪽 큰 캐릭터, 오른쪽 내용', () {
    for (final (size, pad) in const [
      (Size(568, 320), FakeViewPadding()),
      (Size(844, 390), FakeViewPadding()),
      (Size(932, 430), FakeViewPadding(left: 59, right: 59, bottom: 21)),
      (Size(1280, 800), FakeViewPadding()),
    ]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('$name: 넘침 없이 화면 안, 버튼 60px 이상', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.view.padding = pad;
        t.view.viewPadding = pad;
        addTearDown(t.view.reset);
        final s = await makeState();
        await t.pumpWidget(wrap(s, resultFrame(onNext: () {})));
        await settle(t, 2000);
        expect(t.takeException(), isNull, reason: '넘침(overflow) 없음');

        final safe = Rect.fromLTRB(
          pad.left,
          pad.top,
          size.width - pad.right,
          size.height - pad.bottom,
        );
        final hero = t.getRect(find.byType(PokeCharacter).last);
        expect(safe.contains(hero.topLeft), isTrue, reason: '노치 안쪽');
        expect(safe.contains(hero.bottomRight - const Offset(1, 1)), isTrue);
        // 캐릭터는 크게: 화면 높이의 절반 이상
        final art = t.getSize(find.byType(CharacterView).last);
        expect(art.height, greaterThan(size.height * .5), reason: '$art');

        for (final label in ['또 하기', '다음 단계', '집으로']) {
          final r = t.getRect(pressable(label));
          expect(r.width, greaterThanOrEqualTo(60), reason: label);
          expect(r.height, greaterThanOrEqualTo(60), reason: label);
          expect(safe.contains(r.topLeft), isTrue, reason: label);
          expect(
            safe.contains(r.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: label,
          );
          // 버튼은 모두 캐릭터 오른쪽
          expect(r.left, greaterThan(hero.right), reason: label);
        }
        final ribbon = t.getRect(find.text('정말 잘했어요!'));
        expect(ribbon.left, greaterThan(hero.right));
        expect(find.text('+22'), findsOneWidget);
        expect(find.text('2단계가 열렸어요!'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('결과 화면 캐릭터도 누르면 콕 반응한다', (t) async {
      t.view.physicalSize = const Size(844, 390);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await makeState();
      await t.pumpWidget(wrap(s, resultFrame()));
      await settle(t, 1500);
      audioOf(s).played.clear();
      await t.tap(find.byType(PokeCharacter).last);
      await t.pump();
      expect(audioOf(s).played, [Sfx.poke]);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('캐릭터 콕 누르기', () {
    test('몸짓은 폴짝 → 흔들 → 쭉 순서로 번갈아 나온다', () {
      expect(
        [for (var n = 0; n < 6; n++) PokeCharacter.motionFor(n)],
        [
          PokeMotion.hop,
          PokeMotion.wiggle,
          PokeMotion.stretch,
          PokeMotion.hop,
          PokeMotion.wiggle,
          PokeMotion.stretch,
        ],
      );
    });

    test('두 번에 한 번 짧은 말: 안녕 → 동물 이름 → …', () {
      final lines = [
        for (var n = 0; n < 10; n++) PokeCharacter.lineFor(n, Zodiac.tiger),
      ];
      expect(lines, [
        '안녕!',
        null,
        '나는 호랑이야!',
        null,
        '간지러워!',
        null,
        '같이 놀자!',
        null,
        '또 만져 줘!',
        null,
      ]);
    });

    test('하는 말은 모두 녹음 문장 목록에 있다', () {
      final all = VoiceLines.all();
      for (final l in PokeCharacter.lines) {
        expect(all, contains(l));
      }
      for (final z in Zodiac.values) {
        expect(all, contains(z.hello));
      }
    });

    test('poke.wav 소리 자리가 있다', () {
      expect(Sfx.poke.asset, 'audio/sfx/poke.wav');
      expect(File('assets/audio/sfx/poke.wav').existsSync(), isTrue);
    });

    testWidgets('누르면 소리를 내고 0.8초 한 번만 움직인 뒤 멈춘다 (공용 시계)', (t) async {
      t.view.physicalSize = const Size(844, 390);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await makeState();
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      final listenersBefore = SlowClock.instance.listenerCount;
      audioOf(s).played.clear();
      audioOf(s).spoken.clear();

      final poke = find.byType(PokeCharacter);
      expect(poke, findsOneWidget);
      final st = t.state<PokeCharacterState>(poke);
      Matrix4 matrix() => t
          .widget<Transform>(
            find.descendant(of: poke, matching: find.byType(Transform)).first,
          )
          .transform;

      await t.tap(poke);
      await t.pump();
      expect(audioOf(s).played, [Sfx.poke]);
      expect(audioOf(s).spoken, ['안녕!']);
      expect(st.moving, isTrue);
      expect(st.motion, PokeMotion.hop);
      expect(SlowClock.instance.listenerCount, listenersBefore + 1);

      await t.pump(const Duration(milliseconds: 400));
      expect(st.moving, isTrue);
      await settle(t, 600);
      expect(st.moving, isFalse, reason: '1초 안에 멈춘다');
      expect(matrix(), Matrix4.identity());
      expect(
        SlowClock.instance.listenerCount,
        listenersBefore,
        reason: '멈추면 시계를 놓는다',
      );

      // 두 번째: 흔들기, 말은 하지 않고 소리만
      await t.tap(poke);
      await t.pump();
      await t.pump(const Duration(milliseconds: 150));
      expect(st.motion, PokeMotion.wiggle);
      expect(matrix(), isNot(Matrix4.identity()));
      expect(audioOf(s).played, [Sfx.poke, Sfx.poke]);
      expect(audioOf(s).spoken, ['안녕!']);
      await settle(t, 1000);

      // 세 번째: 쭉 늘리기 + 동물 이름
      await t.tap(poke);
      await t.pump();
      expect(st.motion, PokeMotion.stretch);
      expect(audioOf(s).spoken.last, s.zodiac.hello);
      await settle(t, 1000);
      expect(st.moving, isFalse);
    });

    testWidgets('홈·놀이터·내 캐릭터 화면의 캐릭터: 터치 칸 60px 이상, 누르면 소리', (t) async {
      t.view.physicalSize = const Size(568, 320);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final screen in const [
        HomeScreen(),
        PlaygroundScreen(),
        CharacterScreen(),
      ]) {
        final s = await makeState();
        await t.pumpWidget(wrap(s, screen));
        await settle(t);
        final poke = find.byType(PokeCharacter);
        expect(poke, findsOneWidget, reason: '${screen.runtimeType}');
        final r = t.getRect(poke);
        expect(
          r.width,
          greaterThanOrEqualTo(60),
          reason: '${screen.runtimeType}',
        );
        expect(r.height, greaterThanOrEqualTo(60));
        // 그림 영역 전체가 터치 칸
        final art = t.getRect(
          find.descendant(of: poke, matching: find.byType(CharacterView)),
        );
        expect(r.contains(art.center), isTrue);
        expect(r.width, greaterThanOrEqualTo(art.width - .5));
        audioOf(s).played.clear();
        await t.tapAt(Offset(art.left + art.width * .2, art.bottom - 4));
        await t.pump();
        expect(audioOf(s).played, [Sfx.poke], reason: '${screen.runtimeType}');
        expect(t.takeException(), isNull);
        await settle(t, 1000);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('작은 캐릭터도 터치 칸은 60px', (t) async {
      final s = await makeState();
      await t.pumpWidget(
        wrap(
          s,
          const Center(
            child: PokeCharacter(child: SizedBox(width: 30, height: 30)),
          ),
        ),
      );
      final r = t.getRect(find.byType(PokeCharacter));
      expect(r.width, greaterThanOrEqualTo(60));
      expect(r.height, greaterThanOrEqualTo(60));
    });

    testWidgets('움직임 줄이기 설정이면 소리만 내고 움직이지 않는다', (t) async {
      final s = await makeState();
      await t.pumpWidget(
        AppScope(
          state: s,
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: PokeCharacter(child: SizedBox(width: 80, height: 96)),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byType(PokeCharacter));
      await t.pump();
      expect(audioOf(s).played, [Sfx.poke]);
      expect(
        t.state<PokeCharacterState>(find.byType(PokeCharacter)).moving,
        isFalse,
      );
    });
  });
}
