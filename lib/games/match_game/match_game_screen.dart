import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/game_objects.dart';
import '../../data/stages.dart';
import '../../services/audio_service.dart';
import '../../services/game_state.dart';
import '../common/object_art.dart';
import '../common/quiz_session.dart';
import '../common/quiz_widgets.dart';
import 'match_round.dart';

/// 짝 맞추기(회전목마): 모두 보이는 카드 중 같은 그림 두 장을 차례로 누르기.
/// 한 판(5문제) = 카드 판 5개. 판의 짝을 모두 맞추면 한 문제를 푼 것이다.
class MatchGameScreen extends StatefulWidget {
  const MatchGameScreen({super.key, required this.stageId, this.random});

  final int stageId;
  final Random? random;

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen>
    with QuizSession<MatchGameScreen> {
  late final MatchStage stage = Stages.match[widget.stageId - 1];
  late final Random rng = widget.random ?? Random();
  final _tileKeys = <int, GlobalKey>{};

  late MatchRound round;
  int wobbleIndex = -1;
  int wobbleTrigger = 0;

  @override
  GameKind get kind => GameKind.match;
  @override
  int get stageId => widget.stageId;
  @override
  String get promptLine {
    final sel = round.selected;
    return sel == null ? MatchBoard.prompt : round.board.pickedLine(sel);
  }

  @override
  Widget nextStageScreen() => MatchGameScreen(stageId: stage.id + 1);

  MatchRound _newRound([MatchBoard? prev]) =>
      MatchRound(MatchBoard.generate(stage, rng, previous: prev));

  @override
  void nextQuestion() {
    round = _newRound(round.board);
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
    final board = round.board;
    final first = round.selected;
    final outcome = round.pick(i);
    switch (outcome) {
      case MatchOutcome.ignored:
        return;
      case MatchOutcome.selected:
        state.audio.play(Sfx.tap);
        setState(() => bubble = null);
        state.audio.say(board.pickedLine(i));
      case MatchOutcome.wrong:
        setState(() {
          wobbleIndex = i;
          wobbleTrigger++;
        });
        onWrong(board.wrongLine(first!));
      case MatchOutcome.matched:
        state.audio.play(Sfx.correct);
        setState(() => bubble = '똑같아요!');
        state.audio.say(board.matchedLine(i));
      case MatchOutcome.finished:
        onSolved(
          firstTry: round.firstTry,
          praise: '${board.matchedLine(i)} 정말 잘했어요!',
          at: _tileKeys[i],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = round.board;
    final sel = round.selected;
    return quizFrame(
      context,
      card: QuizCard(
        prompt: sel == null
            ? MatchBoard.prompt
            : '똑같은 ${board.cards[sel].objectLabel(board.colorVariant)} 찾아볼까요?',
        onReplay: ask,
        coinPopAmount: coinPopAmount,
        coinPopTrigger: coinPopTrigger,
        hintId: sel,
        hint: round.showHint
            ? QuizHintBox(
                label: '찾는 그림 ${board.labelOf(sel!)}',
                say: '${board.labelOf(sel)}!',
                child: ObjectIcon(
                  board.cards[sel].kind,
                  color: board.cards[sel].color.color,
                  size: double.infinity,
                ),
              )
            : null,
        body: QuizGrid(
          count: board.cards.length,
          gap: 10,
          builder: (i, w, h) {
            final c = board.cards[i];
            return QuizTile(
              key: _tileKeys.putIfAbsent(i, GlobalKey.new),
              width: w,
              height: h,
              color: const Color(0xFFFDEFF6),
              semanticLabel: '카드 ${board.labelOf(i)}',
              selected: sel == i,
              done: round.matched.contains(i),
              faded: round.wrongPicks.contains(i),
              glow: round.glowIndex == i,
              wobble: wobbleIndex == i ? wobbleTrigger : 0,
              enabled: !round.isDisabled(i) && sel != i,
              onTap: () => _onPick(i),
              child: ObjectIcon(
                c.kind,
                color: c.color.color,
                size: double.infinity,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 단계 카드 그림: 짝 카드 두 쌍
class MatchStageArt extends StatelessWidget {
  const MatchStageArt(this.stage, {super.key});
  final MatchStage stage;

  @override
  Widget build(BuildContext context) {
    const s = 48.0;
    final a = stage.objects.first;
    final b = stage.colorVariant ? a : stage.objects[1];
    final cb = stage.colorVariant ? GameColor.blue : GameColor.yellow;
    Widget card(ObjectKind k, GameColor col) => Container(
      width: s,
      height: s,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEFF6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ObjectIcon(k, color: col.color, size: double.infinity),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [card(a, GameColor.red), card(b, cb)],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [card(b, cb), card(a, GameColor.red)],
        ),
      ],
    );
  }
}
