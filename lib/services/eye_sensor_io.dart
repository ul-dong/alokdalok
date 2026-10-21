import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'eye_guard.dart';

EyeSensor createEyeSensor() => _MlKitEyeSensor();

/// 안드로이드·iOS: 앞카메라 + ML Kit 얼굴 인식 (기기 안에서만 처리).
/// 발열을 줄이려고 낮은 해상도로, 0.7초에 한 번만 살펴본다.
class _MlKitEyeSensor implements EyeSensor {
  CameraController? _cam;
  CameraDescription? _desc;
  FaceDetector? _detector;
  StreamController<FaceReading?>? _out;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  static const _interval = Duration(milliseconds: 700);

  /// 3살 아이 얼굴 너비(ML Kit 얼굴 상자 기준) 약 13cm, 앞카메라 가로 화각 약 70도로 가정.
  /// 기기마다 다르므로 설정에서 30cm 기준을 맞추면 그 값을 쓴다.
  @override
  double defaultDistanceCm(double size) => pinholeDistanceCm(size, 13, 70);

  @override
  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Stream<FaceReading?> start() {
    final out = _out = StreamController<FaceReading?>();
    _open(out);
    return out.stream;
  }

  Future<void> _open(StreamController<FaceReading?> out) async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw '앞카메라가 없어요',
      );
      _desc = front;
      final cam = _cam = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await cam.initialize();
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: .08,
        ),
      );
      await cam.startImageStream(_onFrame);
    } catch (e) {
      if (!out.isClosed) {
        out.addError(e is CameraException ? '카메라를 쓸 수 없어요' : e);
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final now = DateTime.now();
    if (_busy || now.difference(_lastRun) < _interval) return;
    _busy = true;
    _lastRun = now;
    try {
      final made = _toInput(image);
      if (made == null) return;
      final (input, frameWidth) = made;
      final faces = await _detector!.processImage(input);
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
