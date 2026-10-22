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
/// - 프레임 중에서 [EyeGuard]가 정한 간격(평소 1.5초, 가까우면 0.5초)마다 하나만 검사한다.
class _MlKitEyeSensor implements EyeSensor {
  CameraController? _cam;
  CameraDescription? _desc;
  FaceDetector? _detector;
  StreamController<FaceReading?>? _out;
  bool _busy = false;
  final _gate = EyeCheckGate();

  /// 켤 때마다 늘어난다. 카메라를 여는 사이에 꺼지면 연 것을 바로 닫는다.
  int _gen = 0;

  // 디버그 실행에서 1분마다 실제 받은 프레임 수와 검사 횟수를 알려 준다 (기기에서 확인용)
  int _frames = 0, _checks = 0;
  DateTime _countFrom = DateTime.now();

  /// 3살 아이 얼굴 너비(ML Kit 얼굴 상자 기준) 약 13cm, 앞카메라 가로 화각 약 70도로 가정.
  /// 기기마다 다르므로 설정에서 30cm 기준을 맞추면 그 값을 쓴다.
  @override
  double defaultDistanceCm(double size) => pinholeDistanceCm(size, 13, 70);

  @override
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void setInterval(Duration interval) => _gate.interval = interval;

  @override
  Stream<FaceReading?> start() {
    final out = _out = StreamController<FaceReading?>();
    _gate.reset();
    _frames = _checks = 0;
    _countFrom = DateTime.now();
    _open(out, ++_gen);
    return out.stream;
  }

  Future<void> _open(StreamController<FaceReading?> out, int gen) async {
    CameraController? cam;
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw '앞카메라가 없어요',
      );
      if (gen != _gen) return;
      cam = eyeCameraController(front, ios: Platform.isIOS);
      await cam.initialize();
      if (gen != _gen) {
        await cam.dispose();
        return;
      }
      // 미리보기 화면은 쓰지 않는다 (안드로이드: Preview 연결을 풀어 프레임을 덜 만든다)
      try {
        await cam.pausePreview();
      } catch (_) {}
      _desc = front;
      _cam = cam;
      _detector ??= FaceDetector(options: eyeFaceDetectorOptions());
      await cam.startImageStream(_onFrame);
    } catch (e) {
      if (gen != _gen) {
        try {
          await cam?.dispose();
        } catch (_) {}
        return;
      }
      if (!out.isClosed) {
        out.addError(e is CameraException ? '카메라를 쓸 수 없어요' : e);
      }
    }
  }

  void _countFrame(bool checked) {
    if (!kDebugMode) return;
    _frames++;
    if (checked) _checks++;
    final now = DateTime.now();
    final sec = now.difference(_countFrom).inMilliseconds / 1000;
    if (sec >= 60) {
      debugPrint(
        '눈 지킴이: ${sec.round()}초 동안 카메라 프레임 $_frames장 '
        '(초당 ${(_frames / sec).toStringAsFixed(1)}), 검사 $_checks번',
      );
      _frames = _checks = 0;
      _countFrom = now;
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final take = !_busy && _gate.take(DateTime.now());
    _countFrame(take);
    if (!take) return;
    _busy = true;
    try {
      final made = _toInput(image);
      if (made == null) return;
      final (input, frameWidth) = made;
      final detector = _detector;
      if (detector == null) return;
      final faces = await detector.processImage(input);
      final out = _out;
      if (out == null || out.isClosed) return;
      if (faces.isEmpty) {
        out.add(null);
        return;
      }
      faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
      final f = faces.first;
      out.add(
        FaceReading(
          size: f.boundingBox.width / frameWidth,
          yaw: f.headEulerAngleY ?? 0,
          pitch: f.headEulerAngleX ?? 0,
          roll: f.headEulerAngleZ ?? 0,
        ),
      );
    } catch (e) {
      debugPrint('eye guard: $e');
    } finally {
      _busy = false;
    }
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
    await _out?.close();
    _out = null;
  }
}
