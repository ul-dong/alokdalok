import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../../services/game_state.dart';
import '../common/object_art.dart';
import '../common/quiz_session.dart';
import '../common/quiz_widgets.dart';
import 'size_round.dart';

/// 크기 놀이(시소): 같은 물건 중 큰 것 / 작은 것 (3개 이상이면 가장 큰 / 가장 작은) 찾기.
class SizeGameScreen extends StatefulWidget {
  const SizeGameScreen({super.key, required this.stageId, this.random});

  final int stageId;
  final Random? random;

  @override
  State<SizeGameScreen> createState() => _SizeGameScreenState();
}

class _SizeGameScreenState extends State<SizeGameScreen>
    with QuizSession<SizeGameScreen> {
  late final SizeStage stage = Stages.size[widget.stageId - 1];
  late final Random rng = widget.random ?? Random();
  final _tileKeys = <int, GlobalKey>{};

  late SizeRound round;
  int wobbleIndex = -1;
  int wobbleTrigger = 0;

  @override
  GameKind get kind => GameKind.size;
  @override
  int get stageId => widget.stageId;
  @override
  String get promptLine => round.question.prompt;
  @override
  Widget nextStageScreen() => SizeGameScreen(stageId: stage.id + 1);

  SizeRound _newRound([SizeQuestion? prev]) =>
      SizeRound(SizeQuestion.generate(stage, rng, previous: prev));

  @override
  void nextQuestion() {
    round = _newRound(round.question);
    wobbleIndex = -1;
  }

  @override
  void initState() {
    super.initState();
    round = _newRound();
    startQuiz();
  }

  @override
  void dispose() {
    stopQuiz();
    super.dispose();
  }

  void _onPick(int i) {
    if (busy) return;
    final q = round.question;
    final outcome = round.answer(i);
    if (outcome == AnswerOutcome.ignored) return;
    if (outcome == AnswerOutcome.correct) {
      onSolved(firstTry: round.firstTry, praise: q.praise, at: _tileKeys[i]);
    } else {
      setState(() {
        wobbleIndex = i;
        wobbleTrigger++;
      });
      onWrong(q.wrongLine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = round.question;
    return quizFrame(
      context,
      card: QuizCard(
        prompt: q.prompt,
        onReplay: ask,
        coinPopAmount: coinPopAmount,
        coinPopTrigger: coinPopTrigger,
        hintId: '${q.kind.name}-${q.ask.name}',
        hint: round.showHint
            ? QuizHintBox(
                label: '${q.ask.adjective} 쪽',
                child: SizeHint(kind: q.kind, color: q.color, ask: q.ask),
              )
            : null,
        body: QuizGrid(
          count: q.scales.length,
          aspect: 1.1,
          builder: (i, w, h) => QuizTile(
            key: _tileKeys.putIfAbsent(i, GlobalKey.new),
            width: w,
            height: h,
            color: const Color(0xFFEFF8FF),
            semanticLabel: '${q.kind.ko} ${i + 1}',
            faded: round.wrongPicks.contains(i),
            glow: round.highlightAnswer && i == q.answerIndex && !round.solved,
            wobble: wobbleIndex == i ? wobbleTrigger : 0,
            enabled: !round.isDisabled(i),
            onTap: () => _onPick(i),
            child: SizedObject(
              kind: q.kind,
              color: q.color.color,
              scale: q.scales[i],
            ),
          ),
        ),
      ),
    );
  }
}

/// 칸 안에 크기 [scale]로 바닥에 놓인 물건 (같은 바닥선이라 크기를 비교하기 쉽다)
class SizedObject extends StatelessWidget {
  const SizedObject({
    super.key,
    required this.kind,
    required this.color,
    required this.scale,
  });
  final ObjectKind kind;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final full = min(c.maxWidth, c.maxHeight * .9);
      return Stack(
        children: [
          // 풀밭 바닥 (파스텔)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: c.maxHeight * .1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFCDEBB4),
                borderRadius: BorderRadius.circular(c.maxHeight * .05),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: c.maxHeight * .04,
            child: Center(
              child: ObjectIcon(kind, color: color, size: full * scale),
            ),
          ),
        ],
      );
    },
  );
}

/// 그림 힌트: 작은 것과 큰 것을 나란히 놓고 찾을 쪽만 색칠 + 노란 동그라미
class SizeHint extends StatelessWidget {
  const SizeHint({
    super.key,
    required this.kind,
    required this.color,
    required this.ask,
  });
  final ObjectKind kind;
  final GameColor color;
  final SizeAsk ask;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final s = min(c.maxWidth, c.maxHeight);
      Widget item(double scale, bool target) => Container(
        width: s * scale * .55,
        height: s * scale * .55,
        decoration: target
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB800), width: 3),
              )
            : null,
        child: ObjectIcon(
          kind,
          color: target ? color.color : const Color(0xFFD9D2CC),
          size: s * scale * .5,
          faded: !target,
        ),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          item(.6, ask == SizeAsk.small),
          SizedBox(width: s * .04),
          item(1, ask == SizeAsk.big),
        ],
      );
    },
  );
}

/// 단계 카드 그림: 같은 물건을 크기만 다르게
class SizeStageArt extends StatelessWidget {
  const SizeStageArt(this.stage, {super.key});
  final SizeStage stage;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final sc in stage.scales)
        ObjectIcon(
          stage.objects.first,
          color: GameColor.red.color,
          size: 64 * sc,
        ),
    ],
  );
}
