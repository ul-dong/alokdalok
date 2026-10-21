import 'dart:async';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/eye_guard.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSensor implements EyeSensor {
  final ctrl = StreamController<FaceReading?>.broadcast();
  @override
  bool get supported => true;
  @override
  Stream<FaceReading?> start() => ctrl.stream;
  @override
  Future<void> stop() async {}

  /// 테스트에서는 size 값을 그대로 "1/거리" 로 쓴다: size = 1/cm
  @override
  double defaultDistanceCm(double size) => 1 / size;
}

FaceReading at(double cm, {double yaw = 0, double pitch = 0, double roll = 0}) =>
    FaceReading(size: 1 / cm, yaw: yaw, pitch: pitch, roll: roll);

void main() {
  group('눈 지킴이 판단', () {
    late DateTime now;
    late EyeGuard g;
    setUp(() {
      now = DateTime(2026);
      g = EyeGuard(sensor: FakeSensor(), now: () => now);
    });
    void step(FaceReading? r, [int ms = 500]) {
      now = now.add(Duration(milliseconds: ms));
      g.feed(r);
    }

    test('30cm보다 가까운 게 2초 넘게 이어지면 경고, 34cm 넘게 물러나면 풀린다', () {
      step(at(25));
      step(at(25));
      expect(g.alert, EyeAlert.none, reason: '잠깐은 괜찮다');
      for (var i = 0; i < 4; i++) {
        step(at(25));
      }
      expect(g.alert, EyeAlert.tooClose);
      step(at(32));
      step(at(32));
      step(at(32));
      expect(g.alert, EyeAlert.tooClose, reason: '경계(30~34cm)에서는 그대로');
      step(at(40));
      step(at(40));
      step(at(40));
      expect(g.alert, EyeAlert.none);
    });

    test('고개를 많이 돌리거나 누워서 보면 3초 뒤 자세 경고', () {
      for (var i = 0; i < 5; i++) {
        step(at(40, yaw: 50));
      }
      expect(g.alert, EyeAlert.none);
      for (var i = 0; i < 3; i++) {
        step(at(40, yaw: 50));
      }
      expect(g.alert, EyeAlert.badAngle);
      for (var i = 0; i < 3; i++) {
        step(at(40));
      }
      expect(g.alert, EyeAlert.none);
      for (var i = 0; i < 8; i++) {
        step(at(40, roll: 80));
      }
      expect(g.alert, EyeAlert.badAngle, reason: '옆으로 누워서 보기');
    });

    test('살짝 내려다보는 정도(20도)는 괜찮고, 얼굴이 안 보이면 막지 않는다', () {
      for (var i = 0; i < 10; i++) {
        step(at(40, pitch: 20, yaw: 15));
      }
      expect(g.alert, EyeAlert.none);
      for (var i = 0; i < 10; i++) {
        step(null);
      }
      expect(g.alert, EyeAlert.none);
    });

    test('30cm 기준 맞추기: 그때 얼굴 크기가 30cm가 된다', () {
      g.feed(const FaceReading(size: .2, yaw: 0, pitch: 0, roll: 0));
      g.calibrateNow();
      expect(g.distanceOf(.2), closeTo(30, .001));
      expect(g.distanceOf(.1), closeTo(60, .001));
    });

    test('부모님 계속하기: 5분 동안 경고를 끈다', () {
      for (var i = 0; i < 6; i++) {
        step(at(20));
      }
      expect(g.alert, EyeAlert.tooClose);
      g.snooze();
      for (var i = 0; i < 6; i++) {
        step(at(20));
      }
      expect(g.alert, EyeAlert.none);
    });
  });

  testWidgets('경고가 뜨면 놀이를 덮고 말해 주며, 바르게 하면 사라진다', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var now = DateTime(2026);
    final sensor = FakeSensor();
    final audio = RecordingAudio();
    final s = GameState(
      storage: MemoryStorage(),
      audio: audio,
      eyeGuard: EyeGuard(sensor: sensor, now: () => now),
    );
    await s.load();
    await s.setNickname('별이');
    await t.pumpWidget(AlokdalokApp(state: s));
    await t.pump(const Duration(seconds: 1));
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(milliseconds: 500));
      s.eye.feed(at(20));
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('화면이 너무 가까워요!'), findsOneWidget);
    expect(audio.spoken.last, contains('화면이 너무 가까워요'));
    for (var i = 0; i < 4; i++) {
      now = now.add(const Duration(milliseconds: 500));
      s.eye.feed(at(45));
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('화면이 너무 가까워요!'), findsNothing);
    expect(audio.spoken.last, '잘했어요! 다시 놀아요.');
    await t.pumpWidget(const SizedBox());
  });
}
