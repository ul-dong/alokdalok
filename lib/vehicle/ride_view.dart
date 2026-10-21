import 'dart:math';

import 'package:flutter/material.dart';

import '../core/slow_clock.dart';

import '../character/animal_painter.dart';
import '../character/character_view.dart';
import '../data/vehicles.dart';
import '../widgets/common.dart';
import 'vehicle_painter.dart';

/// 지금 고른 탈것에 내 친구가 탄 모습. 탈것이 없으면 걸어 다니는 친구를 보여 준다.
/// 탄 친구는 가는 쪽(오른쪽)을 보고 앉는다 (`RiderPose`, 24마리 공통 변환).
/// [cheer]가 바뀌면 웃으며 한 번 폴짝, [moving]이면 바퀴가 굴러가고 불꽃이 흔들린다.
class RideView extends StatefulWidget {
  const RideView({
    super.key,
    required this.width,
    this.cheer = 0,
    this.moving = false,
    this.vehicleId,
    this.showRider = true,
  });

  final double width;
  final int cheer;
  final bool moving;

  /// 보여 줄 탈것 (없으면 지금 타는 탈것)
  final String? vehicleId;
  final bool showRider;

  @override
  State<RideView> createState() => _RideViewState();
}

class _RideViewState extends State<RideView> with TickerProviderStateMixin {
  // 바퀴·불꽃 움직임: 달릴 때만, 초당 20번 (발열 줄이기). 서 있으면 멈춘다.
  static const _loopMs = 1600;
  bool _ticking = false;
  double _loopT = 0;

  void _onClock() {
    if (!mounted) return;
    final ms = (SlowClock.instance.seconds * 1000).round();
    setState(() => _loopT = (ms % _loopMs) / _loopMs);
  }

  void _syncTicker() {
    if (widget.moving && !_ticking) {
      SlowClock.instance.addListener(_onClock);
      _ticking = true;
    } else if (!widget.moving && _ticking) {
      SlowClock.instance.removeListener(_onClock);
      _ticking = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(RideView old) {
    super.didUpdateWidget(old);
    if (widget.cheer != old.cheer) _hop.forward(from: 0);
    _syncTicker();
  }

  @override
  void dispose() {
    if (_ticking) SlowClock.instance.removeListener(_onClock);
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final id = widget.vehicleId ?? state.ride;
    final vehicle = id == null ? null : Vehicles.byId(id);
    if (vehicle == null) {
      // 걸어 다니기: 캐릭터 비율(1 : 1.2)에 맞춰 같은 높이를 쓴다
      final h = widget.width * 2 / 3;
      return SizedBox(
        width: widget.width,
        height: h,
        child: Center(
          child: CharacterView(
            equipped: state.equipped,
            cheer: widget.cheer,
            size: h / 1.2,
          ),
        ),
      );
    }
    final stickers = state.stickersOf(vehicle.id);
    final items = CharacterView.resolve(state.equipped);
    return SizedBox(
      width: widget.width,
      height: widget.width * 2 / 3,
      child: AnimatedBuilder(
        animation: _hop,
        builder: (context, _) {
          final bump = widget.moving
              ? sin(_loopT * 2 * pi * 4).abs() * widget.width * .01
              : 0.0;
          final hop = _hop.isAnimating
              ? -sin(_hop.value * pi) * widget.width * .08
              : 0.0;
          return Transform.translate(
            offset: Offset(0, hop - bump),
            // 그림은 따로 떼어 두고(RepaintBoundary) 초당 20번만 새로 그린다 (발열 줄이기).
            // 서 있을 때는 그림이 바뀌지 않으므로 다시 그리지 않는다.
            child: RepaintBoundary(
              child: CustomPaint(
                painter: VehiclePainter(
                  vehicle: vehicle,
                  paint: state.paintOf(vehicle.id),
                  stickers: stickers,
                  zodiac: widget.showRider ? state.zodiac : null,
                  items: items,
                  phase: widget.moving ? (_loopT * 32).floorToDouble() / 32 : 0,
                  moving: widget.moving,
                  mood: _hop.isAnimating ? CharMood.happy : CharMood.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
