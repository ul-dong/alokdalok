import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// 실기기 렉·터치 진단 (설정 → '부모님께'를 길게 누르면 보이는 진단 칸).
///
/// - 프레임: 최근 1분 동안 그린 화면 한 장마다 걸린 시간(만들기 build + 그리기 raster).
///   16ms를 넘으면 1초 60장을 못 맞춘 것, 33ms를 넘으면 눈에 띄게 끊긴 것이다.
/// - 누름: 마지막 몇 번의 누름이 무엇에 맞았는지(버튼 이름), 얼마나 누르고 있었는지,
///   손가락이 얼마나 움직였는지. "눌렀는데 안 된다"가 길게 누르기(0.4초 넘음), 미끄러짐,
///   덮개 때문인지 숫자로 본다.
/// 숫자는 기기 안에만 잠깐 들고 있고 저장하거나 보내지 않는다.
class PerfMonitor {
  PerfMonitor({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final PerfMonitor instance = PerfMonitor();

  static const window = Duration(minutes: 1);

  final DateTime Function() _now;
  final _frames = ListQueue<(DateTime, double)>();
  bool _started = false;

  /// 앱을 켤 때 한 번 부른다
  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    GestureBinding.instance.pointerRouter.addGlobalRoute(onPointer);
  }

  // ---------------- 프레임 ----------------

  /// 엔진이 알려 주는 프레임 시간 (몇 장씩 묶여서 온다)
  void onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      addFrame((t.buildDuration + t.rasterDuration).inMicroseconds / 1000);
    }
  }

  /// 화면 한 장에 [ms]가 걸렸다
  void addFrame(double ms) {
    final now = _now();
    _frames.add((now, ms));
    _prune(now);
  }

  void _prune(DateTime now) {
    final from = now.subtract(window);
    while (_frames.isNotEmpty && _frames.first.$1.isBefore(from)) {
      _frames.removeFirst();
    }
  }

  /// 최근 1분 요약
  FrameSummary frames() {
    _prune(_now());
    var slow = 0, janky = 0;
    var worst = 0.0, sum = 0.0;
    for (final (_, ms) in _frames) {
      if (ms > 16) slow++;
      if (ms > 33) janky++;
      if (ms > worst) worst = ms;
      sum += ms;
    }
    return FrameSummary(
      count: _frames.length,
      over16: slow,
      over33: janky,
      worstMs: worst,
      averageMs: _frames.isEmpty ? 0 : sum / _frames.length,
    );
  }

  // ---------------- 누름 ----------------

  final _touches = ListQueue<TouchRecord>();
  final Map<int, (DateTime, Offset, String)> _down = {};

  /// 최근 누름 (최근 것이 마지막, 최대 3개)
  List<TouchRecord> get touches => List.unmodifiable(_touches);

  void onPointer(PointerEvent e) {
    if (e is PointerDownEvent) {
      _down[e.pointer] = (_now(), e.position, _hitName(e));
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      final d = _down.remove(e.pointer);
      if (d == null) return;
      _touches.add(
        TouchRecord(
          at: d.$1,
          target: d.$3,
          held: _now().difference(d.$1),
          moved: (e.position - d.$2).distance,
          cancelled: e is PointerCancelEvent,
        ),
      );
      while (_touches.length > 3) {
        _touches.removeFirst();
      }
    }
  }

  /// 누른 자리에서 맨 위에 맞은 것의 이름 (버튼 이름표, 없으면 '이름 없는 칸').
  /// 덮개가 가로채면 덮개 이름이 나온다.
  String _hitName(PointerDownEvent e) {
    try {
      final r = HitTestResult();
      RendererBinding.instance.hitTestInView(r, e.position, e.viewId);
      for (final entry in r.path) {
        final t = entry.target;
        if (t is RenderSemanticsAnnotations) {
          final label = t.properties.label;
          if (label != null && label.isNotEmpty) return label;
        }
      }
      return r.path.length <= 2 ? '빈 곳' : '이름 없는 칸';
    } catch (_) {
      return '알 수 없음';
    }
  }

  /// 테스트용: 기록을 비운다
  void reset() {
    _frames.clear();
    _touches.clear();
    _down.clear();
  }
}

/// 최근 1분 프레임 요약
class FrameSummary {
  const FrameSummary({
    required this.count,
    required this.over16,
    required this.over33,
    required this.worstMs,
    required this.averageMs,
  });
  final int count, over16, over33;
  final double worstMs, averageMs;
}

/// 누름 한 번
class TouchRecord {
  const TouchRecord({
    required this.at,
    required this.target,
    required this.held,
    required this.moved,
    this.cancelled = false,
  });
  final DateTime at;

  /// 맞은 것 (버튼 이름표)
  final String target;

  /// 누르고 있던 시간
  final Duration held;

  /// 손가락이 움직인 거리 (px)
  final double moved;

  /// 시스템이 누름을 취소했다 (다른 앱 알림 등)
  final bool cancelled;
}
