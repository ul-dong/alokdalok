import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/slow_clock.dart';
import '../services/audio_service.dart';
import '../services/game_state.dart';

/// 앱 어디서나 GameState를 꺼내 쓰기 위한 범위 위젯
class AppScope extends InheritedNotifier<GameState> {
  const AppScope({super.key, required GameState state, required super.child})
    : super(notifier: state);

  static GameState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static GameState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// 부드러운 화면 전환 (짧은 페이드)
Route<T> softRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: child,
  ),
);

/// 누르면 살짝 눌리는 버튼. 탭 효과음 포함. 최소 72dp.
/// [speak]가 있으면 누를 때 그 이름을 말한다 (녹음이 없는 말은 기기 음성으로).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.sound = Sfx.tap,
    this.semanticLabel,
    this.enabled = true,
    this.speak,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Sfx? sound;
  final String? semanticLabel;
  final bool enabled;

  /// 누를 때 말할 이름 (null이면 말하지 않는다)
  final String? speak;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTap: active
            ? () {
                final audio = AppScope.read(context).audio;
                if (widget.sound != null) audio.play(widget.sound!);
                if (widget.speak != null) audio.say(widget.speak!);
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? .94 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 놀이 화면의 물건(세는 물건, 견본 그림)을 누르면 이름을 말해 준다. (사양 UI 원칙 1)
/// 정답 보기 칸에는 쓰지 않는다 — 보기를 누르는 것은 답을 고르는 동작이다.
/// 효과음 없이 살짝 작아지기만 하고, [enabled]가 false면(같이 세는 중 등) 아무 일도 하지 않는다.
/// 버튼이 아니라 덤으로 듣는 것이라 물건 크기 그대로 둔다 (많이 섞인 단계에서는 물건이 작다).
class SayName extends StatefulWidget {
  const SayName({
    super.key,
    required this.name,
    required this.child,
    this.enabled = true,
    this.semanticLabel,
  });

  /// 말할 이름 (녹음 조각에 있는 문장, 예: "사과!")
  final String name;
  final Widget child;
  final bool enabled;

  /// 화면 읽기용 이름 (없으면 [name])
  final String? semanticLabel;

  @override
  State<SayName> createState() => _SayNameState();
}

class _SayNameState extends State<SayName> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel ?? widget.name,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.enabled
          ? () => AppScope.read(context).audio.say(widget.name)
          : null,
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    ),
  );
}

/// 크림색 둥근 카드 패널 (레퍼런스 스타일)
class CreamCard extends StatelessWidget {
  const CreamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Palette.cream,
    this.radius = 32,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: Palette.creamDeep, offset: Offset(0, 6)),
        BoxShadow(
          color: Palette.panelShadow,
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

/// 둥근 알약형 버튼 (아래쪽 두께감)
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Colors.white,
    this.edge = Palette.creamDeep,
    this.height = 76,
    this.width,
    this.sound = Sfx.tap,
    this.semanticLabel,
    this.enabled = true,
    this.glow = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color edge;
  final double height;
  final double? width;
  final Sfx? sound;
  final String? semanticLabel;
  final bool enabled;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      sound: sound,
      enabled: enabled,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        alignment: width != null ? Alignment.center : null,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: glow ? Palette.yellow : edge,
            width: glow ? 5 : 3,
          ),
          boxShadow: [
            BoxShadow(color: edge, offset: const Offset(0, 6)),
            if (glow)
              const BoxShadow(
                color: Color(0x88FFD45C),
                blurRadius: 22,
                spreadRadius: 4,
              ),
          ],
        ),
        child: width != null ? child : Align(widthFactor: 1, child: child),
      ),
    );
  }
}

/// 동그란 아이콘 버튼 (일시정지, 뒤로 등)
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 72,
    this.label,
    this.color = Palette.cream,
    this.speakLabel = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? label;
  final Color color;

  /// 누르면 [label]을 말한다
  final bool speakLabel;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    speak: speakLabel ? label : null,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * .48, color: Palette.text),
    ),
  );
}

/// 코인 그림 (새싹 무늬 금화)
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CoinPainter()),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    c.drawCircle(o, r, Paint()..color = Palette.coinDeep);
    c.drawCircle(o, r * .86, Paint()..color = Palette.coin);
    c.drawCircle(o, r * .66, Paint()..color = const Color(0xFFF7C65A));
    final deep = Paint()..color = Palette.coinDeep;
    final stem = Paint()
      ..color = Palette.coinDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .13
      ..strokeCap = StrokeCap.round;
    // 새싹: 줄기 + 동그란 잎 두 장
    c.drawLine(o + Offset(0, r * .42), o + Offset(0, -r * .05), stem);
    c.save();
    c.translate(o.dx - r * .2, o.dy - r * .16);
    c.rotate(-.5);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * .42, height: r * .24),
      deep,
    );
    c.restore();
    c.save();
    c.translate(o.dx + r * .2, o.dy - r * .2);
    c.rotate(.5);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * .42, height: r * .24),
      deep,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 34, this.color = Palette.yellow});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StarPainter(color)),
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * .5;
      final pt = Offset(r + cos(a) * rr, r * 1.06 + sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    c.drawPath(p, Paint()..color = color);
    c.drawPath(
      p,
      Paint()
        ..color = Color.lerp(color, Palette.outline, .45)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .12
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// 코인·별 개수 배지 (큰 숫자)
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.icon,
    required this.value,
    this.label,
  });

  final Widget icon;
  final int value;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label != null ? '$label $value' : null,
    child: Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(10, 6, 18, 6),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(29),
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, _) => Text(
              '${v.round()}',
              style: const TextStyle(
                fontSize: 30,
                color: Palette.text,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 글자 없이 진행을 보여 주는 발자국 표시
class PawProgress extends StatelessWidget {
  const PawProgress({super.key, required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$total개 중 $done개 완료',
    child: Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(29),
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedScale(
                scale: i == done - 1 ? 1.15 : 1,
                duration: const Duration(milliseconds: 300),
                child: PawIcon(size: 30, filled: i < done),
              ),
            ),
        ],
      ),
    ),
  );
}

class PawIcon extends StatelessWidget {
  const PawIcon({super.key, this.size = 30, this.filled = true});
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _PawPainter(filled ? Palette.pink : const Color(0xFFDCD2C2)),
    ),
  );
}

class _PawPainter extends CustomPainter {
  _PawPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 30;
    final p = Paint()..color = color;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(15 * u, 20 * u),
        width: 15 * u,
        height: 12 * u,
      ),
      p,
    );
    for (final o in const [
      Offset(6, 11),
      Offset(11.5, 6),
      Offset(18.5, 6),
      Offset(24, 11),
    ]) {
      c.drawCircle(Offset(o.dx * u, o.dy * u), 3.4 * u, p);
    }
  }

  @override
  bool shouldRepaint(_PawPainter old) => old.color != color;
}

/// 작은 화면에서 넘치지 않도록 내용을 줄여 맞추는 래퍼
class FitBox extends StatelessWidget {
  const FitBox({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);
}

/// 넓은 화면(태블릿·웹)에서 가운데에 폭을 제한
class PhoneWidth extends StatelessWidget {
  const PhoneWidth({super.key, required this.child, this.maxWidth = 560});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// 가로 화면용 기본 틀: 배경 장면 + 안전 영역 + 넓은 화면에서는 가운데 정렬
class LandscapePage extends StatelessWidget {
  const LandscapePage({
    super.key,
    required this.child,
    this.background,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 12),
  });

  final Widget child;
  final Widget? background;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 세로로 들고 있을 때(웹·데스크톱 창) 보여 주는 "가로로 돌려 주세요" 안내
class RotateHint extends StatefulWidget {
  const RotateHint({super.key});

  @override
  State<RotateHint> createState() => _RotateHintState();
}

class _RotateHintState extends State<RotateHint> {
  // 계속 도는 애니메이션 대신 공용 20fps 시계로 몇 번만 눕혀 보이고 멈춘다 (사양 원칙 8).
  static const _periodMs = 2400;
  static const _cycles = 3;
  int _ticks = 0;
  double _value = 0;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    SlowClock.instance.addListener(_onClock);
    _listening = true;
  }

  void _onClock() {
    if (!mounted) return;
    // 시계 한 번 = 50ms (공용 시계 박자로 센다)
    final ms = ++_ticks * SlowClock.interval.inMilliseconds;
    if (ms >= _periodMs * _cycles) {
      // 다 보여 줬으면 누운 모습으로 멈추고 시계에서 빠진다
      _stop();
      setState(() => _value = .5);
      return;
    }
    setState(() => _value = (ms % _periodMs) / _periodMs);
  }

  void _stop() {
    if (!_listening) return;
    SlowClock.instance.removeListener(_onClock);
    _listening = false;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Palette.skyBottom,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              // 0~0.5 동안 천천히 눕히고, 나머지는 멈춰 있다
              angle:
                  -Curves.easeInOut.transform((_value * 2).clamp(0.0, 1.0)) *
                  pi /
                  2,
              child: Container(
                width: 70,
                height: 120,
                decoration: BoxDecoration(
                  color: Palette.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Palette.outline, width: 5),
                ),
                child: const Center(child: StarIcon(size: 36)),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '화면을 옆으로 돌려 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, color: Palette.text),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 화면이 열려 있는 동안 배경 음악을 튼다. 닫히면 아래 화면의 음악으로 돌아간다.
mixin ScreenMusic<T extends StatefulWidget> on State<T> {
  /// 이 화면의 곡 ('home', 'shop', 'spring' …)
  String get musicTrack;

  int _musicId = 0;
  late final AudioService _musicAudio = AppScope.read(context).audio;

  @override
  void initState() {
    super.initState();
    _musicId = _musicAudio.playMusic(musicTrack);
  }

  @override
  void dispose() {
    _musicAudio.stopMusic(_musicId);
    super.dispose();
  }
}
