import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../core/palette.dart';
import '../l10n/l10n.dart';
import '../services/game_state.dart';
import '../services/play_clock.dart';
import 'common.dart';
import 'parental_gate.dart';

/// 놀이 시간·눈 쉬기 덮개. 앱 전체 화면 위에 올린다 (`app.dart`).
///
/// - 1초마다 [GameState.tickPlay]로 논 시간을 세고, 앱이 뒤로 가면 멈춘다.
/// - 이어서 오래 놀면 20초 동안 "창밖 먼 곳을 봐요" (창밖 산 + 줄어드는 고리), 끝나면 저절로 사라진다.
/// - 하루 놀이 시간이 다 되면 "오늘은 여기까지!". 부모 확인을 통과하면 15분 더.
/// - 눈 지킴이 경고가 끝나지 않으면(아이가 떠남·너무 오래) 카메라를 끄고 "쉬어 가기":
///   눈 쉬기 화면을 그대로 쓰고, 화면을 한 번 누르면 돌아온다 (부모 확인 없음).
class PlayGuardOverlay extends StatefulWidget {
  const PlayGuardOverlay({super.key});

  static const tick = Duration(seconds: 1);

  @override
  State<PlayGuardOverlay> createState() => _PlayGuardOverlayState();
}

class _PlayGuardOverlayState extends State<PlayGuardOverlay>
    with WidgetsBindingObserver {
  Timer? _timer;
  GameState? _state;
  PlayBlock _shown = PlayBlock.none;
  bool _gate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(PlayGuardOverlay.tick, (_) => _state?.tickPlay());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.read(context);
    if (!identical(s, _state)) {
      _state?.removeListener(_changed);
      _state = s..addListener(_changed);
      _shown = s.playBlock;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _state?.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final state = _state;
    if (state == null) return;
    switch (s) {
      case AppLifecycleState.resumed:
        state.resumePlay();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        state.pausePlay();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _changed() {
    final state = _state!;
    final b = state.playBlock;
    if (b == _shown) return;
    final was = _shown;
    setState(() {
      _shown = b;
      if (b != PlayBlock.limit) _gate = false;
    });
    switch (b) {
      case PlayBlock.limit:
        state.audio.say(L10n.current.play_limitSay);
      case PlayBlock.eyeBreak:
      case PlayBlock.eyeRest:
        if (was != PlayBlock.eyeBreak && was != PlayBlock.eyeRest) {
          state.audio.say(L10n.current.play_breakSay);
        }
      case PlayBlock.none:
        if (was == PlayBlock.eyeBreak || was == PlayBlock.eyeRest) {
          state.audio.say(L10n.current.play_restedSay);
        } else if (was == PlayBlock.limit) {
          state.audio.say(L10n.current.play_moreSay);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _shown;
    return IgnorePointer(
      ignoring: b == PlayBlock.none,
      child: AnimatedOpacity(
        opacity: b == PlayBlock.none ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: switch (b) {
          PlayBlock.none => const SizedBox.expand(),
          PlayBlock.eyeBreak => EyeBreakCard(play: _state!.play),
          PlayBlock.eyeRest => EyeBreakCard(onWake: _state!.wakeFromEyeRest),
          PlayBlock.limit =>
            _gate
                ? Material(
                    color: const Color(0xFFEDE7FA),
                    child: ParentalGate(
                      onResult: (ok) {
                        if (ok) {
                          _state!.extendPlay();
                        } else {
                          setState(() => _gate = false);
                        }
                      },
                    ),
                  )
                : PlayLimitCard(onParent: () => setState(() => _gate = true)),
        },
      ),
    );
  }
}

/// "오늘은 여기까지!" 덮개
class PlayLimitCard extends StatelessWidget {
  const PlayLimitCard({super.key, required this.onParent});
  final VoidCallback onParent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEDE7FA),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size = min(
                      c.maxHeight / 1.25,
                      c.maxWidth * .9,
                    ).clamp(70.0, 260.0);
                    return Center(
                      child: SizedBox(
                        width: size * 1.1,
                        height: size * 1.2,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            CharacterView(
                              equipped: AppScope.of(context).equipped,
                              size: size,
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: SizedBox.square(
                                dimension: size * .34,
                                child: const CustomPaint(
                                  painter: MoonPainter(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FitBox(
                      child: Text(
                        context.l10n.play_limitTitle,
                        style: TextStyle(fontSize: 48, color: Palette.text),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FitBox(
                      child: Text(
                        context.l10n.play_limitSub,
                        style: TextStyle(
                          fontSize: TextSizes.heading,
                          color: Palette.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FitBox(
                      child: PillButton(
                        height: 60,
                        onTap: onParent,
                        semanticLabel: context.l10n.play_parentMore,
                        child: Text(
                          context.l10n.play_parentMore,
                          style: TextStyle(
                            fontSize: TextSizes.button,
                            color: Palette.textSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "창밖 먼 곳을 봐요" 덮개: 창밖 산 그림 + 줄어드는 고리. 20초 뒤 저절로 사라진다.
///
/// [onWake]를 주면 "쉬어 가기" (눈 지킴이 경고가 끝나지 않아 카메라를 끈 때): 고리 대신
/// 누르는 손 그림을 보여 주고, 화면 어디든 한 번 누르면 [onWake]. 막 뜬 순간(1초)의 터치는 무시한다
/// (경고 화면을 두드리던 손가락에 바로 닫히지 않게).
class EyeBreakCard extends StatefulWidget {
  const EyeBreakCard({super.key, this.play, this.onWake})
    : assert((play == null) != (onWake == null));
  final PlayClock? play;
  final VoidCallback? onWake;

  /// 쉬어 가기 화면이 뜬 뒤 이만큼은 터치를 받지 않는다
  static const wakeDelay = Duration(seconds: 1);

  @override
  State<EyeBreakCard> createState() => _EyeBreakCardState();
}

class _EyeBreakCardState extends State<EyeBreakCard> {
  // 남은 시간 고리는 1초에 한 번만 다시 그린다 (덮개가 떠 있는 동안 공용 시계는 멈춰 있다)
  Timer? _tick, _ready;

  @override
  void initState() {
    super.initState();
    if (widget.onWake != null) {
      _ready = Timer(EyeBreakCard.wakeDelay, () => _ready = null);
    }
    if (widget.play != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ready?.cancel();
    super.dispose();
  }

  void _tap() {
    if (_ready != null) return; // 막 떴다
    widget.onWake?.call();
  }

  @override
  Widget build(BuildContext context) {
    final card = _card();
    if (widget.onWake == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Semantics(
        button: true,
        label: context.l10n.play_tapToPlay,
        child: card,
      ),
    );
  }

  Widget _card() {
    final play = widget.play;
    return Material(
      color: Palette.skyBottom,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: CustomPaint(painter: const WindowViewPainter()),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FitBox(
                      child: Text(
                        context.l10n.play_breakTitle,
                        style: TextStyle(fontSize: 40, color: Palette.text),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (play == null) ...[
                      const Flexible(child: _TapToPlay()),
                    ] else
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 170,
                            maxHeight: 170,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Builder(
                              builder: (context) {
                                final left = play.breakLeft ?? Duration.zero;
                                final f =
                                    left.inMilliseconds /
                                    SafetyRules.breakLength.inMilliseconds;
                                return CustomPaint(
                                  painter: ShrinkingRingPainter(
                                    f.clamp(0.0, 1.0),
                                  ),
                                  child: Center(
                                    child: FitBox(
                                      child: Text(
                                        '${(left.inMilliseconds / 1000).ceil()}',
                                        style: const TextStyle(
                                          fontSize: 44,
                                          color: Palette.textSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 쉬어 가기: "다 쉬었으면 눌러요" (누르는 손)
class _TapToPlay extends StatelessWidget {
  const _TapToPlay();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130, maxHeight: 130),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.mint,
                shape: BoxShape.circle,
              ),
              child: LayoutBuilder(
                builder: (context, c) => Icon(
                  Icons.touch_app_rounded,
                  size: c.maxWidth * .6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      FitBox(
        child: Text(
          context.l10n.play_restDone,
          style: TextStyle(fontSize: 24, color: Palette.textSoft),
        ),
      ),
    ],
  );
}

/// 남은 시간만큼 남는 고리 (12시 방향부터 시계 방향)
class ShrinkingRingPainter extends CustomPainter {
  const ShrinkingRingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas c, Size s) {
    final r = min(s.width, s.height) / 2;
    final stroke = r * .2;
    final o = Offset(s.width / 2, s.height / 2);
    final rect = Rect.fromCircle(center: o, radius: r - stroke / 2);
    c.drawCircle(
      o,
      r - stroke / 2,
      Paint()
        ..color = Palette.creamDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    c.drawArc(
      rect,
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()
        ..color = Palette.mint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(ShrinkingRingPainter old) => old.fraction != fraction;
}

/// 창틀 너머로 보이는 먼 산, 해, 구름
class WindowViewPainter extends CustomPainter {
  const WindowViewPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final frame = w * .06;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & s,
      Radius.circular(w * .06),
    );
    final inner = Rect.fromLTWH(frame, frame, w - frame * 2, h - frame * 2);

    // 창틀
    c.drawRRect(outer, Paint()..color = const Color(0xFFD9B48F));
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(w * .03)));

    // 하늘
    c.drawRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.skyTop, Color(0xFFF4FAFE)],
        ).createShader(inner),
    );

    // 해
    c.drawCircle(
      Offset(inner.left + inner.width * .78, inner.top + inner.height * .22),
      inner.width * .07,
      Paint()..color = const Color(0xFFFFE08A),
    );

    // 구름
    void cloud(double cx, double cy, double r) {
      final p = Paint()..color = Colors.white;
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx - r * .9, cy + r * .25), r * .7, p);
      c.drawCircle(Offset(cx + r * .9, cy + r * .25), r * .75, p);
    }

    cloud(
      inner.left + inner.width * .25,
      inner.top + inner.height * .2,
      inner.width * .05,
    );
    cloud(
      inner.left + inner.width * .55,
      inner.top + inner.height * .13,
      inner.width * .035,
    );

    // 먼 산 (흐린 파랑) → 가까운 산 (초록)
    Path ridge(List<(double, double)> pts, double base) {
      final p = Path()..moveTo(inner.left, inner.top + inner.height * base);
      for (final (x, y) in pts) {
        p.lineTo(inner.left + inner.width * x, inner.top + inner.height * y);
      }
      p
        ..lineTo(inner.right, inner.bottom)
        ..lineTo(inner.left, inner.bottom)
        ..close();
      return p;
    }

    c.drawPath(
      ridge(const [
        (0.0, .62),
        (.18, .42),
        (.32, .55),
        (.5, .34),
        (.68, .52),
        (.84, .4),
        (1.0, .56),
      ], .62),
      Paint()..color = const Color(0xFFA9C8E8),
    );
    // 먼 산 꼭대기 눈
    final snow = Paint()..color = Colors.white.withValues(alpha: .85);
    for (final (x, y) in const [(.18, .42), (.5, .34), (.84, .4)]) {
      final px = inner.left + inner.width * x;
      final py = inner.top + inner.height * y;
      c.drawPath(
        Path()
          ..moveTo(px, py)
          ..lineTo(px - inner.width * .045, py + inner.height * .07)
          ..lineTo(px + inner.width * .045, py + inner.height * .07)
          ..close(),
        snow,
      );
    }
    c.drawPath(
      ridge(const [
        (0.0, .74),
        (.22, .6),
        (.42, .72),
        (.62, .58),
        (.82, .7),
        (1.0, .64),
      ], .74),
      Paint()..color = Palette.grass,
    );
    c.drawPath(
      ridge(const [(0.0, .88), (.3, .8), (.6, .86), (1.0, .8)], .88),
      Paint()..color = Palette.grassDeep,
    );
    c.restore();

    // 창살 (가운데 십자)
    final bar = Paint()..color = const Color(0xFFD9B48F);
    c.drawRect(
      Rect.fromCenter(
        center: inner.center,
        width: frame * .6,
        height: inner.height,
      ),
      bar,
    );
    c.drawRect(
      Rect.fromCenter(
        center: inner.center,
        width: inner.width,
        height: frame * .6,
      ),
      bar,
    );
    // 창틀 테두리
    c.drawRRect(
      outer.deflate(1.5),
      Paint()
        ..color = Palette.outlineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(WindowViewPainter old) => false;
}

/// 초승달과 별 (잘 시간)
class MoonPainter extends CustomPainter {
  const MoonPainter();

  @override
  void paint(Canvas c, Size s) {
    final r = s.width * .36;
    final o = Offset(s.width * .5, s.height * .5);
    final moon = Path()..addOval(Rect.fromCircle(center: o, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(center: o + Offset(r * .55, -r * .3), radius: r * .85),
      );
    c.drawPath(
      Path.combine(PathOperation.difference, moon, bite),
      Paint()..color = Palette.yellow,
    );
    final star = Paint()..color = Palette.coin;
    for (final (x, y, k) in const [(.85, .2, .07), (.9, .75, .05)]) {
      c.drawCircle(Offset(s.width * x, s.height * y), s.width * k, star);
    }
  }

  @override
  bool shouldRepaint(MoonPainter old) => false;
}
