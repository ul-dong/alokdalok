import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/slow_clock.dart';

import '../data/item_catalog.dart';
import '../widgets/common.dart';
import '../widgets/live_transform.dart';
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
  // 숨쉬기(살랑살랑)는 느린 움직임이라 공용 20fps 시계에 맞춘다.
  // 60fps 애니메이션을 계속 돌리면 화면 전체를 쉬지 않고 다시 그려서 기기가 뜨거워진다.
  //
  // 렉 줄이기: 숨쉬기는 setState로 위젯을 다시 만들지 않는다. 위젯을 다시 만들면 홈처럼
  // LayoutBuilder 안에 있는 캐릭터 때문에 화면 전체를 초당 20번 다시 배치하고 그렸다.
  // 위치는 [LiveTransform]이, 그림은 [_phase]가 바뀔 때(초당 약 12번)만 painter가 다시 그린다.
  static const _idlePeriodMs = 3200;

  /// 숨쉬기 진행 (0~1, 시계마다)
  final _idle = ValueNotifier<double>(0);

  /// 그림에 쓰는 숨쉬기 단계 (40칸으로 끊어서 초당 약 12번만 바뀐다: 꼬리 살랑, 눈 깜빡)
  final _phase = ValueNotifier<double>(0);

  /// 폴짝 뛰는 중인지 (웃는 얼굴)
  final _hopping = ValueNotifier<bool>(false);

  void _onClock() {
    if (!mounted || _hop.isAnimating) return;
    final ms = (SlowClock.instance.seconds * 1000).round();
    final t = (ms % _idlePeriodMs) / _idlePeriodMs;
    _idle.value = t;
    _phase.value = (t * 40).floorToDouble() / 40;
  }

  // 멈춤 화면·덮개가 가리면(TickerMode 꺼짐) 숨쉬기를 멈추고 시계에서 빠진다
  ValueListenable<TickerModeData>? _tickerOn;
  bool _listening = false;

  void _syncClock() {
    final on = _tickerOn?.value.enabled ?? true;
    if (on == _listening) return;
    _listening = on;
    on
        ? SlowClock.instance.addListener(_onClock)
        : SlowClock.instance.removeListener(_onClock);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = TickerMode.getValuesNotifier(context);
    if (!identical(n, _tickerOn)) {
      _tickerOn?.removeListener(_syncClock);
      _tickerOn = n..addListener(_syncClock);
    }
    _syncClock();
  }

  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addStatusListener((_) => _hopping.value = _hop.isAnimating);

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (widget.cheer != old.cheer) _hop.forward(from: 0);
  }

  @override
  void dispose() {
    _tickerOn?.removeListener(_syncClock);
    if (_listening) SlowClock.instance.removeListener(_onClock);
    _hop.dispose();
    _idle.dispose();
    _phase.dispose();
    _hopping.dispose();
    super.dispose();
  }

  late final Listenable _move = Listenable.merge([_idle, _hop]);
  late final Listenable _look = Listenable.merge([_phase, _hopping]);

  @override
  Widget build(BuildContext context) {
    final items = CharacterView.resolve(widget.equipped);
    final zodiac = widget.zodiac ?? AppScope.of(context).zodiac;
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final size = widget.size;
    final mood = widget.mood;
    // 숨쉬기·폴짝은 이 칸 안에서만 다시 그린다 (RepaintBoundary)
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size * 1.2,
        child: LiveTransform(
          listenable: _move,
          transform: (box) {
            final hopping = _hop.isAnimating;
            final h = _hop.value;
            // 부드러운 숨쉬기 + 폴짝 (두 번 작게)
            final bob = calm ? 0.0 : sin(_idle.value * 2 * pi) * 2.5;
            final jump = hopping ? -sin(h * 2 * pi).abs() * size * .09 : 0.0;
            final squash = hopping ? 1 + sin(h * 4 * pi) * .03 : 1.0;
            if (bob == 0 && jump == 0 && squash == 1) return null;
            return Matrix4.translationValues(0, bob + jump, 0)..multiply(
              transformAround(
                box,
                Alignment.bottomCenter,
                Matrix4.diagonal3Values(1 / squash, squash, 1),
              ),
            );
          },
          // 숨쉬기는 위치만 옮기고(GPU), 그림 자체는 초당 약 12번만 다시 그린다 (발열 줄이기)
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _LivePainter(
                repaint: _look,
                make: () => AnimalPainter(
                  zodiac: zodiac,
                  items: items,
                  mood: _hopping.value ? CharMood.happy : mood,
                  phase: _phase.value,
                ),
                // 같은 모습이면 위젯을 다시 만들어도 다시 그리지 않는다
                key: (zodiac, items, mood),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [repaint]가 알릴 때 [make]로 그 순간의 그림을 만들어 그린다 (위젯을 다시 만들지 않고).
class _LivePainter extends CustomPainter {
  _LivePainter({required super.repaint, required this.make, required this.key});
  final AnimalPainter Function() make;
  final (Zodiac, Map<ItemSlot, Item>, CharMood) key;

  @override
  void paint(Canvas canvas, Size size) => make().paint(canvas, size);

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.key.$1 != key.$1 ||
      old.key.$3 != key.$3 ||
      !mapEquals(old.key.$2, key.$2);
}
