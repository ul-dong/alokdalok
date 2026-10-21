import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'eye_sensor_io.dart' if (dart.library.js_interop) 'eye_sensor_web.dart';

/// 카메라가 한 번 본 얼굴 정보.
///
/// [size]는 얼굴 크기를 화면 너비에 대한 비율로 나타낸 값이다.
/// 웹은 눈동자(홍채) 지름, 앱은 얼굴 너비를 쓴다 (둘 다 가까울수록 커진다).
class FaceReading {
  const FaceReading({
    required this.size,
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  final double size;

  /// 고개 각도 (도). yaw = 좌우로 돌림, pitch = 위아래로 숙임, roll = 옆으로 기울임
  final double yaw;
  final double pitch;
  final double roll;
}

/// 플랫폼별 카메라 + 얼굴 인식. 사진은 저장하거나 보내지 않고 기기 안에서 숫자만 뽑는다.
abstract class EyeSensor {
  /// 얼굴이 보이면 [FaceReading], 안 보이면 null을 계속 보낸다.
  Stream<FaceReading?> start();
  Future<void> stop();

  /// 얼굴 크기 비율 → 대략적인 거리(cm). 보정 전 기본값 계산에 쓴다.
  double defaultDistanceCm(double size);

  /// 이 기기에서 쓸 수 있는지 (카메라·얼굴 인식 지원)
  bool get supported;

  static EyeSensor create() => createEyeSensor();
}

enum EyeAlert { none, tooClose, badAngle }

/// 눈 지킴이 기준값.
///
/// - 거리: 30cm보다 가까우면 경고. Apple '화면 거리' 기능이 12인치(약 30cm)를 기준으로 쓰고,
///   소아 안과 안내도 태블릿·책은 30~40cm(팔꿈치를 굽힌 거리) 떨어져 보라고 권한다.
///   경고가 뜬 뒤에는 34cm 넘게 물러나야 풀린다 (경계에서 깜빡이지 않게).
/// - 각도: 고개를 좌우로 35도 넘게 돌리거나, 위아래로 30도 넘게 숙이거나/젖히거나,
///   옆으로 45도 넘게 기울이면(누워서 보기) 경고. 화면을 조금 내려다보는(15~20도) 정도는 괜찮다.
/// - 잠깐 고개를 돌리는 건 괜찮게: 거리는 2초, 각도는 3초 넘게 이어질 때만 경고.
///   얼굴이 안 보일 때는 알 수 없으니 막지 않는다.
class EyeRules {
  EyeRules._();
  static const tooCloseCm = 30.0;
  static const clearCm = 34.0;
  static const maxYaw = 35.0;
  static const maxPitch = 30.0;
  static const maxRoll = 45.0;
  static const closeHold = Duration(seconds: 2);
  static const angleHold = Duration(seconds: 3);
  static const clearHold = Duration(milliseconds: 900);
}

/// 카메라 결과를 받아 "너무 가까움 / 자세가 비뚤어짐"을 판단한다.
class EyeGuard extends ChangeNotifier {
  EyeGuard({EyeSensor? sensor, DateTime Function()? now})
    : _sensor = sensor ?? EyeSensor.create(),
      _now = now ?? DateTime.now;

  final EyeSensor _sensor;
  final DateTime Function() _now;
  StreamSubscription<FaceReading?>? _sub;

  bool get supported => _sensor.supported;
  bool _running = false;
  bool get running => _running;

  /// 30cm에서 잰 얼굴 크기 (부모님이 맞춘 값). 없으면 기본 계산을 쓴다.
  double? calibration;

  EyeAlert _alert = EyeAlert.none;
  EyeAlert get alert => _alert;

  FaceReading? _last;
  FaceReading? get last => _last;

  /// 마지막으로 잰 거리 (cm, 얼굴이 안 보이면 null)
  double? get distanceCm => _last == null ? null : distanceOf(_last!.size);

  /// 시작 못 했을 때 이유 (카메라 거부 등)
  String? error;

  DateTime? _closeSince, _angleSince, _goodSince;

  double distanceOf(double size) {
    final cal = calibration;
    if (cal != null && cal > 0) return EyeRules.tooCloseCm * cal / size;
    return _sensor.defaultDistanceCm(size);
  }

  Future<void> start() async {
    if (_running) return;
    error = null;
    _running = true;
    notifyListeners();
    try {
      _sub = _sensor.start().listen(
        feed,
        onError: (Object e) {
          error = '$e';
          stop();
        },
      );
    } catch (e) {
      error = '$e';
      _running = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _sensor.stop();
    _running = false;
    _last = null;
    _closeSince = _angleSince = _goodSince = null;
    _alert = EyeAlert.none;
    notifyListeners();
  }

  /// 지금 얼굴 크기를 "30cm" 기준으로 저장 (부모님이 30cm 떨어진 곳에서 누른다)
  double? calibrateNow() {
    final r = _last;
    if (r == null) return null;
    calibration = r.size;
    notifyListeners();
    return calibration;
  }

  /// 부모님이 "계속하기"를 누르면 경고를 잠깐 끈다
  DateTime? _snoozeUntil;
  void snooze([Duration d = const Duration(minutes: 5)]) {
    _snoozeUntil = _now().add(d);
    _alert = EyeAlert.none;
    _closeSince = _angleSince = null;
    notifyListeners();
  }

  @visibleForTesting
  void feed(FaceReading? r) {
    final now = _now();
    _last = r;
    if (_snoozeUntil != null && now.isBefore(_snoozeUntil!)) {
      notifyListeners();
      return;
    }
    if (r == null) {
      // 얼굴이 안 보이면 판단하지 않는다 (경고 중이면 그대로 둔다)
      _closeSince = _angleSince = null;
      notifyListeners();
      return;
    }
    final d = distanceOf(r.size);
    final close = d < EyeRules.tooCloseCm;
    final farEnough = d > EyeRules.clearCm;
    final tilted =
        r.yaw.abs() > EyeRules.maxYaw ||
        r.pitch.abs() > EyeRules.maxPitch ||
        r.roll.abs() > EyeRules.maxRoll;

    _closeSince = close ? (_closeSince ?? now) : null;
    _angleSince = tilted ? (_angleSince ?? now) : null;

    final closeLong =
        _closeSince != null &&
        now.difference(_closeSince!) >= EyeRules.closeHold;
    final tiltLong =
        _angleSince != null &&
        now.difference(_angleSince!) >= EyeRules.angleHold;

    var next = _alert;
    if (closeLong) {
      next = EyeAlert.tooClose; // 가까운 게 가장 먼저
    } else if (_alert == EyeAlert.none) {
      if (tiltLong) next = EyeAlert.badAngle;
    } else {
      // 경고 중: 원인이 사라진 채로 잠깐 지나면 푼다
      final fixed = _alert == EyeAlert.tooClose ? farEnough : !tilted;
      if (fixed) {
        _goodSince ??= now;
        if (now.difference(_goodSince!) >= EyeRules.clearHold) {
          next = tiltLong ? EyeAlert.badAngle : EyeAlert.none;
          _goodSince = null;
        }
      } else {
        _goodSince = null;
      }
    }
    _alert = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sensor.stop();
    super.dispose();
  }
}

/// 얼굴 크기 비율 → 거리(cm): 핀홀 카메라 모델
/// 거리 = 실제크기 / (2 · 비율 · tan(가로화각/2))
double pinholeDistanceCm(double ratio, double realCm, double hfovDeg) {
  if (ratio <= 0) return double.infinity;
  return realCm / (2 * ratio * tan(hfovDeg * pi / 360));
}
