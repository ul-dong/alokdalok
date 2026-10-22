import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import 'number_shape.dart';

/// 물건 위에 숫자 도장을 "쾅!" 찍는 효과.
///
/// [number]가 생기는 순간: 숫자가 크게 나타났다가 → 물건 위로 쿵 떨어지고 →
/// 물건이 살짝 눌렸다 튀어 오르며 도장 둘레로 잉크가 퍼진다.
class Stamped extends StatefulWidget {
  const Stamped({
    super.key,
    required this.child,
    required this.number,
    required this.badgeSize,
    this.badgeTop = 0,
    this.corner = false,
  });

  final Widget child;
  final int? number;
  final double badgeSize;
  final double badgeTop;

  /// 도장을 물건 가운데 위가 아니라 오른쪽 위 모서리에 붙인다
  /// (작은 화면에서 작은 도장이 물건을 덮지 않게). 이때 [badgeTop]은 쓰지 않는다.
  final bool corner;

  /// 모서리 도장이 물건 밖으로 나가는 정도 (도장 크기 대비)
  static const cornerOut = .22;

  /// 도장 효과 전체 길이
  static const duration = Duration(milliseconds: 520);

  /// 숫자가 생긴 뒤 도장이 물건에 "쾅" 닿기까지 걸리는 시간.
  /// 소리·진동·숫자판은 이 순간에 맞춘다.
  static final impactDelay = Duration(
    milliseconds: (duration.inMilliseconds * _StampedState.drop).round(),
  );

  @override
  State<Stamped> createState() => _StampedState();
}

class _StampedState extends State<Stamped> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Stamped.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.number != null) _c.forward();
  }

  @override
  void didUpdateWidget(Stamped old) {
    super.didUpdateWidget(old);
    if (widget.number != null && old.number != widget.number) {
      _c.forward(from: 0);
    } else if (widget.number == null) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 떨어지는 구간 (0 ~ drop), 그 뒤는 쿵 하고 눌리는 구간
  static const drop = .42;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final n = widget.number;
      final t = _c.value;
      final falling = t < drop;
      final hit = falling ? 0.0 : (t - drop) / (1 - drop); // 0→1
      // 물건 눌림: 부딪히는 순간 납작, 다시 통 튀어 오름
      final squash = n == null || falling
          ? 0.0
          : sin(pi * hit) * exp(-1.5 * hit);
      final s = widget.badgeSize;
      final badgeTop = widget.corner ? -s * Stamped.cornerOut : widget.badgeTop;
      final double? badgeRight = widget.corner ? -s * Stamped.cornerOut : null;
      final badgeScale = n == null
          ? 1.0
          : falling
          ? 3.2 - 2.2 * Curves.easeIn.transform(t / drop)
          : 1 + .18 * sin(pi * hit) * (1 - hit);
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(
              1 + .12 * squash,
              1 - .2 * squash,
              1,
            ),
            child: child,
          ),
          if (n != null) ...[
            // 잉크 퍼짐
            if (!falling && hit < 1)
              Positioned(
                top: badgeTop + s / 2 - s * (.6 + .8 * hit),
                right: badgeRight == null
                    ? null
                    : badgeRight + s / 2 - s * (.6 + .8 * hit),
                child: IgnorePointer(
                  child: Container(
                    width: s * (1.2 + 1.6 * hit),
                    height: s * (1.2 + 1.6 * hit),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NumberShape.colorOf(n)
                            .withValues(alpha: .55 * (1 - hit)),
                        width: 5,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: badgeTop,
              right: badgeRight,
              child: Opacity(
                opacity: falling ? min(1.0, t / .12) : 1,
                child: Transform.rotate(
                  angle: -.14,
                  child: Transform.scale(
                    scale: badgeScale,
                    child: _StampFace(n: n, size: s),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _StampFace extends StatelessWidget {
  const _StampFace({required this.n, required this.size});
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = NumberShape.colorOf(n);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: max(2.5, size * .09)),
        boxShadow: const [
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: size * .58,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

/// 틀렸을 때 크게 한 번 떠오르는 말풍선 ("같이 세어 볼까요?")
class BigPop extends StatelessWidget {
  const BigPop({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(text),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.elasticOut,
    builder: (_, t, child) => Transform.scale(scale: max(0.0, t), child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Palette.yellow, width: 6),
        boxShadow: const [
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 40, color: Palette.text),
      ),
    ),
  );
}
