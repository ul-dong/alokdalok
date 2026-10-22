import 'dart:math';

import 'package:flutter/material.dart';

import '../../character/animal_painter.dart';
import '../../character/character_view.dart';
import '../../core/economy.dart';
import '../../core/palette.dart';
import '../../services/audio_service.dart';
import '../../services/eye_guard.dart';
import '../../services/game_state.dart';
import '../../widgets/common.dart';
import '../../widgets/hold_button.dart';
import '../../widgets/poke_character.dart';
import 'journey_trail.dart';
import 'scene_game.dart';

/// 숫자·색깔 놀이 공통 화면 틀: 배경, 상단 상태 표시줄(일시정지·발자국·별·코인),
/// 캐릭터와 말풍선, 일시정지·결과 화면.
class GameFrame extends StatefulWidget {
  const GameFrame({
    super.key,
    required this.done,
    required this.card,
    required this.cheer,
    required this.bubble,
    required this.onReady,
    this.season,
    required this.result,
    required this.onReplay,
    this.onNext,
    this.total = Economy.questionsPerSession,
    this.mood = CharMood.normal,
  });

  final int done;
  final int total;

  /// 문제 카드 (문제 + 보기)
  final Widget card;
  final int cheer;
  final String? bubble;
  final CharMood mood;
  final ValueChanged<SceneGame> onReady;

  /// 이 단계의 계절 (배경과 음악). null이면 오늘 날짜의 계절.
  final Season? season;

  /// 결과 (null이면 아직 놀이 중)
  final SessionSummary? result;
  final VoidCallback onReplay;
  final VoidCallback? onNext;

  @override
  State<GameFrame> createState() => _GameFrameState();
}

class SessionSummary {
  const SessionSummary({
    required this.coins,
    required this.stars,
    required this.reward,
    this.total = Economy.questionsPerSession,
  });
  final int coins;

  /// 한 번에 맞힌 문제 수 (= 노란 별 수)
  final int stars;

  /// 한 판의 문제 수 (= 별 칸 수)
  final int total;
  final SessionReward reward;
}

class _GameFrameState extends State<GameFrame> {
  bool _paused = false;

  /// 눈 지킴이: 놀이 화면이 보이는 동안만 카메라를 켜고, 멈춤 화면에서는 끈다
  EyeGuard? _eye;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final eye = AppScope.read(context).eye;
    if (!identical(eye, _eye)) {
      _eye?.hidePlay(this);
      _eye = eye..showPlay(this, paused: _paused);
    }
  }

  @override
  void dispose() {
    _eye?.hidePlay(this);
    super.dispose();
  }

  void _setPaused(bool on) {
    setState(() => _paused = on);
    _eye?.showPlay(this, paused: on);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // 멈춤·결과 화면이 덮고 있으면 뒤의 배경(구름·새)과 캐릭터 움직임을 멈춘다 (다시 그리지 않게)
    final still = _paused || widget.result != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setPaused(true);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: TickerMode(
                enabled: !still,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SceneBackground(
                        groundLevel: .78,
                        season: widget.season,
                        onReady: widget.onReady,
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 60,
                                  child: Row(
                                    children: [
                                      RoundIconButton(
                                        icon: Icons.pause_rounded,
                                        label: '잠깐 멈추기',
                                        size: 58,
                                        onTap: () {
                                          state.audio.stopVoice();
                                          _setPaused(true);
                                        },
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: FitBox(
                                            child: PawProgress(
                                              total: widget.total,
                                              done: widget.done,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FitBox(
                                        child: CountBadge(
                                          icon: const CoinIcon(size: 32),
                                          value: state.coins,
                                          label: '코인',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      // 아래쪽은 골인 지점까지 가는 길, 위쪽은 문제 카드
                                      final trailH = (c.maxHeight * .3).clamp(
                                        64.0,
                                        150.0,
                                      );
                                      return Column(
                                        children: [
                                          Expanded(child: widget.card),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: trailH,
                                            child: JourneyTrail(
                                              total: widget.total,
                                              done: widget.done,
                                              cheer: widget.cheer,
                                              bubble: widget.bubble,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_paused) _PauseOverlay(onResume: () => _setPaused(false)),
            if (widget.result != null)
              _ResultOverlay(
                summary: widget.result!,
                onReplay: widget.onReplay,
                onNext: widget.onNext,
              ),
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Container(
      color: const Color(0x803E2A20),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(Gaps.lg),
      child: FitBox(
        child: CreamCard(
          padding: const EdgeInsets.all(28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BigChoice(
                icon: Icons.play_arrow_rounded,
                label: '계속',
                color: Palette.mint,
                onTap: onResume,
              ),
              const SizedBox(width: 24),
              // 실수로 나가지 않게 약 1초 꾹 눌러야 집으로 간다 (고리가 차오름)
              HoldToConfirm(
                icon: Icons.home_rounded,
                label: '집으로',
                color: Palette.sky,
                onConfirmed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: Depth.raised(Depth.edgeOf(color)),
          ),
          child: Icon(icon, size: 60, color: Colors.white),
        ),
        const SizedBox(height: Gaps.sm + 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: TextSizes.label,
            color: Palette.text,
          ),
        ),
      ],
    ),
  );
}

class _ResultOverlay extends StatefulWidget {
  const _ResultOverlay({
    required this.summary,
    required this.onReplay,
    this.onNext,
  });
  final SessionSummary summary;
  final VoidCallback onReplay;
  final VoidCallback? onNext;

  @override
  State<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<_ResultOverlay> {
  int _cheer = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _cheer++);
    });
  }

  /// 오른쪽 내용(리본·별·코인·버튼)을 그리는 기준 크기. 칸에 맞춰 통째로 줄이거나 키운다.
  static const contentSize = Size(420, 372);

  /// 오른쪽 내용 배율의 범위. 아래 한계는 버튼(104)이 60px 아래로 줄지 않게.
  static const minScale = .6;
  static const maxScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = widget.summary;
    final totalCoins = s.coins + s.reward.total;
    return Positioned.fill(
      // 어두운 막 대신 따뜻한 크림빛 막: 축하하는 밝은 분위기 (번쩍임 없이 한 번 서서히)
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        builder: (_, t, child) => Opacity(opacity: t, child: child),
        child: Container(
          color: const Color(0xCCFFF1D6),
          child: Stack(
            children: [
              // 화면 가장자리에 흩어진 색종이 (멈춰 있는 그림)
              const Positioned.fill(
                child: CustomPaint(painter: ConfettiPainter()),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1120,
                      maxHeight: 660,
                    ),
                    child: CreamCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 왼쪽: 햇살 무늬 위에 크게 선 내 친구
                          Expanded(flex: 9, child: _hero(state)),
                          const SizedBox(width: 10),
                          // 오른쪽: 리본, 별, 코인, 열린 단계, 버튼
                          Expanded(
                            flex: 11,
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final k = min(
                                  c.maxWidth / contentSize.width,
                                  c.maxHeight / contentSize.height,
                                ).clamp(minScale, maxScale);
                                return Center(
                                  child: SizedBox(
                                    width: contentSize.width * k,
                                    height: contentSize.height * k,
                                    child: FittedBox(
                                      child: SizedBox.fromSize(
                                        size: contentSize,
                                        child: _content(s, totalCoins),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 왼쪽 무대: 옅은 노란 바탕 + 햇살 + 색종이 + 큰 캐릭터 (누르면 콕 반응)
  Widget _hero(GameState state) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.lg),
    child: ColoredBox(
      color: const Color(0xFFFFF5D9),
      child: LayoutBuilder(
        builder: (context, c) {
          final size = min(
            c.maxHeight * .86 / 1.2,
            c.maxWidth * .82,
          ).clamp(60.0, 420.0).toDouble();
          return Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: SunburstPainter()),
              ),
              const Positioned.fill(
                child: CustomPaint(
                  painter: ConfettiPainter(
                    count: 16,
                    seed: 11,
                    hole: Size(.62, .7),
                  ),
                ),
              ),
              // 발밑 그림자 무대
              Positioned(
                bottom: c.maxHeight * .07,
                child: Container(
                  width: size * .8,
                  height: size * .12,
                  decoration: BoxDecoration(
                    color: const Color(0x22C98A1E),
                    borderRadius: BorderRadius.circular(size),
                  ),
                ),
              ),
              Positioned(
                bottom: c.maxHeight * .07 + size * .04,
                child: PokeCharacter(
                  child: CharacterView(
                    equipped: state.equipped,
                    cheer: _cheer,
                    size: size,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _content(SessionSummary s, int totalCoins) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const _Ribbon(text: '정말 잘했어요!'),
      const SizedBox(height: Gaps.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < s.total; i++)
            _PopIn(
              delayMs: 200 + i * 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: StarIcon(
                  // 가운데 별이 가장 크다 (왕관처럼)
                  size: 44 + (2 - (i - (s.total - 1) / 2).abs()) * 5.0,
                  color: i < s.stars ? Palette.yellow : const Color(0xFFE6DCCB),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: Gaps.md),
      FitBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PopIn(
              delayMs: 850,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 22, 8),
                decoration: chipDecoration(color: Palette.yellowSoft),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 42),
                    const SizedBox(width: Gaps.sm),
                    Text(
                      '+$totalCoins',
                      style: const TextStyle(
                        fontSize: TextSizes.hero,
                        color: Palette.coinDeep,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (s.reward.unlockedStage != null) ...[
              const SizedBox(width: Gaps.lg),
              const Icon(
                Icons.lock_open_rounded,
                size: 26,
                color: Color(0xFFE0607E),
              ),
              const SizedBox(width: Gaps.xs),
              Text(
                '${s.reward.unlockedStage}단계가 열렸어요!',
                style: const TextStyle(
                  fontSize: TextSizes.label,
                  color: Color(0xFFE0607E),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: Gaps.lg + 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BigChoice(
            icon: Icons.replay_rounded,
            label: '또 하기',
            color: Palette.pink,
            onTap: widget.onReplay,
          ),
          if (widget.onNext != null) ...[
            const SizedBox(width: Gaps.lg + 4),
            _BigChoice(
              icon: Icons.arrow_forward_rounded,
              label: '다음 단계',
              color: Palette.mint,
              onTap: widget.onNext!,
            ),
          ],
          const SizedBox(width: Gaps.lg + 4),
          _BigChoice(
            icon: Icons.home_rounded,
            label: '집으로',
            color: Palette.sky,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ],
  );
}

/// 한 번만 통 튀어나온다 (계속 움직이지 않는다)
class _PopIn extends StatelessWidget {
  const _PopIn({required this.delayMs, required this.child});
  final int delayMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = delayMs + 360;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (_, t, c) {
        final local = ((t * total - delayMs) / 360).clamp(0.0, 1.0);
        return Transform.scale(
          scale: Curves.easeOutBack.transform(local),
          child: c,
        );
      },
      child: child,
    );
  }
}

/// 분홍 리본 이름표 (양 끝이 V자로 갈라진 띠)
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _RibbonPainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(56, 10, 56, 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: TextSizes.heading + 2,
          color: Colors.white,
          height: 1.1,
          shadows: [Shadow(color: Color(0x55A8405E), offset: Offset(0, 2))],
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height - 6;
    final ol = Paint()
      ..color = Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    // 뒤쪽 꼬리 (조금 어둡게)
    const tailColor = Color(0xFFE07C9C);
    for (final left in [true, false]) {
      final x0 = left ? 0.0 : w;
      final d = left ? 1.0 : -1.0;
      final tail = Path()
        ..moveTo(x0 + d * 30, 12)
        ..lineTo(x0, 12)
        ..lineTo(x0 + d * 14, h * .5 + 10)
        ..lineTo(x0, h + 6)
        ..lineTo(x0 + d * 30, h + 6)
        ..close();
      c.drawPath(tail, Paint()..color = tailColor);
      c.drawPath(tail, ol);
    }
    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(20, 0, w - 40, h),
      const Radius.circular(14),
    );
    c.drawRRect(band.shift(const Offset(0, 4)), Paint()..color = tailColor);
    c.drawRRect(band, Paint()..color = Palette.pink);
    c.drawRRect(band, ol);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 캐릭터 뒤의 햇살 무늬 (멈춰 있는 옅은 노란 빛살)
class SunburstPainter extends CustomPainter {
  const SunburstPainter();

  @override
  void paint(Canvas c, Size s) {
    final o = Offset(s.width / 2, s.height * .55);
    final r = s.width * .55;
    c.drawCircle(o, r * .5, Paint()..color = const Color(0x55FFE08A));
    final ray = Paint()..color = const Color(0x33FFCF4D);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final p = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + cos(a - .13) * r, o.dy + sin(a - .13) * r)
        ..lineTo(o.dx + cos(a + .13) * r, o.dy + sin(a + .13) * r)
        ..close();
      c.drawPath(p, ray);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 결과 화면의 색종이·별 (정해진 자리, 움직이지 않음).
/// [hole]은 가운데를 비워 둘 타원 크기(칸에 대한 비율)로, 그 안에는 뿌리지 않는다.
class ConfettiPainter extends CustomPainter {
  const ConfettiPainter({this.count = 40, this.seed = 3, this.hole});

  final int count;
  final int seed;
  final Size? hole;

  static const _colors = [
    Color(0xFFF59AB5),
    Color(0xFFFFCF4D),
    Color(0xFF8ED6B5),
    Color(0xFF6FB7E8),
    Color(0xFFC6B5E8),
    Color(0xFFFF9A5A),
  ];

  @override
  void paint(Canvas c, Size s) {
    final rnd = Random(seed);
    for (var i = 0; i < count; i++) {
      var x = 0.0, y = 0.0;
      // 가운데 구멍 밖에 떨어질 때까지 몇 번 다시 뽑는다
      for (var tries = 0; tries < 8; tries++) {
        x = 8 + rnd.nextDouble() * (s.width - 16);
        y = 8 + rnd.nextDouble() * (s.height - 16);
        final h = hole;
        if (h == null) break;
        final dx = (x - s.width / 2) / (s.width * h.width / 2);
        final dy = (y - s.height / 2) / (s.height * h.height / 2);
        if (dx * dx + dy * dy > 1) break;
      }
      final col = _colors[i % _colors.length];
      c.save();
      c.translate(x, y);
      c.rotate(rnd.nextDouble() * pi);
      switch (i % 3) {
        case 0:
          c.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-7, -3.5, 14, 7),
              const Radius.circular(2),
            ),
            Paint()..color = col,
          );
        case 1:
          c.drawCircle(Offset.zero, 5, Paint()..color = col);
        default:
          final p = Path();
          for (var k = 0; k < 10; k++) {
            final a = -pi / 2 + k * pi / 5;
            final rr = k.isEven ? 9.0 : 4.0;
            k == 0
                ? p.moveTo(cos(a) * rr, sin(a) * rr)
                : p.lineTo(cos(a) * rr, sin(a) * rr);
          }
          c.drawPath(p..close(), Paint()..color = col);
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 정답 때 "+2" 코인이 위로 떠오르는 작은 표시
class CoinPop extends StatelessWidget {
  const CoinPop({super.key, required this.amount, required this.trigger});
  final int amount;
  final int trigger;

  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      builder: (_, t, child) => Opacity(
        // t가 딱 .7이면 (1 - .7) / .3이 1을 살짝 넘으므로 0~1로 묶는다
        opacity: t < .7 ? 1 : ((1 - t) / .3).clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, -40 * t), child: child),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 34),
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: const TextStyle(
              fontSize: TextSizes.number,
              color: Palette.coinDeep,
            ),
          ),
        ],
      ),
    );
  }
}

/// 효과음 + 음성을 한 번에
extension Speak on AudioService {
  Future<void> cheer(String text) async {
    await play(Sfx.correct);
    await say(text);
  }
}
