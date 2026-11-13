import 'dart:async';

import 'package:flutter/foundation.dart';

/// 느린 움직임(구름, 숨쉬기, 바퀴)을 위한 공용 시계: 초당 20번.
///
/// 화면 곳곳의 장식 애니메이션이 각자 따로 60fps로 돌면 화면 전체를 쉬지 않고 다시 그려서
/// 기기가 뜨거워진다. 모두 이 시계 하나에 맞춰 움직이면 1초에 최대 20장만 그린다.
class SlowClock extends ChangeNotifier {
  SlowClock._();
  static final SlowClock instance = SlowClock._();

  static const interval = Duration(milliseconds: 50);

  final _watch = Stopwatch();
  Timer? _timer;
  int _listeners = 0;

  /// 지금 이 시계를 듣는 위젯 수 (0이면 시계가 멈춰 있다). 테스트 확인용.
  @visibleForTesting
  int get listenerCount => _listeners;

  /// 시작 후 흐른 시간 (초)
  double get seconds => _watch.elapsedMicroseconds / 1e6;

  /// 지금 시계가 돌고 있는지 (듣는 위젯이 있고 [held]가 아닐 때). 테스트 확인용.
  @visibleForTesting
  bool get ticking => _timer != null;

  bool _held = false;

  /// 덮개(눈 지킴이 경고·눈 쉬기·쉬어 가기·오늘은 여기까지)가 화면을 가리는 동안 시계를 멈춘다.
  /// 듣는 위젯이 있어도 움직이지 않고, 풀리면 멈춘 자리에서 이어 간다.
  bool get held => _held;
  set held(bool on) {
    if (on == _held) return;
    _held = on;
    _apply();
  }

  void _apply() {
    final run = _listeners > 0 && !_held;
    if (run == (_timer != null)) return;
    if (run) {
      _watch.start();
      _timer = Timer.periodic(interval, (_) => notifyListeners());
    } else {
      _timer?.cancel();
      _timer = null;
      _watch.stop();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) _apply();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listeners == 0) _apply();
  }

  @override
  // ignore: must_call_super
  void dispose() {
    // 앱 전체가 같이 쓰므로 버리지 않는다
  }
}
