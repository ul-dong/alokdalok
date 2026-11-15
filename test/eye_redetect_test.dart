// 눈 지킴이: 경고가 풀린 뒤 다시 가까이 오면 다시 경고한다 (실제 창 주기로 돌린다)
// (a) 물러나서 경고가 풀림 (b) 쉬어 가기를 눌러 돌아옴 (c) 눈 쉬기·"오늘은 여기까지" 덮개가 풀림

import 'package:alokdalok/app.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/play_clock.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'eye_guard_test.dart' show FakeSensor, at;

Finder _pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

/// 막 끈 카메라를 OS가 아직 놓는 중이라, 끈 뒤 처음 여는 창이 한 번 실패하는 기기
class _ReleaseLagSensor extends FakeSensor {
  _ReleaseLagSensor({super.scene});
  bool _lag = false;
  int fails = 0;

  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async {
    if (_lag) {
      _lag = false;
      fails++;
      samples++;
      throw '카메라를 잠깐 쓸 수 없어요 (CameraException)';
    }
    return super.sampleOnce(budget: budget);
  }

  @override
  Future<void> stop() {
    _lag = true;
    return super.stop();
  }
}

void main() {
  group('다시 가까이 오면 다시 경고한다 (가짜 센서·가짜 시계, 실제 창 주기)', () {
    late DateTime now;
    late FakeSensor sensor;
    late EyeGuard g;
    final owner = Object();

    /// 지금 카메라 앞의 얼굴 (null = 아무도 없음)
    FaceReading? face;

    Future<void> setUpGuard(WidgetTester t) async {
      now = DateTime(2026);
      face = at(60);
      sensor = FakeSensor(scene: () => face);
      g = EyeGuard(sensor: sensor, now: () => now)..enabled = true;
      g.showPlay(owner);
      await t.pump();
      expect(g.running, isTrue);
    }

    /// 가짜 시계와 테스트 타이머를 100ms씩 같이 흘린다
    Future<void> wait(WidgetTester t, Duration d) async {
      const step = Duration(milliseconds: 100);
      for (var left = d; left > Duration.zero; left -= step) {
        now = now.add(step);
        await t.pump(step);
      }
    }

    /// [cond]가 될 때까지 최대 [limit] 기다린다. 걸린 시간을 돌려준다.
    Future<Duration> until(
      WidgetTester t,
      bool Function() cond, {
      Duration limit = const Duration(seconds: 20),
    }) async {
      final from = now;
      while (!cond()) {
        if (now.difference(from) > limit) {
          fail(
            '${limit.inSeconds}초 안에 바뀌지 않음 (alert ${g.alert}, '
            'running ${g.running}, resting ${g.resting}, '
            'next ${g.nextWindowAt}, samples ${sensor.samples})',
          );
        }
        await wait(t, const Duration(milliseconds: 100));
      }
      return now.difference(from);
    }

    Future<void> closeIn(WidgetTester t) async {
      face = at(20);
      final took = await until(t, () => g.alert == EyeAlert.tooClose);
      expect(took, lessThanOrEqualTo(const Duration(seconds: 14)));
    }

    Future<void> done(WidgetTester t) async {
      g.hidePlay(owner);
      await wait(t, const Duration(milliseconds: 1200));
      g.dispose();
    }

    testWidgets('(a) 경고 → 물러나서 풀림 → 다시 가까이 → 다시 경고 (세 번)', (t) async {
      await setUpGuard(t);
      for (var round = 0; round < 3; round++) {
        await closeIn(t);
        face = at(60);
        await until(t, () => g.alert == EyeAlert.none);
        expect(g.running, isTrue);
        expect(g.nextWindowAt, isNotNull, reason: '다음 창이 잡혀 있어야 한다');
        // 한동안 멀리서 논다 (넉넉 10초 주기로 돌아간다)
        await wait(t, const Duration(seconds: 25));
        expect(g.zone, EyeZone.safe);
      }
      await closeIn(t);
      await done(t);
    });

    testWidgets('(b) 경고 → 아이가 떠나 쉬어 가기 → 눌러 돌아옴 → 다시 가까이 → 다시 경고', (t) async {
      await setUpGuard(t);
      for (var round = 0; round < 2; round++) {
        await closeIn(t);
        face = null; // 아이가 떠났다
        await until(t, () => g.resting);
        expect(sensor.on, isFalse);
        await wait(t, const Duration(seconds: 5));
        face = at(60);
        g.wake();
        await t.pump();
        expect(g.running, isTrue, reason: '돌아오면 다시 켠다');
        await wait(t, const Duration(seconds: 12));
      }
      await closeIn(t);
      await done(t);
    });

    testWidgets('(b) 경고가 75초 이어져 쉬어 가기 → 돌아오자마자 가까이 → 다시 경고', (t) async {
      await setUpGuard(t);
      await closeIn(t);
      await until(t, () => g.resting, limit: const Duration(seconds: 80));
      g.wake(); // 아이는 그대로 가까이 있다
      await t.pump();
      await closeIn(t);
      await done(t);
    });

    testWidgets('(c) 눈 쉬기·"오늘은 여기까지" 덮개가 풀린 뒤 → 다시 가까이 → 다시 경고', (t) async {
      await setUpGuard(t);
      await closeIn(t);
      // 경고 중에 눈 쉬기가 뜬다
      g.blocked = true;
      await wait(t, const Duration(seconds: 2));
      expect(g.running, isFalse);
      expect(g.alert, EyeAlert.none);
      face = at(60);
      await wait(t, const Duration(seconds: 20));
      g.blocked = false;
      await t.pump();
      expect(g.running, isTrue);
      await wait(t, const Duration(seconds: 12));
      await closeIn(t);
      // 경고가 아닐 때 덮개가 떴다 풀린 경우도
      face = at(60);
      await until(t, () => g.alert == EyeAlert.none);
      g.blocked = true;
      await wait(t, const Duration(milliseconds: 500));
      g.blocked = false; // 1초 안에 풀림 (껐다 켜지 않음)
      await wait(t, const Duration(seconds: 12));
      await closeIn(t);
      await done(t);
    });

    testWidgets('창 하나가 실패해도(카메라 잠깐 못 씀) 다음 창에서 다시 본다', (t) async {
      await setUpGuard(t);
      var fails = 2;
      sensor.scene = () {
        if (fails > 0) {
          fails--;
          throw '카메라를 쓸 수 없어요';
        }
        return face;
      };
      await wait(t, const Duration(seconds: 25));
      expect(g.running, isTrue, reason: '한두 번 실패로 눈 지킴이를 죽이지 않는다');
      await closeIn(t);
      await done(t);
    });

    testWidgets('(b)(c) 끈 뒤 처음 여는 창이 실패하는 기기에서도 다시 켜면 다시 경고한다', (t) async {
      now = DateTime(2026);
      face = at(60);
      final lag = _ReleaseLagSensor(scene: () => face);
      sensor = lag;
      g = EyeGuard(sensor: lag, now: () => now)..enabled = true;
      g.showPlay(owner);
      await t.pump();
      await closeIn(t);
      // (b) 쉬어 가기 → 돌아옴
      face = null;
      await until(t, () => g.resting);
      face = at(60);
      g.wake();
      await t.pump();
      await wait(t, const Duration(seconds: 1));
      expect(lag.fails, 1, reason: '돌아와서 처음 연 창은 실패');
      expect(g.running, isTrue, reason: '한 번 실패로 멈추지 않는다');
      expect(g.error, isNull);
      expect(g.lastWindow?.outcome, EyeWindowOutcome.failed);
      expect(
        g.nextWindowIn,
        const Duration(seconds: 3) - const Duration(milliseconds: 1000),
      );
      await closeIn(t);
      // (c) 덮개 → 풀림
      face = at(60);
      await until(t, () => g.alert == EyeAlert.none);
      g.blocked = true;
      await wait(t, const Duration(seconds: 3));
      expect(g.running, isFalse);
      g.blocked = false;
      await t.pump();
      await wait(t, const Duration(seconds: 1));
      expect(lag.fails, 2);
      expect(g.running, isTrue);
      await closeIn(t);
      expect(g.failures, 0, reason: '성공하면 실패 수를 비운다');
      await done(t);
    });

    testWidgets('계속 실패하면 3초 두 번 뒤로는 10초마다 다시 해 본다, 권한 거부만 멈춘다', (t) async {
      await setUpGuard(t);
      sensor.scene = () => throw '카메라 이미지를 받지 못했어요';
      await wait(t, const Duration(seconds: 10)); // 첫 실패 창
      final at0 = sensor.samples;
      await wait(t, const Duration(seconds: 3));
      await wait(t, const Duration(seconds: 3));
      expect(sensor.samples, at0 + 2, reason: '3초 간격 두 번');
      expect(g.failures, 3);
      expect(g.nextWindowIn, greaterThan(const Duration(seconds: 3)));
      expect(g.running, isTrue);
      expect(g.recentWindows.last.message, '카메라 이미지를 받지 못했어요');
      sensor.scene = () => throw const EyeSensorDenied('카메라 사용을 허용해 주세요');
      await wait(t, const Duration(seconds: 11));
      expect(g.running, isFalse);
      expect(g.error, '카메라 사용을 허용해 주세요');
      expect(g.offReason, contains('카메라 사용을 허용해 주세요'));
      g.hidePlay(owner);
      g.dispose();
    });

    testWidgets('부모님 계속하기(5분) 뒤에는 다시 가까이 오면 다시 경고한다', (t) async {
      await setUpGuard(t);
      await closeIn(t);
      g.snooze();
      expect(g.alert, EyeAlert.none);
      expect(g.snoozeLeft, const Duration(minutes: 5));
      await wait(t, const Duration(minutes: 2));
      expect(g.alert, EyeAlert.none, reason: '5분 동안은 경고하지 않는다');
      await wait(t, const Duration(minutes: 3));
      expect(g.snoozeLeft, isNull);
      await closeIn(t);
      await done(t);
    });
  });

  group('앱에서도 다시 가까이 오면 다시 경고한다 (덮개·놀이 화면 포함)', () {
    late DateTime now;
    late FakeSensor sensor;
    late GameState s;
    FaceReading? face;

    Future<void> app(WidgetTester t, {int limit = 0, int brk = 10}) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      now = DateTime(2026, 10, 21, 9);
      face = at(60);
      sensor = FakeSensor(scene: () => face);
      s = GameState(
        storage: MemoryStorage.noticeSeen(),
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: sensor, now: () => now),
        now: () => now,
      );
      await s.load();
      await s.setNickname('별이');
      await s.setPlayLimit(limit);
      await s.setEyeBreak(brk);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(seconds: 1));
    }

    Future<void> openGame(WidgetTester t) async {
      Navigator.of(t.element(find.byType(HomeScreen)))
          .push(softRoute(gameScreen(GameKind.shape, 1)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> wait(WidgetTester t, Duration d) async {
      const step = Duration(milliseconds: 100);
      for (var left = d; left > Duration.zero; left -= step) {
        now = now.add(step);
        await t.pump(step);
      }
    }

    Future<Duration> until(
      WidgetTester t,
      bool Function() cond, {
      Duration limit = const Duration(seconds: 20),
    }) async {
      final from = now;
      while (!cond()) {
        if (now.difference(from) > limit) {
          fail(
            '${limit.inSeconds}초 안에 바뀌지 않음 (alert ${s.eye.alert}, '
            'running ${s.eye.running}, wanted ${s.eye.wanted}, '
            'block ${s.playBlock}, error ${s.eye.error}, '
            'samples ${sensor.samples})',
          );
        }
        await wait(t, const Duration(milliseconds: 100));
      }
      return now.difference(from);
    }

    Future<void> closeIn(WidgetTester t) async {
      face = at(20);
      await until(t, () => s.eye.alert == EyeAlert.tooClose);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('화면이 너무 가까워요!'), findsOneWidget);
    }

    Future<void> finish(WidgetTester t) async {
      await s.eye.stop();
      s.eye.enabled = false;
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 7));
    }

    testWidgets('(a) 놀이 중 경고 → 물러남 → 다시 가까이 → 다시 경고', (t) async {
      await app(t);
      await openGame(t);
      for (var i = 0; i < 3; i++) {
        await closeIn(t);
        face = at(60);
        await until(t, () => s.eye.alert == EyeAlert.none);
        await wait(t, const Duration(seconds: 15));
      }
      await closeIn(t);
      face = at(60);
      await finish(t);
    });

    testWidgets('(b) 쉬어 가기를 눌러 돌아온 뒤 → 다시 가까이 → 다시 경고', (t) async {
      await app(t);
      await openGame(t);
      await closeIn(t);
      face = null;
      await until(t, () => s.playBlock == PlayBlock.eyeRest);
      await wait(t, const Duration(seconds: 3));
      face = at(60);
      await t.tap(find.text('창밖 먼 곳을 봐요'));
      await t.pump();
      expect(s.playBlock, PlayBlock.none);
      await wait(t, const Duration(seconds: 12));
      await closeIn(t);
      face = at(60);
      await finish(t);
    });

    testWidgets('(c) 눈 쉬기 덮개가 풀린 뒤 → 다시 가까이 → 다시 경고', (t) async {
      await app(t, brk: 10);
      await openGame(t);
      await until(
        t,
        () => s.playBlock == PlayBlock.eyeBreak,
        limit: const Duration(minutes: 11),
      );
      await until(
        t,
        () => s.playBlock == PlayBlock.none,
        limit: const Duration(seconds: 30),
      );
      await wait(t, const Duration(seconds: 2));
      await closeIn(t);
      face = at(60);
      await finish(t);
    });

    testWidgets('(c) "오늘은 여기까지" → 부모님이 15분 더 → 다시 가까이 → 다시 경고', (t) async {
      await app(t, limit: 10, brk: 20);
      await openGame(t);
      await until(
        t,
        () => s.playBlock == PlayBlock.limit,
        limit: const Duration(minutes: 11),
      );
      await wait(t, const Duration(seconds: 3));
      expect(sensor.on, isFalse);
      s.extendPlay();
      await t.pump();
      expect(s.playBlock, PlayBlock.none);
      await wait(t, const Duration(seconds: 2));
      await closeIn(t);
      face = at(60);
      await finish(t);
    });

    testWidgets('홈에서 가까이 보면 경고 덮개가 뜨고, 덮개 뒤 시계·음악이 멈춘다', (t) async {
      await app(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(s.eye.running, isTrue, reason: '홈도 아이 화면');
      final music = (s.audio as RecordingAudio).music;
      await closeIn(t);
      expect(SlowClock.instance.held, isTrue);
      expect(SlowClock.instance.ticking, isFalse);
      expect((s.audio as RecordingAudio).musicHeld, isTrue);
      face = at(60);
      await until(t, () => s.eye.alert == EyeAlert.none);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('화면이 너무 가까워요!'), findsNothing);
      expect(SlowClock.instance.held, isFalse);
      expect((s.audio as RecordingAudio).music, music);
      expect(s.eye.running, isTrue);
      await finish(t);
    });

    testWidgets('부모 확인·설정 화면에서는 카메라를 끄고, 홈으로 돌아오면 켠다', (t) async {
      await app(t);
      expect(sensor.on, isTrue);
      await t.tap(_pressable(HomeScreen.settingsLabel));
      await wait(t, const Duration(milliseconds: 500));
      expect(find.byType(ParentalGate), findsOneWidget);
      expect(sensor.on, isTrue, reason: '1초는 기다린다');
      await wait(t, const Duration(milliseconds: 700));
      expect(sensor.on, isFalse, reason: '부모 확인');
      expect(s.eye.offReason, contains('부모님'));
      // 가까이 와도 경고하지 않는다 (카메라 꺼짐)
      face = at(20);
      await wait(t, const Duration(seconds: 6));
      expect(s.eye.alert, EyeAlert.none);
      final q = t.widget<Text>(find.byKey(ParentalGate.questionKey)).data!;
      for (final d in '${ParentalGate.answerOf(q)}'.split('')) {
        await t.tap(_pressable('숫자 $d'));
        await t.pump(const Duration(milliseconds: 50));
      }
      await wait(t, const Duration(seconds: 2));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(sensor.on, isFalse, reason: '설정 화면');
      expect(s.eye.alert, EyeAlert.none);
      final starts = sensor.starts;
      face = at(60);
      Navigator.of(t.element(find.byType(SettingsScreen))).pop();
      await wait(t, const Duration(milliseconds: 500));
      expect(find.byType(SettingsScreen), findsNothing);
      expect(sensor.on, isTrue, reason: '홈으로 돌아오면 켠다');
      expect(sensor.starts, starts + 1);
      // 부모 확인을 닫으면 (1초 안) 껐다 켜지 않는다
      await t.tap(_pressable(HomeScreen.settingsLabel));
      await wait(t, const Duration(milliseconds: 400));
      await t.tap(_pressable('닫기'));
      await wait(t, const Duration(seconds: 2));
      expect(sensor.on, isTrue);
      expect(sensor.starts, starts + 1);
      await finish(t);
    });

    testWidgets('홈 → 놀이 → 홈 전환에 껐다 켜지 않는다 (1초 지연)', (t) async {
      await app(t);
      expect(sensor.starts, 1);
      for (var i = 0; i < 2; i++) {
        await openGame(t);
        await wait(t, const Duration(seconds: 3));
        Navigator.of(t.element(find.byType(Scaffold).last)).pop();
        await wait(t, const Duration(seconds: 2));
        expect(find.byType(HomeScreen), findsOneWidget);
      }
      expect(sensor.starts, 1);
      expect(sensor.stops, 0);
      expect(sensor.on, isTrue);
      await finish(t);
    });
  });
}
