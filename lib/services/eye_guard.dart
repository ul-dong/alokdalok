import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'device_heat.dart';
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
///
/// 발열을 줄이려고 카메라를 계속 켜 두지 않는다: [EyeGuard]가 정한 때마다 [sampleOnce]로
/// 짧게 열어서(최대 [EyeRules.windowBudget]) 2~3장만 보고 다시 닫는다.
abstract class EyeSensor {
  /// 카메라 창을 한 번 연다: 이미지 받기 시작 → [budget] 안에서 유효 프레임 2~3장 →
  /// 그중 얼굴이 가장 큰 판독 하나 → 이미지 받기 멈춤 → 돌려준다.
  /// 얼굴을 못 보면 null. 카메라를 쓸 수 없으면 오류를 던진다.
  Future<FaceReading?> sampleOnce({Duration budget = EyeRules.windowBudget});

  /// 카메라를 완전히 놓는다 (진행 중인 창도 닫는다: 그 [sampleOnce]는 null).
  Future<void> stop();

  /// 창 사이에 카메라(CameraController·video 스트림)를 살려 둘지.
  /// true면 다음 창이 빨리 열리고 안드로이드 12+ 카메라 표시등이 덜 깜빡인다.
  /// false면 창마다 카메라를 새로 열고 닫는다(dispose). 실기기에서 둘을 재 보고 고른다.
  bool keepCamera = EyeRules.keepCameraDefault;

  /// 진단 칸에 보이는 방식 이름
  String get mode;

  /// 얼굴 크기 비율 → 대략적인 거리(cm). 보정 전 기본값 계산에 쓴다.
  double defaultDistanceCm(double size);

  /// 이 기기에서 쓸 수 있는지 (카메라·얼굴 인식 지원)
  bool get supported;

  /// 얼굴 인식 한 번에 걸린 시간 (진단 칸, 웹만. 앱은 [EyeStats]의 창 열기 시간을 본다)
  EyeDetectStats? get detectStats => null;

  static EyeSensor create() => createEyeSensor();
}

/// 얼굴 인식 시간 (진단 칸). 웹은 Web Worker에서 인식하므로 [mainMs]만 화면(터치)을 막는다.
class EyeDetectStats {
  const EyeDetectStats({
    required this.where,
    required this.lastMs,
    required this.maxMs,
    required this.mainMs,
    required this.initMs,
    required this.count,
  });

  /// '일꾼'(Web Worker) 또는 '메인'
  final String where;

  /// 마지막 인식 시간, 가장 오래 걸린 인식 시간 (ms, 아직 없으면 음수)
  final double lastMs, maxMs;

  /// 마지막 인식에서 메인 스레드를 막은 시간 (영상 한 장 뜨기, ms)
  final double mainMs;

  /// 인식기 준비 시간 (ms)
  final double initMs;
  final int count;
}

/// 카메라를 아예 쓸 수 없을 때 [EyeSensor.sampleOnce]가 던진다 (권한 거부, 앞카메라 없음 등).
/// 이때만 눈 지킴이를 멈추고 이유를 보여 준다. 그 밖의 오류(카메라가 잠깐 바쁨, 스트림 실패)는
/// 다음 창에서 다시 해 본다 ([EyeGuard]가 카메라를 새로 연다).
class EyeSensorDenied implements Exception {
  const EyeSensorDenied(this.message);
  final String message;

  @override
  String toString() => message;
}

enum EyeAlert { none, tooClose, badAngle }

/// 카메라 창 하나의 결과 (진단 칸)
enum EyeWindowOutcome {
  /// 얼굴을 봤다
  face,

  /// 얼굴이 안 보였다
  noFace,

  /// 창을 못 열었다 (다음 창에서 다시)
  failed,
}

/// 카메라 창 하나의 결과와 시각 (진단 칸에서 멈췄는지 바로 보이게)
class EyeWindowResult {
  const EyeWindowResult({
    required this.at,
    required this.outcome,
    this.cm,
    this.message,
  });
  final DateTime at;
  final EyeWindowOutcome outcome;

  /// 얼굴을 봤으면 거리 (cm)
  final double? cm;

  /// 실패 이유
  final String? message;
}

/// 지금 보이는 화면의 종류 ([EyeGuard.showScreen])
enum EyeScreen {
  /// 아이가 보는 화면 (홈·놀이터·단계 고르기·내 캐릭터·상점·꾸미기·첫 실행·놀이·결과): 카메라를 켠다
  child,

  /// 멈춤 화면: 끈다
  paused,

  /// 부모님 화면 (설정, 부모 확인): 끈다
  parent,
}

/// 다음 창까지 얼마나 기다릴지 정하는 상태
enum EyeZone {
  /// 거리 넉넉(경고 거리의 1.4배보다 멂)하고 자세 바름, 또는 얼굴이 안 보임: 10초
  safe,

  /// 기준 가까이(경고 거리의 1.2배 이하, 또는 고개 각도가 기준의 80% 넘음): 3초
  caution,

  /// 경고 중: 1.5초
  alert,
}

/// 눈 지킴이 기준값.
///
/// - 거리: 30cm보다 가까우면 경고. Apple '화면 거리' 기능이 12인치(약 30cm)를 기준으로 쓰고,
///   소아 안과 안내도 태블릿·책은 30~40cm(팔꿈치를 굽힌 거리) 떨어져 보라고 권한다.
///   경고가 뜬 뒤에는 34cm 넘게 물러나야 풀린다 (경계에서 깜빡이지 않게).
/// - 각도: 고개를 좌우로 35도 넘게 돌리거나, 위아래로 30도 넘게 숙이거나/젖히거나,
///   옆으로 45도 넘게 기울이면(누워서 보기) 경고. 화면을 조금 내려다보는(15~20도) 정도는 괜찮다.
/// - 잠깐 고개를 돌리는 건 괜찮게: 처음 본 뒤 다음 창(3초 뒤)에서도 그대로일 때만 경고
///   (거리 2초, 각도 2.5초 이상 이어짐). 얼굴이 안 보일 때는 알 수 없으니 막지 않는다.
/// - 경고는 끝이 있다 (발열 줄이기): 경고 중 얼굴이 10초 넘게 안 보이면(아이가 떠남) 또는
///   경고가 75초 넘게 이어지면 카메라를 끄고 "쉬어 가기" 화면으로 넘어간다. 화면을 한 번 누르면 돌아온다.
/// - 카메라는 짧게 열어서 보고 끈다 (발열 2단계): 창 주기 넉넉 10초, 기준 가까이 3초, 경고 중 1.5초.
///   기기가 따뜻하거나 절전·배터리 20% 이하면 두 배, 뜨거우면 이번 실행 동안 끈다 ([DeviceHeat]).
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

  /// 가까움이 이만큼 이어져야 경고 (처음 본 창 → 3초 뒤 다음 창에서 확인)
  static const closeHold = Duration(seconds: 2);

  /// 자세가 이만큼 이어져야 경고 (3초 창 주기에 맞춰 두 번째 창에서 확인되게)
  static const angleHold = Duration(milliseconds: 2500);
  static const clearHold = Duration(milliseconds: 900);

  /// 창 주기: 넉넉함(멀고 자세 바름, 또는 얼굴 안 보임)
  static const safeInterval = Duration(seconds: 10);

  /// 창 주기: 기준 가까이
  static const cautionInterval = Duration(seconds: 3);

  /// 창 주기: 경고 중
  static const alertInterval = Duration(milliseconds: 1500);

  /// 이 거리(경고 거리의 1.4배, 기본 42cm)보다 멀고 자세가 바르면 넉넉함
  static const safeRatio = 1.4;

  /// 이 거리(경고 거리의 1.2배, 기본 36cm) 안으로 들어오면 기준 가까이
  static const nearRatio = 1.2;

  /// 고개 각도가 기준의 이만큼(80%)을 넘으면 기준 가까이
  static const nearAngleRatio = .8;

  /// 창 하나를 열어 둘 수 있는 최대 시간
  static const windowBudget = Duration(seconds: 1);

  /// 창 하나에서 볼 프레임 수 (얼굴을 2장에서 봤으면 거기서 끝낸다)
  static const windowFrames = 3;
  static const windowFramesWithFace = 2;

  /// 웹: 창 안에서 프레임을 보는 간격
  static const webFrameGap = Duration(milliseconds: 200);

  /// 창 사이에 카메라를 살려 둘지 (false = 창마다 dispose). 진단 칸에서 바꿔 볼 수 있다.
  static const keepCameraDefault = true;

  /// 기기가 따뜻하거나 절전·배터리 부족일 때 창 주기를 몇 배로
  static const heatBackoff = 2;

  /// 경고 중 얼굴이 이만큼 안 보이면 아이가 떠난 것으로 보고 카메라를 끈다 → 쉬어 가기
  static const noFaceGiveUp = Duration(seconds: 10);

  /// 경고가 이만큼 이어지면 카메라를 끄고 쉬게 한다 → 쉬어 가기
  static const alertGiveUp = Duration(seconds: 75);

  /// 아이 화면을 벗어나도 이만큼은 카메라를 그대로 둔다 (짧은 화면 전환마다 껐다 켜지 않게)
  static const offDelay = Duration(seconds: 1);

  /// 화면을 누른 직후 이만큼은 카메라 창을 열지 않는다 (창 하나에 한 번만 미룬다).
  /// 창을 열고 얼굴을 보는 일이 누른 화면이 바뀌는 순간과 겹치면 화면이 늦게 바뀐다 (특히 웹).
  static const touchQuiet = Duration(seconds: 1);

  /// 창을 못 열면(카메라가 잠깐 바쁨 등) 이만큼 뒤 다시 연다. 처음 [quickRetries]번은 3초,
  /// 그 뒤로는 넉넉 주기(10초, 백오프 적용). 실패해도 눈 지킴이를 멈추지 않는다.
  static const quickRetries = 2;

  /// 진단 칸에 남기는 최근 창 수
  static const recentWindows = 5;

  /// 카메라 초당 프레임 (안드로이드 CameraX / iOS AVFoundation에 요청하는 값)
  static const androidFps = 10;
  static const iosFps = 5;

  /// 창 주기 (발열·절전 백오프 전)
  static Duration intervalOf(EyeZone z) => switch (z) {
    EyeZone.safe => safeInterval,
    EyeZone.caution => cautionInterval,
    EyeZone.alert => alertInterval,
  };
}

/// 카메라 창 한 번: 프레임을 받기 시작해서 [budget] 안에 [frames]장(얼굴을 봤으면
/// [framesWithFace]장)을 살펴보고, 얼굴이 가장 큰 판독을 돌려준 뒤 받기를 멈춘다.
/// 앱(ML Kit)과 웹(MediaPipe)이 같이 쓴다. 프레임을 살펴보는 중에 온 프레임은 건너뛴다.
class EyeWindow<T> {
  EyeWindow({
    required this.open,
    required this.close,
    required this.analyze,
    this.budget = EyeRules.windowBudget,
    this.frames = EyeRules.windowFrames,
    this.framesWithFace = EyeRules.windowFramesWithFace,
  });

  /// 프레임 받기 시작 (받은 프레임은 onFrame으로)
  final Future<void> Function(void Function(T frame) onFrame) open;

  /// 프레임 받기 멈춤 (창이 어떻게 끝나든 한 번 부른다)
  final Future<void> Function() close;

  /// 프레임 하나 → 얼굴(없으면 null). 쓸 수 없는 프레임이면 오류를 던진다(세지 않음).
  final Future<FaceReading?> Function(T frame) analyze;
  final Duration budget;
  final int frames, framesWithFace;

  final _done = Completer<FaceReading?>();
  FaceReading? _best;
  bool _busy = false;
  int _valid = 0;

  /// 살펴본(유효한) 프레임 수
  int get valid => _valid;

  void _finish() {
    if (!_done.isCompleted) _done.complete(_best);
  }

  /// 창을 바로 닫는다 (카메라를 끌 때). 그때까지 본 것 중 가장 큰 얼굴을 돌려준다.
  void abort() => _finish();

  void _onFrame(T frame) {
    if (_busy || _done.isCompleted) return;
    _busy = true;
    analyze(frame)
        .then(
          (r) {
            if (_done.isCompleted) return;
            _valid++;
            final best = _best;
            if (r != null && (best == null || r.size > best.size)) _best = r;
            if (_valid >= frames ||
                (_best != null && _valid >= framesWithFace)) {
              _finish();
            }
          },
          onError: (Object _) {}, // 쓸 수 없는 프레임: 다음 것을 본다
        )
        .whenComplete(() => _busy = false);
  }

  Future<FaceReading?> run() async {
    final timer = Timer(budget, _finish);
    try {
      await open(_onFrame);
      return await _done.future;
    } finally {
      timer.cancel();
      _finish();
      try {
        await close();
      } catch (_) {}
    }
  }
}

/// 카메라 결과를 받아 "너무 가까움 / 자세가 비뚤어짐"을 판단한다.
///
/// 발열을 줄이려고 카메라는 꼭 필요할 때만 켠다 ([wanted]):
/// 눈 지킴이가 켜져 있고, 앱이 앞에 있고, 아이 화면이 보이고(설정·부모 확인·멈춤 화면 아님, [watching]),
/// "오늘은 여기까지!"·눈 쉬기·쉬어 가기 덮개가 없고, 기기가 뜨겁지 않을 때([heatOff]).
/// 경고 덮개가 떠 있는 동안은 풀림을 봐야 하니 켜 두되,
/// 얼굴이 [EyeRules.noFaceGiveUp] 넘게 안 보이거나 경고가 [EyeRules.alertGiveUp] 넘게 이어지면
/// 카메라를 끄고 [resting](쉬어 가기)으로 넘어간다. 화면을 한 번 누르면([wake]) 다시 켠다.
/// 조건이 사라져도 [EyeRules.offDelay] 동안은 기다렸다가 끈다 (짧은 화면 전환).
///
/// 켜져 있는([running]) 동안에도 카메라는 [checkInterval]마다 한 번 짧게 열 뿐이다 ([EyeSensor.sampleOnce]).
class EyeGuard extends ChangeNotifier {
  EyeGuard({
    EyeSensor? sensor,
    DateTime Function()? now,
    EyeStats? stats,
    DeviceHeat? heat,
  }) : _sensor = sensor ?? EyeSensor.create(),
       _now = now ?? DateTime.now,
       _stats = stats ?? EyeStats.instance,
       _heat = heat ?? DeviceHeat.instance {
    _heat.addListener(_onHeat);
    _onHeat();
  }

  final EyeSensor _sensor;
  final DateTime Function() _now;
  final EyeStats _stats;
  final DeviceHeat _heat;

  bool get supported => _sensor.supported;
  bool _running = false;

  /// 지금 눈 지킴이가 돌고 있는지 (카메라는 그 안에서 창마다 잠깐씩 켜진다)
  bool get running => _running;

  /// 지금 카메라 창이 열려 있는지
  bool get windowOpen => _windowOpen;
  bool _windowOpen = false;

  /// 기기 열·절전 상태 (진단 칸)
  DeviceHeat get heat => _heat;

  /// 창 사이에 카메라를 살려 둘지 (진단 칸에서 바꿔 본다)
  bool get keepCamera => _sensor.keepCamera;
  set keepCamera(bool on) {
    if (_sensor.keepCamera == on) return;
    _sensor.keepCamera = on;
    notifyListeners();
  }

  /// 진단 칸에 보이는 방식 이름
  String get cameraMode => _sensor.mode;

  /// 얼굴 인식 시간 (진단 칸, 웹)
  EyeDetectStats? get detectStats => _sensor.detectStats;

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

  EyeZone _zone = EyeZone.safe;

  /// 지금 창 주기를 정하는 상태
  EyeZone get zone => _zone;

  /// 다음 창까지의 주기 (창을 연 때부터 잰다): 넉넉 10초, 기준 가까이 3초, 경고 중 1.5초.
  /// 기기가 따뜻하거나 절전·배터리 부족이면 두 배. 30cm 기준 맞추는 중에는 바로바로.
  Duration get checkInterval {
    if (_measuring > 0) return EyeRules.alertInterval;
    return EyeRules.intervalOf(_zone) * _heat.backoff;
  }

  bool _resting = false;

  /// 경고가 끝나지 않아 카메라를 끄고 쉬는 중 ("쉬어 가기" 화면). 화면을 누르면 [wake].
  bool get resting => _resting;

  bool _heatOff = false;

  /// 기기가 뜨거워서(열 상태 SEVERE 이상) 이번 실행 동안 눈 지킴이를 껐다
  bool get heatOff => _heatOff;

  void _onHeat() {
    if (!_heatOff && _heat.tooHot) {
      _heatOff = true;
      _sync(now: true);
    }
    notifyListeners();
  }

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

  /// 지금 떠 있는 화면들과 그 종류 (아이 화면 / 멈춤 / 부모님 화면)
  final Map<Object, EyeScreen> _screens = {};
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

  /// 아이 화면이 보이고, 멈춤 화면·부모님 화면(설정, 부모 확인)이 떠 있지 않은지
  bool get watching =>
      _screens.values.contains(EyeScreen.child) &&
      _screens.values.every((k) => k == EyeScreen.child);

  /// 지금 카메라가 켜져 있어야 하는지
  bool get wanted =>
      _enabled &&
      supported &&
      _foreground &&
      error == null &&
      !_blocked &&
      !_resting &&
      !_heatOff &&
      (_measuring > 0 || _alert != EyeAlert.none || watching);

  /// 화면([owner])이 보인다. 아이 화면이면 켜고, 멈춤·부모님 화면이 하나라도 떠 있으면 끈다.
  /// 끌 때는 [EyeRules.offDelay]만큼 기다린다 (짧은 화면 전환마다 껐다 켜지 않게).
  void showScreen(Object owner, EyeScreen kind) {
    if (_screens[owner] == kind) return;
    _screens[owner] = kind;
    _sync();
  }

  /// 화면([owner])이 사라졌다
  void hideScreen(Object owner) {
    if (_screens.remove(owner) == null) return;
    _sync();
  }

  /// 놀이 화면([owner])이 보인다. [paused]면 멈춤 화면이 열려 있다.
  void showPlay(Object owner, {bool paused = false}) =>
      showScreen(owner, paused ? EyeScreen.paused : EyeScreen.child);

  /// 놀이 화면([owner])이 사라졌다
  void hidePlay(Object owner) => hideScreen(owner);

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

  // ---------- 카메라 창 열고 닫기 ----------

  /// 켜고 끌 때마다 늘어난다. 기다리는 사이에 다른 명령이 오면 앞의 것은 그만둔다.
  int _gen = 0;
  Future<void>? _stopping;

  /// 다음 창을 여는 타이머
  Timer? _windowTimer;
  DateTime? _windowAt;

  Future<void> start() async {
    if (_running) return;
    final gen = ++_gen;
    error = null;
    _running = true;
    _zone = EyeZone.safe;
    notifyListeners();
    // 앞서 끄던 카메라가 다 꺼진 뒤에 켠다
    final pending = _stopping;
    if (pending != null) await pending;
    if (gen != _gen) return;
    unawaited(_openWindow(gen)); // 첫 창은 바로 연다
  }

  DateTime? _touchedAt;

  /// 화면을 눌렀다 (앱 전체의 누름을 [EyeGuardOverlay]가 알려 준다)
  void touched() => _touchedAt = _now();

  /// 창 하나: 카메라를 잠깐 열어 얼굴을 보고 닫은 뒤, [checkInterval] 뒤 다음 창을 잡는다.
  /// 화면을 막 눌렀으면 [EyeRules.touchQuiet]이 지날 때까지 한 번만 미룬다 ([deferred]).
  Future<void> _openWindow(int gen, {bool deferred = false}) async {
    _windowTimer = null;
    _windowAt = null;
    if (gen != _gen || !_running) return;
    final touched = _touchedAt;
    if (!deferred && _measuring == 0 && touched != null) {
      final quietAt = touched.add(EyeRules.touchQuiet);
      final wait = quietAt.difference(_now());
      if (wait > Duration.zero) {
        _windowAt = quietAt;
        _windowTimer = Timer(wait, () => _openWindow(gen, deferred: true));
        return;
      }
    }
    final began = _now();
    _windowOpen = true;
    _stats.cameraOn(true);
    FaceReading? r;
    Object? err;
    try {
      r = await _sensor.sampleOnce(budget: EyeRules.windowBudget);
    } catch (e) {
      err = e;
    }
    if (gen != _gen) return; // 그 사이에 껐다 (stop이 기록을 닫았다)
    _windowOpen = false;
    _stats.cameraOn(false);
    _stats.windowClosed(_now().difference(began));
    if (err is EyeSensorDenied) {
      // 카메라를 아예 쓸 수 없다 (권한 거부 등): 멈추고 이유를 보여 준다
      error = err.message;
      _remember(EyeWindowOutcome.failed, message: err.message);
      unawaited(stop());
      return;
    }
    if (err != null) {
      // 카메라가 잠깐 바빴다 (막 끈 카메라를 OS가 아직 놓는 중, 스트림 실패 등):
      // 눈 지킴이를 멈추지 않고 잠시 뒤 다시 연다. 센서는 실패한 카메라를 놓아 두어 새로 연다.
      _failures++;
      _remember(EyeWindowOutcome.failed, message: '$err');
      notifyListeners();
      _schedule(gen, began, retry: true);
      return;
    }
    _failures = 0;
    _remember(
      r == null ? EyeWindowOutcome.noFace : EyeWindowOutcome.face,
      cm: r == null ? null : distanceOf(r.size),
    );
    feed(r);
    if (gen != _gen || !_running) return; // 쉬어 가기로 넘어갔다
    _schedule(gen, began);
  }

  /// 창을 연 때([from])부터 [checkInterval] 뒤에 다음 창을 잡는다.
  /// [retry]면 실패한 창의 다시 열기: 처음 몇 번은 3초, 그 뒤는 넉넉 주기.
  void _schedule(int gen, DateTime from, {bool retry = false}) {
    _windowTimer?.cancel();
    final every = !retry
        ? checkInterval
        : (_failures <= EyeRules.quickRetries
                  ? EyeRules.cautionInterval
                  : EyeRules.safeInterval) *
              _heat.backoff;
    final at = from.add(every);
    _windowAt = at;
    var wait = at.difference(_now());
    if (wait.isNegative) wait = Duration.zero;
    _windowTimer = Timer(wait, () => _openWindow(gen));
  }

  /// 기다리는 창을 지금 바로 연다 (30cm 기준 맞추기)
  void _openNow() {
    if (!_running || _windowTimer == null) return;
    _windowTimer?.cancel();
    _windowTimer = null;
    unawaited(_openWindow(_gen));
  }

  /// 다음 창 예정 시각 (테스트·진단용)
  DateTime? get nextWindowAt => _windowAt;

  /// 다음 창까지 남은 시간 (창이 열려 있거나 꺼져 있으면 null)
  Duration? get nextWindowIn {
    final at = _windowAt;
    if (at == null) return null;
    final d = at.difference(_now());
    return d.isNegative ? Duration.zero : d;
  }

  /// 이어서 실패한 창 수 (성공하면 0)
  int get failures => _failures;
  int _failures = 0;

  final _recent = ListQueue<EyeWindowResult>();

  /// 최근 창 결과 (오래된 것부터, 최대 [EyeRules.recentWindows]개). 꺼도 남는다.
  List<EyeWindowResult> get recentWindows => List.unmodifiable(_recent);

  /// 마지막 창 결과 (없으면 null)
  EyeWindowResult? get lastWindow => _recent.isEmpty ? null : _recent.last;

  void _remember(EyeWindowOutcome o, {double? cm, String? message}) {
    _recent.add(
      EyeWindowResult(at: _now(), outcome: o, cm: cm, message: message),
    );
    while (_recent.length > EyeRules.recentWindows) {
      _recent.removeFirst();
    }
  }

  /// 부모님 "계속하기"로 경고를 쉬는 남은 시간 (없으면 null)
  Duration? get snoozeLeft {
    final u = _snoozeUntil;
    if (u == null) return null;
    final d = u.difference(_now());
    return d > Duration.zero ? d : null;
  }

  /// 지금 카메라가 꺼져 있는 이유 (진단 칸). 켜져 있으면 null.
  String? get offReason {
    if (_running) return null;
    if (!supported) return '이 기기에서 쓸 수 없음';
    if (_heatOff) return '기기가 뜨거움';
    if (!_enabled) return '설정에서 꺼짐';
    if (error != null) return '오류: $error';
    if (!_foreground) return '앱이 뒤에 있음';
    if (_resting) return '쉬어 가기 중';
    if (_blocked) return '눈 쉬기, 오늘은 여기까지 덮개';
    final kinds = _screens.values;
    if (kinds.contains(EyeScreen.parent)) return '부모님 화면 (설정, 부모 확인)';
    if (kinds.contains(EyeScreen.paused)) return '멈춤 화면';
    if (!kinds.contains(EyeScreen.child)) return '아이 화면이 없음';
    return '켜는 중';
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

  Future<void> stop() async {
    _gen++;
    _offTimer?.cancel();
    _offTimer = null;
    _windowTimer?.cancel();
    _windowTimer = null;
    _windowAt = null;
    final wasRunning = _running;
    _running = false;
    _windowOpen = false;
    _stats.cameraOn(false);
    _last = null;
    _closeSince = _angleSince = _goodSince = null;
    _alertSince = _faceSeenAt = null;
    _alert = EyeAlert.none;
    _zone = EyeZone.safe;
    _failures = 0;
    notifyListeners();
    if (!wasRunning) return;
    final before = _stopping;
    final done = _stopping = () async {
      if (before != null) await before;
      await _sensor.stop();
    }();
    await done;
    if (identical(_stopping, done)) _stopping = null;
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
    _openNow(); // 이미 돌고 있으면 다음 창을 기다리지 않는다
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
    _zone = EyeZone.safe;
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
      _zone = EyeZone.safe;
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
      _zone = _alert == EyeAlert.none ? EyeZone.safe : EyeZone.alert;
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

    // 경고까지 걸리는 시간(2초·2.5초)은 처음 본 시각부터 실제 시각으로 잰다
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
    _zone = next != EyeAlert.none ? EyeZone.alert : zoneOf(r, previous: _zone);
    if (next != was) _sync();
    notifyListeners();
  }

  /// 경고가 아닐 때의 창 주기 상태.
  /// 기준 가까이(경고 거리의 1.2배 이하, 또는 고개 각도가 기준의 80% 넘음) → [EyeZone.caution],
  /// 넉넉함(1.4배보다 멀고 자세 바름) → [EyeZone.safe], 그 사이(1.2~1.4배)는 [previous]를 그대로
  /// (경고에서 막 풀린 경우는 기준 가까이로 본다).
  EyeZone zoneOf(FaceReading r, {required EyeZone previous}) {
    const k = EyeRules.nearAngleRatio;
    final d = distanceOf(r.size);
    final turned =
        r.yaw.abs() > EyeRules.maxYaw * k ||
        r.pitch.abs() > EyeRules.maxPitch * k ||
        r.roll.abs() > EyeRules.maxRoll * k;
    if (turned || d <= tooCloseCm * EyeRules.nearRatio) return EyeZone.caution;
    if (d > tooCloseCm * EyeRules.safeRatio) return EyeZone.safe;
    return previous == EyeZone.alert ? EyeZone.caution : previous;
  }

  @override
  void dispose() {
    _heat.removeListener(_onHeat);
    _offTimer?.cancel();
    _windowTimer?.cancel();
    _gen++;
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
/// 최근 1분 동안 카메라에서 실제로 받은 프레임 수, 얼굴 검사 횟수, 카메라가 켜져 있던 시간,
/// 창(카메라를 잠깐 연 것) 수와 창 하나를 열어 둔 시간을 센다.
/// `CameraController(fps: 10)` 요청이 기기에서 실제로 먹히는지(30fps로 들어오지 않는지),
/// 창 사이에 카메라를 살려 두는 방식과 매번 닫는 방식 중 무엇이 창을 짧게 여는지 확인하는 용도.
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

  /// 창을 닫은 시각과 열어 둔 시간
  final _windows = ListQueue<(DateTime, Duration)>();
  Duration? _lastWindow;

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

  /// 카메라 창 하나를 닫았다 ([open] = 연 때부터 닫을 때까지)
  void windowClosed(Duration open) {
    final now = _now();
    _windows.add((now, open));
    _lastWindow = open;
    _prune(now);
  }

  void _prune(DateTime now) {
    final from = now.subtract(window);
    while (_windows.isNotEmpty && _windows.first.$1.isBefore(from)) {
      _windows.removeFirst();
    }
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
    var open = Duration.zero;
    for (final (_, d) in _windows) {
      open += d;
    }
    return EyeStatsSummary(
      window: span,
      cameraOn: on,
      frames: _frames.length,
      checks: _checks.length,
      windows: _windows.length,
      windowAverage: _windows.isEmpty ? null : open ~/ _windows.length,
      lastWindow: _lastWindow,
    );
  }

  /// 기록을 비우고 지금부터 다시 잰다 (진단 칸에서 방식을 바꿀 때)
  void reset() {
    _since = _now();
    _frames.clear();
    _checks.clear();
    _windows.clear();
    _lastWindow = null;
    // 지금 켜져 있으면 지금부터 다시 잰다
    final wasOn = cameraIsOn;
    _spans.clear();
    if (wasOn) _spans.add((_since, null));
  }
}

/// [EyeStats.summary] 결과
class EyeStatsSummary {
  const EyeStatsSummary({
    required this.window,
    required this.cameraOn,
    required this.frames,
    required this.checks,
    this.windows = 0,
    this.windowAverage,
    this.lastWindow,
  });

  /// 잰 시간 (보통 1분)
  final Duration window;

  /// 그동안 카메라가 켜져 있던 시간
  final Duration cameraOn;
  final int frames;
  final int checks;

  /// 그동안 연 카메라 창 수
  final int windows;

  /// 창 하나를 열어 둔 평균 시간 (창이 없으면 null)
  final Duration? windowAverage;

  /// 마지막 창을 열어 둔 시간 (1분이 지나도 남는다)
  final Duration? lastWindow;

  /// 카메라가 켜져 있는 동안 실제로 받은 초당 프레임 수 (켜진 적 없으면 null)
  double? get fps => cameraOn.inMilliseconds < 500
      ? null
      : frames * 1000 / cameraOn.inMilliseconds;

  /// 카메라가 켜져 있던 시간 비율 (0~1)
  double get onRatio => window.inMilliseconds <= 0
      ? 0
      : (cameraOn.inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
}
