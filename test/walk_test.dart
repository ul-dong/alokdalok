import 'package:alokdalok/character/character_view.dart';
import 'package:alokdalok/character/rider_pose.dart';
import 'package:alokdalok/character/walk_view.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/games/common/journey_trail.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/vehicle/ride_view.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 골인 길 걷기: 정답을 맞히면 옆모습으로 다리를 번갈아 내딛으며 다음 깃발까지 걷고, 도착하면 정면.

Future<GameState> fresh({bool ride = false}) async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  await s.setNickname('별이');
  if (ride) {
    for (var i = 0; i < 60; i++) {
      await s.rewardCorrect(firstTry: true);
    }
    await s.buyVehicle('car');
    await s.setRide('car');
  }
  return s;
}

Future<ValueNotifier<int>> pumpTrail(
  WidgetTester t,
  GameState s, {
  bool calm = false,
}) async {
  t.view.physicalSize = const Size(844, 390);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final done = ValueNotifier(0);
  await t.pumpWidget(
    AppScope(
      state: s,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(844, 390),
            disableAnimations: calm,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 70,
                child: ValueListenableBuilder<int>(
                  valueListenable: done,
                  builder: (_, d, _) => JourneyTrail(total: 5, done: d),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  return done;
}

Future<void> pumpMs(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('이동 중에는 옆모습으로 걷고, 도착하면 정면으로 돌아온다', (t) async {
    final s = await fresh();
    final done = await pumpTrail(t, s);
    expect(find.byType(WalkView), findsNothing);
    expect(find.byType(CharacterView), findsOneWidget);

    done.value = 1;
    await pumpMs(t, 300);
    expect(find.byType(WalkView), findsOneWidget);
    expect(find.byType(CharacterView), findsNothing);
    expect(t.widget<WalkView>(find.byType(WalkView)).still, isFalse);

    await pumpMs(t, 1200);
    expect(find.byType(WalkView), findsNothing);
    expect(find.byType(CharacterView), findsOneWidget);
  });

  testWidgets('걸음 단계가 시간에 따라 바뀌고 앞뒤 발이 번갈아 나간다', (t) async {
    final s = await fresh();
    final done = await pumpTrail(t, s);
    done.value = 1;
    final steps = <double>[];
    for (var i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 50));
      final w = find.byType(WalkView);
      if (w.evaluate().isNotEmpty) steps.add(t.widget<WalkView>(w).step);
    }
    expect(steps.toSet().length, greaterThan(5));
    final swings = steps.map(RiderPose.nearFootSwing).toList();
    expect(swings.any((v) => v > .5), isTrue, reason: '앞쪽 발이 앞으로');
    expect(swings.any((v) => v < -.5), isTrue, reason: '앞쪽 발이 뒤로');
    // 몸은 걸음에 맞춰 1~3px 출렁인다 (캐릭터 좌표)
    final bobs = [for (final f in steps) RiderPose.walkBob(f)];
    final range =
        bobs.reduce((a, b) => a > b ? a : b) -
        bobs.reduce((a, b) => a < b ? a : b);
    expect(range, inInclusiveRange(1, 3));
    await pumpMs(t, 1200);
  });

  testWidgets('이동이 끝나면 공용 시계 구독을 놓는다', (t) async {
    final s = await fresh();
    final done = await pumpTrail(t, s);
    final idle = SlowClock.instance.listenerCount;
    done.value = 1;
    await pumpMs(t, 200);
    // 걷는 동안: 걷는 친구가 시계를 듣는다 (서 있는 친구 대신이라 전체 수는 그대로)
    expect(
      t.state<JourneyWalkerState>(find.byType(JourneyWalker)).walking,
      isTrue,
    );
    expect(SlowClock.instance.listenerCount, idle);
    await pumpMs(t, 1200);
    expect(SlowClock.instance.listenerCount, idle);
    expect(
      t.state<JourneyWalkerState>(find.byType(JourneyWalker)).walking,
      isFalse,
    );
  });

  testWidgets('탈것을 타고 있으면 걷지 않고 타고 간다', (t) async {
    final s = await fresh(ride: true);
    final done = await pumpTrail(t, s);
    done.value = 1;
    await pumpMs(t, 300);
    expect(find.byType(RideView), findsOneWidget);
    expect(find.byType(WalkView), findsNothing);
    expect(find.byType(JourneyWalker), findsNothing);
    await pumpMs(t, 1200);
  });

  testWidgets('움직임 줄이기면 걷기 동작 없이 옆모습으로만 이동한다', (t) async {
    final s = await fresh();
    final done = await pumpTrail(t, s, calm: true);
    done.value = 1;
    await pumpMs(t, 300);
    final w = t.widget<WalkView>(find.byType(WalkView));
    expect(w.still, isTrue);
    await pumpMs(t, 1200);
    expect(find.byType(WalkView), findsNothing);
  });

  test('한 걸음은 0.35~0.45초', () {
    final perStep = JourneyWalker.duration / JourneyWalker.steps;
    expect(perStep, inInclusiveRange(.35, .45));
  });
}
