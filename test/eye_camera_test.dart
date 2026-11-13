// 눈 지킴이 카메라 발열 줄이기: 필요할 때만 켜기, 창 주기(짧게 열어서 보고 끄기), 기기 열 백오프,
// 경고까지 걸리는 시간, 카메라·ML Kit 설정, 1분 켜짐 비율
import 'dart:async';
import 'dart:io';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/games/common/game_frame.dart';
import 'package:alokdalok/games/game_entry.dart';
import 'package:alokdalok/core/slow_clock.dart';
import 'package:alokdalok/screens/home_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/device_heat.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'eye_guard_test.dart' show FakeSensor, at;

const _ms = Duration(milliseconds: 1);

/// 카메라를 허락하지 않은 기기
class _DeniedSensor extends FakeSensor {
  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async => throw const EyeSensorDenied('카메라 사용을 허용해 주세요');
}

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
      expect(sensor.waiting, isTrue, reason: '창을 바로 연다');
      sensor.reply(const FaceReading(size: .2, yaw: 0, pitch: 0, roll: 0));
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

  group('창 주기 (카메라를 짧게 열어서 보고 끈다)', () {
    late DateTime now;
    late FakeSensor sensor;
    late DeviceHeat heat;
    late EyeGuard g;
    setUp(() {
      now = DateTime(2026);
      sensor = FakeSensor();
      heat = DeviceHeat();
      g = EyeGuard(sensor: sensor, now: () => now, heat: heat);
    });
    void step(FaceReading? r, [Duration? d]) {
      now = now.add(d ?? g.checkInterval);
      g.feed(r);
    }

    const s10 = Duration(seconds: 10), s3 = Duration(seconds: 3);
    const s15 = Duration(milliseconds: 1500);

    test('넉넉(42cm 넘고 자세 바름) 10초, 기준 가까이(36cm 이하·각도 80% 넘음) 3초, 그 사이는 직전 그대로', () {
      expect(g.checkInterval, s10);
      step(at(50));
      expect((g.zone, g.checkInterval), (EyeZone.safe, s10));
      step(at(36));
      expect((g.zone, g.checkInterval), (EyeZone.caution, s3), reason: '36cm');
      step(at(40));
      expect(g.checkInterval, s3, reason: '36~42cm는 직전(기준 가까이) 그대로');
      step(at(42));
      expect(g.checkInterval, s3, reason: '42cm는 아직 넉넉하지 않다');
      step(at(43));
      expect(g.checkInterval, s10);
      step(at(40));
      expect(g.checkInterval, s10, reason: '36~42cm는 직전(넉넉) 그대로');
      step(at(50, yaw: 28)); // 35도의 80% (넘지 않음)
      expect(g.checkInterval, s10);
      step(at(50, yaw: 29));
      expect(g.checkInterval, s3);
      step(at(50, pitch: 25)); // 30도의 80% = 24
      expect(g.checkInterval, s3);
      step(at(50));
      expect(g.checkInterval, s10);
      step(at(50, roll: 37)); // 45도의 80% = 36
      expect(g.checkInterval, s3);
      step(null);
      expect(g.checkInterval, s10, reason: '얼굴이 안 보이면 넉넉');
    });

    test('경고 중 1.5초 (얼굴이 잠깐 안 보여도), 풀리면 기준 가까이 3초부터', () {
      while (g.alert == EyeAlert.none) {
        step(at(25));
      }
      expect(g.alert, EyeAlert.tooClose);
      expect((g.zone, g.checkInterval), (EyeZone.alert, s15));
      step(at(33)); // 경계 (30~34cm)
      expect(g.checkInterval, s15);
      step(null);
      expect(g.checkInterval, s15);
      for (var i = 0; i < 20; i++) {
        step(at(25));
        expect(g.checkInterval, s15, reason: '경고 중에는 줄곧 1.5초');
      }
      step(at(38));
      step(at(38));
      expect(g.alert, EyeAlert.none);
      expect(g.checkInterval, s3, reason: '막 풀린 36~42cm는 기준 가까이');
      step(at(50));
      expect(g.checkInterval, s10);
    });

    test('기준 거리를 40cm로 바꾸면 48cm 이하 3초, 56cm 넘으면 10초', () {
      g.tooCloseCm = 40;
      step(at(57));
      expect(g.checkInterval, s10);
      step(at(49));
      expect(g.checkInterval, s10, reason: '48~56cm는 직전 그대로');
      step(at(48));
      expect(g.checkInterval, s3);
      step(at(56));
      expect(g.checkInterval, s3);
      step(at(57));
      expect(g.checkInterval, s10);
    });

    test('기기가 따뜻하거나(MODERATE 이상) 절전·배터리 20% 이하면 창 주기 2배', () {
      HeatStatus st(HeatLevel l, {bool? save, int? battery}) =>
          HeatStatus(thermal: l, powerSave: save, battery: battery);
      heat.update(st(HeatLevel.none, save: false, battery: 80));
      expect(g.checkInterval, s10);
      heat.update(st(HeatLevel.light));
      expect(g.checkInterval, s10, reason: 'LIGHT는 그대로');
      heat.update(st(HeatLevel.moderate));
      expect(g.checkInterval, s10 * 2);
      step(at(36));
      expect(g.checkInterval, s3 * 2);
      while (g.alert == EyeAlert.none) {
        step(at(25));
      }
      expect(g.checkInterval, s15 * 2);
      heat.update(st(HeatLevel.none));
      expect(g.checkInterval, s15);
      heat.update(st(HeatLevel.none, save: true));
      expect(g.checkInterval, s15 * 2, reason: '절전 모드');
      heat.update(st(HeatLevel.unknown, battery: 20));
      expect(g.checkInterval, s15 * 2, reason: '배터리 20%');
      heat.update(st(HeatLevel.unknown, battery: 21));
      expect(g.checkInterval, s15, reason: '열 상태를 모르면(안드로이드 10 미만·웹) 그대로');
      heat.update(st(HeatLevel.moderate, save: true, battery: 5));
      expect(g.checkInterval, s15 * 2, reason: '겹쳐도 2배');
      expect(g.heatOff, isFalse);
    });

    test('켜자마자 첫 창을 열고, 다음 창은 연 때부터 주기만큼 뒤', () async {
      final st = EyeStats(now: () => now);
      final auto = FakeSensor(scene: () => at(60));
      final g2 = EyeGuard(sensor: auto, now: () => now, stats: st, heat: heat);
      await g2.start();
      await Future<void>.delayed(Duration.zero);
      expect(auto.samples, 1, reason: '켜자마자 첫 창');
      expect(g2.nextWindowAt, now.add(s10));
      expect(auto.budgets.single, EyeRules.windowBudget);
      await g2.stop();
    });
  });

  group('기기 열·절전 (플랫폼 채널 값)', () {
    test('안드로이드 THERMAL_STATUS 0~6 / 모름 -1 → 단계, 지도 → 상태', () {
      expect(HeatLevel.fromRaw(-1), HeatLevel.unknown);
      expect(HeatLevel.fromRaw(null), HeatLevel.unknown);
      expect(HeatLevel.fromRaw(0), HeatLevel.none);
      expect(HeatLevel.fromRaw(2), HeatLevel.moderate);
      expect(HeatLevel.fromRaw(3), HeatLevel.severe);
      expect(HeatLevel.fromRaw(6), HeatLevel.shutdown);
      expect(HeatLevel.fromRaw(7), HeatLevel.unknown);
      final s = HeatStatus.fromMap({
        'thermal': 2,
        'powerSave': true,
        'battery': 15,
      });
      expect(s.thermal, HeatLevel.moderate);
      expect(s.powerSave, isTrue);
      expect(s.battery, 15);
      final none = HeatStatus.fromMap({'thermal': -1, 'battery': -1});
      expect(none.thermal, HeatLevel.unknown);
      expect(none.battery, isNull);
      expect(DeviceHeat(none).backoff, 1);
    });

    testWidgets('채널이 없으면(테스트·웹) 모름으로 두고 늘리지 않는다', (t) async {
      final h = DeviceHeat();
      await t.runAsync(h.bind); // 채널 응답은 진짜 시간으로 온다
      expect(h.bound, isFalse);
      expect(h.status.thermal, HeatLevel.unknown);
      expect(h.backoff, 1);
    });

    testWidgets('네이티브가 값을 보내면(start·changed) 바로 바뀐다', (t) async {
      final messenger = t.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DeviceHeat.channel, (call) async {
        expect(call.method, 'start');
        return {'thermal': 0, 'powerSave': false, 'battery': 90};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(DeviceHeat.channel, null),
      );
      final h = DeviceHeat();
      await h.bind();
      expect(h.bound, isTrue);
      expect(h.status.thermal, HeatLevel.none);
      expect(h.status.battery, 90);
      const codec = StandardMethodCodec();
      await messenger.handlePlatformMessage(
        DeviceHeat.channel.name,
        codec.encodeMethodCall(
          const MethodCall('changed', {'thermal': 3, 'powerSave': false, 'battery': 90}),
        ),
        (_) {},
      );
      expect(h.tooHot, isTrue);
    });

    testWidgets('기기가 뜨거우면(SEVERE 이상) 이번 실행 동안 눈 지킴이를 끈다', (t) async {
      final heat = DeviceHeat();
      final sensor = FakeSensor();
      final owner = Object();
      final g = EyeGuard(sensor: sensor, heat: heat)..enabled = true;
      g.showPlay(owner);
      await t.pump();
      expect(g.running, isTrue);
      heat.update(const HeatStatus(thermal: HeatLevel.moderate));
      await t.pump();
      expect(g.running, isTrue, reason: 'MODERATE는 늦추기만');
      heat.update(const HeatStatus(thermal: HeatLevel.severe));
      await t.pump();
      expect(g.heatOff, isTrue);
      expect(g.running, isFalse);
      expect(sensor.on, isFalse);
      expect(g.wanted, isFalse);
      expect(g.enabled, isTrue, reason: '설정은 그대로 (이번 실행만)');
      heat.update(const HeatStatus(thermal: HeatLevel.none));
      await t.pump(const Duration(seconds: 5));
      expect(g.heatOff, isTrue, reason: '식어도 앱을 다시 켤 때까지 꺼 둔다');
      expect(sensor.on, isFalse);
      g.hidePlay(owner);
      g.dispose();
    });

    testWidgets('처음부터 뜨거우면 켜지 않는다', (t) async {
      final heat = DeviceHeat(const HeatStatus(thermal: HeatLevel.critical));
      final sensor = FakeSensor();
      final g = EyeGuard(sensor: sensor, heat: heat)..enabled = true;
      g.showPlay(Object());
      await t.pump();
      expect(g.heatOff, isTrue);
      expect(sensor.starts, 0);
      g.dispose();
    });
  });

  group('카메라 창 하나 (EyeWindow: sampleOnce의 속)', () {
    /// [gap]마다 프레임을 보내는 가짜 스트림
    ({EyeWindow<int> w, List<String> log}) make(
      Future<FaceReading?> Function(int frame) analyze, {
      Duration gap = const Duration(milliseconds: 100),
      bool frames = true,
    }) {
      final log = <String>[];
      Timer? timer;
      final w = EyeWindow<int>(
        open: (onFrame) async {
          log.add('open');
          var n = 0;
          if (frames) {
            timer = Timer.periodic(gap, (_) => onFrame(n++));
          }
        },
        close: () async {
          timer?.cancel();
          log.add('close');
        },
        analyze: analyze,
      );
      return (w: w, log: log);
    }

    testWidgets('얼굴을 못 보면 3장 본 뒤 null, 스트림을 닫는다', (t) async {
      final (:w, :log) = make((_) async => null);
      FaceReading? got = const FaceReading(size: 1, yaw: 0, pitch: 0, roll: 0);
      var done = false;
      w.run().then((r) {
        got = r;
        done = true;
      });
      await t.pump(const Duration(milliseconds: 250));
      expect(done, isFalse);
      await t.pump(const Duration(milliseconds: 100));
      expect(done, isTrue, reason: '3장째(0.3초)에 끝');
      expect(got, isNull);
      expect(w.valid, 3);
      expect(log, ['open', 'close']);
    });

    testWidgets('budget(1초) 안에 쓸 만한 프레임이 없으면 1초에 null, 스트림을 닫는다', (t) async {
      final (:w, :log) = make((_) async => throw StateError('dark'));
      FaceReading? got = const FaceReading(size: 1, yaw: 0, pitch: 0, roll: 0);
      var done = false;
      w.run().then((r) {
        got = r;
        done = true;
      });
      await t.pump(const Duration(milliseconds: 999));
      expect(done, isFalse);
      await t.pump(const Duration(milliseconds: 1));
      expect(done, isTrue);
      expect(got, isNull);
      expect(w.valid, 0);
      expect(log, ['open', 'close']);
      // 프레임이 아예 안 와도 마찬가지
      final quiet = make((_) async => null, frames: false);
      var quietDone = false;
      quiet.w.run().then((r) => quietDone = r == null);
      await t.pump(EyeRules.windowBudget);
      expect(quietDone, isTrue);
      expect(quiet.log, ['open', 'close']);
    });

    testWidgets('얼굴을 보면 2장에서 끝내고, 그중 얼굴이 가장 큰(가까운) 것을 고른다', (t) async {
      final sizes = [1 / 40, 1 / 30, 1 / 20];
      final (:w, :log) = make(
        (i) async => FaceReading(size: sizes[i], yaw: 0, pitch: 0, roll: 0),
      );
      FaceReading? got;
      w.run().then((r) => got = r);
      await t.pump(const Duration(milliseconds: 200));
      expect(got?.size, 1 / 30);
      expect(w.valid, 2);
      expect(log, ['open', 'close']);
    });

    testWidgets('살펴보는 중에 온 프레임은 건너뛴다, 첫 장이 비어도 다음 장을 본다', (t) async {
      var calls = 0;
      final (:w, log: _) = make((i) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return i == 0 ? null : at(50);
      });
      FaceReading? got;
      w.run().then((r) => got = r);
      await t.pump(const Duration(seconds: 1));
      expect(got, isNotNull);
      expect(calls, lessThanOrEqualTo(3), reason: '0.1초마다 오지만 0.25초씩 걸린다');
    });

    testWidgets('카메라를 끄면(abort) 바로 닫는다', (t) async {
      final (:w, :log) = make((_) async => null, frames: false);
      var done = false;
      w.run().then((_) => done = true);
      await t.pump(const Duration(milliseconds: 100));
      w.abort();
      await t.pump();
      expect(done, isTrue);
      expect(log, ['open', 'close']);
    });

    testWidgets('창을 못 열면(카메라 거부) 오류를 넘기고 닫는다, 눈 지킴이는 멈추고 이유를 남긴다', (t) async {
      final log = <String>[];
      final w = EyeWindow<int>(
        open: (_) async => throw '카메라 사용을 허용해 주세요',
        close: () async => log.add('close'),
        analyze: (_) async => null,
      );
      await expectLater(w.run(), throwsA('카메라 사용을 허용해 주세요'));
      expect(log, ['close']);

      final sensor = _DeniedSensor();
      final g = EyeGuard(sensor: sensor, heat: DeviceHeat())..enabled = true;
      g.showPlay(Object());
      await t.pump();
      await t.pump();
      expect(g.error, '카메라 사용을 허용해 주세요');
      expect(g.running, isFalse);
      expect(g.wanted, isFalse);
      g.dispose();
    });
  });

  group('경고까지 걸리는 시간 (처음 본 뒤 다음 창에서 확인: 3~5초)', () {
    /// 창 주기를 따라 살펴보며 [pose]대로 움직이는 아이를 본다. 경고가 처음 뜬 시각(초)을 돌려준다.
    double? firstAlert(
      FaceReading Function(double sec) pose, {
      required double until,
      EyeAlert want = EyeAlert.tooClose,
      HeatStatus heat = const HeatStatus(),
    }) {
      final t0 = DateTime(2026);
      var now = t0;
      final g = EyeGuard(
        sensor: FakeSensor(),
        now: () => now,
        heat: DeviceHeat(heat),
      );
      while (now.difference(t0).inMilliseconds / 1000 <= until) {
        final sec = now.difference(t0).inMilliseconds / 1000;
        g.feed(pose(sec));
        if (g.alert == want) return sec;
        now = now.add(g.checkInterval);
      }
      return null;
    }

    test('넉넉하다가 갑자기 가까워지면: 처음 본 창 + 3초', () {
      FaceReading jump(double s) => at(s < 12 ? 60 : 20);
      // 창 0·10·20초 → 20초에 처음 봄 → 23초 경고
      expect(firstAlert(jump, until: 60), 23);
    });

    test('기준 가까이(33cm)에서 놀다 가까워지면: 처음 본 창 + 3초', () {
      FaceReading lean(double s) => at(s < 7 ? 33 : 25);
      // 창 0·3·6·9초 → 9초에 처음 봄 → 12초 경고
      expect(firstAlert(lean, until: 60), 12);
    });

    test('천천히 다가오면: 36cm를 지나며 3초 창이 되고, 가까움을 처음 본 창 + 3초', () {
      FaceReading approach(double s) => at((60 - 2 * s).clamp(25, 60));
      // 0초 60cm → 10초 40cm(넉넉 그대로) → 20초 25cm(처음 봄) → 23초 경고
      expect(firstAlert(approach, until: 60), 23);
    });

    test('자세 경고도 처음 본 창 + 3초 (2.5초 넘게 이어짐)', () {
      FaceReading turn(double s) => at(60, yaw: s < 6 ? 0 : 50);
      expect(firstAlert(turn, until: 60, want: EyeAlert.badAngle), 13);
    });

    test('기기가 따뜻하면 처음 본 창 + 6초', () {
      FaceReading lean(double s) => at(s < 7 ? 33 : 25);
      final alertAt = firstAlert(
        lean,
        until: 60,
        heat: const HeatStatus(thermal: HeatLevel.moderate),
      );
      // 창 0·6·12초 → 12초에 처음 봄 → 18초 경고
      expect(alertAt, 18);
    });

    test('창 하나에서만 가까웠다면(스친 것) 경고하지 않는다', () {
      FaceReading pass(double s) => at(s >= 3 && s < 5 ? 20 : 33);
      expect(firstAlert(pass, until: 60), isNull);
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

    test('웹: 320x240, 초당 5장(최대 10장), 창을 열 때 play·닫을 때 pause (창 주기는 앱이 정한다)', () {
      final js = File('web/eye_guard.js').readAsStringSync();
      expect(js, contains('width: { ideal: 320 }'));
      expect(js, contains('height: { ideal: 240 }'));
      expect(js, contains('frameRate: { ideal: 5, max: 10 }'));
      expect(js, contains('open: async function ()'));
      expect(js, contains('detect: function ()'));
      expect(js, contains('pause: function ()'));
      expect(js, contains('await video.play()'));
      expect(js, contains('if (video) video.pause()'));
      expect(js, isNot(contains('setTimeout(tick')), reason: '스스로 도는 검사 없음');
      expect(js, isNot(contains('640')));
      final dart = File('lib/services/eye_sensor_web.dart').readAsStringSync();
      expect(dart, contains('EyeWindow<int>('));
      expect(dart, contains('g.pause()'));
    });

    test('앱: 창마다 이미지 스트림을 열고 닫는다, 컨트롤러는 기본으로 살려 둔다', () {
      final io = File('lib/services/eye_sensor_io.dart').readAsStringSync();
      expect(io, contains('EyeWindow<CameraImage>('));
      expect(io, contains('cam.startImageStream('));
      expect(io, contains('await cam.stopImageStream()'));
      expect(EyeRules.keepCameraDefault, isTrue);
      expect(EyeRules.windowBudget, const Duration(seconds: 1));
    });
  });

  group('1분 동안 카메라가 켜져 있는 시간 비율 (상태별)', () {
    /// 놀이 화면에서 [scene]을 계속 보는 1분 동안 카메라 켜짐 비율.
    /// 창 하나를 여는 데 [window]가 걸린다고 본다 (최악은 budget 1초).
    Future<(double, int)> minute(
      WidgetTester t,
      FaceReading? Function() scene, {
      required Duration window,
      HeatStatus heat = const HeatStatus(),
      Duration warmUp = const Duration(seconds: 5),
    }) async {
      DateTime now() => t.binding.clock.now();
      final st = EyeStats(now: now);
      final sensor = FakeSensor(scene: scene, windowTime: window);
      final owner = Object();
      final g = EyeGuard(
        sensor: sensor,
        now: now,
        stats: st,
        heat: DeviceHeat(heat),
      )..enabled = true;
      g.showPlay(owner);
      await t.pump();
      await t.pump(warmUp);
      st.reset();
      final before = sensor.samples;
      await t.pump(const Duration(minutes: 1));
      final sum = st.summary();
      expect(sum.window, EyeStats.window);
      expect(g.resting, isFalse);
      final windows = sensor.samples - before;
      g.enabled = false;
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(sensor.on, isFalse);
      g.dispose();
      return (sum.onRatio, windows);
    }

    FaceReading safe() => at(60);
    FaceReading caution() => at(33);
    FaceReading alert() => at(20);
    const worst = EyeRules.windowBudget; // 창을 1초 꽉 채워 연다고 볼 때
    const typical = Duration(milliseconds: 400); // 2~3장 (초당 10장 + ML Kit)
    const warm = HeatStatus(thermal: HeatLevel.moderate);

    testWidgets('안전 구간은 15% 이하, 기준 가까이·경고 중은 창 주기만큼', (t) async {
      final rows = <String>[];
      final got = <String, double>{};
      Future<void> row(
        String name,
        FaceReading Function() scene, {
        HeatStatus heat = const HeatStatus(),
      }) async {
        final (w1, n1) = await minute(t, scene, window: worst, heat: heat);
        final (w4, _) = await minute(t, scene, window: typical, heat: heat);
        got[name] = w1;
        rows.add(
          '| $name | $n1 | ${(w4 * 100).toStringAsFixed(0)}% | ${(w1 * 100).toStringAsFixed(0)}% |',
        );
      }

      await row('안전 (10초)', safe);
      await row('주의 (3초)', caution);
      await row('경고 중 (1.5초)', alert);
      await row('안전, 기기 따뜻함 (20초)', safe, heat: warm);
      await row('주의, 기기 따뜻함 (6초)', caution, heat: warm);
      await row('경고 중, 기기 따뜻함 (3초)', alert, heat: warm);
      debugPrint(
        '| 상태 | 1분 창 수 | 켜짐 (창 0.4초) | 켜짐 (창 1초, 최악) |\n'
        '| 전 (스트림 계속) | - | 100% | 100% |\n'
        '${rows.join('\n')}',
      );
      expect(got['안전 (10초)'], lessThanOrEqualTo(.15));
      expect(got['안전 (10초)'], closeTo(.10, .01));
      expect(got['주의 (3초)'], closeTo(.33, .02));
      expect(got['경고 중 (1.5초)'], closeTo(.67, .02));
      expect(got['안전, 기기 따뜻함 (20초)'], closeTo(.05, .02));
      expect(got['주의, 기기 따뜻함 (6초)'], closeTo(.17, .02));
      expect(got['경고 중, 기기 따뜻함 (3초)'], closeTo(.33, .02));
    });

    testWidgets('얼굴이 안 보이면(아이가 없음) 안전과 같이 10초', (t) async {
      final (ratio, windows) = await minute(t, () => null, window: worst);
      expect(windows, 6);
      expect(ratio, closeTo(.10, .01));
    });
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

    testWidgets('홈에서도 켜지고, 홈 → 놀이 → 홈은 껐다 켜지 않고, 멈춤 화면에서는 꺼진다', (t) async {
      final (s, sensor) = await app(t);
      expect(s.eyeGuardOn, isTrue, reason: '기본 켜짐');
      expect(sensor.on, isTrue, reason: '홈도 아이 화면');
      expect(sensor.starts, 1);
      await openGame(t);
      expect(sensor.on, isTrue, reason: '놀이 화면');
      expect(sensor.starts, 1, reason: '홈 → 놀이에 껐다 켜지 않는다');
      expect(sensor.stops, 0);
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
      await t.pump(const Duration(milliseconds: 1500));
      expect(sensor.on, isTrue, reason: '홈으로 돌아와도 그대로');
      expect(sensor.starts, 2, reason: '놀이 → 홈에 껐다 켜지 않는다');
      expect(sensor.stops, 1, reason: '멈춤 화면 때 한 번만');
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
      // 1.5초마다 보므로 10초를 넘긴 첫 창 (10.5초)
      expect(now.difference(seen), const Duration(milliseconds: 10500));
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
      for (var i = 0; i < 6; i++) {
        step(null); // 1.5초씩 9초
      }
      step(at(20));
      for (var i = 0; i < 6; i++) {
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
        EyeRules.alertGiveUp,
        reason: '1.5초 간격 50번째 창',
      );
      expect(sensor.on, isFalse);
      expect(g.resting, isTrue);
      // 75초 동안 1.5초 간격
      expect(checks, 50);
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
