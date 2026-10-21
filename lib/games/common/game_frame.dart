import 'package:flutter/material.dart';

import '../../character/animal_painter.dart';
import '../../character/character_view.dart';
import '../../core/economy.dart';
import '../../core/palette.dart';
import '../../services/audio_service.dart';
import '../../services/game_state.dart';
import '../../widgets/common.dart';
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
  });
  final int coins;
  final int stars;
  final SessionReward reward;
}

class _GameFrameState extends State<GameFrame> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paused = true);
      },
      child: Scaffold(
        body: Stack(
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
                                  setState(() => _paused = true);
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
            if (_paused)
              _PauseOverlay(onResume: () => setState(() => _paused = false)),
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
      color: const Color(0x663E2A20),
      alignment: Alignment.center,
      child: CreamCard(
        padding: const EdgeInsets.all(28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BigChoice(
              icon: Icons.play_arrow_rounded,
              label: '계속',
              color: Palette.mint,
              onTap: onResume,
            ),
            const SizedBox(width: 24),
            _BigChoice(
              icon: Icons.home_rounded,
              label: '집으로',
              color: Palette.sky,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
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
            boxShadow: [
              BoxShadow(
                color: Color.lerp(color, Colors.black, .15)!,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 64, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 22, color: Palette.text)),
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = widget.summary;
    final totalCoins = s.coins + s.reward.total;
    return Positioned.fill(
      child: Container(
        color: const Color(0x553E2A20),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: FitBox(
          child: CreamCard(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '정말 잘했어요!',
                    style: TextStyle(fontSize: 34, color: Palette.text),
                  ),
                  const SizedBox(height: 6),
                  CharacterView(
                    equipped: state.equipped,
                    cheer: _cheer,
                    size: 140,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < Economy.questionsPerSession; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: StarIcon(
                            size: 40,
                            color: i < s.stars
                                ? Palette.yellow
                                : const Color(0xFFE6DCCB),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.yellowSoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinIcon(size: 40),
                        const SizedBox(width: 8),
                        Text(
                          '+$totalCoins',
                          style: const TextStyle(
                            fontSize: 36,
                            color: Palette.coinDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.reward.unlockedStage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${s.reward.unlockedStage}단계가 열렸어요!',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFFE0607E),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                        const SizedBox(width: 14),
                        _BigChoice(
                          icon: Icons.arrow_forward_rounded,
                          label: '다음 단계',
                          color: Palette.mint,
                          onTap: widget.onNext!,
                        ),
                      ],
                      const SizedBox(width: 14),
                      _BigChoice(
                        icon: Icons.home_rounded,
                        label: '집으로',
                        color: Palette.sky,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        opacity: t < .7 ? 1 : (1 - t) / .3,
        child: Transform.translate(offset: Offset(0, -40 * t), child: child),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinIcon(size: 34),
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: const TextStyle(fontSize: 30, color: Palette.coinDeep),
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
