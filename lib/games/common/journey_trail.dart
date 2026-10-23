import 'dart:math';

import 'package:flutter/material.dart';

import '../../character/character_view.dart';
import '../../character/walk_view.dart';
import '../../core/slow_clock.dart';
import '../../core/palette.dart';
import '../../data/item_catalog.dart';
import '../../vehicle/ride_view.dart';
import '../../widgets/common.dart';

/// 골인 지점까지 가는 길. 문제를 맞힐 때마다 내 친구가 다음 깃발까지 앞으로 가고,
/// 마지막 문제를 맞히면 골인 지점에 도착한다. 탈것을 타고 있으면 탈것을 타고 간다.
class JourneyTrail extends StatelessWidget {
  const JourneyTrail({
    super.key,
    required this.total,
    required this.done,
    this.cheer = 0,
    this.bubble,
  });

  final int total;
  final int done;
  final int cheer;
  final String? bubble;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final riding = state.ride != null;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final riderH = h * .92;
        final riderW = riding ? riderH * 1.5 : riderH / 1.2;
        final goalW = h * .9;
        final startX = riderW / 2 + 4;
        final goalX = w - goalW / 2 - 6;
        double xFor(int i) => startX + (goalX - startX) * (i / max(1, total));
        final arrived = done >= total;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoadPainter(
                  total: total,
                  done: done,
                  xFor: xFor,
                  goalX: goalX,
                  goalW: goalW,
                ),
              ),
            ),
            // 지나온 깃발의 별
            for (var i = 1; i < total; i++)
              Positioned(
                left: xFor(i) - 14,
                top: h * .08,
                child: AnimatedScale(
                  scale: i <= done ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: const StarIcon(size: 28),
                ),
              ),
            // 내 친구: 탈것을 타면 타고 가고, 아니면 옆을 보고 걸어간다
            if (riding)
              TweenAnimationBuilder<double>(
                tween: Tween(end: done.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeInOut,
                builder: (context, t, _) {
                  final moving = (t - done).abs() > .01;
                  final x = startX + (goalX - startX) * (t / max(1, total));
                  return Positioned(
                    left: min(x, goalX) - riderW / 2,
                    bottom: h * .02,
                    child: RideView(
                      width: riderW,
                      cheer: cheer,
                      moving: moving,
                    ),
                  );
                },
              )
            else
              JourneyWalker(
                done: done,
                total: total,
                startX: startX,
                goalX: goalX,
                size: riderH / 1.2,
                bottom: h * .02,
                cheer: cheer,
                equipped: state.equipped,
              ),
            // 말풍선
            if (bubble != null)
              Positioned(
                left: (xFor(min(done, total)) + riderW / 2 - 4).clamp(
                  0.0,
                  max(0.0, w - 200),
                ),
                top: 0,
                child: _Bubble(text: bubble!),
              ),
            if (arrived)
              Positioned(
                left: goalX - goalW / 2,
                top: -h * .1,
                width: goalW,
                child: const _GoalBurst(),
              ),
          ],
        );
      },
    );
  }
}

/// 걸어가는 내 친구. 정답을 맞혀 [done]이 늘면 다음 깃발까지 옆을 보고 걸어가고,
/// 도착하면 다시 정면을 본다. 움직임은 공용 20fps 시계([SlowClock])로, 걷는 동안에만 시계를 듣는다.
class JourneyWalker extends StatefulWidget {
  const JourneyWalker({
    super.key,
    required this.done,
    required this.total,
    required this.startX,
    required this.goalX,
    required this.size,
    required this.bottom,
    required this.equipped,
    this.cheer = 0,
  });

  final int done;
  final int total;
  final double startX;
  final double goalX;
  final double size;
  final double bottom;
  final Map<ItemSlot, String> equipped;
  final int cheer;

  /// 깃발 하나를 걸어가는 시간 (초)
  static const double duration = 1.1;

  /// 깃발 하나를 걸어가는 걸음 수 (한 걸음 약 0.37초)
  static const int steps = 3;

  @override
  State<JourneyWalker> createState() => JourneyWalkerState();
}

class JourneyWalkerState extends State<JourneyWalker> {
  late double _pos = widget.done.toDouble();
  double _from = 0;
  int _ticks = 0;
  bool _listening = false;

  /// 지금 걸어가는 중인지
  bool get walking => _listening;

  /// 걸음 주기 (0~1, 0.5마다 앞뒤 발이 바뀐다). 걸어간 거리에 맞춰서 발이 미끄러지지 않게.
  double get step {
    final span = (widget.done - _from).abs();
    if (span == 0) return 0;
    final f = ((_pos - _from).abs() / span).clamp(0.0, 1.0);
    return (f * JourneyWalker.steps / 2) % 1.0;
  }

  @override
  void didUpdateWidget(JourneyWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done == oldWidget.done) return;
    if (widget.done < oldWidget.done) {
      // 처음부터 다시: 걷지 않고 바로 그 자리로
      _stop();
      _pos = widget.done.toDouble();
      return;
    }
    _from = _pos;
    _ticks = 0;
    if (!_listening) {
      SlowClock.instance.addListener(_tick);
      _listening = true;
    }
  }

  void _stop() {
    if (!_listening) return;
    SlowClock.instance.removeListener(_tick);
    _listening = false;
  }

  void _tick() {
    if (!mounted) return;
    _ticks++;
    final t =
        (_ticks *
                SlowClock.interval.inMilliseconds /
                1000 /
                JourneyWalker.duration)
            .clamp(0.0, 1.0);
    setState(() {
      _pos = _from + (widget.done - _from) * Curves.easeInOut.transform(t);
      if (t >= 1) {
        _pos = widget.done.toDouble();
        _stop();
      }
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final x = w.startX + (w.goalX - w.startX) * (_pos / max(1, w.total));
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned(
      left: min(x, w.goalX) - w.size / 2,
      bottom: w.bottom,
      child: walking
          ? WalkView(
              equipped: w.equipped,
              step: step,
              size: w.size,
              still: calm,
            )
          : CharacterView(equipped: w.equipped, cheer: w.cheer, size: w.size),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween(begin: .6, end: 1),
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutBack,
    builder: (_, s, child) => Transform.scale(
      scale: s,
      alignment: Alignment.bottomLeft,
      child: child,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: TextSizes.button, color: Palette.text),
      ),
    ),
  );
}

/// 골인했을 때 깃발 위로 반짝이는 "골인!"
class _GoalBurst extends StatelessWidget {
  const _GoalBurst();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 600),
    curve: Curves.elasticOut,
    builder: (_, t, child) => Transform.scale(scale: t, child: child),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Palette.pink,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const FitBox(
          child: Text(
            '골인!',
            style: TextStyle(fontSize: TextSizes.label, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({
    required this.total,
    required this.done,
    required this.xFor,
    required this.goalX,
    required this.goalW,
  });

  final int total;
  final int done;
  final double Function(int) xFor;
  final double goalX;
  final double goalW;

  static const ink = Color(0xFF5B4033);

  @override
  void paint(Canvas c, Size size) {
    final h = size.height;
    final roadTop = h * .62;
    // 모래길
    final road = RRect.fromLTRBR(
      0,
      roadTop,
      size.width,
      h,
      Radius.circular(h * .19),
    );
    c.drawRRect(road, Paint()..color = const Color(0xFFF0DDB2));
    c.drawRRect(
      road,
      Paint()
        ..color = const Color(0xFFDCC392)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // 지나온 길은 진하게
    final passedTo = xFor(min(done, total));
    c.drawRRect(
      RRect.fromLTRBR(
        4,
        roadTop + 4,
        max(8, passedTo),
        h - 4,
        Radius.circular(h * .17),
      ),
      Paint()..color = const Color(0xFFFFE7A8),
    );
    // 가운데 점선
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final midY = (roadTop + h) / 2;
    for (var x = 16.0; x < goalX - goalW / 2; x += 28) {
      c.drawLine(Offset(x, midY), Offset(x + 12, midY), dash);
    }
    // 중간 깃발 (번호)
    for (var i = 1; i < total; i++) {
      _flag(
        c,
        Offset(xFor(i), roadTop + 4),
        h * .5,
        i <= done ? const Color(0xFFF59AB5) : const Color(0xFFE8DDCB),
        '$i',
      );
    }
    // 골인 아치 + 체크무늬 깃발
    _goal(c, Offset(goalX, roadTop + 6), goalW, h);
  }

  void _flag(Canvas c, Offset base, double height, Color color, String label) {
    final pole = Paint()
      ..color = ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final top = base - Offset(0, height);
    c.drawLine(base, top, pole);
    final flag = Path()
      ..moveTo(top.dx + 2, top.dy)
      ..lineTo(top.dx + height * .55, top.dy + height * .18)
      ..lineTo(top.dx + 2, top.dy + height * .36)
      ..close();
    c.drawPath(flag, Paint()..color = color);
    c.drawPath(
      flag,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Jua',
          fontSize: height * .22,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, top + Offset(height * .1, height * .18 - tp.height / 2));
  }

  void _goal(Canvas c, Offset base, double w, double h) {
    final left = base.dx - w * .42, right = base.dx + w * .42;
    final top = base.dy - h * .72;
    final post = Paint()
      ..color = ink
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(left, base.dy), Offset(left, top), post);
    c.drawLine(Offset(right, base.dy), Offset(right, top), post);
    // 체크무늬 현수막
    final banner = Rect.fromLTRB(
      left - 4,
      top - h * .02,
      right + 4,
      top + h * .16,
    );
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(banner, const Radius.circular(6)));
    final cell = banner.height / 2;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col * cell < banner.width; col++) {
        c.drawRect(
          Rect.fromLTWH(
            banner.left + col * cell,
            banner.top + row * cell,
            cell,
            cell,
          ),
          Paint()
            ..color = (row + col).isEven
                ? Colors.white
                : const Color(0xFF3D3D3D),
        );
      }
    }
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(banner, const Radius.circular(6)),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // 풍선 장식
    for (final (x, color) in [
      (left, const Color(0xFFF26B5E)),
      (right, const Color(0xFF5B9BE6)),
    ]) {
      final o = Offset(x, top - h * .08);
      c.drawOval(
        Rect.fromCenter(center: o, width: h * .14, height: h * .17),
        Paint()..color = color,
      );
      c.drawOval(
        Rect.fromCenter(center: o, width: h * .14, height: h * .17),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.done != done || old.total != total;
}
