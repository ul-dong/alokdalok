import 'dart:math';

import 'package:flutter/material.dart';

import '../core/slow_clock.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import 'animal_painter.dart';
import 'zodiac.dart';

/// 움직이는 캐릭터. [cheer] 값이 바뀔 때마다 한 번 폴짝 뛰며 기뻐한다.
class CharacterView extends StatefulWidget {
  const CharacterView({
    super.key,
    required this.equipped,
    this.cheer = 0,
    this.mood = CharMood.normal,
    this.size = 200,
    this.zodiac,
  });

  /// 그릴 동물 (없으면 지금 고른 동물)
  final Zodiac? zodiac;

  /// 부위별 장착 아이템 id
  final Map<ItemSlot, String> equipped;
  final int cheer;
  final CharMood mood;
  final double size;

  static Map<ItemSlot, Item> resolve(Map<ItemSlot, String> ids) => {
    for (final e in ids.entries)
      if (ItemCatalog.byId(e.value) != null) e.key: ItemCatalog.byId(e.value)!,
  };

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with TickerProviderStateMixin {
  // 숨쉬기(살랑살랑)는 느린 움직임이라 초당 15번만 바꾼다.
  // 60fps 애니메이션을 계속 돌리면 화면 전체를 쉬지 않고 다시 그려서 기기가 뜨거워진다.
  static const _idlePeriodMs = 3200;
  double _idleT = 0;

  void _onClock() {
    if (!mounted || _hop.isAnimating) return;
    final ms = (SlowClock.instance.seconds * 1000).round();
    setState(() => _idleT = (ms % _idlePeriodMs) / _idlePeriodMs);
  }

  @override
  void initState() {
    super.initState();
    SlowClock.instance.addListener(_onClock);
  }

  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (widget.cheer != old.cheer) _hop.forward(from: 0);
  }

  @override
  void dispose() {
    SlowClock.instance.removeListener(_onClock);
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = CharacterView.resolve(widget.equipped);
    final zodiac = widget.zodiac ?? AppScope.of(context).zodiac;
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.2,
      child: AnimatedBuilder(
        animation: _hop,
        builder: (context, _) {
          final t = _idleT;
          final h = _hop.value;
          final hopping = _hop.isAnimating;
          // 부드러운 숨쉬기 + 폴짝 (두 번 작게)
          final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          final bob = calm ? 0.0 : sin(t * 2 * pi) * 2.5;
          final jump = hopping
              ? -sin(h * 2 * pi).abs() * widget.size * .09
              : 0.0;
          final squash = hopping ? 1 + sin(h * 4 * pi) * .03 : 1.0;
          return Transform.translate(
            offset: Offset(0, bob + jump),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1 / squash, squash, 1),
              // 숨쉬기는 위치만 옮기고(GPU), 그림 자체는 초당 약 12번만 다시 그린다 (발열 줄이기)
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: AnimalPainter(
                    zodiac: zodiac,
                    items: items,
                    mood: hopping ? CharMood.happy : widget.mood,
                    phase: (t * 40).floorToDouble() / 40,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
