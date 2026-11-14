// 렉·발열 점검: 홈·놀이 화면에서 1초 동안 다시 그리는 횟수, 무거운 그림 한 장 그리는 시간,
// 녹음 음성 조각 플레이어가 쌓이지 않는지, 아이 손가락이 조금 미끄러져도 눌리는지.
// (2026-11-14 실기기 "발열 살짝, 렉, 터치 안 될 때 있음" 보고)
import 'dart:ui' show PictureRecorder;

import 'package:alokdalok/character/animal_painter.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/games/common/scene_game.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/playground_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/perf_monitor.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/poke_character.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 300);
}

List<RenderRepaintBoundary> _boundaries(RenderObject root) {
  final out = <RenderRepaintBoundary>[];
  void walk(RenderObject o) {
    if (o is RenderRepaintBoundary) out.add(o);
    o.visitChildren(walk);
  }

  walk(root);
  return out;
}

int _paints(RenderRepaintBoundary b) =>
    b.debugSymmetricPaintCount + b.debugAsymmetricPaintCount;

/// 1초(공용 시계 20박) 동안 센 값
class SecondCount {
  SecondCount(this.rebuilds, this.paints, this.textPaints, this.customPaints);

  /// 다시 만든(build) 위젯 수
  final int rebuilds;

  /// 다시 그린(paint) RenderObject 수
  final int paints;

  /// 그중 글자(RenderParagraph): 글자는 움직이지 않으므로 0이어야 한다.
  /// 0이 아니면 움직이는 그림 때문에 버튼·글자까지 통째로 다시 그리는 것이다.
  final int textPaints;

  /// 그중 CustomPainter 그림 (캐릭터·배경 칸·버튼 그림)
  final int customPaints;

  @override
  String toString() =>
      'rebuild $rebuilds, paint $paints (글자 $textPaints, CustomPaint $customPaints)';
}

/// 1초 동안 다시 만든 위젯 수와 다시 그린 RenderObject 수를 센다 (Timeline에 남는 paint 기록).
Future<SecondCount> countSecond(WidgetTester t) async {
  var rebuilds = 0;
  debugOnRebuildDirtyWidget = (e, builtOnce) => rebuilds++;
  debugProfilePaintsEnabled = true;
  FlutterTimeline.debugCollectionEnabled = true;
  FlutterTimeline.debugReset();
  late AggregatedTimings timings;
  try {
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    timings = FlutterTimeline.debugCollect();
  } finally {
    debugOnRebuildDirtyWidget = null;
    debugProfilePaintsEnabled = false;
    FlutterTimeline.debugCollectionEnabled = false;
  }
  int count(bool Function(String) test) =>
      timings.timedBlocks.where((b) => test(b.name)).length;
  return SecondCount(
    rebuilds,
    count((n) => n.startsWith('Render') || n.startsWith('_Render')),
    count((n) => n == 'RenderParagraph'),
    count((n) => n == 'RenderCustomPaint'),
  );
}

/// 그림 한 장을 [n]번 그리는 데 걸린 평균 시간 (ms)
double timePaint(void Function(Canvas) paint, {int n = 30}) {
  // 처음 한 번은 준비(글꼴·모양 기억)라 빼고 잰다
  final warm = PictureRecorder();
  paint(Canvas(warm));
  warm.endRecording().dispose();
  final sw = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    final r = PictureRecorder();
    paint(Canvas(r));
    r.endRecording().dispose();
  }
  return sw.elapsedMicroseconds / n / 1000;
}

void main() {
  // 가짜 시간(위젯 테스트)에서도 숨쉬기가 실제처럼 움직이게
  setUp(() => SlowClock.debugCountTicks = true);
  tearDown(() => SlowClock.debugCountTicks = false);
  audioTests();
  perfMonitorTests();

  group('1초 동안 다시 그리는 양', () {
    testWidgets('홈: 숨쉬기 때문에 화면 전체를 다시 그리지 않고, 캐릭터 그림은 초당 13번 이하', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      final c = await countSecond(t);
      debugPrint('홈 1초: $c');
      // 고치기 전: rebuild 80, paint 2880 (글자 140) - 숨쉬기 때문에 화면 전체를 초당 20번
      expect(c.textPaints, 0, reason: '글자, 버튼은 다시 그리지 않는다');
      expect(c.rebuilds, 0);
      expect(c.paints, lessThan(300));
      // 캐릭터 그림은 숨쉬기 단계가 바뀔 때만 (한 마리 초당 약 13번)
      expect(c.customPaints, lessThanOrEqualTo(13 * 2 + 2));
      await done(t);
    });

    testWidgets('놀이터: 화면 전체를 다시 그리지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const PlaygroundScreen()));
      await settle(t);
      final c = await countSecond(t);
      debugPrint('놀이터 1초: $c');
      // 고치기 전: rebuild 40, paint 3580 (글자 160)
      expect(c.textPaints, 0, reason: '글자, 버튼은 다시 그리지 않는다');
      expect(c.paints, lessThan(200));
      await done(t);
    });

    testWidgets('숫자 놀이: 화면 전체를 다시 그리지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, gameScreen(GameKind.number, 1)));
      await settle(t, 1500);
      final c = await countSecond(t);
      debugPrint('숫자 놀이 1초: $c');
      // 고치기 전: rebuild 40, paint 2940 (글자 80)
      expect(c.textPaints, 0, reason: '글자, 버튼은 다시 그리지 않는다');
      expect(c.paints, lessThan(200));
      await done(t);
    });

    testWidgets('홈 위에 놀이터를 올리면 아래 홈은 그리지도 다시 만들지도 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      await t.tap(find.text(HomeScreen.playgroundLabel));
      await settle(t);
      final homeChars = find.descendant(
        of: find.byType(HomeScreen, skipOffstage: false),
        matching: find.byType(CustomPaint, skipOffstage: false),
        skipOffstage: false,
      );
      expect(homeChars, findsWidgets);
      final homeEl = t.element(find.byType(HomeScreen, skipOffstage: false));
      expect(TickerMode.valuesOf(homeEl).enabled, isFalse);
      final hidden = _boundaries(homeEl.renderObject!).toList();
      for (final b in hidden) {
        b.debugResetMetrics();
      }
      var rebuilds = 0;
      debugOnRebuildDirtyWidget = (e, _) {
        if (e == homeEl ||
            e.findAncestorWidgetOfExactType<HomeScreen>() != null) {
          rebuilds++;
        }
      };
      try {
        await settle(t, 1000);
      } finally {
        debugOnRebuildDirtyWidget = null;
      }
      final paints = hidden.fold(0, (a, b) => a + _paints(b));
      debugPrint('놀이터 아래 홈 1초: rebuild $rebuilds, 다시 그리기 $paints');
      expect(paints, 0);
      expect(rebuilds, 0);
      await done(t);
    });
  });

  group('그림 한 장 그리는 시간 (참고용 출력)', () {
    test('계절 풍경 한 장', () async {
      for (final season in Season.values) {
        final g = SceneGame(season: season, groundLevel: .8);
        g.onGameResize(Vector2(844, 390));
        await g.onLoad();
        g.update(0);
        final ms = timePaint((c) => g.render(c));
        debugPrint('풍경 ${season.name}: ${ms.toStringAsFixed(2)}ms');
      }
    });

    test('캐릭터 한 장', () {
      final p = AnimalPainter(zodiac: Zodiac.tiger, items: const {});
      final ms = timePaint((c) => p.paint(c, const Size(200, 240)));
      debugPrint('캐릭터 한 장: ${ms.toStringAsFixed(2)}ms');
    });
  });
}

/// 가짜 녹음 조각 플레이어: 불러오기에 시간이 걸린다 (그 사이 다음 말이 시작될 수 있게)
class _FakeClip implements ClipPlayer {
  static int made = 0, disposed = 0;
  _FakeClip() {
    made++;
  }

  @override
  Future<void> load(String asset) =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  @override
  Future<void> play() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  @override
  Future<void> dispose() async => disposed++;
}

void audioTests() {
  group('녹음 조각 플레이어가 쌓이지 않는다', () {
    setUp(() => _FakeClip.made = _FakeClip.disposed = 0);
    const three = [VoiceClip('a.mp3'), VoiceClip('b.mp3'), VoiceClip('c.mp3')];

    test('말을 연달아(불러오는 중에) 20번 시작해도 끝나면 0개', () async {
      final q = ClipQueue(_FakeClip.new);
      final all = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        all.add(q.play(three));
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await Future.wait(all);
      debugPrint(
        '조각 플레이어: 만든 ${_FakeClip.made}, 놓은 ${_FakeClip.disposed}, 남음 ${q.alive}',
      );
      expect(q.alive, 0);
      expect(_FakeClip.disposed, _FakeClip.made);
    });

    test('말하는 동안만 살아 있고, 멈추면 바로 놓는다', () async {
      final q = ClipQueue(_FakeClip.new);
      final f = q.play(three);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(q.alive, 3);
      await q.stop();
      expect(q.alive, 0);
      await f;
      expect(_FakeClip.disposed, _FakeClip.made);
    });
  });
}

void perfMonitorTests() {
  group('렉, 터치 진단 기록', () {
    test('최근 1분 프레임: 16ms, 33ms 넘는 장 수, 가장 느린 장, 평균', () {
      var now = DateTime(2026, 11, 14, 10);
      final m = PerfMonitor(now: () => now);
      for (final ms in [5.0, 10.0, 20.0, 40.0]) {
        m.addFrame(ms);
      }
      var f = m.frames();
      expect(f.count, 4);
      expect(f.over16, 2);
      expect(f.over33, 1);
      expect(f.worstMs, 40);
      expect(f.averageMs, closeTo(18.75, .01));
      now = now.add(const Duration(seconds: 61));
      f = m.frames();
      expect(f.count, 0, reason: '1분 지난 것은 버린다');
    });

    testWidgets('누름: 맞은 버튼 이름, 누른 시간, 움직인 거리', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      final m = PerfMonitor();
      t.binding.pointerRouter.addGlobalRoute(m.onPointer);
      addTearDown(() => t.binding.pointerRouter.removeGlobalRoute(m.onPointer));
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      final g = await t.startGesture(
        t.getCenter(find.text(HomeScreen.characterLabel)),
      );
      await t.pump(const Duration(milliseconds: 120));
      await g.moveBy(const Offset(10, 0));
      await g.up();
      await settle(t);
      final r = m.touches.last;
      expect(r.target, HomeScreen.characterLabel);
      expect(r.moved, closeTo(10, .5));
      await done(t);
    });

    testWidgets('아이 손가락이 25px 미끄러져도 짧은 누르기로 받는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      final g = await t.startGesture(
        t.getCenter(find.text(HomeScreen.playgroundLabel)),
      );
      await t.pump(const Duration(milliseconds: 80));
      await g.moveBy(const Offset(15, 20)); // 25px
      await t.pump(const Duration(milliseconds: 80));
      await g.up();
      await settle(t);
      expect(find.byType(PlaygroundScreen), findsOneWidget);
      await done(t);
    });

    testWidgets('캐릭터를 콕 눌러 움직이는 동안에도 글자, 버튼은 다시 그리지 않는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(wrap(s, const HomeScreen()));
      await settle(t);
      await t.tap(find.byType(PokeCharacter));
      final c = await countSecond(t);
      debugPrint('콕 누른 뒤 1초: $c');
      expect(c.textPaints, 0);
      expect(c.rebuilds, lessThan(10));
      await done(t);
    });
  });
}
