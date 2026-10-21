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
import '../common/game_frame.dart';
import '../common/korean_numbers.dart';
import '../common/number_shape.dart';
import '../common/object_art.dart';
import '../common/scene_game.dart';
import '../common/stamp.dart';
import 'number_round.dart';

/// 숫자 놀이: 화면의 사물 개수를 세어 맞히기.
class NumberGameScreen extends StatefulWidget {
  const NumberGameScreen({super.key, required this.stageId, this.random});

  final int stageId;

  /// 테스트에서 문제를 고정하기 위한 난수
  final Random? random;

  @override
  State<NumberGameScreen> createState() => _NumberGameScreenState();
}

class _NumberGameScreenState extends State<NumberGameScreen> {
  late final NumberStage stage = Stages.number[widget.stageId - 1];
  late final Season season = seasonForStage(widget.stageId);
  int _musicId = 0;
  late final AudioService _audio = AppScope.read(context).audio;
  late final Random rng = widget.random ?? Random();
  final _choiceKeys = <int, GlobalKey>{};

  late NumberRound round;
  int done = 0;
  int sessionCoins = 0;
  int sessionStars = 0;
  int cheer = 0;
  int coinPopTrigger = 0;
  int coinPopAmount = 0;
  int hintShown = 0;
  String? bubble;

  /// 틀렸을 때 크게 떠오르는 말 (세기 시작하면 사라진다)
  String? bigPop;
  SessionSummary? summary;
  SceneGame? scene;
  bool busy = false;
  Timer? _hintTimer;
  Timer? _nextTimer;

  GameState get state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _musicId = _audio.playMusic(season.track);
    round = NumberRound(NumberQuestion.generate(stage, rng));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() {
    _hintToken++;
    _nextToken++;
    _audio.stopMusic(_musicId);
    _hintTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _ask() {
    if (!mounted) return;
    state.audio.say(round.question.prompt);
  }

  Future<void> _onPick(int choice) async {
    if (busy) return;
    final outcome = round.answer(choice);
    if (outcome == AnswerOutcome.ignored) return;

    if (outcome == AnswerOutcome.correct) {
      busy = true;
      _hintTimer?.cancel();
      _hintToken++;
      final firstTry = round.firstTry;
      final amount = await state.rewardCorrect(firstTry: firstTry);
      if (!mounted) return;
      setState(() {
        done++;
        sessionCoins += amount;
        if (firstTry) sessionStars++;
        cheer++;
        hintShown = round.question.count;
        bigPop = null;
        coinPopAmount = amount;
        coinPopTrigger++;
        bubble = '정말 잘했어요!';
      });
      _celebrateAt(choice);
      state.audio.play(Sfx.correct);
      HapticFeedback.lightImpact(); // 맞혔을 때 살짝 '톡' (휴대폰·태블릿)
      _afterSpeech(state.audio.say('${round.question.answerLine} 정말 잘했어요!'));
    } else {
      state.audio.play(Sfx.tryAgain);
      setState(() {
        bubble = '같이 세어 볼까요?';
        bigPop = '같이 세어 볼까요?';
      });
      _startCountingHint();
    }
  }

  /// 사물에 하나씩 번호를 붙이며 같이 세어 보는 힌트
  int _hintToken = 0;

  /// 같이 세어 보기: 번호 붙이기와 "하나, 둘…" 소리를 한 박자씩 맞춘다.
  /// 숫자 하나를 말하기 시작할 때 그 물건에 번호가 붙고, 말이 끝나면 다음 숫자로.
  Future<void> _startCountingHint() async {
    _hintTimer?.cancel();
    final token = ++_hintToken;
    final n = round.question.count;
    setState(() => hintShown = 0);
    // 1) "같이 세어 볼까요?"를 크게 띄우고 말한다
    await Future.wait([
      state.audio
          .say('같이 세어 볼까요?')
          .timeout(const Duration(seconds: 4), onTimeout: () {}),
      Future<void>.delayed(const Duration(milliseconds: 1100)),
    ]);
    if (!mounted || token != _hintToken) return;
    setState(() => bigPop = null);
    // 2) 물건마다 숫자 도장 "쾅!" — 도장이 닿는 순간 소리와 "하나"
    for (var i = 1; i <= n; i++) {
      if (!mounted || token != _hintToken) return;
      setState(() => hintShown = i);
      await Future<void>.delayed(const Duration(milliseconds: 210));
      if (!mounted || token != _hintToken) return;
      state.audio.play(Sfx.stamp);
      HapticFeedback.mediumImpact();
      final spoken = state.audio.say(KoreanNumbers.count(i));
      await Future.wait([
        spoken.timeout(const Duration(seconds: 3), onTimeout: () {}),
        Future<void>.delayed(const Duration(milliseconds: 520)),
      ]);
    }
  }

  void _celebrateAt(int choice) {
    final box =
        _choiceKeys[choice]?.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null && box.hasSize
        ? box.localToGlobal(box.size.center(Offset.zero))
        : null;
    scene?.celebrate(center);
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
      final reward = await state.completeSession(GameKind.number, stage.id);
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
      round = NumberRound(
        NumberQuestion.generate(stage, rng, previous: round.question),
      );
      hintShown = 0;
      bubble = null;
      bigPop = null;
      busy = false;
    });
    _ask();
  }

  /// 한 가지 물건만 세는 단계: 색을 바꿀 수 있는 물건은 문제마다 다른 원색으로 칠한다.
  /// 단계가 올라가면 쓰는 색도 달라진다 (1단계 빨·노·파 → 2단계 초록·주황·보라 …).
  static const _stageTints = [
    [GameColor.red, GameColor.yellow, GameColor.blue],
    [GameColor.green, GameColor.orange, GameColor.purple, GameColor.red],
    [
      GameColor.pink,
      GameColor.blue,
      GameColor.yellow,
      GameColor.green,
      GameColor.orange,
    ],
  ];
  static const _tintable = {
    ObjectKind.car,
    ObjectKind.balloon,
    ObjectKind.ball,
    ObjectKind.star,
    ObjectKind.flower,
    ObjectKind.fish,
  };
  final _tints = Expando<Color>();
  final _tintRng = Random();

  Color? _tintFor(NumberQuestion q) {
    if (!_tintable.contains(q.kind)) return null;
    return _tints[q] ??= () {
      final set = _stageTints[(stage.id - 1) % _stageTints.length];
      return set[_tintRng.nextInt(set.length)].color;
    }();
  }

  void _replay() {
    setState(() {
      round = NumberRound(
        NumberQuestion.generate(stage, rng, previous: round.question),
      );
      done = 0;
      sessionCoins = 0;
      sessionStars = 0;
      hintShown = 0;
      bubble = null;
      summary = null;
      busy = false;
    });
    _ask();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = AppScope.of(context).unlockedStage(GameKind.number);
    final hasNext = stage.id < Stages.number.length && stage.id < unlocked;
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
          ? () => Navigator.of(context).pushReplacement(
              softRoute(NumberGameScreen(stageId: stage.id + 1)),
            )
          : null,
      card: CreamCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
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
                  RoundIconButton(
                    icon: Icons.volume_up_rounded,
                    label: '다시 듣기',
                    size: 52,
                    color: Palette.yellowSoft,
                    onTap: _ask,
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // 넓은 가로 카드: 왼쪽에 셀 사물, 오른쪽에 큰 보기 버튼 3개
                  final h = min(c.maxHeight, max(150.0, c.maxHeight * .55));
                  return Row(
                    children: [
                      Expanded(
                        flex: q.choices.length > 3
                            ? 10
                            : (q.scattered ? 14 : 11),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (q.scattered)
                              ScatterField(
                                key: ValueKey(q),
                                question: q,
                                hintShown: hintShown,
                              )
                            else
                              ObjectField(
                                key: ValueKey(q),
                                kind: q.kind,
                                tint: _tintFor(q),
                                count: q.count,
                                hintShown: hintShown,
                              ),
                            if (bigPop != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: FitBox(child: BigPop(text: bigPop!)),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: CoinPop(
                                amount: coinPopAmount,
                                trigger: coinPopTrigger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: q.choices.length > 3 ? 10 : 9,
                        child: LayoutBuilder(
                          builder: (context, cc) {
                            final n = q.choices.length;
                            // 한 줄에 놓으면 버튼이 48보다 좁아질 때만 2줄(2x2)로
                            final perRow =
                                n > 3 && (cc.maxWidth - 10 * (n - 1)) / n < 48
                                ? (n / 2).ceil()
                                : n;
                            final rows = (n / perRow).ceil();
                            final bh = rows == 1
                                ? h
                                : (cc.maxHeight - 10 * (rows - 1)) / rows;
                            Widget button(int ch) => AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: round.wrongPicks.contains(ch) ? .35 : 1,
                              child: PillButton(
                                key: _choiceKeys.putIfAbsent(ch, GlobalKey.new),
                                height: bh,
                                sound: null,
                                semanticLabel: '$ch',
                                enabled: !round.isDisabled(ch),
                                glow:
                                    round.wrongPicks.length >= 2 &&
                                    ch == q.count &&
                                    !round.solved,
                                onTap: () => _onPick(ch),
                                // 좁은 휴대폰에서도 숫자·주사위가 크게 보이게 안쪽 여백을 줄인다
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: _ChoiceFace(value: ch),
                              ),
                            );
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var r = 0; r < rows; r++) ...[
                                  if (r > 0) const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      for (
                                        var i = r * perRow;
                                        i < min(n, (r + 1) * perRow);
                                        i++
                                      ) ...[
                                        if (i > r * perRow)
                                          const SizedBox(width: 10),
                                        Expanded(child: button(q.choices[i])),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
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
    );
  }
}

/// 보기 버튼: 큰 숫자 + 주사위 모양 발자국 (숫자를 못 읽어도 모양으로 고를 수 있게)
class _ChoiceFace extends StatelessWidget {
  const _ChoiceFace({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // 좁고 긴 버튼이면 주사위를 위아래로 쌓아 크게 보이게
      final narrow = c.maxWidth < 100 && value > 5;
      return FitBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 46,
                color: NumberShape.colorOf(value),
                height: 1.05,
                shadows: const [Shadow(color: Colors.white, blurRadius: 2)],
              ),
            ),
            const SizedBox(height: 6),
            NumberShape(value, vertical: narrow),
          ],
        ),
      );
    },
  );
}

/// 사물 [n]개를 줄로 나누는 방법 (위 줄이 같거나 더 많게). 예: 5 → [3, 2], 7 → [4, 3], 10 → [5, 5]
List<int> objectRows(int n) {
  if (n <= 0) return const [];
  if (n <= 5) return n <= 3 ? [n] : [(n + 1) ~/ 2, n ~/ 2];
  return [(n + 1) ~/ 2, n ~/ 2];
}

/// 문제 사물 배치. 개수에 따라 줄을 나눠 크게 보여 준다.
/// 그려지는 사물 수는 항상 [count]와 같다 (인덱스를 미리 계산해 실수로 더 그리지 않게 한다).
class ObjectField extends StatelessWidget {
  const ObjectField({
    super.key,
    required this.kind,
    required this.count,
    required this.hintShown,
    this.tint,
  });

  final ObjectKind kind;

  /// 물건 색 (없으면 원래 색)
  final Color? tint;
  final int count;
  final int hintShown;

  @override
  Widget build(BuildContext context) {
    final rows = objectRows(count);
    final cols = rows.isEmpty ? 1 : rows.first;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = min(c.maxWidth / cols, c.maxHeight / max(1, rows.length));
        final size = min(cell * .86, 150.0);
        var start = 0;
        final rowWidgets = <Widget>[];
        for (final n in rows) {
          final first = start;
          rowWidgets.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < n; k++) _item(first + k, size, cell),
              ],
            ),
          );
          start += n;
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowWidgets,
        );
      },
    );
  }

  Widget _item(int i, double size, double cell) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + i * 90),
        curve: Curves.easeOutBack,
        builder: (_, t, child) =>
            Transform.scale(scale: max(0.0, t), child: child),
        child: SizedBox(
          width: cell,
          height: cell,
          child: Stamped(
            number: i < hintShown ? i + 1 : null,
            badgeSize: max(30, size * .4),
            child: ObjectIcon(kind, color: tint, size: size),
          ),
        ),
      );
}

/// 여러 물건을 흩어 놓은 화면. 힌트 때는 세는 물건에만 번호를 붙이고 나머지는 흐리게 한다.
class ScatterField extends StatelessWidget {
  const ScatterField({
    super.key,
    required this.question,
    required this.hintShown,
  });

  final NumberQuestion question;
  final int hintShown;

  @override
  Widget build(BuildContext context) {
    final order = question.targetsInOrder;
    return LayoutBuilder(
      builder: (context, c) {
        final cellW = c.maxWidth / question.cols;
        final cellH = c.maxHeight / question.rows;
        final size = min(min(cellW * .8, cellH * .9), 120.0);
        final counting = hintShown > 0;
        var i = 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final o in question.scene)
              Positioned(
                left: (o.x * c.maxWidth - size / 2).clamp(
                  0.0,
                  max(0.0, c.maxWidth - size),
                ),
                top: (o.y * c.maxHeight - size / 2).clamp(
                  0.0,
                  max(0.0, c.maxHeight - size),
                ),
                width: size,
                height: size,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 380 + (i++) * 60),
                  curve: Curves.easeOutBack,
                  builder: (_, t, child) =>
                      Transform.scale(scale: max(0.0, t), child: child),
                  child: Stamped(
                    number: o.target && order.indexOf(o) < hintShown
                        ? order.indexOf(o) + 1
                        : null,
                    badgeSize: max(28, size * .4),
                    badgeTop: -4,
                    child: ObjectIcon(
                      o.kind,
                      color: o.color?.color,
                      size: size,
                      faded: counting && !o.target,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
