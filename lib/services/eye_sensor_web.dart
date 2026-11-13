import 'dart:async';
import 'dart:js_interop';

import 'eye_guard.dart';

EyeSensor createEyeSensor() => _WebEyeSensor();

@JS('alokEyeGuard')
external _Guard? get _guard;

extension type _Guard(JSObject _) implements JSObject {
  /// 잘 열리면 null, 안 되면 메시지
  external JSPromise<JSString?> open();

  /// [size, yaw, pitch, roll] / 얼굴 없음 [] / 아직 볼 수 없음 null
  external JSArray<JSNumber>? detect();
  external void pause();
  external void stop();
}

/// 웹: web/eye_guard.js (MediaPipe 얼굴 랜드마크)를 부른다.
///
/// 앱과 같은 구조로 카메라를 짧게 열어서 보고 끈다 ([EyeWindow]): 창을 열 때 `video.play()`,
/// [EyeRules.webFrameGap]마다 한 장씩 2~3장을 보고, 창을 닫을 때 `video.pause()`.
/// [keepCamera]가 false면 창마다 카메라 스트림을 완전히 끈다.
/// 웹은 기기 열 정보가 없어 창 주기를 늘리지 않는다.
class _WebEyeSensor implements EyeSensor {
  EyeWindow<int>? _window;
  int _gen = 0;

  @override
  bool keepCamera = EyeRules.keepCameraDefault;

  @override
  String get mode =>
      keepCamera ? '영상 멈춤 (video.pause)' : '창마다 끄기 (스트림 종료)';

  /// 홍채 지름 약 1.17cm, 태블릿·휴대폰 앞카메라 가로 화각 약 62도로 가정.
  /// 기기마다 다르므로 설정에서 30cm 기준을 맞추면 그 값을 쓴다.
  @override
  double defaultDistanceCm(double size) => pinholeDistanceCm(size, 1.17, 62);

  @override
  bool get supported => _guard != null;

  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async {
    final g = _guard;
    if (g == null) throw '눈 지킴이를 불러오지 못했어요';
    final gen = _gen;
    Timer? ticker;
    final w = _window = EyeWindow<int>(
      budget: budget,
      open: (onFrame) async {
        final err = await g.open().toDart;
        if (err != null) throw err.toDart;
        if (gen != _gen) return;
        var n = 0;
        void tick() {
          EyeStats.instance.frame(); // 진단 칸: 살펴보려고 꺼낸 프레임
          onFrame(n++);
        }

        tick();
        ticker = Timer.periodic(EyeRules.webFrameGap, (_) => tick());
      },
      close: () async {
        ticker?.cancel();
        if (gen != _gen) return; // 이미 stop()이 껐다
        if (keepCamera) {
          g.pause();
        } else {
          g.stop();
        }
      },
      analyze: (_) async {
        final r = g.detect();
        if (r == null) throw StateError('not ready');
        final v = r.toDart;
        if (v.length < 4) return null; // 얼굴 없음
        return FaceReading(
          size: v[0].toDartDouble,
          yaw: v[1].toDartDouble,
          pitch: v[2].toDartDouble,
          roll: v[3].toDartDouble,
        );
      },
    );
    try {
      return await w.run();
    } finally {
      if (identical(_window, w)) _window = null;
    }
  }

  @override
  Future<void> stop() async {
    _gen++;
    _window?.abort();
    _window = null;
    _guard?.stop();
  }
}
