import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/audio_service.dart';
import 'common.dart';

/// 꾹 눌러야 되는 큰 동그라미 버튼 (실수로 나가지 않게).
/// 누르고 있는 동안 둘레의 고리가 차오르고, 다 차면 [onConfirmed]를 부른다.
/// 손을 일찍 떼면 고리가 다시 줄어들고 "꾹 누르고 있어요"라고 알려 준다.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onConfirmed,
    this.size = 104,
    this.holdTime = defaultHoldTime,
  });

  static const defaultHoldTime = Duration(milliseconds: 1000);
  static const hint = '꾹 누르고 있어요.';

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onConfirmed;
  final double size;
  final Duration holdTime;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.holdTime,
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener(_onStatus);
  bool _done = false;

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_done) {
      _done = true;
      AppScope.read(context).audio.play(Sfx.tap);
      widget.onConfirmed();
    }
  }

  void _down() {
    if (_done) return;
    _c.forward();
  }

  void _up() {
    if (_done) return;
    if (_c.value < 1) {
      _c.reverse();
      AppScope.read(context).audio.say(HoldToConfirm.hint);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.size + 20;
    return Semantics(
      button: true,
      label: '${widget.label} (꾹 누르기)',
      // 손가락이 조금 움직여도 끊기지 않도록 날 포인터 이벤트로 받는다
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => SizedBox.square(
                dimension: ring,
                child: CustomPaint(
                  painter: HoldRingPainter(progress: _c.value),
                  child: Center(
                    child: Transform.scale(
                      scale: 1 - _c.value * .06,
                      child: child,
                    ),
                  ),
                ),
              ),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(widget.color, Colors.black, .15)!,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: widget.size * .6,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: TextSizes.label,
                color: Palette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 차오르는 고리
class HoldRingPainter extends CustomPainter {
  HoldRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide / 2 - 5;
    final o = s.center(Offset.zero);
    final base = Paint()
      ..color = Palette.creamDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    c.drawCircle(o, r, base);
    if (progress <= 0) return;
    c.drawArc(
      Rect.fromCircle(center: o, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = Palette.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(HoldRingPainter old) => old.progress != progress;
}
