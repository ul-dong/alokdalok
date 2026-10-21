import 'dart:math';

import 'package:alokdalok/app.dart';
import 'package:alokdalok/character/nickname.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/games/common/object_art.dart';
import 'package:alokdalok/games/common/journey_trail.dart';
import 'package:alokdalok/screens/bag_screen.dart';
import 'package:alokdalok/screens/settings_screen.dart';
import 'package:alokdalok/shop/item_widgets.dart';
import 'package:alokdalok/vehicle/garage_screen.dart';
import 'package:alokdalok/screens/character_screen.dart';
import 'package:alokdalok/screens/stage_picker.dart';
import 'package:alokdalok/screens/zodiac_picker_screen.dart';
import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_game_screen.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/number_game/number_game_screen.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/shop/shop_screen.dart';
import 'package:alokdalok/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<GameState> makeState({bool named = true}) async {
  final s = GameState(storage: MemoryStorage(), audio: RecordingAudio());
  await s.load();
  if (named) await s.setNickname('별이');
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

/// 반복 애니메이션 때문에 pumpAndSettle 대신 시간을 정해 넘긴다
Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder pressable(String label) =>
    find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

Finder choiceButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(PillButton));

void main() {
  for (final size in const [
    Size(568, 320), // 아주 작은 휴대폰 (가로)
    Size(640, 360),
    Size(844, 390), // 요즘 휴대폰
    Size(1180, 820), // 태블릿
    Size(1366, 768), // 노트북 브라우저
    Size(1280, 800), // 갤럭시 탭 (가로)
  ]) {
    testWidgets(
      '메인 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 깨지지 않는다',
      (t) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(AlokdalokApp(state: s));
        await settle(t);
        expect(t.takeException(), isNull);
        expect(find.textContaining('별이', findRichText: true), findsOneWidget);
        // 홈에는 큰 버튼 세 개만 (놀이터 가기 · 내 캐릭터 · 꾸미기 상점)
        for (final label in ['놀이터 가기', '내 캐릭터', '꾸미기 상점']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        for (final label in ['숫자 놀이', '색깔 놀이', '내 가방', '탈것 꾸미기']) {
          expect(find.text(label), findsNothing, reason: label);
        }
      },
    );

    testWidgets(
      '숫자 놀이 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 깨지지 않는다',
      (t) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(
          wrap(s, NumberGameScreen(stageId: 3, random: Random(1))),
        );
        await settle(t);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '색깔 놀이 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 깨지지 않는다',
      (t) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(
          wrap(s, ColorGameScreen(stageId: 3, random: Random(1))),
        );
        await settle(t);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '상점 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 깨지지 않는다',
      (t) async {
        await setSize(t, size);
        final s = await makeState();
        await t.pumpWidget(wrap(s, const ShopScreen()));
        await settle(t);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('첫 실행: 친구 고르기 → 이름 짓기 → 메인 화면에 표시', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState(named: false);
    await t.pumpWidget(AlokdalokApp(state: s));
    await settle(t);
    expect(pressable('12지신'), findsOneWidget);
    expect(pressable('공룡'), findsOneWidget);
    expect(t.takeException(), isNull);

    // 공룡 탭: 트리케라톱스를 고를 수 있다
    await t.tap(pressable('공룡'));
    await settle(t, 300);
    expect(pressable('트리케라톱스'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(pressable('트리케라톱스'));
    await settle(t, 300);
    expect((s.audio as RecordingAudio).spoken.last, '나는 트리케라톱스야!');

    await t.tap(pressable('12지신'));
    await settle(t, 300);
    await t.tap(pressable('토끼'));
    await settle(t, 300);
    await t.tap(pressable('이 친구로 할래요'));
    await settle(t);
    expect(s.zodiac, Zodiac.rabbit);
    expect(find.text('이름을 지어 주세요'), findsOneWidget);
    expect(t.takeException(), isNull);

    // 잘못된 입력은 거절
    await t.enterText(find.byType(TextField), '바보');
    await t.tap(find.text('좋아요'));
    await settle(t, 300);
    expect(find.text('다른 닉네임을 써 주세요.'), findsOneWidget);
    expect(s.nicknameChosen, isFalse);

    // 예시 이름은 보여 주지 않는다. 비워 두고 좋아요 → 아무 이름이나 지어 준다
    expect(find.text('콩이'), findsNothing);
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('좋아요'));
    await settle(t);
    expect(Nickname.randomPool, contains(s.nickname));
    expect(s.nicknameChosen, isTrue);
    expect(find.textContaining(s.nickname, findRichText: true), findsOneWidget);
    expect(find.text('놀이터 가기'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('세로 창이면 가로로 돌려 달라는 안내만 보인다', (t) async {
    await setSize(t, const Size(390, 844));
    final s = await makeState();
    await t.pumpWidget(AlokdalokApp(state: s));
    await settle(t);
    expect(find.text('화면을 옆으로 돌려 주세요'), findsOneWidget);
    expect(find.text('놀이터 가기'), findsNothing);
  });

  for (final n in List.generate(10, (i) => i + 1)) {
    testWidgets('숫자 문제 사물은 정확히 $n개 그려진다', (t) async {
      await setSize(t, const Size(844, 390));
      final s = await makeState();
      await t.pumpWidget(
        wrap(
          s,
          Scaffold(
            body: SizedBox(
              width: 500,
              height: 220,
              child: ObjectField(kind: ObjectKind.fish, count: n, hintShown: 0),
            ),
          ),
        ),
      );
      await settle(t, 1500);
      expect(find.byType(ObjectIcon), findsNWidgets(n));
      expect(objectRows(n).fold<int>(0, (a, b) => a + b), n);
    });
  }

  for (final size in const [Size(568, 320), Size(844, 390), Size(1180, 820)]) {
    testWidgets(
      '친구 고르기·내 캐릭터·가방 화면이 ${size.width.toInt()}x${size.height.toInt()}에서 깨지지 않는다',
      (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (final page in const [
          ZodiacPickerScreen(),
          CharacterScreen(),
          BagScreen(),
        ]) {
          await t.pumpWidget(wrap(s, page));
          await settle(t);
          expect(
            t.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
        }
        await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.number)));
        await settle(t);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('숫자 놀이: 오답은 코인을 줄이지 않고, 정답은 코인을 준다', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    final audio = s.audio as RecordingAudio;
    // 같은 시드로 화면이 낼 첫 문제를 미리 계산
    final expected = NumberQuestion.generate(Stages.number[0], Random(42));
    await t.pumpWidget(
      wrap(s, NumberGameScreen(stageId: 1, random: Random(42))),
    );
    await settle(t);
    expect(find.text(expected.prompt), findsOneWidget);
    expect(audio.spoken, contains(expected.prompt), reason: '문제를 음성으로 읽어 준다');

    final coins = s.coins;
    final wrong = expected.choices.firstWhere((c) => c != expected.count);
    await t.tap(choiceButton('$wrong'));
    await settle(t, 300);
    expect(s.coins, coins, reason: '오답에 코인 차감 없음');
    expect(audio.played.last, Sfx.tryAgain);
    expect(find.text('같이 세어 볼까요?'), findsWidgets); // 말풍선 + 크게 뜨는 안내

    await t.tap(choiceButton('${expected.count}'));
    await settle(t, 300);
    expect(s.coins, coins + Economy.correctAfterRetry);
    expect(audio.played, contains(Sfx.correct));

    await settle(t, 2500); // 다음 문제로
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('숫자 놀이: 5문제를 끝내면 결과 화면과 완료 보상', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    final rng = Random(5);
    final mirror = Random(5);
    await t.pumpWidget(wrap(s, NumberGameScreen(stageId: 1, random: rng)));
    await settle(t);
    final start = s.coins;
    NumberQuestion? prev;
    for (var i = 0; i < Economy.questionsPerSession; i++) {
      final q = NumberQuestion.generate(
        Stages.number[0],
        mirror,
        previous: prev,
      );
      prev = q;
      await t.tap(choiceButton('${q.count}'));
      await settle(t, 2400);
    }
    await settle(t, 600);
    expect(find.text('또 하기'), findsOneWidget);
    final expectedCoins =
        start +
        Economy.correctFirstTry * Economy.questionsPerSession +
        Economy.sessionComplete +
        Economy.firstPlayBonus +
        Economy.newStageBonus;
    expect(s.coins, expectedCoins);
    expect(s.unlockedStage(GameKind.number), 2);
    expect(find.text('다음 단계'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('색깔 놀이: 정답 사물을 누르면 성공', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    final q = ColorQuestion.generate(Stages.color[1], Random(9));
    await t.pumpWidget(wrap(s, ColorGameScreen(stageId: 2, random: Random(9))));
    await settle(t);
    expect(find.text(q.prompt), findsOneWidget);
    final coins = s.coins;

    final tiles = find.byType(Pressable).evaluate().where((e) {
      final label = (e.widget as Pressable).semanticLabel ?? '';
      return label.endsWith(q.target.kind.ko) && !label.contains('듣기');
    }).toList();
    expect(tiles.length, q.choices.length);

    final wrongIndex = q.answerIndex == 0 ? 1 : 0;
    await t.tap(find.byWidget(tiles[wrongIndex].widget));
    await settle(t, 300);
    expect(s.coins, coins);
    final audio = s.audio as RecordingAudio;
    expect(
      audio.spoken.last,
      contains(q.choices[wrongIndex].color.name),
      reason: '누른 색 이름을 알려 준다',
    );

    await t.tap(find.byWidget(tiles[q.answerIndex].widget));
    await settle(t, 300);
    expect(s.coins, coins + Economy.correctAfterRetry);
    await settle(t, 2400);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('상점: 확인 후 구매, 코인 부족하면 구매 버튼 대신 안내', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    await t.pumpWidget(wrap(s, const ShopScreen()));
    await settle(t);

    // 공주 탭 → 분홍 리본(10코인) 선택 → 사기 → 확인
    await t.tap(pressable('공주'));
    await settle(t, 300);
    await t.tap(pressable('분홍 리본, 코인 10개'));
    await settle(t, 300);
    await t.tap(pressable('코인 10개로 사기'));
    await settle(t, 400);
    expect(find.text('10개로 살까요?'), findsOneWidget);
    await t.tap(pressable('아니요'));
    await settle(t, 400);
    expect(s.owns('ribbon_pink'), isFalse, reason: '취소하면 사지 않음');

    await t.tap(pressable('코인 10개로 사기'));
    await settle(t, 400);
    await t.tap(pressable('네'));
    await settle(t, 400);
    expect(s.owns('ribbon_pink'), isTrue);
    expect(s.coins, 0);

    // 이제 코인이 0 → 왕관 선택 시 구매 버튼 없음
    await t.tap(pressable('반짝 왕관, 코인 30개'));
    await settle(t, 300);
    expect(pressable('코인 30개로 사기'), findsNothing);
    expect(find.textContaining('놀이하면서 코인을 모아요'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('상점: 탈것 탭에서 자동차를 사서 타고, 테마 탭은 화살표로 넘긴다', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    for (var i = 0; i < 20; i++) {
      await s.rewardCorrect(firstTry: true);
    }
    await t.pumpWidget(wrap(s, const ShopScreen()));
    await settle(t);
    for (final label in ['탈것', '로봇', '공주']) {
      expect(pressable(label), findsOneWidget, reason: label);
    }
    // 뒤쪽 테마는 큰 화살표로 한 쪽씩 넘겨서 본다 (옆으로 밀기 없음)
    final tabs = find.byType(ThemeTabs);
    for (var i = 0; i < 10 && pressable('발레리나').evaluate().isEmpty; i++) {
      await t.tap(find.descendant(of: tabs, matching: pressable('다음 쪽')));
      await settle(t, 300);
    }
    expect(pressable('발레리나'), findsOneWidget);
    await t.tap(pressable('발레리나'));
    await settle(t, 300);
    expect(pressable('발레 튀튀, 코인 40개'), findsOneWidget);
    for (var i = 0; i < 10 && pressable('탈것').evaluate().isEmpty; i++) {
      await t.tap(find.descendant(of: tabs, matching: pressable('앞 쪽')));
      await settle(t, 300);
    }
    await t.tap(pressable('탈것'));
    await settle(t, 300);
    await t.tap(pressable('자동차, 코인 40개'));
    await settle(t, 300);
    await t.tap(pressable('코인 40개로 사기'));
    await settle(t, 400);
    await t.tap(pressable('네'));
    await settle(t, 600);
    expect(s.ownsVehicle('car'), isTrue);
    expect(s.ride, isNull, reason: '사고 나서 "탑승!"을 눌러야 탄다');
    await t.tap(pressable('탑승!'));
    await settle(t, 400);
    expect(s.ride, 'car');
    expect(t.takeException(), isNull);
  });

  for (final size in const [
    Size(568, 320),
    Size(844, 390),
    Size(1280, 800), // 갤럭시 탭 (가로)
    Size(1340, 800), // 갤럭시 탭 S 계열 (가로, dp)
  ]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    for (final vehicle in ['rocket', 'balloon', 'train', 'airplane']) {
      testWidgets('탈것 꾸미기($vehicle): $name에서 스티커 붙이고 지우기', (t) async {
        await setSize(t, size);
        final s = await makeState();
        for (var i = 0; i < 30; i++) {
          await s.rewardCorrect(firstTry: true);
        }
        await s.buyVehicle(vehicle);
        await t.pumpWidget(wrap(s, const GarageScreen()));
        await settle(t);
        expect(t.takeException(), isNull);
        final body = find.bySemanticsLabel(RegExp('눌러서 스티커 붙이기'));
        expect(body, findsOneWidget);
        // 차체 안쪽 한 점을 눌러 붙인다 (탈것마다 차체 위치가 다르다)
        final box = t.getRect(body);
        final scale = min(box.width / 300, box.height / 200);
        final origin = box.center - Offset(150 * scale, 100 * scale);
        final spot = switch (vehicle) {
          'balloon' => const Offset(150, 40),
          'train' => const Offset(190, 120),
          'airplane' => const Offset(120, 112),
          _ => const Offset(120, 118),
        };
        await t.tapAt(origin + spot * scale);
        await settle(t, 300);
        expect(s.stickersOf(vehicle).length, 1);
        await t.tap(pressable('지우개'));
        await settle(t, 200);
        await t.tapAt(origin + spot * scale);
        await settle(t, 300);
        expect(s.stickersOf(vehicle), isEmpty);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('탈것 꾸미기: $name에서 색을 사서 칠한다', (t) async {
      await setSize(t, size);
      final s = await makeState();
      for (var i = 0; i < 30; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      await s.buyVehicle('tank');
      await t.pumpWidget(wrap(s, const GarageScreen()));
      await settle(t);
      await t.tap(pressable('색칠'));
      await settle(t, 300);
      expect(t.takeException(), isNull);
      final coins = s.coins;
      await t.tap(pressable('보라색, 코인 10개'));
      await settle(t, 400);
      await t.tap(pressable('네'));
      await settle(t, 400);
      expect(s.paintOf('tank').id, 'paint_purple');
      expect(s.coins, coins - 10);
      await t.tap(pressable('초록색')); // 기본 색은 공짜
      await settle(t, 300);
      expect(s.paintOf('tank').id, 'paint_green');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('단계 고르기·섞인 숫자 문제·탈것 탄 놀이 화면이 $name에서 깨지지 않는다', (t) async {
      await setSize(t, size);
      final s = await makeState();
      for (var i = 0; i < 30; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      await s.buyVehicle('motorcycle');
      await s.setRide('motorcycle');
      for (var id = 1; id <= 4; id++) {
        await s.completeSession(GameKind.number, id);
      }
      await t.pumpWidget(wrap(s, const StagePicker(game: GameKind.number)));
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.byType(JourneyTrail), findsOneWidget);
      expect(pressable('5단계'), findsOneWidget, reason: '열린 단계가 보이게 스크롤');
      for (final id in [2, 5, 8]) {
        await t.pumpWidget(
          wrap(s, NumberGameScreen(stageId: id, random: Random(id))),
        );
        await settle(t, 1500);
        expect(t.takeException(), isNull, reason: '$id단계');
        expect(find.byType(JourneyTrail), findsOneWidget);
        if (id >= 4) expect(find.byType(ScatterField), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      }
      for (final id in [1, 5]) {
        await t.pumpWidget(wrap(s, ColorGameScreen(stageId: id)));
        await settle(t, 1200);
        expect(t.takeException(), isNull, reason: '색 $id단계');
        await t.pumpWidget(const SizedBox());
      }
      await t.pumpWidget(wrap(s, const SettingsScreen()));
      await settle(t);
      expect(t.takeException(), isNull);
      expect(pressable('녹음'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('섞인 숫자 문제: 틀리면 세는 물건에만 번호가 붙고, 맞히면 다음 문제', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    await t.pumpWidget(
      wrap(s, NumberGameScreen(stageId: 8, random: Random(3))),
    );
    await settle(t, 1200);
    final field = t.widget<ScatterField>(find.byType(ScatterField));
    final q = field.question;
    final audio = s.audio as RecordingAudio;
    expect(audio.spoken.last, q.prompt);
    final wrong = q.choices.firstWhere((c) => c != q.count);
    await t.tap(choiceButton('$wrong'));
    await settle(t, 650 * q.count + 400);
    // 세는 물건 수만큼 번호
    for (var n = 1; n <= q.count; n++) {
      expect(find.text('$n'), findsWidgets);
    }
    final coins = s.coins;
    await t.tap(choiceButton('${q.count}'));
    await settle(t, 400);
    expect(s.coins, coins + Economy.correctAfterRetry);
    expect(audio.spoken.last, contains(q.answerLine));
    await settle(t, 2400);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('단계마다 계절 음악이 나오고, 나가면 꺼지고, 설정에서 끌 수 있다', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    final audio = s.audio as RecordingAudio;
    await t.pumpWidget(
      wrap(
        s,
        NumberGameScreen(key: const ValueKey(2), stageId: 2, random: Random(1)),
      ),
    );
    await settle(t, 600);
    expect(audio.music, 'summer', reason: '2단계는 여름');
    await t.pumpWidget(
      wrap(
        s,
        NumberGameScreen(key: const ValueKey(4), stageId: 4, random: Random(1)),
      ),
    );
    await settle(t, 600);
    expect(audio.music, 'winter', reason: '4단계는 겨울');
    await t.pumpWidget(wrap(s, const ColorGameScreen(stageId: 5)));
    await settle(t, 600);
    expect(audio.music, 'spring', reason: '5단계는 다시 봄');
    await s.setMusic(false);
    expect(audio.music, isNull);
    await s.setMusic(true);
    expect(audio.music, 'spring', reason: '다시 켜면 이어서');
    await t.pumpWidget(const SizedBox());
    await settle(t, 200);
    expect(audio.music, isNull, reason: '놀이에서 나가면 음악 끔');
  });

  testWidgets('메인 화면 음악 → 놀이(계절 음악) → 돌아오면 다시 메인 음악', (t) async {
    await setSize(t, const Size(844, 390));
    final s = await makeState();
    final audio = s.audio as RecordingAudio;
    await t.pumpWidget(AlokdalokApp(state: s));
    await settle(t);
    expect(audio.music, 'home');
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute(
        builder: (_) => NumberGameScreen(stageId: 3, random: Random(2)),
      ),
    );
    await settle(t, 1200);
    expect(audio.music, 'autumn');
    nav.pop();
    await settle(t, 1200);
    expect(audio.music, 'home');
    nav.push(MaterialPageRoute(builder: (_) => const ShopScreen()));
    await settle(t, 1200);
    expect(audio.music, 'shop');
    nav.pop();
    await settle(t, 1200);
    expect(audio.music, 'home');
  });
}
