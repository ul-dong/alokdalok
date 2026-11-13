// 눈 지킴이 카메라 발열 줄이기: 필요할 때만 켜기, 검사 간격, 판정 시간, 카메라·ML Kit 설정, 1분 추정
import 'dart:io';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/games/common/game_frame.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/eye_sensor_io.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/play_clock.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/eye_guard_overlay.dart';
import 'package:alokdalok/widgets/play_guard_overlay.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'eye_guard_test.dart' show FakeSensor, at;

const _ms = Duration(milliseconds: 1);

void main() {
  group('카메라는 필요할 때만 켠다 (가짜 센서·가짜 시계)', () {
    late FakeSensor sensor;
    late EyeGuard g;
    late DateTime now;
    final owner = Object();

    void setUpGuard() {
      now = DateTime(2026);
      sensor = FakeSensor();
      g = EyeGuard(sensor: sensor, now: () => now)..enabled = true;
    }

    /// 가짜 시계와 테스트 타이머를 같이 흘린다
    Future<void> wait(WidgetTester t, Duration d) async {
      now = now.add(d);
      await t.pump(d);
    }

    testWidgets('놀이 화면이 없으면 꺼져 있고, 놀이 화면이 보이면 바로 켜진다', (t) async {
      setUpGuard();
      await t.pump();
      expect(sensor.on, isFalse, reason: '켜짐 설정만으로는 카메라를 켜지 않는다');
      g.showPlay(owner);
      await t.pump();
      expect(sensor.on, isTrue);
      expect(sensor.starts, 1);
      g.hidePlay(owner);
      await wait(t, _ms * 900);
      expect(sensor.on, isTrue, reason: '1초 안의 짧은 전환에는 끄지 않는다');
      await wait(t, _ms * 200);
      expect(sensor.on, isFalse, reason: '1초가 지나면 끈다');
      expect(sensor.stops, 1);
    });

    testWidgets('짧은 화면 전환(다음 단계 등)에는 껐다 켜지 않는다', (t) async {
      setUpGuard();
      final next = Object();
      g.showPlay(owner);
      await t.pump();
      g.hidePlay(owner);
      await wait(t, _ms * 300);
      g.showPlay(next);
      await wait(t, _ms * 3000);
      expect(sensor.starts, 1);
      expect(sensor.stops, 0);
      expect(sensor.on, isTrue);
      g.hidePlay(next);
      await wait(t, _ms * 1100);
    });

    testWidgets('멈춤 화면이 열리면 끄고, 닫으면 다시 켠다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      await t.pump();
      g.showPlay(owner, paused: true);
      await wait(t, _ms * 1100);
      expect(sensor.on, isFalse);
      g.showPlay(owner);
      await t.pump();
      expect(sensor.on, isTrue);
      expect(sensor.starts, 2);
      g.hidePlay(owner);
      await wait(t, _ms * 1100);
    });

    testWidgets('앱이 뒤로 가면(paused·hidden) 바로 끄고, 돌아오면 켠다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      await t.pump();
      g.setForeground(false, immediate: true);
      await t.pump();
      expect(sensor.on, isFalse, reason: '기다리지 않고 바로');
      g.setForeground(true);
      await t.pump();
      expect(sensor.on, isTrue);
      // inactive(알림창 등)는 1초 기다린다
      g.setForeground(false);
      await wait(t, _ms * 500);
      expect(sensor.on, isTrue);
      g.setForeground(true);
      await wait(t, _ms * 1500);
      expect(sensor.on, isTrue, reason: '잠깐 inactive였다 돌아오면 그대로');
      expect(sensor.starts, 2);
      g.setForeground(false);
      await wait(t, _ms * 500);
      g.setForeground(false, immediate: true); // inactive → paused
      await t.pump();
      expect(sensor.on, isFalse);
      g.hidePlay(owner);
      await wait(t, _ms * 1100);
    });

    testWidgets('"오늘은 여기까지!"·눈 쉬기 덮개가 뜨면 끄고, 사라지면 켠다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      await t.pump();
      g.blocked = true;
      await wait(t, _ms * 1100);
      expect(sensor.on, isFalse);
      g.blocked = false;
      await t.pump();
      expect(sensor.on, isTrue);
      g.hidePlay(owner);
      await wait(t, _ms * 1100);
    });

    testWidgets('경고 덮개가 떠 있는 동안은 멈춤 화면이어도 켜 두고, 풀리면 끈다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      await t.pump();
      for (var i = 0; i < 6; i++) {
        now = now.add(_ms * 500);
        g.feed(at(20));
      }
      expect(g.alert, EyeAlert.tooClose);
      g.showPlay(owner, paused: true); // 안드로이드 뒤로 가기 → 멈춤
      await wait(t, _ms * 3000);
      expect(sensor.on, isTrue, reason: '풀림을 확인해야 한다');
      for (var i = 0; i < 4; i++) {
        now = now.add(_ms * 500);
        g.feed(at(45));
      }
      expect(g.alert, EyeAlert.none);
      await wait(t, _ms * 1100);
      expect(sensor.on, isFalse);
      g.hidePlay(owner);
    });

    testWidgets('설정에서 끄면 바로 끄고, 켜면 놀이 화면에서 다시 켠다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      await t.pump();
      g.enabled = false;
      await t.pump();
      expect(sensor.on, isFalse);
      g.enabled = true;
      await t.pump();
      expect(sensor.on, isTrue);
      g.hidePlay(owner);
      await wait(t, _ms * 1100);
    });

    testWidgets('30cm 기준 맞추기는 카메라를 잠깐 켜서 얼굴을 한 번 보고 끈다', (t) async {
      setUpGuard();
      final f = g.measureAndCalibrate();
      await t.pump();
      expect(sensor.on, isTrue);
      sensor.ctrl.add(const FaceReading(size: .2, yaw: 0, pitch: 0, roll: 0));
      await t.pump();
      expect(await f, .2);
      expect(g.distanceOf(.2), closeTo(30, .001));
      await wait(t, _ms * 1100);
      expect(sensor.on, isFalse);
    });

    testWidgets('빠르게 켜고 끄고 켜도 카메라가 하나만 켜진다', (t) async {
      setUpGuard();
      g.showPlay(owner);
      g.enabled = false;
      g.enabled = true;
      await t.pump();
      await t.pump();
      expect(g.running, isTrue);
      expect(sensor.on, isTrue);
      expect(sensor.starts - sensor.stops, 1);
      g.hidePlay(owner);
      await wait(t, _ms * 1100);
    });
  });

  group('검사 간격', () {
    late DateTime now;
    late FakeSensor sensor;
    late EyeGuard g;
    setUp(() {
      now = DateTime(2026);
      sensor = FakeSensor();
      g = EyeGuard(sensor: sensor, now: () => now);
    });
    void step(FaceReading? r, [Duration? d]) {
      now = now.add(d ?? g.checkInterval);
      g.feed(r);
    }

    test('평소 1.5초, 36cm 이하·각도 80% 이상이면 0.5초, 멀어지면 다시 1.5초', () {
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(at(50));
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(at(36));
      expect(
        g.checkInterval,
        const Duration(milliseconds: 500),
        reason: '36cm',
      );
      step(at(37));
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(at(50, yaw: 28)); // 35도의 80%
      expect(g.checkInterval, const Duration(milliseconds: 500));
      step(at(50, pitch: 24)); // 30도의 80%
      expect(g.checkInterval, const Duration(milliseconds: 500));
      step(at(50, roll: 36)); // 45도의 80%
      expect(g.checkInterval, const Duration(milliseconds: 500));
      step(at(50, yaw: 20, pitch: 15, roll: 20));
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(null);
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      expect(sensor.intervals, [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1500),
      ], reason: '바뀔 때만 센서에 알린다');
    });

    test('경고 중 간격은 1초 (얼굴이 잠깐 안 보여도), 경고가 20초 넘으면 1.5초', () {
      for (var i = 0; i < 8; i++) {
        step(at(25));
      }
      expect(g.alert, EyeAlert.tooClose);
      expect(g.checkInterval, const Duration(seconds: 1));
      step(at(33)); // 경계 (30~34cm)
      expect(g.checkInterval, const Duration(seconds: 1));
      step(null);
      expect(g.checkInterval, const Duration(seconds: 1));
      // 경고가 뜬 뒤 20초 동안은 1초
      while (g.checkInterval == const Duration(seconds: 1)) {
        step(at(25));
        expect(g.alert, EyeAlert.tooClose);
      }
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(null);
      expect(
        g.checkInterval,
        const Duration(milliseconds: 1500),
        reason: '얼굴이 잠깐 안 보여도 늦춘 간격 그대로',
      );
      for (var i = 0; i < 3; i++) {
        step(at(60));
      }
      expect(g.alert, EyeAlert.none);
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      while (g.alert == EyeAlert.none) {
        step(at(25));
      }
      expect(
        g.checkInterval,
        const Duration(seconds: 1),
        reason: '새 경고는 다시 1초부터',
      );
    });

    test('경고가 정확히 20초 이어진 때부터 1.5초', () {
      final t0 = now;
      while (g.alert == EyeAlert.none) {
        step(at(20));
      }
      final alertAt = now;
      // 1.5초에 처음 가까이 봄 → 0.5초 간격 → 2초 뒤 경고
      expect(alertAt.difference(t0), const Duration(milliseconds: 3500));
      while (now.difference(alertAt) < EyeRules.alertSlowAfter) {
        expect(g.checkInterval, EyeRules.alertInterval);
        step(at(20));
      }
      expect(now.difference(alertAt), EyeRules.alertSlowAfter);
      expect(g.checkInterval, const Duration(milliseconds: 1500));
    });

    test('기준 거리를 40cm로 바꾸면 48cm부터 촘촘히 본다', () {
      g.tooCloseCm = 40;
      step(at(49));
      expect(g.checkInterval, const Duration(milliseconds: 1500));
      step(at(48));
      expect(g.checkInterval, const Duration(milliseconds: 500));
    });
  });

  group('2~3초 판정 시간은 검사 간격과 상관없이 그대로', () {
    /// 간격을 따라 검사하며 [pose]대로 움직이는 아이를 본다. 경고가 처음 뜬 시각(초)을 돌려준다.
    double? firstAlert(
      FaceReading Function(double sec) pose, {
      Duration? fixed,
      required double until,
      EyeAlert want = EyeAlert.tooClose,
    }) {
      final t0 = DateTime(2026);
      var now = t0;
      final g = EyeGuard(sensor: FakeSensor(), now: () => now);
      while (now.difference(t0).inMilliseconds / 1000 <= until) {
        final sec = now.difference(t0).inMilliseconds / 1000;
        g.feed(pose(sec));
        if (g.alert == want) return sec;
        now = now.add(fixed ?? g.checkInterval);
      }
      return null;
    }

    test('가까워진 뒤 처음 본 때부터 정확히 2초 (가깝게 다가오는 동안 이미 0.5초 간격)', () {
      // 50cm에서 1초에 5cm씩 다가와 25cm에 멈춤: 36cm를 지나며 0.5초 간격이 된다
      FaceReading approach(double s) => at((50 - 5 * s).clamp(25, 50));
      final alertAt = firstAlert(approach, until: 20)!;
      // 30cm보다 가까워지는 것은 4초 뒤 → 4.5초에 처음 보고 6.5초에 경고
      expect(alertAt, 6.5);
      // 예전(0.7초 고정)과 비교: 처음 본 때 + 2초 이상, + 검사 간격 이내
      final before = firstAlert(approach, fixed: _ms * 700, until: 20)!;
      expect(before, closeTo(6.3, .001));
    });

    test('갑자기 가까워져도 경고까지 걸리는 시간은 처음 본 때부터 2초', () {
      // 10초째에 갑자기 20cm로
      FaceReading jump(double s) => at(s < 10 ? 60 : 20);
      final alertAt = firstAlert(jump, until: 30)!;
      // 평소 1.5초 간격: 10.5초에 처음 봄 → 12.5초 경고
      expect(alertAt, 12.5);
    });

    test('자세 경고는 처음 본 때부터 3초', () {
      FaceReading turn(double s) => at(60, yaw: s < 6 ? 0 : 50);
      final alertAt = firstAlert(turn, until: 30, want: EyeAlert.badAngle)!;
      // 6초에 처음 봄(1.5초 간격 4번째) → 9초 경고
      expect(alertAt, 9.0);
    });
  });

  group('카메라·ML Kit 설정', () {
    test('ML Kit: 빠른 모드, 얼굴 상자와 고개 각도만 (landmarks·contours·classification·tracking 끔)', () {
      final o = eyeFaceDetectorOptions();
      expect(o.performanceMode, FaceDetectorMode.fast);
      expect(o.enableLandmarks, isFalse);
      expect(o.enableContours, isFalse);
      expect(o.enableClassification, isFalse);
      expect(o.enableTracking, isFalse);
      expect(o.minFaceSize, .08);
    });

    test('카메라: 가장 낮은 해상도, 초당 5~10장, 소리 없음', () {
      const front = CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );
      for (final ios in [false, true]) {
        final c = eyeCameraController(front, ios: ios);
        expect(c.mediaSettings.resolutionPreset, ResolutionPreset.low);
        expect(c.mediaSettings.fps, inInclusiveRange(5, 10));
        expect(c.mediaSettings.enableAudio, isFalse);
        expect(
          c.imageFormatGroup,
          ios ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
        );
      }
      expect(eyeCameraFps(ios: false), 10);
      expect(eyeCameraFps(ios: true), 5);
    });

    test('웹: 320x240, 초당 5장(최대 10장)으로 받고 간격은 앱이 정한다', () {
      final js = File('web/eye_guard.js').readAsStringSync();
      expect(js, contains('width: { ideal: 320 }'));
      expect(js, contains('height: { ideal: 240 }'));
      expect(js, contains('frameRate: { ideal: 5, max: 10 }'));
      expect(js, contains('setInterval: function (ms)'));
      expect(js, isNot(contains('640')));
    });
  });

  test('1분 추정: 카메라 프레임 수와 검사 횟수 (전/후)', () {
    /// [fps]로 들어오는 프레임 중에서 [interval]마다 하나를 검사할 때 1분 동안의 수
    (int frames, int checks) minute(int fps, Duration Function() interval) {
      final gate = EyeCheckGate();
      final t0 = DateTime(2026);
      var frames = 0, checks = 0;
      for (var i = 0; i < 60 * fps; i++) {
        frames++;
        gate.interval = interval();
        if (gate.take(t0.add(Duration(microseconds: i * 1000000 ~/ fps)))) {
          checks++;
        }
      }
      return (frames, checks);
    }

    final before = minute(30, () => _ms * 700);
    final calm = minute(EyeRules.androidFps, () => EyeRules.slowInterval);
    final near = minute(EyeRules.androidFps, () => EyeRules.fastInterval);
    final iosCalm = minute(EyeRules.iosFps, () => EyeRules.slowInterval);
    final iosNear = minute(EyeRules.iosFps, () => EyeRules.fastInterval);
    debugPrint(
      '| 경우 | 초당 프레임 | 1분 프레임 | 1분 검사 |\n'
      '| 전 (30fps, 0.7초) | 30 | ${before.$1} | ${before.$2} |\n'
      '| 후 안드로이드 평소 | ${EyeRules.androidFps} | ${calm.$1} | ${calm.$2} |\n'
      '| 후 안드로이드 가까움·경고 | ${EyeRules.androidFps} | ${near.$1} | ${near.$2} |\n'
      '| 후 iOS 평소 | ${EyeRules.iosFps} | ${iosCalm.$1} | ${iosCalm.$2} |\n'
      '| 후 iOS 가까움·경고 | ${EyeRules.iosFps} | ${iosNear.$1} | ${iosNear.$2} |',
    );
    expect(before, (1800, 86));
    expect(calm, (600, 40));
    expect(near, (600, 120));
    expect(iosCalm, (300, 38), reason: '5fps라 실제 간격 1.6초');
    expect(iosNear, (300, 100), reason: '5fps라 실제 간격 0.6초');
  });

  group('앱 화면에 따라 켜고 끈다', () {
    Future<(GameState, FakeSensor)> app(
      WidgetTester t, {
      int limit = 0,
      int brk = 10,
      DateTime Function()? clock,
    }) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final sensor = FakeSensor();
      final s = GameState(
        storage: MemoryStorage(),
        audio: RecordingAudio(),
        eyeGuard: EyeGuard(sensor: sensor, now: clock),
        now: clock,
      );
      await s.load();
      await s.setNickname('별이');
      await s.setPlayLimit(limit);
      await s.setEyeBreak(brk);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(seconds: 1));
      return (s, sensor);
    }

    Future<void> openGame(WidgetTester t) async {
      Navigator.of(t.element(find.byType(HomeScreen)))
          .push(softRoute(gameScreen(GameKind.shape, 1)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    Future<void> finish(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 7));
    }

    testWidgets('홈에서는 꺼져 있고, 놀이 화면에서 켜지고, 멈춤·집으로 가면 꺼진다', (t) async {
      final (s, sensor) = await app(t);
      expect(s.eyeGuardOn, isTrue, reason: '기본 켜짐');
      expect(sensor.on, isFalse, reason: '홈 화면');
      await openGame(t);
      expect(sensor.on, isTrue, reason: '놀이 화면');
      await t.tap(find.byIcon(Icons.pause_rounded));
      await t.pump(const Duration(milliseconds: 1100));
      expect(sensor.on, isFalse, reason: '멈춤 화면');
      await t.tap(find.text('계속'));
      await t.pump();
      expect(sensor.on, isTrue);
      expect(sensor.starts, 2);
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300)); // 페이드 끝
      await t.pump(); // 놀이 화면이 사라진다
      expect(find.byType(GameFrame), findsNothing);
      expect(sensor.on, isTrue, reason: '나간 직후 1초는 기다린다');
      await t.pump(const Duration(milliseconds: 1100));
      expect(sensor.on, isFalse, reason: '홈으로 돌아옴');
      await finish(t);
    });

    testWidgets('멈춤 화면·덮개 뒤와 가려진 화면은 다시 그리지 않는다 (공용 시계에서 빠짐)', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, _) = await app(t, clock: () => now);
      final home = SlowClock.instance.listenerCount;
      expect(home, greaterThan(0), reason: '홈: 배경·캐릭터가 천천히 움직인다');
      await openGame(t);
      final playing = SlowClock.instance.listenerCount;
      expect(playing, greaterThan(0), reason: '놀이 화면 배경·캐릭터');
      await t.tap(find.byIcon(Icons.pause_rounded));
      await t.pump();
      expect(
        SlowClock.instance.listenerCount,
        0,
        reason: '멈춤 화면 뒤와 그 아래 홈 화면은 멈춘다',
      );
      await t.tap(find.text('계속'));
      await t.pump();
      expect(SlowClock.instance.listenerCount, playing);
      // 눈 지킴이 경고 덮개
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(20));
      }
      await t.pump();
      expect(s.eye.alert, EyeAlert.tooClose);
      expect(SlowClock.instance.listenerCount, lessThan(playing));
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(60));
        await t.pump(const Duration(milliseconds: 500));
      }
      expect(s.eye.alert, EyeAlert.none);
      expect(SlowClock.instance.listenerCount, playing);
      await finish(t);
    });

    testWidgets('앱이 뒤로 가면 끄고, 돌아오면 다시 켠다', (t) async {
      final (_, sensor) = await app(t);
      await openGame(t);
      expect(sensor.on, isTrue);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump(const Duration(milliseconds: 100));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(sensor.on, isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(sensor.on, isTrue);
      await finish(t);
    });

    testWidgets('눈 쉬기 덮개가 떠 있는 동안은 꺼지고, 끝나면 켜진다', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, sensor) = await app(t, brk: 10, clock: () => now);
      await openGame(t);
      expect(sensor.on, isTrue);
      for (var i = 0; i < 10 * 12; i++) {
        now = now.add(const Duration(seconds: 5));
        await t.pump(const Duration(seconds: 5));
        if (s.playBlock != PlayBlock.none) break;
      }
      expect(s.playBlock, PlayBlock.eyeBreak);
      await t.pump(const Duration(milliseconds: 1100));
      expect(sensor.on, isFalse);
      for (var i = 0; i < 25 && s.playBlock != PlayBlock.none; i++) {
        now = now.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(s.playBlock, PlayBlock.none);
      await t.pump();
      expect(sensor.on, isTrue);
      await finish(t);
    });

    testWidgets('"오늘은 여기까지!" 덮개가 뜨면 꺼진다', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, sensor) = await app(t, limit: 10, brk: 20, clock: () => now);
      await openGame(t);
      expect(sensor.on, isTrue);
      for (var i = 0; i < 11 * 12 && s.playBlock == PlayBlock.none; i++) {
        now = now.add(const Duration(seconds: 5));
        await t.pump(const Duration(seconds: 5));
      }
      expect(s.playBlock, PlayBlock.limit);
      await t.pump(const Duration(milliseconds: 1100));
      expect(sensor.on, isFalse);
      await finish(t);
    });
  });

  group('경고는 끝이 있다 (발열 줄이기)', () {
    late DateTime now;
    late FakeSensor sensor;
    late EyeGuard g;
    final owner = Object();

    Future<void> setUpGuard(WidgetTester t) async {
      now = DateTime(2026);
      sensor = FakeSensor();
      g = EyeGuard(sensor: sensor, now: () => now)..enabled = true;
      g.showPlay(owner);
      await t.pump();
      expect(g.running, isTrue);
    }

    /// 검사 간격대로 [r]을 본다
    void step(FaceReading? r) {
      now = now.add(g.checkInterval);
      g.feed(r);
    }

    void alertNow() {
      while (g.alert == EyeAlert.none) {
        step(at(20));
      }
    }

    testWidgets('경고 중 얼굴이 10초 안 보이면 카메라를 끄고 쉬어 가기, 누르면 다시 켠다', (t) async {
      await setUpGuard(t);
      alertNow();
      final seen = now; // 마지막으로 얼굴을 본 때
      while (g.running) {
        step(null);
        await t.pump();
      }
      expect(now.difference(seen), EyeRules.noFaceGiveUp);
      expect(sensor.on, isFalse);
      expect(g.resting, isTrue);
      expect(g.alert, EyeAlert.none);
      expect(g.wanted, isFalse, reason: '놀이 화면이어도 쉬는 동안은 켜지 않는다');
      await t.pump(const Duration(seconds: 5));
      expect(sensor.on, isFalse);
      g.wake();
      await t.pump();
      expect(g.resting, isFalse);
      expect(sensor.on, isTrue, reason: '돌아오면 다시 켠다');
      expect(sensor.starts, 2);
      g.hidePlay(owner);
      await t.pump(const Duration(milliseconds: 1100));
    });

    testWidgets('얼굴이 잠깐(10초 안) 안 보였다 다시 보이면 경고 그대로', (t) async {
      await setUpGuard(t);
      alertNow();
      for (var i = 0; i < 8; i++) {
        step(null);
      }
      step(at(20));
      for (var i = 0; i < 8; i++) {
        step(null);
      }
      await t.pump();
      expect(g.running, isTrue);
      expect(g.alert, EyeAlert.tooClose);
      expect(g.resting, isFalse);
      g.hidePlay(owner);
      await t.pump(const Duration(milliseconds: 1100));
      g.stop();
    });

    testWidgets('경고가 75초 이어지면 카메라를 끄고 쉬어 가기', (t) async {
      await setUpGuard(t);
      alertNow();
      final alertAt = now;
      var checks = 0;
      while (g.running) {
        step(at(20, yaw: checks.isEven ? 0 : 50)); // 가까움·고개 돌림이 섞여도 한 번의 경고
        checks++;
        await t.pump();
      }
      expect(
        now.difference(alertAt),
        const Duration(seconds: 75, milliseconds: 500),
        reason: '75초를 넘긴 첫 검사 (1.5초 간격)',
      );
      expect(sensor.on, isFalse);
      expect(g.resting, isTrue);
      // 20초 동안 1초 간격(20번) + 55초 동안 1.5초 간격(약 37번)
      expect(checks, inInclusiveRange(55, 58));
      g.hidePlay(owner);
      await t.pump(const Duration(milliseconds: 1100));
    });
  });

  group('덮개가 떠 있으면 밑단을 멈춘다 (앱)', () {
    Future<(GameState, FakeSensor, RecordingAudio)> app(
      WidgetTester t,
      DateTime Function() clock,
    ) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final sensor = FakeSensor();
      final audio = RecordingAudio();
      final s = GameState(
        storage: MemoryStorage(),
        audio: audio,
        eyeGuard: EyeGuard(sensor: sensor, now: clock),
        now: clock,
      );
      await s.load();
      await s.setNickname('별이');
      await s.setPlayLimit(0);
      await t.pumpWidget(AlokdalokApp(state: s));
      await t.pump(const Duration(seconds: 1));
      Navigator.of(t.element(find.byType(HomeScreen)))
          .push(softRoute(gameScreen(GameKind.shape, 1)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      return (s, sensor, audio);
    }

    Future<void> finish(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 7));
    }

    const close = '화면이 너무 가까워요. 조금 뒤로 가 볼까요?';

    testWidgets('경고 음성은 8초마다 최대 3번, 그 뒤로는 조용히', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, _, audio) = await app(t, () => now);
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(20));
      }
      await t.pump();
      expect(s.eye.alert, EyeAlert.tooClose);
      int said() => audio.spoken.where((e) => e == close).length;
      expect(said(), 1);
      // 1분 동안 1초마다 계속 가까이 본다 (75초 전이라 경고는 그대로)
      for (var i = 0; i < 60; i++) {
        now = now.add(const Duration(seconds: 1));
        s.eye.feed(at(20));
        await t.pump(const Duration(seconds: 1));
      }
      expect(s.eye.alert, EyeAlert.tooClose);
      expect(said(), EyeGuardOverlay.maxSpeaks);
      expect(said(), 3);
      // 풀렸다가 다시 경고가 뜨면 처음부터 다시 3번까지
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(60));
      }
      await t.pump();
      expect(s.eye.alert, EyeAlert.none);
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(20));
      }
      await t.pump();
      expect(said(), 4);
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(60));
      }
      await t.pump();
      await finish(t);
    });

    testWidgets('경고·쉬어 가기 동안 공용 시계·배경 음악·장면을 멈추고, 돌아오면 되돌린다', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, sensor, audio) = await app(t, () => now);
      expect(SlowClock.instance.ticking, isTrue);
      expect(audio.music, isNotNull, reason: '놀이 화면 음악');
      final track = audio.music;
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(20));
      }
      await t.pump();
      expect(s.eye.alert, EyeAlert.tooClose);
      expect(SlowClock.instance.held, isTrue);
      expect(SlowClock.instance.ticking, isFalse);
      expect(audio.musicHeld, isTrue);
      expect(audio.music, isNull);
      final card = t.widget<Material>(
        find
            .descendant(
              of: find.byType(EyeGuardOverlay),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, const Color(0xFFFFF6E5), reason: '완전히 불투명');
      // 아이가 떠난다: 10초 넘게 얼굴이 안 보임 → 쉬어 가기
      for (var i = 0; i < 12 && s.eye.running; i++) {
        now = now.add(const Duration(seconds: 1));
        s.eye.feed(null);
        await t.pump(const Duration(seconds: 1));
      }
      await t.pump(const Duration(milliseconds: 400));
      expect(sensor.on, isFalse);
      expect(s.playBlock, PlayBlock.eyeRest);
      expect(find.text('창밖 먼 곳을 봐요'), findsOneWidget);
      expect(find.text('다 쉬었으면 화면을 눌러요'), findsOneWidget);
      expect(audio.spoken.last, '창밖 먼 곳을 봐요.');
      expect(
        audio.spoken.contains('잘했어요! 다시 놀아요.'),
        isFalse,
        reason: '바르게 앉아서 풀린 게 아니다',
      );
      expect(SlowClock.instance.ticking, isFalse);
      expect(audio.music, isNull);
      // 한참 뒤에도 그대로 (카메라 꺼짐)
      await t.pump(const Duration(seconds: 30));
      expect(sensor.on, isFalse);
      expect(s.playBlock, PlayBlock.eyeRest);
      // 화면을 한 번 누르면 돌아온다 (부모 확인 없음)
      await t.tap(find.text('창밖 먼 곳을 봐요'));
      await t.pump();
      expect(s.playBlock, PlayBlock.none);
      expect(sensor.on, isTrue, reason: '카메라를 다시 켠다');
      expect(audio.spoken.last, '잘 쉬었어요! 다시 놀아요.');
      expect(SlowClock.instance.held, isFalse);
      expect(SlowClock.instance.ticking, isTrue);
      expect(audio.music, track);
      await finish(t);
    });

    testWidgets('쉬어 가기가 막 뜬 순간(1초 안)의 터치는 무시한다', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, _, _) = await app(t, () => now);
      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(milliseconds: 500));
        s.eye.feed(at(20));
      }
      for (var i = 0; i < 12 && s.eye.running; i++) {
        now = now.add(const Duration(seconds: 1));
        s.eye.feed(null);
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(s.playBlock, PlayBlock.eyeRest);
      await t.tap(find.text('창밖 먼 곳을 봐요'));
      await t.pump();
      expect(s.playBlock, PlayBlock.eyeRest);
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('창밖 먼 곳을 봐요'));
      await t.pump();
      expect(s.playBlock, PlayBlock.none);
      await finish(t);
    });

    testWidgets('눈 쉬기·오늘은 여기까지 덮개도 시계와 음악을 멈춘다', (t) async {
      var now = DateTime(2026, 10, 21, 9);
      final (s, _, audio) = await app(t, () => now);
      for (var i = 0; i < 10 * 12 && s.playBlock == PlayBlock.none; i++) {
        now = now.add(const Duration(seconds: 5));
        await t.pump(const Duration(seconds: 5));
      }
      expect(s.playBlock, PlayBlock.eyeBreak);
      expect(SlowClock.instance.ticking, isFalse);
      expect(audio.music, isNull);
      // 고리는 1초에 한 번씩 줄어든다 (공용 시계 없이)
      String left() => t
          .widgetList<Text>(
            find.descendant(
              of: find.byType(EyeBreakCard),
              matching: find.byType(Text),
            ),
          )
          .map((e) => e.data)
          .firstWhere((d) => int.tryParse(d ?? '') != null)!;
      final a = left();
      now = now.add(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 2));
      expect(int.parse(left()), int.parse(a) - 2);
      for (var i = 0; i < 25 && s.playBlock != PlayBlock.none; i++) {
        now = now.add(const Duration(seconds: 1));
        await t.pump(const Duration(seconds: 1));
      }
      expect(s.playBlock, PlayBlock.none);
      expect(SlowClock.instance.ticking, isTrue);
      expect(audio.music, isNotNull);
      await s.setPlayLimit(10);
      await t.pump(const Duration(seconds: 1));
      expect(s.playBlock, PlayBlock.limit);
      expect(SlowClock.instance.ticking, isFalse);
      expect(audio.music, isNull);
      await finish(t);
      expect(SlowClock.instance.held, isFalse, reason: '앱이 사라지면 풀어 둔다');
    });
  });

  group('실측 진단 (EyeStats)', () {
    test('최근 1분의 실제 초당 프레임·검사 횟수·카메라 켜짐 비율', () {
      var now = DateTime(2026);
      final st = EyeStats(now: () => now);
      expect(st.summary().fps, isNull);
      now = now.add(const Duration(seconds: 30)); // 30초 꺼져 있음
      st.cameraOn(true);
      // 30초 동안 초당 30장 (요청이 안 먹힌 기기), 1.5초마다 검사
      for (var i = 0; i < 30 * 30; i++) {
        now = now.add(const Duration(microseconds: 1000000 ~/ 30));
        st.frame();
        if (i % 45 == 0) st.check();
      }
      var sum = st.summary();
      expect(sum.window.inSeconds, closeTo(60, 1));
      expect(sum.fps, closeTo(30, .5));
      expect(sum.checks, 20);
      expect(sum.onRatio, closeTo(.5, .01));
      // 카메라를 끄고 1분이 지나면 기록이 비워진다
      st.cameraOn(false);
      now = now.add(const Duration(seconds: 61));
      sum = st.summary();
      expect(sum.frames, 0);
      expect(sum.checks, 0);
      expect(sum.onRatio, 0);
      expect(sum.fps, isNull);
    });

    test('앱을 켠 지 1분이 안 됐으면 켠 뒤부터 잰다, 켜져 있는 구간이 1분을 넘으면 1분만', () {
      var now = DateTime(2026);
      final st = EyeStats(now: () => now)..cameraOn(true);
      for (var i = 0; i < 100; i++) {
        now = now.add(const Duration(milliseconds: 100));
        st.frame();
      }
      var sum = st.summary();
      expect(sum.window, const Duration(seconds: 10));
      expect(sum.onRatio, 1);
      expect(sum.fps, closeTo(10, .01));
      for (var i = 0; i < 1200; i++) {
        now = now.add(const Duration(milliseconds: 100));
        st.frame();
      }
      sum = st.summary();
      expect(sum.window, EyeStats.window);
      expect(sum.cameraOn, EyeStats.window);
      expect(sum.frames, inInclusiveRange(600, 601));
    });

    test('눈 지킴이가 켜고 끄고 검사한 것을 기록한다', () async {
      var now = DateTime(2026);
      final st = EyeStats(now: () => now);
      final g = EyeGuard(sensor: FakeSensor(), now: () => now, stats: st);
      await g.start();
      now = now.add(const Duration(seconds: 3));
      g.feed(at(60));
      g.feed(null);
      now = now.add(const Duration(seconds: 3));
      await g.stop();
      now = now.add(const Duration(seconds: 6));
      final sum = st.summary();
      expect(sum.checks, 2);
      expect(sum.cameraOn, const Duration(seconds: 6));
      expect(sum.onRatio, closeTo(.5, .001));
    });

    testWidgets('설정의 \'부모님께\'를 길게 누르면 진단 칸이 열린다', (t) async {
      t.view.physicalSize = const Size(844, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
      await s.load();
      await t.pumpWidget(
        AppScope(
          state: s,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      expect(find.byType(EyeDiagnosticsPanel), findsNothing);
      await t.longPress(find.textContaining('회원가입'));
      await t.pump();
      expect(find.byType(EyeDiagnosticsPanel), findsOneWidget);
      expect(find.text('눈 지킴이 진단 (최근 1분)'), findsOneWidget);
      expect(find.text('실제 초당 프레임'), findsOneWidget);
      expect(find.text('검사 횟수'), findsOneWidget);
      expect(find.text('카메라 켜짐'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
      await t.longPress(find.textContaining('회원가입'));
      await t.pump();
      expect(find.byType(EyeDiagnosticsPanel), findsNothing);
    });
  });
}
