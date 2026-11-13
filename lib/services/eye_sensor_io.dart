import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'eye_guard.dart';

EyeSensor createEyeSensor() => _MlKitEyeSensor();

/// ML Kit 얼굴 인식 설정. 눈 지킴이는 얼굴 상자(boundingBox, 거리)와
/// 고개 각도(headEulerAngleX/Y/Z)만 쓰므로 눈·코 위치(landmarks), 윤곽(contours),
/// 웃음·눈 뜸 분류(classification), 얼굴 따라가기(tracking)는 모두 끈다.
@visibleForTesting
FaceDetectorOptions eyeFaceDetectorOptions() => FaceDetectorOptions(
  performanceMode: FaceDetectorMode.fast,
  enableLandmarks: false,
  enableContours: false,
  enableClassification: false,
  enableTracking: false,
  minFaceSize: .08,
);

/// 카메라에 요청하는 초당 프레임 수 (안드로이드 10, iOS 5)
@visibleForTesting
int eyeCameraFps({required bool ios}) =>
    ios ? EyeRules.iosFps : EyeRules.androidFps;

/// 카메라 설정: 가장 낮은 해상도 + 낮은 프레임 수 + 소리 없음
@visibleForTesting
CameraController eyeCameraController(
  CameraDescription front, {
  required bool ios,
}) => CameraController(
  front,
  ResolutionPreset.low,
  enableAudio: false,
  fps: eyeCameraFps(ios: ios),
  imageFormatGroup: ios ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
);

/// 안드로이드·iOS: 앞카메라 + ML Kit 얼굴 인식 (기기 안에서만 처리, 저장·전송 없음).
///
/// 발열 줄이기:
/// - 가장 낮은 해상도, 초당 5~10장만 찍게 요청한다 (기본 30장).
/// - 화면 미리보기는 쓰지 않으므로 멈춰 둔다 (안드로이드는 Preview를 떼어 내서 GPU로 안 보낸다).
/// - 이미지 스트림을 계속 열어 두지 않는다: [sampleOnce]가 부를 때만 스트림을 열어 2~3장을 보고
///   바로 [CameraController.stopImageStream]으로 닫는다 ([EyeWindow]). 버려지는 프레임이
///   센서 → CameraX → 플랫폼 채널 → Dart 복사를 거치지 않게 한다.
/// - 창 사이에 [CameraController]는 살려 둔다([keepCamera], 재시작이 빠르고 표시등이 덜 깜빡인다).
///   false면 창마다 dispose 한다 (진단 칸에서 바꿔 실기기에서 비교).
class _MlKitEyeSensor implements EyeSensor {
  CameraController? _cam;
  CameraDescription? _desc;
  FaceDetector? _detector;
  EyeWindow<CameraImage>? _window;

  @override
  bool keepCamera = EyeRules.keepCameraDefault;

  @override
  String get mode => keepCamera ? '카메라 유지 (stopImageStream)' : '창마다 끄기 (dispose)';

  /// 끌 때마다 늘어난다. 카메라를 여는 사이에 꺼지면 연 것을 바로 닫는다.
  int _gen = 0;

  // 디버그 실행에서 1분마다 실제 받은 프레임 수와 창 수를 로그로 알려 준다 (기기에서 확인용).
  // release 빌드에서도 설정의 숨은 진단 칸([EyeStats])으로 볼 수 있다.
  int _frames = 0, _windows = 0;
  DateTime _countFrom = DateTime.now();

  /// 3살 아이 얼굴 너비(ML Kit 얼굴 상자 기준) 약 13cm, 앞카메라 가로 화각 약 70도로 가정.
  /// 기기마다 다르므로 설정에서 30cm 기준을 맞추면 그 값을 쓴다.
  @override
  double defaultDistanceCm(double size) => pinholeDistanceCm(size, 13, 70);

  @override
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 카메라를 연다 (이미 열려 있으면 그대로). 그 사이에 꺼지면 null.
  Future<CameraController?> _camera(int gen) async {
    final open = _cam;
    if (open != null) return open;
    CameraController? cam;
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw '앞카메라가 없어요',
      );
      if (gen != _gen) return null;
      cam = eyeCameraController(front, ios: Platform.isIOS);
      await cam.initialize();
      if (gen != _gen) {
        await cam.dispose();
        return null;
      }
      // 미리보기 화면은 쓰지 않는다 (안드로이드: Preview 연결을 풀어 프레임을 덜 만든다)
      try {
        await cam.pausePreview();
      } catch (_) {}
      _desc = front;
      _detector ??= FaceDetector(options: eyeFaceDetectorOptions());
      return _cam = cam;
    } catch (e) {
      if (gen != _gen) {
        try {
          await cam?.dispose();
        } catch (_) {}
        return null;
      }
      throw e is CameraException ? '카메라를 쓸 수 없어요' : e;
    }
  }

  @override
  Future<FaceReading?> sampleOnce({
    Duration budget = EyeRules.windowBudget,
  }) async {
    final gen = _gen;
    final cam = await _camera(gen);
    if (cam == null || gen != _gen) return null;
    final w = _window = EyeWindow<CameraImage>(
      budget: budget,
      open: (onFrame) => cam.startImageStream((image) {
        _countFrame();
        onFrame(image);
      }),
      close: () async {
        if (cam.value.isStreamingImages) await cam.stopImageStream();
      },
      analyze: _analyze,
    );
    try {
      return await w.run();
    } finally {
      if (identical(_window, w)) _window = null;
      _countWindow();
      // 창마다 끄는 방식: 카메라를 놓는다 (얼굴 인식기는 살려 둔다)
      if (!keepCamera && gen == _gen && identical(_cam, cam)) {
        _cam = null;
        try {
          await cam.dispose();
        } catch (_) {}
      }
    }
  }

  /// 받은 프레임을 진단 기록([EyeStats], 설정 '부모님께' 아래 숨은 칸)에 남긴다.
  void _countFrame() {
    EyeStats.instance.frame();
    if (kDebugMode) _frames++;
  }

  /// 디버그 실행에서는 1분마다 로그로도 알려 준다.
  void _countWindow() {
    if (!kDebugMode) return;
    _windows++;
    final now = DateTime.now();
    final sec = now.difference(_countFrom).inMilliseconds / 1000;
    if (sec >= 60) {
      debugPrint(
        '눈 지킴이: ${sec.round()}초 동안 창 $_windows번, 카메라 프레임 $_frames장 ($mode)',
      );
      _frames = _windows = 0;
      _countFrom = now;
    }
  }

  /// 프레임 하나 → 가장 큰 얼굴 (없으면 null). 쓸 수 없는 프레임이면 오류.
  Future<FaceReading?> _analyze(CameraImage image) async {
    final made = _toInput(image);
    final detector = _detector;
    if (made == null || detector == null) throw StateError('frame');
    final (input, frameWidth) = made;
    final faces = await detector.processImage(input);
    if (faces.isEmpty) return null;
    faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
    final f = faces.first;
    return FaceReading(
      size: f.boundingBox.width / frameWidth,
      yaw: f.headEulerAngleY ?? 0,
      pitch: f.headEulerAngleX ?? 0,
      roll: f.headEulerAngleZ ?? 0,
    );
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// 카메라 프레임 → ML Kit 입력 (+ 바로 세운 화면의 가로 픽셀 수)
  (InputImage, double)? _toInput(CameraImage image) {
    final desc = _desc, cam = _cam;
    if (desc == null || cam == null) return null;
    final sensor = desc.sensorOrientation;
    int deg;
    if (Platform.isIOS) {
      deg = sensor;
    } else {
      final comp = _orientations[cam.value.deviceOrientation];
      if (comp == null) return null;
      deg = (sensor + comp) % 360; // 앞카메라
    }
    final rotation = InputImageRotationValue.fromRawValue(deg);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
    final turned = deg % 180 != 0;
    final w = (turned ? image.height : image.width).toDouble();
    return (input, w);
  }

  @override
  Future<void> stop() async {
    _gen++;
    _window?.abort();
    _window = null;
    final cam = _cam;
    _cam = null;
    try {
      if (cam != null) {
        if (cam.value.isStreamingImages) await cam.stopImageStream();
        await cam.dispose();
      }
    } catch (_) {}
    await _detector?.close();
    _detector = null;
  }
}
