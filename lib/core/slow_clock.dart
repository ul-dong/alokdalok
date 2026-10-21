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

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) {
      _watch.start();
      _timer = Timer.periodic(interval, (_) => notifyListeners());
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listeners == 0) {
      _timer?.cancel();
      _timer = null;
      _watch.stop();
    }
  }

  @override
  // ignore: must_call_super
  void dispose() {
    // 앱 전체가 같이 쓰므로 버리지 않는다
  }
}
