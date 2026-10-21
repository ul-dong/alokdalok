import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/economy.dart';
import '../../services/audio_service.dart';
import '../../services/game_state.dart';
import '../../widgets/common.dart';
import 'game_frame.dart';
import 'scene_game.dart';

/// 모양·크기·짝 맞추기 놀이가 함께 쓰는 한 판 흐름.
///
/// 문제 읽기 → (오답: 부드러운 안내) → 정답: 효과음·칭찬·코인 → 다음 문제,
/// 5문제를 끝내면 별·코인 결과와 "또 하기 / 다음 단계 / 집으로".
/// 단계마다 계절 배경과 음악이 바뀐다.
mixin QuizSession<T extends StatefulWidget> on State<T> {
  /// 놀이 종류 (진행 저장 위치)
  GameKind get kind;
  int get stageId;

  /// 지금 문제를 읽어 주는 말
  String get promptLine;

  /// 새 문제를 만든다 (setState 안에서 불린다)
  void nextQuestion();

  /// 다음 단계 화면
  Widget nextStageScreen();

  late final Season season = seasonForStage(stageId);
  late final AudioService _quizAudio = AppScope.read(context).audio;
  int _musicId = 0;
  int _nextToken = 0;

  int done = 0;
  int sessionCoins = 0;
  int sessionStars = 0;
  int cheer = 0;
  int coinPopTrigger = 0;
  int coinPopAmount = 0;
  String? bubble;
  SessionSummary? summary;
  SceneGame? scene;

  /// 정답 뒤 다음 문제로 넘어가는 동안은 누르기를 막는다
  bool busy = false;

  GameState get state => AppScope.read(context);

  /// initState에서 부른다: 계절 음악을 켜고 첫 문제를 읽는다.
  void startQuiz() {
    _musicId = _quizAudio.playMusic(season.track);
    WidgetsBinding.instance.addPostFrameCallback((_) => ask());
  }

  /// dispose에서 부른다.
  void stopQuiz() {
    _nextToken++;
    _quizAudio.stopMusic(_musicId);
  }

  void ask() {
    if (mounted) state.audio.say(promptLine);
  }

  /// 정답: 효과음 → 칭찬 → 코인 → (말이 끝나면) 다음 문제
  Future<void> onSolved({
    required bool firstTry,
    required String praise,
    GlobalKey? at,
  }) async {
    busy = true;
    state.audio.play(Sfx.correct);
    HapticFeedback.lightImpact();
    final speech = state.audio.say(praise);
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
    final box = at?.currentContext?.findRenderObject() as RenderBox?;
    scene?.celebrate(
      box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : null,
    );
    unawaited(_afterSpeech(speech));
  }

  /// 오답: 혼내지 않고 "다시 찾아볼까요?" 하고 부드럽게 다시 이끈다.
  void onWrong(String line) {
    state.audio.play(Sfx.tryAgain);
    setState(() => bubble = '다시 찾아볼까요?');
    state.audio.say(line);
  }

  /// 칭찬을 끝까지 들려준 뒤 다음 문제로 (최소 1.6초는 기뻐할 시간)
  Future<void> _afterSpeech(Future<void> speech) async {
    final token = ++_nextToken;
    await Future.wait([
      speech.timeout(const Duration(seconds: 6), onTimeout: () {}),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (mounted && token == _nextToken) await _next();
  }

  Future<void> _next() async {
    if (!mounted) return;
    if (done >= Economy.questionsPerSession) {
      final reward = await state.completeSession(kind, stageId);
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
      nextQuestion();
      bubble = null;
      busy = false;
    });
    ask();
  }

  /// "또 하기"
  void replayQuiz() {
    _nextToken++;
    setState(() {
      nextQuestion();
      done = 0;
      sessionCoins = 0;
      sessionStars = 0;
      bubble = null;
      summary = null;
      busy = false;
    });
    ask();
  }

  /// 공통 놀이 틀 (위 상태줄·가운데 문제 카드·아래 길과 말풍선·결과 화면)
  Widget quizFrame(BuildContext context, {required Widget card}) {
    final unlocked = AppScope.of(context).unlockedStage(kind);
    final hasNext = stageId < kind.stageCount && stageId < unlocked;
    return GameFrame(
      done: done,
      cheer: cheer,
      bubble: bubble,
      result: summary,
      onReady: (g) => scene = g,
      season: season,
      onReplay: replayQuiz,
      onNext: hasNext
          ? () =>
                Navigator.of(context)
                    .pushReplacement(softRoute(nextStageScreen()))
          : null,
      card: card,
    );
  }
}
