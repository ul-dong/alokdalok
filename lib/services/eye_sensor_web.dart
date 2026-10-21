import 'dart:async';
import 'dart:js_interop';

import 'eye_guard.dart';

EyeSensor createEyeSensor() => _WebEyeSensor();

@JS('alokEyeGuard')
external _Guard? get _guard;

extension type _Guard(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(
    JSFunction onFace,
    JSFunction onNoFace,
    JSFunction onError,
  );
  external void stop();
}

/// 웹: web/eye_guard.js (MediaPipe 얼굴 랜드마크)를 부른다.
class _WebEyeSensor implements EyeSensor {
  StreamController<FaceReading?>? _out;

  /// 홍채 지름 약 1.17cm, 태블릿·휴대폰 앞카메라 가로 화각 약 62도로 가정.
  /// 기기마다 다르므로 설정에서 30cm 기준을 맞추면 그 값을 쓴다.
  @override
  double defaultDistanceCm(double size) => pinholeDistanceCm(size, 1.17, 62);

  @override
  bool get supported => _guard != null;

  @override
  Stream<FaceReading?> start() {
    final out = _out = StreamController<FaceReading?>();
    final g = _guard;
    if (g == null) {
      out.addError('눈 지킴이를 불러오지 못했어요');
      return out.stream;
    }
    void onFace(JSNumber size, JSNumber yaw, JSNumber pitch, JSNumber roll) {
      if (out.isClosed) return;
      out.add(
        FaceReading(
          size: size.toDartDouble,
          yaw: yaw.toDartDouble,
          pitch: pitch.toDartDouble,
          roll: roll.toDartDouble,
        ),
      );
    }

    void onNoFace() {
      if (!out.isClosed) out.add(null);
    }

    void onError(JSString msg) {
      if (!out.isClosed) out.addError(msg.toDart);
    }

    g.start(onFace.toJS, onNoFace.toJS, onError.toJS);
    return out.stream;
  }

  @override
  Future<void> stop() async {
    _guard?.stop();
    await _out?.close();
    _out = null;
  }
}
