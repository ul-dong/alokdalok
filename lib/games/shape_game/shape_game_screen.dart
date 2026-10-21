import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../../services/game_state.dart';
import '../common/quiz_session.dart';
import '../common/quiz_widgets.dart';
import 'shape_art.dart';
import 'shape_round.dart';

/// 모양 놀이(모래놀이터): 말한 모양(또는 견본과 같은 모양)을 찾아 누르기.
class ShapeGameScreen extends StatefulWidget {
  const ShapeGameScreen({super.key, required this.stageId, this.random});

  final int stageId;
  final Random? random;

  @override
  State<ShapeGameScreen> createState() => _ShapeGameScreenState();
}

/// 모래놀이터 느낌의 보기 칸 바탕 (파스텔)
const sandTile = Color(0xFFFFF3D9);

class _ShapeGameScreenState extends State<ShapeGameScreen>
    with QuizSession<ShapeGameScreen> {
  late final ShapeStage stage = Stages.shape[widget.stageId - 1];
  late final Random rng = widget.random ?? Random();
  final _tileKeys = <int, GlobalKey>{};

  late ShapeRound round;
  int wobbleIndex = -1;
  int wobbleTrigger = 0;

  @override
  GameKind get kind => GameKind.shape;
  @override
  int get stageId => widget.stageId;
  @override
  String get promptLine => round.question.prompt;
  @override
  Widget nextStageScreen() => ShapeGameScreen(stageId: stage.id + 1);

  ShapeRound _newRound([ShapeQuestion? prev]) => ShapeRound(
    ShapeQuestion.generate(stage, rng, previous: prev),
    sampleFromStart: stage.sampleFromStart,
  );

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
      onWrong(q.wrongLine(i));
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
        hintId: '${q.shape.name}-${q.sampleColor.id}',
        hint: round.showSample
            ? QuizHintBox(
                label: '견본 ${q.shape.ko}',
                say: '${q.shape.ko}!',
                child: ShapeIcon(
                  q.shape,
                  color: q.sampleColor.color,
                  size: double.infinity,
                ),
              )
            : null,
        body: QuizGrid(
          count: q.choices.length,
          builder: (i, w, h) {
            final c = q.choices[i];
            return QuizTile(
              key: _tileKeys.putIfAbsent(i, GlobalKey.new),
              width: w,
              height: h,
              color: sandTile,
              semanticLabel: '${c.color.adjective} ${c.shape.ko}',
              faded: round.wrongPicks.contains(i),
              glow:
                  round.highlightAnswer && i == q.answerIndex && !round.solved,
              wobble: wobbleIndex == i ? wobbleTrigger : 0,
              enabled: !round.isDisabled(i),
              onTap: () => _onPick(i),
              child: ShapeIcon(
                c.shape,
                color: c.color.color,
                angle: c.angle,
                size: double.infinity,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 단계 카드 그림: 그 단계에서 만나는 모양 몇 개
class ShapeStageArt extends StatelessWidget {
  const ShapeStageArt(this.stage, {super.key});
  final ShapeStage stage;

  @override
  Widget build(BuildContext context) {
    final shapes = stage.shapes.take(3).toList();
    final colors = stage.sameColor
        ? [GameColor.blue, GameColor.blue, GameColor.blue]
        : [GameColor.red, GameColor.blue, GameColor.yellow];
    // 단계 카드는 FittedBox 안에 놓이므로 고정 크기로 그린다
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shapes.length; i++)
          ShapeIcon(
            shapes[i],
            color: colors[i].color,
            size: 56,
            angle: stage.rotate && !shapes[i].rotationFree ? 20 : 0,
            outlineOnly: stage.matchSample && i == 0,
          ),
      ],
    );
  }
}
