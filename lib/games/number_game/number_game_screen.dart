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
import '../common/korean_numbers.dart';
import '../common/number_shape.dart';
import '../common/object_art.dart';
import '../common/quiz_widgets.dart';
import '../common/scene_game.dart';
import '../common/stamp.dart';
import 'number_round.dart';

/// 숫자 놀이: 화면의 사물 개수를 세어 맞히기.
class NumberGameScreen extends StatefulWidget {
  const NumberGameScreen({super.key, required this.stageId, this.random});

  final int stageId;

  /// 테스트에서 문제를 고정하기 위한 난수
  final Random? random;

  /// 같이 세는 숫자판 제목 (틀렸을 때 말로도 읽어 준다)
  static const boardTitle = '같이 세어 볼까요?';

  /// 정답 때 마지막 숫자에 이어 말하는 칭찬 ("셋, 정말 잘했어요!")
  static const praise = '정말 잘했어요!';

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

  SessionSummary? summary;
  SceneGame? scene;
  bool busy = false;

  /// 같이 세는 중 (물건을 눌러도 이름을 말하지 않는다: 세는 소리를 끊지 않게)
  bool counting = false;

  /// 보기 자리를 덮는 큰 숫자판을 보여 줄지
  bool boardUp = false;

  /// 숫자판에 쓰인 숫자 (0이면 아직 세기 전: 제목만)
  int boardNumber = 0;

  /// 숫자판 아래 말 (정답 때 "셋! 정말 잘했어요!")
  String? boardPraise;

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
    _countToken++;
    _audio.stopMusic(_musicId);
    super.dispose();
  }

  void _ask() {
    if (!mounted) return;
    state.audio.say(round.question.prompt);
  }

  /// 세는 한 박자의 가장 짧은 길이 (말이 짧거나 소리가 꺼져 있어도 이만큼은 기다린다)
  static const slowBeat = Duration(milliseconds: 520);
  static const fastBeat = Duration(milliseconds: 300);

  /// 틀렸을 때: 다 센 뒤 판을 내리기까지 기다리는 시간
  static const boardHold = Duration(milliseconds: 900);

  /// 세기를 시작하거나 화면이 사라질 때마다 올라간다 (지난 세기를 멈춘다)
  int _countToken = 0;
  bool _alive(int token) => mounted && token == _countToken;

  Future<void> _onPick(int choice) async {
    if (busy || counting) return;
    final outcome = round.answer(choice);
    if (outcome == AnswerOutcome.ignored) return;

    if (outcome == AnswerOutcome.correct) {
      busy = true;
      final token = ++_countToken;
      final firstTry = round.firstTry;
      final amount = await state.rewardCorrect(firstTry: firstTry);
      if (!_alive(token)) return;
      setState(() {
        done++;
        sessionCoins += amount;
        if (firstTry) sessionStars++;
        cheer++;
        coinPopAmount = amount;
        coinPopTrigger++;
        bubble = NumberGameScreen.praise;
      });
      _celebrateAt(choice);
      state.audio.play(Sfx.correct);
      HapticFeedback.lightImpact(); // 맞혔을 때 살짝 '톡' (휴대폰·태블릿)
      // 빠르게 같이 세고, 마지막 숫자에 칭찬을 이어 말한다: "셋! 정말 잘했어요!"
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!_alive(token)) return;
      final ok = await _countAlong(token, fast: true);
      if (!ok) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_alive(token)) await _next();
    } else {
      state.audio.play(Sfx.tryAgain);
      final token = ++_countToken;
      setState(() => bubble = NumberGameScreen.boardTitle);
      // 1) 판을 띄우고 "같이 세어 볼까요?"
      _raiseBoard();
      await Future.wait([
        state.audio
            .say(NumberGameScreen.boardTitle)
            .timeout(const Duration(seconds: 4), onTimeout: () {}),
        Future<void>.delayed(const Duration(milliseconds: 1100)),
      ]);
      if (!_alive(token)) return;
      // 2) 하나, 둘, 셋 …
      final ok = await _countAlong(token, fast: false);
      if (!ok) return;
      // 3) 잠깐 보여 준 뒤 판을 내리고 다시 고르게 한다
      await Future<void>.delayed(boardHold);
      if (!_alive(token)) return;
      setState(() {
        boardUp = false;
        counting = false;
      });
    }
  }

  void _raiseBoard() => setState(() {
    boardUp = true;
    boardNumber = 0;
    boardPraise = null;
    hintShown = 0;
    counting = true;
  });

  /// 같이 세기: 물건마다 숫자 도장이 떨어지고, 도장이 "쾅" 닿는 바로 그 순간
  /// 숫자판의 숫자·도장 소리·진동·목소리("하나")가 함께 나온다.
  /// 말이 끝나야(그리고 [slowBeat]/[fastBeat]가 지나야) 다음 숫자로 넘어간다.
  /// [fast]면 정답 축하용: 박자가 빠르고 마지막 숫자에 칭찬을 붙인다.
  /// 도중에 화면이 사라지거나 새 세기가 시작되면 false.
  Future<bool> _countAlong(int token, {required bool fast}) async {
    final n = round.question.count;
    if (!boardUp) _raiseBoard();
    for (var i = 1; i <= n; i++) {
      if (!_alive(token)) return false;
      setState(() => hintShown = i); // 도장이 떨어지기 시작
      await Future<void>.delayed(Stamped.impactDelay);
      if (!_alive(token)) return false;
      final last = i == n;
      final word = KoreanNumbers.count(i);
      setState(() {
        boardNumber = i;
        if (fast && last) boardPraise = NumberGameScreen.praise;
      });
      state.audio.play(Sfx.stamp);
      HapticFeedback.mediumImpact();
      final spoken = state.audio.say(
        fast && last ? '$word, ${NumberGameScreen.praise}' : word,
      );
      await Future.wait([
        spoken.timeout(
          Duration(seconds: fast && last ? 6 : 3),
          onTimeout: () {},
        ),
        Future<void>.delayed(fast ? fastBeat : slowBeat),
      ]);
    }
    return _alive(token);
  }

  void _celebrateAt(int choice) {
    final box =
        _choiceKeys[choice]?.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null && box.hasSize
        ? box.localToGlobal(box.size.center(Offset.zero))
        : null;
    scene?.celebrate(center);
  }

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
        _lowerBoard();
        bubble = null;
      });
      scene?.celebrate();
      return;
    }
    setState(() {
      round = NumberRound(
        NumberQuestion.generate(stage, rng, previous: round.question),
      );
      _lowerBoard();
      bubble = null;
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
  final _tints = Expando<Color>();
  final _tintRng = Random();

  Color? _tintFor(NumberQuestion q) {
    if (!q.kind.tintable) return null;
    return _tints[q] ??= () {
      final set = _stageTints[(stage.id - 1) % _stageTints.length];
      return set[_tintRng.nextInt(set.length)].color;
    }();
  }

  /// 판을 내리고 도장을 지운다 (setState 안에서 부른다)
  void _lowerBoard() {
    _countToken++;
    hintShown = 0;
    counting = false;
    boardUp = false;
    boardNumber = 0;
    boardPraise = null;
  }

  void _replay() {
    setState(() {
      round = NumberRound(
        NumberQuestion.generate(stage, rng, previous: round.question),
      );
      done = 0;
      sessionCoins = 0;
      sessionStars = 0;
      _lowerBoard();
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
        child: LayoutBuilder(
          builder: (context, card) => Column(
            children: [
              SizedBox(
                height: quizHeaderHeight(card.maxHeight),
                child: Row(
                  children: [
                    Expanded(
                      child: FitBox(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          q.prompt,
                          style: TextStyle(
                            fontSize: quizPromptSize(card.maxHeight),
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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 넓은 가로 카드: 왼쪽에 셀 사물, 오른쪽에 큰 보기 버튼
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
                                  canName: !busy && !counting,
                                )
                              else
                                ObjectField(
                                  key: ValueKey(q),
                                  kind: q.kind,
                                  tint: _tintFor(q),
                                  count: q.count,
                                  hintShown: hintShown,
                                  canName: !busy && !counting,
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
                              // 1~3줄 중 버튼이 가장 크게 나오는 배치
                              final g = TileGrid.fit(
                                n,
                                cc.biggest,
                                aspect: 1.25,
                                gap: 10,
                                maxRows: TileGrid.quizMaxRows,
                              );
                              final perRow = g.cols;
                              final rows = g.rows;
                              final cellW =
                                  (cc.maxWidth - 10 * (perRow - 1)) / perRow;
                              // 줄 높이를 다 쓰되, 너무 길쭉하지 않게
                              final bh = min(
                                (cc.maxHeight - 10 * (rows - 1)) / rows,
                                cellW * 1.5,
                              );
                              Widget button(int ch) => AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: round.wrongPicks.contains(ch)
                                    ? .35
                                    : 1,
                                child: PillButton(
                                  key: _choiceKeys.putIfAbsent(
                                    ch,
                                    GlobalKey.new,
                                  ),
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
                              final choices = Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var r = 0; r < rows; r++) ...[
                                    if (r > 0) const SizedBox(height: 10),
                                    // 칸 너비를 모두 같게 (마지막 줄이 덜 차면 가운데로)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (
                                          var i = r * perRow;
                                          i < min(n, (r + 1) * perRow);
                                          i++
                                        ) ...[
                                          if (i > r * perRow)
                                            const SizedBox(width: 10),
                                          SizedBox(
                                            width: cellW,
                                            child: button(q.choices[i]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              );
                              return Stack(
                                children: [
                                  choices,
                                  // 같이 세는 동안 보기 자리 전체를 덮는 큰 숫자판
                                  if (boardUp)
                                    Positioned.fill(
                                      child: AbsorbPointer(
                                        child: CountBoard(
                                          title: NumberGameScreen.boardTitle,
                                          number: boardNumber,
                                          praise: boardPraise,
                                        ),
                                      ),
                                    ),
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
      ),
    );
  }
}

/// 같이 세는 동안 보기 자리를 덮는 큰 숫자판.
/// 위에 제목("같이 세어 볼까요?"), 가운데에 지금 센 숫자를 아주 크게, 아래에 한글 읽기("셋").
/// 정답 축하 때는 마지막 숫자 아래에 칭찬("셋! 정말 잘했어요!")을 쓴다.
class CountBoard extends StatelessWidget {
  const CountBoard({
    super.key,
    required this.title,
    required this.number,
    this.praise,
  });

  final String title;

  /// 지금 센 숫자 (0이면 아직 세기 전)
  final int number;
  final String? praise;

  static const numberKey = ValueKey('countBoardNumber');
  static const readingKey = ValueKey('countBoardReading');

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    builder: (_, t, child) => Transform.scale(
      scale: .85 + .15 * t,
      child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final color = number > 0
            ? NumberShape.colorOf(number)
            : Palette.textSoft;
        final reading = number > 0
            ? (praise != null
                  ? '${KoreanNumbers.count(number)}! $praise'
                  : KoreanNumbers.count(number))
            : '';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(min(28.0, h * .12)),
            border: Border.all(color: Palette.yellow, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Palette.panelShadow,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: h * .04),
          child: Column(
            children: [
              SizedBox(
                height: h * .16,
                width: double.infinity,
                child: FitBox(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 40, color: Palette.text),
                  ),
                ),
              ),
              Expanded(
                child: FitBox(
                  // 숫자가 바뀔 때마다 "쾅" 하고 커졌다 자리 잡는다
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(number),
                    tween: Tween(begin: number > 0 ? 1.5 : 1, end: 1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (_, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Text(
                      number > 0 ? '$number' : ' ',
                      key: numberKey,
                      style: TextStyle(
                        fontSize: 220,
                        height: 1.0,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: h * .2,
                width: double.infinity,
                child: FitBox(
                  child: Text(
                    reading.isEmpty ? ' ' : reading,
                    key: readingKey,
                    style: TextStyle(fontSize: 60, color: color),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
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
    this.canName = true,
  });

  final ObjectKind kind;

  /// 물건을 누르면 이름을 말해 줄지 (세는 중·정답 뒤에는 끈다)
  final bool canName;

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
          child: SayName(
            name: kind.sayName(),
            enabled: canName,
            child: Stamped(
              number: i < hintShown ? i + 1 : null,
              badgeSize: max(30, size * .4),
              child: ObjectIcon(kind, color: tint, size: size),
            ),
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
    this.canName = true,
  });

  final NumberQuestion question;
  final int hintShown;

  /// 물건을 누르면 이름을 말해 줄지 (세는 중·정답 뒤에는 끈다)
  final bool canName;

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
                  child: SayName(
                    name: o.kind.sayName(o.color),
                    enabled: canName,
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
              ),
          ],
        );
      },
    );
  }
}
