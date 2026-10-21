import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/slow_clock.dart';
import 'common.dart';

/// 큰 노란 "다시 듣기" 버튼 (62px). 눈에 띄도록 6초마다 한 번 통통 튄다.
///
/// 튀는 동안(약 0.6초)만 공용 20fps 시계([SlowClock])를 듣고, 나머지 시간에는 다시 그리지 않는다.
class ListenAgainButton extends StatefulWidget {
  const ListenAgainButton({
    super.key,
    required this.onTap,
    this.size = defaultSize,
    this.label = '다시 듣기',
  });

  static const defaultSize = 62.0;

  /// 몇 초마다 튀는지
  static const every = Duration(seconds: 6);

  /// 한 번 튀는 시간
  static const hopTime = 0.6;

  /// 튀는 높이 (버튼 크기 대비)
  static double hopOffset(double t, double size) {
    if (t <= 0 || t >= hopTime) return 0;
    // 큰 통 + 작은 통
    final u = t / hopTime;
    final h = u < .6 ? sin(u / .6 * pi) : sin((u - .6) / .4 * pi) * .35;
    return -h * size * .18;
  }

  final VoidCallback onTap;
  final double size;
  final String label;

  @override
  State<ListenAgainButton> createState() => _ListenAgainButtonState();
}

class _ListenAgainButtonState extends State<ListenAgainButton> {
  Timer? _timer;

  /// 튀기 시작한 뒤 시계가 몇 번 똑딱였는지 (null이면 쉬는 중)
  int? _ticks;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(ListenAgainButton.every, (_) => _hop());
  }

  void _hop() {
    if (!mounted || _ticks != null) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _ticks = 0;
    SlowClock.instance.addListener(_tick);
  }

  void _tick() {
    final n = _ticks;
    if (n == null) return;
    _ticks = n + 1;
    final t = _ticks! * SlowClock.interval.inMilliseconds / 1000;
    if (t >= ListenAgainButton.hopTime) {
      _stopHop();
      setState(() => _offset = 0);
      return;
    }
    setState(() => _offset = ListenAgainButton.hopOffset(t, widget.size));
  }

  void _stopHop() {
    if (_ticks == null) return;
    _ticks = null;
    SlowClock.instance.removeListener(_tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopHop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, _offset),
    child: Pressable(
      onTap: widget.onTap,
      semanticLabel: widget.label,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: Palette.yellow,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Palette.coinDeep, offset: Offset(0, 5)),
            BoxShadow(
              color: Palette.panelShadow,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.volume_up_rounded,
          size: widget.size * .55,
          color: Palette.text,
        ),
      ),
    ),
  );
}
