import 'dart:async';
import 'dart:collection';
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

  /// 얼굴을 살펴보는 간격. [EyeGuard]가 상황에 맞춰 바꾼다
  /// (평소 1.5초, 기준 가까이 0.5초, 경고 중 1초 → 20초 뒤 1.5초).
  void setInterval(Duration interval);

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
/// - 경고는 끝이 있다 (발열 줄이기): 경고 중 얼굴이 10초 넘게 안 보이면(아이가 떠남) 또는
///   경고가 75초 넘게 이어지면 카메라를 끄고 "쉬어 가기" 화면으로 넘어간다. 화면을 한 번 누르면 돌아온다.
class EyeRules {
  EyeRules._();
  static const tooCloseCm = 30.0;
  static const clearCm = 34.0;
  static const maxYaw = 35.0;
  static const maxPitch = 30.0;
  static const maxRoll = 45.0;

  /// 경고가 풀리는 거리 = 경고 거리 + 이만큼 (경계에서 깜빡이지 않게)
  static const clearMarginCm = 4.0;

  /// 부모님이 맞추는 기준 거리 ("30cm 기준 맞추기")
  static const calibrationCm = 30.0;
  static const closeHold = Duration(seconds: 2);
  static const angleHold = Duration(seconds: 3);
  static const clearHold = Duration(milliseconds: 900);

  /// 평소(거리 넉넉, 자세 바름) 살펴보는 간격
  static const slowInterval = Duration(milliseconds: 1500);

  /// 기준에 가까워졌을 때(경고 전) 살펴보는 간격
  static const fastInterval = Duration(milliseconds: 500);

  /// 경고 중 살펴보는 간격
  static const alertInterval = Duration(seconds: 1);

  /// 경고가 이만큼 이어지면 간격을 [slowInterval](1.5초)로 늦춘다
  static const alertSlowAfter = Duration(seconds: 20);

  /// 경고 중 얼굴이 이만큼 안 보이면 아이가 떠난 것으로 보고 카메라를 끈다 → 쉬어 가기
  static const noFaceGiveUp = Duration(seconds: 10);

  /// 경고가 이만큼 이어지면 카메라를 끄고 쉬게 한다 → 쉬어 가기
  static const alertGiveUp = Duration(seconds: 75);

  /// 이 거리(경고 거리의 1.2배, 기본 36cm) 안으로 들어오면 촘촘히 본다
  static const nearRatio = 1.2;

  /// 고개 각도가 기준의 이만큼(80%)을 넘으면 촘촘히 본다
  static const nearAngleRatio = .8;

  /// 놀이 화면을 벗어나도 이만큼은 카메라를 그대로 둔다 (짧은 화면 전환마다 껐다 켜지 않게)
  static const offDelay = Duration(seconds: 1);

  /// 카메라 초당 프레임 (안드로이드 CameraX / iOS AVFoundation에 요청하는 값)
  static const androidFps = 10;
  static const iosFps = 5;
}

/// 카메라 프레임 중에서 [interval]마다 하나만 검사하도록 고르는 문.
/// 앱(ML Kit)에서 쓰고, 테스트에서는 1분 동안의 검사 횟수를 계산하는 데 쓴다.
class EyeCheckGate {
  EyeCheckGate([this.interval = EyeRules.slowInterval]);

  Duration interval;
  DateTime? _last;

  /// 이 프레임을 검사할지. 검사하기로 하면 시각을 기억한다.
  bool take(DateTime now) {
    final last = _last;
    if (last != null && now.difference(last) < interval) return false;
    _last = now;
    return true;
  }

  void reset() => _last = null;
}

/// 카메라 결과를 받아 "너무 가까움 / 자세가 비뚤어짐"을 판단한다.
///
/// 발열을 줄이려고 카메라는 꼭 필요할 때만 켠다 ([wanted]):
/// 눈 지킴이가 켜져 있고, 앱이 앞에 있고, 놀이 화면이 보이고(멈춤 화면 아님),
/// "오늘은 여기까지!"·눈 쉬기·쉬어 가기 덮개가 없을 때. 경고 덮개가 떠 있는 동안은 풀림을 봐야 하니 켜 두되,
/// 얼굴이 [EyeRules.noFaceGiveUp] 넘게 안 보이거나 경고가 [EyeRules.alertGiveUp] 넘게 이어지면
/// 카메라를 끄고 [resting](쉬어 가기)으로 넘어간다. 화면을 한 번 누르면([wake]) 다시 켠다.
/// 조건이 사라져도 [EyeRules.offDelay] 동안은 기다렸다가 끈다 (짧은 화면 전환).
class EyeGuard extends ChangeNotifier {
  EyeGuard({EyeSensor? sensor, DateTime Function()? now, EyeStats? stats})
    : _sensor = sensor ?? EyeSensor.create(),
      _now = now ?? DateTime.now,
      _stats = stats ?? EyeStats.instance;

  final EyeSensor _sensor;
  final DateTime Function() _now;
  final EyeStats _stats;
  StreamSubscription<FaceReading?>? _sub;

  bool get supported => _sensor.supported;
  bool _running = false;

  /// 지금 카메라가 켜져 있는지
  bool get running => _running;

  /// 30cm에서 잰 얼굴 크기 (부모님이 맞춘 값). 없으면 기본 계산을 쓴다.
  double? calibration;

  /// 이보다 가까우면 경고하는 거리 (cm). 부모님이 설정에서 조절한다.
  double tooCloseCm = EyeRules.tooCloseCm;

  /// 경고가 풀리는 거리 (cm)
  double get clearCm => tooCloseCm + EyeRules.clearMarginCm;

  EyeAlert _alert = EyeAlert.none;
  EyeAlert get alert => _alert;

  FaceReading? _last;
  FaceReading? get last => _last;

  /// 마지막으로 잰 거리 (cm, 얼굴이 안 보이면 null)
  double? get distanceCm => _last == null ? null : distanceOf(_last!.size);

  /// 시작 못 했을 때 이유 (카메라 거부 등)
  String? error;

  DateTime? _closeSince, _angleSince, _goodSince;

  /// 경고가 처음 뜬 시각, 마지막으로 얼굴을 본 시각
  DateTime? _alertSince, _faceSeenAt;

  Duration _interval = EyeRules.slowInterval;

  /// 지금 얼굴을 살펴보는 간격 (평소 1.5초, 기준 가까이 0.5초, 경고 중 1초 → 20초 뒤 1.5초)
  Duration get checkInterval => _interval;

  bool _resting = false;

  /// 경고가 끝나지 않아 카메라를 끄고 쉬는 중 ("쉬어 가기" 화면). 화면을 누르면 [wake].
  bool get resting => _resting;

  double distanceOf(double size) {
    final cal = calibration;
    if (cal != null && cal > 0) return EyeRules.calibrationCm * cal / size;
    return _sensor.defaultDistanceCm(size);
  }

  // ---------- 언제 카메라를 켤까 ----------

  bool _enabled = false;
  bool _foreground = true;
  bool _blocked = false;
  int _measuring = 0;

  /// 보이는 놀이 화면 → 멈춤 화면이 열려 있는지
  final Map<Object, bool> _plays = {};
  Timer? _offTimer;

  /// 설정의 눈 지킴이 켜짐/꺼짐
  bool get enabled => _enabled;
  set enabled(bool on) {
    if (_enabled == on) return;
    _enabled = on;
    error = null;
    _sync(now: !on);
    notifyListeners();
  }

  /// 놀이 화면이 보이고 멈춤 화면이 열려 있지 않은지
  bool get playing => _plays.values.any((paused) => !paused);

  /// 지금 카메라가 켜져 있어야 하는지
  bool get wanted =>
      _enabled &&
      supported &&
      _foreground &&
      error == null &&
      !_blocked &&
      !_resting &&
      (_measuring > 0 || _alert != EyeAlert.none || playing);

  /// 놀이 화면([owner])이 보인다. [paused]면 멈춤 화면이 열려 있다.
  void showPlay(Object owner, {bool paused = false}) {
    if (_plays[owner] == paused) return;
    _plays[owner] = paused;
    _sync();
  }

  /// 놀이 화면([owner])이 사라졌다
  void hidePlay(Object owner) {
    if (_plays.remove(owner) == null) return;
    _sync();
  }

  /// 앱이 앞에 있는지. 뒤로 가면(paused·hidden) 기다리지 않고 바로 끈다.
  void setForeground(bool on, {bool immediate = false}) {
    if (_foreground == on) {
      if (!on && immediate && _running) unawaited(stop());
      return;
    }
    _foreground = on;
    if (on) error = null; // 그 사이에 카메라를 허용했을 수 있다
    _sync(now: !on && immediate);
  }

  /// "오늘은 여기까지!"·눈 쉬기 덮개가 떠 있는지
  set blocked(bool on) {
    if (_blocked == on) return;
    _blocked = on;
    _sync();
  }

  bool get blocked => _blocked;

  bool _syncQueued = false, _syncNow = false;

  /// 켜고 끌지 정한다. 화면을 그리는 도중(didChangeDependencies·dispose)에 불려도 되게
  /// 바로 하지 않고 지금 일이 끝난 뒤(microtask) 한 번에 처리한다.
  void _sync({bool now = false}) {
    _syncNow |= now;
    if (_syncQueued) return;
    _syncQueued = true;
    scheduleMicrotask(() {
      final immediate = _syncNow;
      _syncQueued = _syncNow = false;
      _apply(now: immediate);
    });
  }

  void _apply({required bool now}) {
    if (wanted) {
      _offTimer?.cancel();
      _offTimer = null;
      if (!_running) unawaited(start());
    } else if (_running) {
      if (now) {
        unawaited(stop());
      } else {
        _offTimer ??= Timer(EyeRules.offDelay, () {
          _offTimer = null;
          if (!wanted && _running) unawaited(stop());
        });
      }
    }
  }

  // ---------- 카메라 켜고 끄기 ----------

  /// 켜고 끌 때마다 늘어난다. 기다리는 사이에 다른 명령이 오면 앞의 것은 그만둔다.
  int _gen = 0;
  Future<void>? _stopping;

  Future<void> start() async {
    if (_running) return;
    final gen = ++_gen;
    error = null;
    _running = true;
    _stats.cameraOn(true);
    _setInterval(EyeRules.slowInterval);
    notifyListeners();
    // 앞서 끄던 카메라가 다 꺼진 뒤에 켠다
    final pending = _stopping;
    if (pending != null) await pending;
    if (gen != _gen) return;
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
      _stats.cameraOn(false);
      notifyListeners();
    }
  }

  /// 경고가 끝나지 않는다: 경고를 풀고 카메라를 끈 뒤 "쉬어 가기"로 넘어간다
  void _rest() {
    _resting = true;
    _alert = EyeAlert.none;
    unawaited(stop()); // 카메라를 바로 끄고 알린다
  }

  /// "쉬어 가기" 화면을 눌렀다: 다시 놀고, 놀이 화면이면 카메라를 다시 켠다
  void wake() {
    if (!_resting) return;
    _resting = false;
    _sync();
    notifyListeners();
  }

  /// 경고 중 검사 간격: 1초, 경고가 20초 넘게 이어지면 1.5초
  Duration _alertCheck(DateTime now) {
    final since = _alertSince;
    return since != null && now.difference(since) >= EyeRules.alertSlowAfter
        ? EyeRules.slowInterval
        : EyeRules.alertInterval;
  }

  Future<void> stop() async {
    _gen++;
    _offTimer?.cancel();
    _offTimer = null;
    final sub = _sub;
    _sub = null;
    final wasRunning = _running;
    _running = false;
    if (wasRunning) _stats.cameraOn(false);
    _last = null;
    _closeSince = _angleSince = _goodSince = null;
    _alertSince = _faceSeenAt = null;
    _alert = EyeAlert.none;
    notifyListeners();
    if (!wasRunning && sub == null) return;
    final before = _stopping;
    final done = _stopping = () async {
      // 구독은 바로 끊는다 (취소 완료를 기다릴 필요는 없다)
      unawaited(sub?.cancel());
      if (before != null) await before;
      await _sensor.stop();
    }();
    await done;
    if (identical(_stopping, done)) _stopping = null;
  }

  void _setInterval(Duration d) {
    if (d == _interval) return;
    _interval = d;
    _sensor.setInterval(d);
  }

  /// 지금 얼굴 크기를 "30cm" 기준으로 저장 (부모님이 30cm 떨어진 곳에서 누른다)
  double? calibrateNow() {
    final r = _last;
    if (r == null) return null;
    calibration = r.size;
    notifyListeners();
    return calibration;
  }

  Completer<FaceReading>? _nextFace;

  /// 설정 화면에서 "30cm 기준 맞추기": 카메라를 잠깐 켜서 얼굴을 한 번 보고 기준으로 저장한다.
  /// [timeout] 안에 얼굴이 안 보이면 null.
  Future<double?> measureAndCalibrate({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_running && _last != null) return calibrateNow();
    final wait = _nextFace ??= Completer<FaceReading>();
    _measuring++;
    _sync();
    try {
      await wait.future.timeout(timeout);
      return calibrateNow();
    } on TimeoutException {
      return null;
    } finally {
      if (identical(_nextFace, wait)) _nextFace = null;
      _measuring--;
      _sync();
    }
  }

  /// 부모님이 "계속하기"를 누르면 경고를 잠깐 끈다
  DateTime? _snoozeUntil;
  void snooze([Duration d = const Duration(minutes: 5)]) {
    _snoozeUntil = _now().add(d);
    _alert = EyeAlert.none;
    _closeSince = _angleSince = null;
    _alertSince = _faceSeenAt = null;
    _setInterval(EyeRules.slowInterval);
    _sync();
    notifyListeners();
  }

  @visibleForTesting
  void feed(FaceReading? r) {
    final now = _now();
    _last = r;
    _stats.check();
    if (r != null) {
      final w = _nextFace;
      if (w != null && !w.isCompleted) w.complete(r);
    }
    if (_snoozeUntil != null && now.isBefore(_snoozeUntil!)) {
      _setInterval(EyeRules.slowInterval);
      notifyListeners();
      return;
    }
    if (r == null) {
      // 얼굴이 안 보이면 판단하지 않는다 (경고 중이면 잠깐은 그대로 둔다)
      _closeSince = _angleSince = null;
      if (_alert != EyeAlert.none) {
        // 마지막으로 얼굴을 본 때부터 잰다
        final seen = _faceSeenAt ??= now;
        if (now.difference(seen) >= EyeRules.noFaceGiveUp ||
            now.difference(_alertSince ?? now) >= EyeRules.alertGiveUp) {
          _rest(); // 아이가 떠났다 (또는 경고가 너무 길다)
          return;
        }
      }
      _setInterval(
        _alert == EyeAlert.none ? EyeRules.slowInterval : _alertCheck(now),
      );
      notifyListeners();
      return;
    }
    _faceSeenAt = now;
    final d = distanceOf(r.size);
    final close = d < tooCloseCm;
    final farEnough = d > clearCm;
    final tilted =
        r.yaw.abs() > EyeRules.maxYaw ||
        r.pitch.abs() > EyeRules.maxPitch ||
        r.roll.abs() > EyeRules.maxRoll;

    // 경고까지 걸리는 시간(2초·3초)은 처음 본 시각부터 실제 시각으로 잰다 (검사 간격과 상관없다)
    _closeSince = close ? (_closeSince ?? now) : null;
    _angleSince = tilted ? (_angleSince ?? now) : null;

    final closeLong =
        _closeSince != null &&
        now.difference(_closeSince!) >= EyeRules.closeHold;
    final tiltLong =
        _angleSince != null &&
        now.difference(_angleSince!) >= EyeRules.angleHold;

    final was = _alert;
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
    if (next == EyeAlert.none) {
      _alertSince = null;
    } else {
      final since = _alertSince ??= now;
      if (now.difference(since) >= EyeRules.alertGiveUp) {
        _rest(); // 경고가 너무 길다: 카메라를 끄고 쉬게 한다
        return;
      }
    }
    _setInterval(
      next != EyeAlert.none
          ? _alertCheck(now)
          : isNear(r)
          ? EyeRules.fastInterval
          : EyeRules.slowInterval,
    );
    if (next != was) _sync();
    notifyListeners();
  }

  /// 기준에 가까운지 (36cm 이하, 또는 고개 각도가 기준의 80% 이상)
  bool isNear(FaceReading r) {
    const k = EyeRules.nearAngleRatio;
    return distanceOf(r.size) <= tooCloseCm * EyeRules.nearRatio ||
        r.yaw.abs() >= EyeRules.maxYaw * k ||
        r.pitch.abs() >= EyeRules.maxPitch * k ||
        r.roll.abs() >= EyeRules.maxRoll * k;
  }

  @override
  void dispose() {
    _offTimer?.cancel();
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

/// 눈 지킴이 실측 진단 (설정 → '부모님께'를 길게 누르면 보인다).
///
/// 최근 1분 동안 카메라에서 실제로 받은 프레임 수, 얼굴 검사 횟수, 카메라가 켜져 있던 시간을 센다.
/// `CameraController(fps: 10)` 요청이 기기에서 실제로 먹히는지(30fps로 들어오지 않는지) 확인하는 용도.
/// 숫자만 기기 안에 잠깐 들고 있고 저장하거나 보내지 않는다.
class EyeStats {
  EyeStats({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _since = _now();
  }

  /// 앱 전체가 같이 쓰는 기록 (앱 카메라 센서와 [EyeGuard]가 채운다)
  static final EyeStats instance = EyeStats();

  static const window = Duration(minutes: 1);

  final DateTime Function() _now;
  late DateTime _since;
  final _frames = ListQueue<DateTime>();
  final _checks = ListQueue<DateTime>();

  /// 카메라가 켜져 있던 구간 (끝이 null이면 지금도 켜져 있다)
  final _spans = ListQueue<(DateTime, DateTime?)>();

  bool get cameraIsOn => _spans.isNotEmpty && _spans.last.$2 == null;

  void cameraOn(bool on) {
    final now = _now();
    if (on == cameraIsOn) return;
    if (on) {
      _spans.add((now, null));
    } else {
      _spans.add((_spans.removeLast().$1, now));
    }
    _prune(now);
  }

  /// 카메라 프레임 하나를 받았다 (앱 카메라 센서)
  void frame() {
    final now = _now();
    _frames.add(now);
    _prune(now);
  }

  /// 얼굴을 한 번 검사했다
  void check() {
    final now = _now();
    _checks.add(now);
    _prune(now);
  }

  void _prune(DateTime now) {
    final from = now.subtract(window);
    while (_frames.isNotEmpty && _frames.first.isBefore(from)) {
      _frames.removeFirst();
    }
    while (_checks.isNotEmpty && _checks.first.isBefore(from)) {
      _checks.removeFirst();
    }
    while (_spans.isNotEmpty) {
      final end = _spans.first.$2;
      if (end == null || !end.isBefore(from)) break;
      _spans.removeFirst();
    }
  }

  /// 최근 1분 요약 (앱을 켠 지 1분이 안 됐으면 켠 뒤부터)
  EyeStatsSummary summary() {
    final now = _now();
    _prune(now);
    var from = now.subtract(window);
    if (_since.isAfter(from)) from = _since;
    final span = now.difference(from);
    var on = Duration.zero;
    for (final (a, b) in _spans) {
      final s = a.isBefore(from) ? from : a;
      final e = b ?? now;
      if (e.isAfter(s)) on += e.difference(s);
    }
    return EyeStatsSummary(
      window: span,
      cameraOn: on,
      frames: _frames.length,
      checks: _checks.length,
    );
  }

  @visibleForTesting
  void reset() {
    _since = _now();
    _frames.clear();
    _checks.clear();
    _spans.clear();
  }
}

/// [EyeStats.summary] 결과
class EyeStatsSummary {
  const EyeStatsSummary({
    required this.window,
    required this.cameraOn,
    required this.frames,
    required this.checks,
  });

  /// 잰 시간 (보통 1분)
  final Duration window;

  /// 그동안 카메라가 켜져 있던 시간
  final Duration cameraOn;
  final int frames;
  final int checks;

  /// 카메라가 켜져 있는 동안 실제로 받은 초당 프레임 수 (켜진 적 없으면 null)
  double? get fps => cameraOn.inMilliseconds < 500
      ? null
      : frames * 1000 / cameraOn.inMilliseconds;

  /// 카메라가 켜져 있던 시간 비율 (0~1)
  double get onRatio => window.inMilliseconds <= 0
      ? 0
      : (cameraOn.inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
}
