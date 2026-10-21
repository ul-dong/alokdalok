// 통합 마무리: 물건 이름 말하기, 단계 카드 그림 크기, 옆으로 밀기·계속 도는 애니메이션 없음,
// 짧은 페이드 전환, 공용 격자
import 'dart:io';
import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart' as quiz;
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/shape_game/shape_game_screen.dart';
import 'package:alokdalok/games/shape_game/shape_round.dart';
import 'package:alokdalok/games/size_game/size_game_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/paged_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> makeState({bool named = true, bool rich = false}) async {
  final storage = MemoryStorage();
  if (rich) {
    // 코인이 많고 옷을 다 가진 아이 (내 캐릭터 화면에 옷 칸이 가득)
    final d = SaveData.decode(null)
      ..coins = 2000
      ..owned = {for (final i in ItemCatalog.all) i.id};
    storage.raw = d.encode();
  }
  final s = GameState(storage: storage, audio: RecordingAudio());
  await s.load();
  if (named) await s.setNickname('별이');
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

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 7));
}

RecordingAudio audioOf(GameState s) => s.audio as RecordingAudio;

const sizes = [Size(568, 320), Size(844, 390), Size(1280, 800)];

/// lib/ 아래 모든 dart 파일 (경로, 내용)
List<(String, String)> libSources() => [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart')) (f.path, f.readAsStringSync()),
];

void main() {
  group('놀이 화면 물건을 누르면 이름을 말한다 (원칙 1)', () {
    testWidgets('숫자 놀이: 세는 물건을 누르면 이름, 답을 고른 것으로 치지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = NumberQuestion.generate(Stages.number[0], Random(4));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(4))),
      );
      await settle(t);
      final names = find.byType(SayName);
      expect(names, findsNWidgets(q.count));
      final coins = s.coins;
      await t.tap(names.first);
      await settle(t, 200);
      expect(audioOf(s).spoken.last, q.kind.sayName());
      expect(audioOf(s).played, isNot(contains(Sfx.tryAgain)));
      expect(audioOf(s).played, isNot(contains(Sfx.correct)));
      expect(s.coins, coins);
      await done(t);
    });

    testWidgets('숫자 놀이: 같이 세는 동안에는 물건을 눌러도 세는 소리를 끊지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = NumberQuestion.generate(Stages.number[0], Random(4));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(4))),
      );
      await settle(t);
      // 틀린 보기를 눌러 같이 세기 시작
      final wrong = q.choices.indexWhere((c) => c != q.count);
      await t.tap(find.text('${q.choices[wrong]}').first);
      await settle(t, 300);
      expect(
        t.widgetList<SayName>(find.byType(SayName)).every((w) => !w.enabled),
        isTrue,
      );
      await settle(t, 6000);
      // 다 세고 나면 다시 누를 수 있다
      expect(
        t.widgetList<SayName>(find.byType(SayName)).every((w) => w.enabled),
        isTrue,
      );
      await done(t);
    });

    testWidgets('모양 놀이: 견본 그림을 누르면 모양 이름', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final q = ShapeQuestion.generate(Stages.shape[4], Random(2));
      await t.pumpWidget(
        wrap(s, ShapeGameScreen(stageId: 5, random: Random(2))),
      );
      await settle(t);
      await t.tap(find.byType(SayName));
      await settle(t, 200);
      expect(audioOf(s).spoken.last, '${q.shape.ko}!');
      await done(t);
    });

    testWidgets('보기 칸은 그대로 답 고르기 (이름 말하기를 덧씌우지 않는다)', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      for (final screen in <Widget>[
        ShapeGameScreen(stageId: 5, random: Random(2)),
        SizeGameScreen(stageId: 1, random: Random(2)),
        ColorGameScreen(stageId: 1, random: Random(2)),
      ]) {
        await t.pumpWidget(wrap(s, screen));
        await settle(t);
        for (final tile in t.widgetList<quiz.QuizTile>(
          find.byType(quiz.QuizTile),
        )) {
          expect(
            find.descendant(
              of: find.byWidget(tile),
              matching: find.byType(SayName),
            ),
            findsNothing,
          );
        }
        await t.pumpWidget(const SizedBox());
      }
      await done(t);
    });

    test('누르면 말하는 이름은 모두 녹음 조각에 있다', () {
      final lines = VoiceLines.all().toSet();
      for (final k in ObjectKind.values) {
        expect(lines, contains(k.sayName()));
        for (final c in GameColor.extended) {
          expect(lines, contains(k.sayName(c)));
        }
      }
      for (final c in GameColor.extended) {
        expect(lines, contains('${c.name}!'));
      }
    });
  });

  group('단계 카드 그림', () {
    for (final size in sizes) {
      testWidgets('카드 크기에 맞춰 그림을 키운다 (${size.width.toInt()})', (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (final kind in GameKind.values) {
          await t.pumpWidget(wrap(s, StagePicker(game: kind)));
          await settle(t);
          expect(t.takeException(), isNull);
          final box = find.byType(StageArtBox).first;
          final area = t.getSize(box);
          final fitted = find
              .descendant(of: box, matching: find.byType(FittedBox))
              .first;
          final art = t.widget<FittedBox>(fitted).child!;
          final drawn = t.getRect(
            find.descendant(of: fitted, matching: find.byWidget(art)),
          );
          // 그림이 칸의 가로나 세로 한쪽을 (거의) 다 채운다
          final fill = max(
            drawn.width / area.width,
            drawn.height / area.height,
          );
          expect(fill, greaterThan(.95), reason: '$kind $drawn / $area');
          await t.pumpWidget(const SizedBox());
        }
        await done(t);
      });
    }
  });

  group('옆으로 밀기 없음 (원칙 4)', () {
    test('lib 어디에도 가로 스크롤이 없다', () {
      final bad = <String>[];
      for (final (path, src) in libSources()) {
        if (src.contains('Axis.horizontal') ||
            RegExp(r'scrollDirection\s*:').hasMatch(src) ||
            src.contains('PageView')) {
          bad.add(path);
        }
      }
      expect(bad, isEmpty);
    });

    test('세로로 미는 목록도 부모님 화면(설정·이름 입력)과 안 쓰는 내 가방에만', () {
      const allowed = {
        'settings_screen.dart',
        'nickname_screen.dart',
        'bag_screen.dart',
      };
      final bad = <String>[];
      for (final (path, src) in libSources()) {
        final name = path.split(Platform.pathSeparator).last;
        if (allowed.contains(name)) continue;
        if (RegExp(
          r'\b(ListView|GridView|SingleChildScrollView|CustomScrollView)\b',
        ).hasMatch(src)) {
          bad.add(path);
        }
      }
      expect(bad, isEmpty);
    });

    for (final size in sizes) {
      testWidgets('상점·내 캐릭터 옷 칸은 밀지 않고 한 화면/화살표 (${size.width.toInt()})', (
        t,
      ) async {
        await setSize(t, size);
        final s = await makeState(rich: true);
        for (final w in <Widget>[const ShopScreen(), const CharacterScreen()]) {
          await t.pumpWidget(wrap(s, w));
          await settle(t);
          expect(t.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing, reason: '$w');
          expect(find.byType(PagedGrid), findsWidgets, reason: '$w');
          await t.pumpWidget(const SizedBox());
        }
        await done(t);
      });
    }
  });

  group('계속 도는 애니메이션 없음 (원칙 8)', () {
    test('lib에 repeat() 애니메이션이 없고, 빠른 시계는 반짝이 잠깐뿐', () {
      final repeats = <String>[];
      final fast = <String>[];
      for (final (path, src) in libSources()) {
        if (RegExp(r'\.\.?repeat\(').hasMatch(src)) repeats.add(path);
        if (src.contains('createTicker(')) fast.add(path);
        for (final m in RegExp(
          r'Timer\.periodic\(\s*const Duration\(milliseconds:\s*(\d+)\)',
        ).allMatches(src)) {
          if (int.parse(m.group(1)!) < 50 &&
              !path.endsWith('scene_game.dart')) {
            fast.add(path);
          }
        }
      }
      expect(repeats, isEmpty);
      expect(fast, isEmpty);
    });

    testWidgets('세로 안내는 몇 번만 눕혀 보이고 시계에서 빠진다', (t) async {
      final before = SlowClock.instance.listenerCount;
      await t.pumpWidget(const MaterialApp(home: RotateHint()));
      expect(SlowClock.instance.listenerCount, before + 1);
      await t.pump(const Duration(milliseconds: 1300));
      final mid = t.widget<Transform>(
        find.descendant(
          of: find.byType(RotateHint),
          matching: find.byType(Transform),
        ),
      );
      expect(mid.transform.isIdentity(), isFalse, reason: '눕는 중');
      for (var i = 0; i < 80; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(SlowClock.instance.listenerCount, before, reason: '멈춤');
      expect(find.text('화면을 옆으로 돌려 주세요'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('화면 전환 (원칙 9)', () {
    testWidgets('첫 화면이 끝나 홈으로 바뀔 때도 짧은 페이드', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState(named: false);
      await t.pumpWidget(AlokdalokApp(state: s));
      await settle(t, 300);
      expect(find.byType(HomeScreen), findsNothing);
      await s.setNickname('별이');
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // 바뀌는 중: 홈이 서서히 나타난다 (번쩍 바뀌지 않음)
      final fade = t.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(HomeScreen),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await settle(t, 400);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(RootGate.fadeDuration.inMilliseconds, lessThanOrEqualTo(300));
      await done(t);
    });
  });

  group('공용 격자', () {
    test('놀이 보기 격자(TileGrid)는 공용 격자 모듈 하나에 있다', () {
      final g = quiz.TileGrid.fit(6, const Size(600, 300));
      expect(g, isA<TileGrid>());
      expect(g.rows * g.cols, greaterThanOrEqualTo(6));
      expect(File('lib/vehicle/fit_grid.dart').existsSync(), isFalse);
      // 줄 배치는 GridRows 하나만 쓴다
      final rowBuilders = libSources()
          .where((e) => e.$2.contains('GridRows('))
          .map((e) => e.$1.split(Platform.pathSeparator).last)
          .toSet();
      expect(
        rowBuilders,
        containsAll(['paged_grid.dart', 'quiz_widgets.dart']),
      );
    });

    testWidgets('GridRows: 칸 크기와 사이를 지켜 줄지어 놓는다', (t) async {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: GridRows(
              last: 5,
              cols: 3,
              cellWidth: 40,
              cellHeight: 30,
              gap: 10,
              itemBuilder: (i) => SizedBox(key: ValueKey(i)),
            ),
          ),
        ),
      );
      Rect r(int i) => t.getRect(find.byKey(ValueKey(i)));
      expect(r(0).size, const Size(40, 30));
      expect(r(1).left - r(0).right, 10);
      expect(r(3).top - r(0).bottom, 10);
      // 덜 찬 줄은 가운데 맞춤 (칸 반 개 + 사이 반만큼 안쪽)
      expect(r(3).left, r(0).left + 25);
      expect(find.byType(Row), findsNWidgets(2));
    });
  });
}
