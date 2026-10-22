// 놀이 화면 다듬기: 같이 세기 숫자판 박자, 꾹 눌러 나가기, 큰 화면 카드 크기,
// 고유색 물건(사과는 빨강), 외곽선 없는 물건 그림
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/common/korean_numbers.dart';
import 'package:alokdalok/games/common/object_art.dart';
import 'package:alokdalok/games/common/quiz_widgets.dart';
import 'package:alokdalok/games/common/stamp.dart';
import 'package:alokdalok/games/match_game/match_game_screen.dart';
import 'package:alokdalok/games/match_game/match_round.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/size_game/size_round.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:alokdalok/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 말 길이를 흉내 내는 소리: 말은 [sayMs] 뒤에 끝나고, 모든 일을 [log]에 남긴다.
class TimedAudio extends RecordingAudio {
  TimedAudio(this.log, {this.sayMs = 700});
  final List<String> log;
  final int sayMs;

  @override
  Future<void> play(Sfx sfx) async {
    log.add('sfx:${sfx.name}');
    return super.play(sfx);
  }

  @override
  Future<void> say(String text) async {
    log.add('say:$text');
    await super.say(text);
    await Future<void>.delayed(Duration(milliseconds: sayMs));
    log.add('done:$text');
  }
}

Future<GameState> makeState([AudioService? audio]) async {
  final s = GameState(
    storage: MemoryStorage(),
    audio: audio ?? RecordingAudio(),
  );
  await s.load();
  await s.setNickname('별이');
  return s;
}

Widget wrap(GameState s, Widget home) => AppScope(
  state: s,
  child: MaterialApp(home: home),
);

Future<void> setSize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder choiceButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(PillButton));

/// 숫자판에 지금 쓰인 숫자 (판이 없으면 null, 세기 전이면 0)
int? boardNumber(WidgetTester t) {
  final f = find.byKey(CountBoard.numberKey);
  if (f.evaluate().isEmpty) return null;
  return int.tryParse(t.widget<Text>(f).data!.trim()) ?? 0;
}

int stampedCount(WidgetTester t) => t
    .widgetList<Stamped>(find.byType(Stamped))
    .where((w) => w.number != null)
    .length;

/// 1단계에서 세는 물건이 [min]개 이상 나오는 시드
int seedWithCount(int min) {
  for (var seed = 1; seed < 500; seed++) {
    if (NumberQuestion.generate(Stages.number[0], Random(seed)).count >= min) {
      return seed;
    }
  }
  throw StateError('no seed');
}

void main() {
  group('숫자 놀이: 같이 세기 큰 숫자판', () {
    /// 10ms마다 화면과 소리를 지켜보며 박자를 기록한다.
    /// 반환: 일 → 그 일이 처음 일어난 칸 번호
    Future<Map<String, int>> watch(
      WidgetTester t,
      List<String> log,
      List<String> haptics,
      int steps, {
      void Function(int step)? onStep,
    }) async {
      final at = <String, int>{};
      var seen = 0, seenHaptic = 0, stamps = 0;
      int? lastBoard;
      for (var step = 0; step < steps; step++) {
        await t.pump(const Duration(milliseconds: 10));
        for (; seen < log.length; seen++) {
          var key = log[seen];
          if (key == 'sfx:stamp') key = 'stamp:${++stamps}';
          at.putIfAbsent(key, () => step);
        }
        for (; seenHaptic < haptics.length; seenHaptic++) {
          at.putIfAbsent('haptic:${seenHaptic + 1}', () => step);
        }
        final b = boardNumber(t);
        if (b != lastBoard) {
          lastBoard = b;
          at.putIfAbsent('board:${b ?? 'gone'}', () => step);
          if (b != null && b > 0) {
            // 숫자판이 n이 되는 순간 물건 n개에 도장이 찍혀 있다
            expect(stampedCount(t), b, reason: '숫자판 $b와 도장 수');
          }
        }
        onStep?.call(step);
      }
      return at;
    }

    List<String> mockHaptics(WidgetTester t) {
      final haptics = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return haptics;
    }

    testWidgets('틀리면: 숫자판 숫자·도장·진동·목소리가 같은 순간, 말이 끝나야 다음 숫자, 0.9초 뒤 판을 내린다', (
      t,
    ) async {
      await setSize(t, const Size(844, 390));
      final log = <String>[];
      final s = await makeState(TimedAudio(log));
      final haptics = mockHaptics(t);
      final seed = seedWithCount(3);
      final q = NumberQuestion.generate(Stages.number[0], Random(seed));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(seed))),
      );
      await settle(t, 900);
      expect(find.byType(CountBoard), findsNothing);
      final wrong = q.choices.firstWhere((c) => c != q.count);
      log.clear();
      await t.tap(choiceButton('$wrong'));

      final at = await watch(t, log, haptics, 600);
      // 판이 먼저 뜨고 제목을 말한다
      expect(at['board:0'], isNotNull, reason: '판에 제목만 먼저');
      expect(log, contains('say:${NumberGameScreen.boardTitle}'));
      expect(find.text(NumberGameScreen.boardTitle), findsWidgets);
      for (var i = 1; i <= q.count; i++) {
        final word = KoreanNumbers.count(i);
        final board = at['board:$i'];
        expect(board, isNotNull, reason: '숫자판 $i');
        expect(at['stamp:$i'], board, reason: '$i: 도장 소리와 숫자판이 같은 순간');
        expect(at['haptic:$i'], board, reason: '$i: 진동과 숫자판이 같은 순간');
        expect(at['say:$word'], board, reason: '$i: "$word"와 숫자판이 같은 순간');
        if (i > 1) {
          final prev = KoreanNumbers.count(i - 1);
          expect(
            board,
            greaterThanOrEqualTo(at['done:$prev']!),
            reason: '"$prev" 말이 끝난 뒤에야 $i',
          );
        }
      }
      // 다 센 뒤 약 0.9초 뒤 판이 내려간다
      final lastDone = at['done:${KoreanNumbers.count(q.count)}']!;
      final gone = at['board:gone']!;
      expect((gone - lastDone) * 10, inInclusiveRange(850, 1000));
      expect(haptics.length, q.count);
      // 판이 내려가면 다시 고를 수 있다
      final coins = s.coins;
      await t.tap(choiceButton('${q.count}'));
      await t.pump(const Duration(milliseconds: 50));
      expect(s.coins, greaterThan(coins));
      await t.pumpWidget(const SizedBox());
      await settle(t, 3000);
    });

    testWidgets('맞히면: 빠르게 같이 센 뒤 "셋, 정말 잘했어요!"를 이어 말하고 다음 문제', (t) async {
      await setSize(t, const Size(844, 390));
      final log = <String>[];
      final s = await makeState(TimedAudio(log, sayMs: 250));
      final haptics = mockHaptics(t);
      final seed = seedWithCount(3);
      final q = NumberQuestion.generate(Stages.number[0], Random(seed));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(seed))),
      );
      await settle(t, 900);
      log.clear();
      await t.tap(choiceButton('${q.count}'));
      final at = await watch(t, log, haptics, 400);
      final finale =
          '${KoreanNumbers.count(q.count)}, ${NumberGameScreen.praise}';
      for (var i = 1; i <= q.count; i++) {
        final line = i == q.count ? finale : KoreanNumbers.count(i);
        expect(at['say:$line'], at['board:$i'], reason: '$i');
        expect(at['stamp:$i'], at['board:$i'], reason: '$i');
      }
      expect(log, isNot(contains('say:${NumberGameScreen.boardTitle}')));
      // 빠르게: 한 박자가 틀렸을 때보다 짧다
      final beat = (at['board:2']! - at['board:1']!) * 10;
      expect(beat, lessThan(700));
      // 칭찬 뒤 다음 문제
      expect(at['board:gone'], greaterThan(at['done:$finale']!));
      expect(find.byType(CountBoard), findsNothing);
      await t.pumpWidget(const SizedBox());
      await settle(t, 3000);
    });

    testWidgets('정답 숫자판에는 큰 숫자와 "셋! 정말 잘했어요!"가 보인다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await makeState();
      final seed = seedWithCount(3);
      final q = NumberQuestion.generate(Stages.number[0], Random(seed));
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(seed))),
      );
      await settle(t, 900);
      await t.tap(choiceButton('${q.count}'));
      var sawPraise = false;
      for (var i = 0; i < 300 && !sawPraise; i++) {
        await t.pump(const Duration(milliseconds: 10));
        sawPraise = find
            .text('${KoreanNumbers.count(q.count)}! ${NumberGameScreen.praise}')
            .evaluate()
            .isNotEmpty;
      }
      expect(sawPraise, isTrue);
      expect(boardNumber(t), q.count);
      // 숫자판은 보기 자리 전체를 덮는다 (보기 버튼 위)
      final board = t.getRect(find.byType(CountBoard));
      for (final c in q.choices) {
        final r = t.getRect(choiceButton('$c').first);
        expect(board.contains(r.center), isTrue);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await settle(t, 3000);
    });

    testWidgets('세는 도중 화면이 사라져도 오류가 없다 (비동기 단계마다 mounted 확인)', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState(TimedAudio(<String>[]));
      final seed = seedWithCount(3);
      final q = NumberQuestion.generate(Stages.number[0], Random(seed));
      for (final pick in [q.count, q.choices.firstWhere((c) => c != q.count)]) {
        await t.pumpWidget(
          wrap(s, NumberGameScreen(stageId: 1, random: Random(seed))),
        );
        await settle(t, 900);
        await t.tap(choiceButton('$pick'));
        await settle(t, 1500); // 세는 도중
        await t.pumpWidget(const SizedBox());
        await settle(t, 8000);
        expect(t.takeException(), isNull);
      }
    });

    for (final size in const [
      Size(568, 320),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      testWidgets(
        '숫자판이 ${size.width.toInt()}x${size.height.toInt()}에서 넘치지 않는다',
        (t) async {
          await setSize(t, size);
          final s = await makeState();
          final q = NumberQuestion.generate(Stages.number[7], Random(3));
          await t.pumpWidget(
            wrap(s, NumberGameScreen(stageId: 8, random: Random(3))),
          );
          await settle(t, 900);
          await t.tap(
            choiceButton('${q.choices.firstWhere((c) => c != q.count)}'),
          );
          await settle(t, 2400);
          expect(find.byType(CountBoard), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await settle(t, 8000);
        },
      );
    }
  });

  test('같이 세기·꾹 누르기에서 하는 말은 모두 이미 있는 녹음 조각으로 나뉜다', () {
    final lines = VoiceLines.all();
    final pack = VoicePack({
      for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3',
    });
    for (final text in [
      NumberGameScreen.boardTitle,
      HoldToConfirm.hint,
      for (var n = 1; n <= 10; n++) ...[
        KoreanNumbers.count(n),
        '${KoreanNumbers.count(n)}, ${NumberGameScreen.praise}',
      ],
    ]) {
      expect(pack.plan(text), isNotNull, reason: text);
    }
  });

  test('실제 녹음 팩(manifest)으로도 새 화면의 말이 녹음 조각으로 재생된다', () {
    final manifest = (jsonDecode(
      File('assets/voice/manifest.json').readAsStringSync(),
    ) as Map).cast<String, String>();
    final pack = VoicePack(manifest);
    // 말 → 기대하는 조각 문장들
    final cases = {
      HoldToConfirm.hint: ['꾹 누르고 있어요.'],
      NumberGameScreen.boardTitle: ['같이 세어 볼까요?'],
      '${KoreanNumbers.count(3)}, ${NumberGameScreen.praise}': [
        '셋',
        '정말 잘했어요!',
      ],
    };
    for (final e in cases.entries) {
      final clips = pack.plan(e.key);
      expect(clips, isNotNull, reason: e.key);
      expect(
        [for (final c in clips!) c.file],
        [for (final s in e.value) manifest[s]],
        reason: e.key,
      );
      for (final c in clips) {
        expect(File('assets/voice/${c.file}').existsSync(), isTrue);
      }
    }
  });

  group('멈춤 화면: 꾹 눌러 나가기', () {
    Future<void> openPause(WidgetTester t, GameState s) async {
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(1))),
      );
      await settle(t, 800);
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is Pressable && w.semanticLabel == '잠깐 멈추기',
        ),
      );
      await settle(t, 300);
    }

    double ring(WidgetTester t) =>
        (t
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (w) => w is CustomPaint && w.painter is HoldRingPainter,
                      ),
                    )
                    .painter!
                as HoldRingPainter)
            .progress;

    testWidgets('이름표는 "집으로 (꾹)"이고 손가락 그림이 붙는다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await openPause(t, s);
      expect(find.text('집으로 (꾹)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HoldToConfirm),
          matching: find.byIcon(Icons.touch_app_rounded),
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('톡 누르면 고리가 살짝 차올랐다 줄고 "꾹 누르고 있어요"라고 말한다 (나가지 않음)', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await openPause(t, s);
      final home = find.byType(HoldToConfirm);
      final g = await t.startGesture(t.getCenter(home));
      await t.pump(const Duration(milliseconds: 30));
      await g.up();
      var peak = 0.0;
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 20));
        peak = max(peak, ring(t));
      }
      expect(peak, greaterThanOrEqualTo(HoldToConfirm.nudge - .01));
      await settle(t, 600);
      expect(ring(t), 0, reason: '다시 비워진다');
      expect((s.audio as RecordingAudio).spoken.last, HoldToConfirm.hint);
      expect(find.byType(NumberGameScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('약 0.9초 꾹 누르면 고리가 다 차고 나간다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await openPause(t, s);
      expect(HoldToConfirm.defaultHoldTime, const Duration(milliseconds: 900));
      final g = await t.startGesture(t.getCenter(find.byType(HoldToConfirm)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 450));
      expect(ring(t), inInclusiveRange(.4, .6));
      await t.pump(const Duration(milliseconds: 500));
      await g.up();
      await settle(t, 800);
      expect(find.byType(NumberGameScreen), findsNothing);
    });
  });

  group('큰 화면에서 보기·카드 크기', () {
    test('카드 수에 따라 1~3줄 중 칸이 가장 큰 배치를 고른다', () {
      // 넓은 칸: 4장은 한 줄
      expect(TileGrid.fit(4, const Size(1000, 300), maxRows: 3).rows, 1);
      // 정사각형에 가까운 칸: 4장은 2x2가 더 크다
      final sq = TileGrid.fit(4, const Size(600, 560), maxRows: 3);
      expect((sq.rows, sq.cols), (2, 2));
      // 12장은 최대 3줄
      expect(
        TileGrid.fit(12, const Size(400, 1000), maxRows: 3).rows,
        lessThanOrEqualTo(3),
      );
      // 한계를 주지 않으면 자리를 다 쓴다 (예전 230 한계 없음)
      expect(TileGrid.fit(2, const Size(1000, 600)).tile, greaterThan(400));
    });

    testWidgets('1280x800 짝 맞추기 4장은 판을 크게 채운다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await makeState();
      await t.pumpWidget(
        wrap(s, MatchGameScreen(stageId: 1, random: Random(1))),
      );
      await settle(t, 900);
      final tiles = find.byType(QuizTile);
      expect(tiles, findsNWidgets(4));
      final w = t.widget<QuizTile>(tiles.first).width;
      expect(w, greaterThan(200), reason: '예전에는 170으로 묶여 작게 모였다');
      // 카드 묶음이 보기 칸 높이나 너비의 대부분을 쓴다
      final rects = [for (var i = 0; i < 4; i++) t.getRect(tiles.at(i))];
      final span = rects.reduce((a, b) => a.expandToInclude(b));
      final body = t.getRect(find.byType(QuizGrid));
      expect(
        max(span.width / body.width, span.height / body.height),
        greaterThan(.9),
      );
      await t.pumpWidget(const SizedBox());
      await settle(t, 3000);
    });

    testWidgets('1280x800 숫자 보기는 큰 동그라미에 맞춰 숫자도 커진다', (t) async {
      await setSize(t, const Size(1280, 800));
      final s = await makeState();
      await t.pumpWidget(
        wrap(s, NumberGameScreen(stageId: 1, random: Random(1))),
      );
      await settle(t, 900);
      final buttons = find.byType(PillButton);
      final big = [
        for (final e in buttons.evaluate())
          if (t.getSize(find.byWidget(e.widget)).height > 180) e.widget,
      ];
      expect(big, isNotEmpty, reason: '1280 화면의 숫자 보기 동그라미');
      for (final b in big) {
        final button = t.getSize(find.byWidget(b));
        final digit = find.descendant(
          of: find.byWidget(b),
          matching: find.byWidgetPredicate(
            (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
          ),
        );
        // 예전에는 46px 글씨 그대로라 버튼 높이의 약 20%였다
        expect(t.getRect(digit).height / button.height, greaterThan(.28));
      }
      await t.pumpWidget(const SizedBox());
      await settle(t, 3000);
    });

    for (final size in const [Size(568, 320), Size(844, 390), Size(1280, 800)]) {
      testWidgets(
        '${size.width.toInt()} 숫자 보기에는 숫자만 크게 (주사위 발자국 그림 없음)',
        (t) async {
          await setSize(t, size);
          final s = await makeState();
          await t.pumpWidget(
            wrap(s, NumberGameScreen(stageId: 1, random: Random(1))),
          );
          await settle(t, 900);
          final digitButtons = [
            for (final e in find.byType(PillButton).evaluate())
              if (RegExp(
                r'^\d+$',
              ).hasMatch((e.widget as PillButton).semanticLabel ?? ''))
                e.widget,
          ];
          expect(digitButtons, isNotEmpty);
          for (final b in digitButtons) {
            final paints = find.descendant(
              of: find.byWidget(b),
              matching: find.byType(CustomPaint),
            );
            for (final p in t.widgetList<CustomPaint>(paints)) {
              expect(p.painter, isNull, reason: '보기 안에 주사위 그림이 없다');
              expect(p.foregroundPainter, isNull);
            }
            final digit = find.descendant(
              of: find.byWidget(b),
              matching: find.byWidgetPredicate(
                (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
              ),
            );
            expect(digit, findsOneWidget, reason: '숫자 하나만');
            // 숫자가 버튼 높이의 절반 가까이 차지할 만큼 크다
            expect(
              t.getRect(digit).height / t.getSize(find.byWidget(b)).height,
              greaterThan(.4),
            );
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await settle(t, 3000);
        },
      );
    }

    test('문제 글씨는 화면(카드 높이)에 비례해 커진다', () {
      expect(quizPromptSize(200), 28);
      expect(quizPromptSize(560), greaterThan(36));
      expect(quizPromptSize(2000), lessThanOrEqualTo(46));
    });
  });

  group('고유색 물건: 사과는 늘 빨강', () {
    test('색을 바꿔 쓰는 물건은 원래 여러 색인 것만', () {
      expect(
        {
          for (final k in ObjectKind.values)
            if (k.tintable) k,
        },
        {
          ObjectKind.ball,
          ObjectKind.balloon,
          ObjectKind.car,
          ObjectKind.star,
          ObjectKind.flower,
          ObjectKind.fish,
        },
      );
      expect(ObjectKind.apple.fixedColor, GameColor.red);
      expect(ObjectKind.duck.fixedColor, GameColor.yellow);
      expect(ObjectKind.apple.colorFor(GameColor.yellow), GameColor.red);
      expect(ObjectKind.ball.colorFor(GameColor.yellow), GameColor.yellow);
      expect(ObjectKind.apple.naturalColor, GameColor.red.color);
    });

    test('짝 맞추기·크기 놀이·색깔 놀이 문제에서 사과는 빨강, 오리는 노랑', () {
      for (var seed = 0; seed < 60; seed++) {
        for (final st in Stages.match) {
          final b = MatchBoard.generate(st, Random(seed));
          for (final c in b.cards) {
            if (!c.kind.tintable) {
              expect(c.color, c.kind.fixedColor, reason: '${c.kind} ${st.id}');
            }
          }
          // 서로 다른 짝은 그림이 달라야 한다
          final faces = {for (final c in b.cards) '${c.kind}/${c.color}'};
          expect(faces.length, b.pairs);
        }
        for (final st in Stages.size) {
          final q = SizeQuestion.generate(st, Random(seed));
          if (!q.kind.tintable) expect(q.color, q.kind.fixedColor);
        }
        for (final st in Stages.color) {
          final q = ColorQuestion.generate(st, Random(seed));
          for (final c in q.choices) {
            expect(c.kind.tintable, isTrue, reason: '${c.kind} ${c.color}');
          }
        }
      }
      // 같은 물건 다른 색 단계와 색이 섞인 숫자 단계는 색을 바꿀 수 있는 물건만
      for (final st in Stages.match.where((m) => m.colorVariant)) {
        expect(st.objects.every((k) => k.tintable), isTrue);
      }
      for (final st in Stages.number.where(
        (n) => n.mode == NumberMode.mixColors || n.mode == NumberMode.mixBoth,
      )) {
        expect(st.objects.every((k) => k.tintable), isTrue, reason: '${st.id}');
      }
    });

    testWidgets('사과 그림에 다른 색을 줘도 빨강으로 그린다', (t) async {
      await t.pumpWidget(
        const Center(child: ObjectIcon(ObjectKind.apple, color: Colors.yellow)),
      );
      final p =
          t.widget<CustomPaint>(find.byType(CustomPaint)).painter!
              as ObjectPainter;
      expect(p.color, GameColor.red.color);
    });
  });

  group('놀이 물건 그림체', () {
    test('물건·모양 그림에 갈색 외곽선이 없다', () {
      for (final path in [
        'lib/games/common/object_art.dart',
        'lib/games/shape_game/shape_art.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src.contains('Palette.outline'), isFalse, reason: path);
      }
    });

    testWidgets('모든 물건을 작은 크기(28px)에서도 그린다', (t) async {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final k in ObjectKind.values) ...[
                ObjectIcon(k, size: 28),
                ObjectIcon(k, size: 28, faded: true),
              ],
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
    });
  });
}
