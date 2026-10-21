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

  static const defaultHoldTime = Duration(milliseconds: 900);
  static const hint = '꾹 누르고 있어요.';

  /// 이름표 뒤에 붙는 표시 ("집으로 (꾹)")
  static String shownLabel(String label) => '$label (꾹)';

  /// 짧게 톡 눌렀을 때 고리가 이만큼 차올랐다가 다시 줄어든다 (눌린 걸 눈으로 알게)
  static const nudge = .3;

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
    // animateTo(살짝 차오름)도 끝나면 completed가 되므로, 고리가 다 찼을 때만 나간다
    if (s == AnimationStatus.completed && _c.value >= 1 && !_done) {
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
    if (_c.value >= 1) return;
    AppScope.read(context).audio.say(HoldToConfirm.hint);
    if (_c.value < HoldToConfirm.nudge) {
      // 톡 누르면 고리가 거의 안 보이므로, 조금 차오르는 모습을 보여 준 뒤 줄인다
      _c
          .animateTo(
            HoldToConfirm.nudge,
            duration: const Duration(milliseconds: 160),
          )
          .whenCompleteOrCancel(() {
            if (mounted && !_done && !_pressed) _c.reverse();
          });
    } else {
      _c.reverse();
    }
  }

  bool _pressed = false;

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
        onPointerDown: (_) {
          _pressed = true;
          _down();
        },
        onPointerUp: (_) {
          _pressed = false;
          _up();
        },
        onPointerCancel: (_) {
          _pressed = false;
          _up();
        },
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
            // 손가락 그림 + "집으로 (꾹)": 꾹 눌러야 하는 버튼이라는 표시
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: TextSizes.label + 6,
                  color: Palette.textSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  HoldToConfirm.shownLabel(widget.label),
                  style: const TextStyle(
                    fontSize: TextSizes.label,
                    color: Palette.text,
                  ),
                ),
              ],
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

  static const trackColor = Color(0xFFE3D3BC);
  static const fillColor = Color(0xFFFFB82E);

  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide / 2 - 6;
    final o = s.center(Offset.zero);
    // 크림 카드 위에서도 보이도록 진한 바탕 고리
    final base = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    c.drawCircle(o, r, base);
    if (progress <= 0) return;
    c.drawArc(
      Rect.fromCircle(center: o, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(HoldRingPainter old) => old.progress != progress;
}
