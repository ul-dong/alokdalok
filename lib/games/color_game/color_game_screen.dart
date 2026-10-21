import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/economy.dart';
import '../../core/palette.dart';
import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../../services/audio_service.dart';
import '../../services/game_state.dart';
import '../../widgets/common.dart';
import '../../widgets/listen_again_button.dart';
import '../common/game_frame.dart';
import '../common/object_art.dart';
import '../common/scene_game.dart';
import 'color_round.dart';

/// 색깔 놀이: 말한 색의 사물을 찾아 누르기.
class ColorGameScreen extends StatefulWidget {
  const ColorGameScreen({super.key, required this.stageId, this.random});

  final int stageId;
  final Random? random;

  @override
  State<ColorGameScreen> createState() => _ColorGameScreenState();
}

class _ColorGameScreenState extends State<ColorGameScreen> {
  late final ColorStage stage = Stages.color[widget.stageId - 1];
  late final Season season = seasonForStage(widget.stageId);
  int _musicId = 0;
  late final AudioService _audio = AppScope.read(context).audio;
  late final Random rng = widget.random ?? Random();
  final _tileKeys = <int, GlobalKey>{};

  late ColorRound round;
  int done = 0;
  int sessionCoins = 0;
  int sessionStars = 0;
  int cheer = 0;
  int coinPopTrigger = 0;
  int coinPopAmount = 0;
  int wobbleIndex = -1;
  int wobbleTrigger = 0;
  String? bubble;
  SessionSummary? summary;
  SceneGame? scene;
  bool busy = false;
  Timer? _nextTimer;

  GameState get state => AppScope.read(context);

  ColorRound _newRound([ColorQuestion? prev]) => ColorRound(
    ColorQuestion.generate(stage, rng, previous: prev),
    swatchFromStart: stage.swatchFromStart,
  );

  @override
  void initState() {
    super.initState();
    _musicId = _audio.playMusic(season.track);
    round = _newRound();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() {
    _nextToken++;
    _audio.stopMusic(_musicId);
    _nextTimer?.cancel();
    super.dispose();
  }

  void _ask() {
    if (mounted) state.audio.say(round.question.prompt);
  }

  Future<void> _onPick(int index) async {
    if (busy) return;
    final outcome = round.answer(index);
    if (outcome == AnswerOutcome.ignored) return;
    final picked = round.question.choices[index];
    final target = round.question.target;

    if (outcome == AnswerOutcome.correct) {
      busy = true;
      final firstTry = round.firstTry;
      final amount = await state.rewardCorrect(firstTry: firstTry);
      if (!mounted) return;
      setState(() {
        done++;
        sessionCoins += amount;
        if (firstTry) sessionStars++;
        cheer++;
        coinPopAmount = amount;
        coinPopTrigger++;
        bubble = '정말 잘했어요!';
      });
      final box =
          _tileKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
      scene?.celebrate(
        box != null && box.hasSize
            ? box.localToGlobal(box.size.center(Offset.zero))
            : null,
      );
      state.audio.play(Sfx.correct);
      HapticFeedback.lightImpact(); // 맞혔을 때 살짝 '톡' (휴대폰·태블릿)
      _afterSpeech(state.audio.say('${target.color.name}! 정말 잘했어요!'));
    } else {
      state.audio.play(Sfx.tryAgain);
      setState(() {
        wobbleIndex = index;
        wobbleTrigger++;
        bubble = '한 번 더 해 볼까요?';
      });
      // 누른 색의 이름을 알려 주며 다시 찾아보게 한다 (틀렸다고 강조하지 않음)
      state.audio.say(
        '이건 ${picked.color.name}이에요. ${target.color.name}을 찾아볼까요?',
      );
    }
  }

  /// 칭찬하는 말을 끝까지 들려준 뒤 다음 문제로 (말이 짧아도 최소 1.6초는 기뻐할 시간)
  Future<void> _afterSpeech(Future<void> speech) async {
    final token = ++_nextToken;
    await Future.wait([
      speech.timeout(const Duration(seconds: 6), onTimeout: () {}),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (mounted && token == _nextToken) await _next();
  }

  int _nextToken = 0;

  Future<void> _next() async {
    if (!mounted) return;
    if (done >= Economy.questionsPerSession) {
      final reward = await state.completeSession(GameKind.color, stage.id);
      state.audio.play(Sfx.fanfare);
      state.audio.say('정말 잘했어요! 코인을 받았어요.');
      if (!mounted) return;
      setState(() {
        summary = SessionSummary(
          coins: sessionCoins,
          stars: sessionStars,
          reward: reward,
        );
        bubble = null;
      });
      scene?.celebrate();
      return;
    }
    setState(() {
      round = _newRound(round.question);
      bubble = null;
      wobbleIndex = -1;
      busy = false;
    });
    _ask();
  }

  void _replay() {
    setState(() {
      round = _newRound(round.question);
      done = 0;
      sessionCoins = 0;
      sessionStars = 0;
      bubble = null;
      summary = null;
      wobbleIndex = -1;
      busy = false;
    });
    _ask();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = AppScope.of(context).unlockedStage(GameKind.color);
    final hasNext = stage.id < Stages.color.length && stage.id < unlocked;
    final q = round.question;
    return GameFrame(
      done: done,
      cheer: cheer,
      bubble: bubble,
      result: summary,
      onReady: (g) => scene = g,
      season: season,
      onReplay: _replay,
      onNext: hasNext
          ? () => Navigator.of(
              context,
            ).pushReplacement(softRoute(ColorGameScreen(stageId: stage.id + 1)))
          : null,
      card: CreamCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: round.showSwatch
                        ? _Swatch(
                            key: ValueKey(q.target.color.id),
                            color: q.target.color.color,
                          )
                        : const SizedBox(
                            key: ValueKey('none'),
                            width: 0,
                            height: 56,
                          ),
                  ),
                  if (round.showSwatch) const SizedBox(width: 12),
                  Expanded(
                    child: FitBox(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        q.prompt,
                        style: const TextStyle(
                          fontSize: 28,
                          color: Palette.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 큰 노란 "다시 듣기" (62px, 6초마다 통통)
                  ListenAgainButton(onTap: _ask),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final n = q.choices.length;
                      const gap = 14.0;
                      // 한 줄 배치와 (보기 3개일 때) 위 2·아래 1 배치 중 카드가 더 커지는 쪽을 쓴다
                      final rowTile = min(
                        (c.maxWidth - gap * (n - 1)) / n,
                        c.maxHeight / 1.1,
                      );
                      final triTile = n == 3
                          ? min(
                              (c.maxWidth - gap) / 2,
                              (c.maxHeight - gap) / 2 / 1.1,
                            )
                          : 0.0;
                      // 가로 화면에서는 한 줄이 기본. 공간이 정사각형에 가까울 때만 위 2·아래 1
                      final triangle = triTile > rowTile * 1.15;
                      final tile = (triangle ? triTile : rowTile).clamp(
                        80.0,
                        240.0,
                      );
                      Widget tileAt(int i) => _ChoiceTile(
                        key: _tileKeys.putIfAbsent(i, GlobalKey.new),
                        choice: q.choices[i],
                        size: tile,
                        faded: round.wrongPicks.contains(i),
                        glow:
                            round.highlightAnswer &&
                            i == q.answerIndex &&
                            !round.solved,
                        wobble: wobbleIndex == i ? wobbleTrigger : 0,
                        enabled: !round.isDisabled(i),
                        onTap: () => _onPick(i),
                      );
                      if (triangle) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  tileAt(0),
                                  const SizedBox(width: gap),
                                  tileAt(1),
                                ],
                              ),
                              const SizedBox(height: gap),
                              tileAt(2),
                            ],
                          ),
                        );
                      }
                      return Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < n; i++) ...[
                              if (i > 0) const SizedBox(width: gap),
                              tileAt(i),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    right: 8,
                    child: CoinPop(
                      amount: coinPopAmount,
                      trigger: coinPopTrigger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 찾을 색을 크게 보여 주는 물감 방울
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Palette.outline, width: 4),
      boxShadow: const [
        BoxShadow(
          color: Palette.panelShadow,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Align(
      alignment: const Alignment(-.4, -.4),
      child: Container(
        width: 16,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.choice,
    required this.size,
    required this.faded,
    required this.glow,
    required this.wobble,
    required this.enabled,
    required this.onTap,
  });

  final ColorChoice choice;
  final double size;
  final bool faded;
  final bool glow;
  final int wobble;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size * 1.1,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(size * .2),
        border: Border.all(
          color: glow ? Palette.yellow : Colors.white,
          width: glow ? 6 : 4,
        ),
        boxShadow: [
          const BoxShadow(color: Palette.creamDeep, offset: Offset(0, 6)),
          if (glow)
            const BoxShadow(
              color: Color(0x88FFD45C),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          const BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ObjectIcon(
        choice.kind,
        color: choice.color.color,
        size: size * .84,
        faded: faded,
      ),
    );
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      sound: null,
      semanticLabel: '${choice.color.adjective} ${choice.kind.ko}',
      child: TweenAnimationBuilder<double>(
        key: ValueKey(wobble),
        tween: Tween(begin: wobble == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (_, t, child) => Transform.rotate(
          angle: sin(t * pi * 4) * (1 - t) * .12,
          child: child,
        ),
        child: card,
      ),
    );
  }
}
