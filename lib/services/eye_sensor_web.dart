import 'dart:async';
import 'dart:js_interop';

import '../l10n/l10n.dart';
import 'eye_guard.dart';

EyeSensor createEyeSensor() => _WebEyeSensor();

@JS('alokEyeGuard')
external _Guard? get _guard;

extension type _Guard(JSObject _) implements JSObject {
  /// 잘 열리면 null, 안 되면 메시지 ('!'로 시작하면 카메라를 아예 쓸 수 없음: 권한 거부 등)
  external JSPromise<JSString?> open();

  /// [size, yaw, pitch, roll] / 얼굴 없음 [] / 아직 볼 수 없음 null.
  /// 인식은 Web Worker에서 해서 메인 스레드(화면·터치)를 막지 않는다 (web/eye_worker.js).
  external JSPromise<JSArray<JSNumber>?> detect();

  /// 진단: [어디서, 마지막 인식 ms, 1회 최대 ms, 메인 스레드를 막은 ms, 준비 ms, 횟수]
  external JSArray<JSAny?>? stats();
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

  /// 이어서 쓸 만한 프레임을 한 장도 못 본 창 수. 영상이 멈춘 것 같으면(카메라 트랙이 끝남 등)
  /// 카메라 스트림을 놓아서 다음 창에서 새로 연다.
  int _emptyWindows = 0;
  static const _maxEmptyWindows = 2;

  @override
  bool keepCamera = EyeRules.keepCameraDefault;

  @override
  String get mode => keepCamera ? '영상 멈춤 (video.pause)' : '창마다 끄기 (스트림 종료)';

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
    if (g == null) throw EyeSensorDenied(L10n.current.eye_errLoad);
    final gen = _gen;
    Timer? ticker;
    final w = _window = EyeWindow<int>(
      budget: budget,
      open: (onFrame) async {
        final err = (await g.open().toDart)?.toDart;
        if (err != null) {
          throw err.startsWith('!') ? EyeSensorDenied(err.substring(1)) : err;
        }
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
        final r = await g.detect().toDart;
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
      if (gen == _gen) {
        _emptyWindows = w.valid == 0 ? _emptyWindows + 1 : 0;
        if (_emptyWindows >= _maxEmptyWindows) {
          _emptyWindows = 0;
          g.stop(); // 다음 창에서 카메라를 새로 연다
        }
      }
    }
  }

  @override
  EyeDetectStats? get detectStats {
    try {
      final v = _guard?.stats()?.toDart;
      if (v == null || v.length < 6) return null;
      double n(int i) => (v[i] as JSNumber?)?.toDartDouble ?? -1;
      return EyeDetectStats(
        where: (v[0] as JSString?)?.toDart ?? '',
        lastMs: n(1),
        maxMs: n(2),
        mainMs: n(3),
        initMs: n(4),
        count: n(5).round(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> stop() async {
    _emptyWindows = 0;
    _gen++;
    _window?.abort();
    _window = null;
    _guard?.stop();
  }
}
