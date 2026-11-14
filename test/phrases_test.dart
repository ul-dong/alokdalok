// 문장 조립기: 한국어 조사·셈 단위 고르기, 영어 관사·복수형, 언어 바꾸기.
import 'dart:math';

import 'package:alokdalok/character/nickname.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/l10n/en/english_phrases.dart';
import 'package:alokdalok/l10n/ko/korean_phrases.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/l10n/phrases.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ko = KoreanPhrases();
  const en = EnglishPhrases();
  const red = GameColor.red, blue = GameColor.blue;

  tearDown(() => L10n.use(AppLanguage.fallback));

  group('한국어: 조사 고르기 (받침)', () {
    test('이/가, 은/는, 을/를', () {
      expect(hasBatchim('사과'), isFalse);
      expect(hasBatchim('별'), isTrue);
      expect(hasBatchim('apple'), isFalse);
      expect(hasBatchim(''), isFalse);
      expect(KoreanPhrases.subject('사과'), '사과가');
      expect(KoreanPhrases.subject('별'), '별이');
      expect(KoreanPhrases.topic('풍선'), '풍선은');
      expect(KoreanPhrases.topic('오리'), '오리는');
      expect(KoreanPhrases.objectCase('자동차'), '자동차를');
      expect(KoreanPhrases.objectCase('꽃'), '꽃을');
    });

    test('셈 단위: 동물은 마리, 나머지는 개', () {
      expect(ko.countAnswer(ObjectKind.apple, null, 3), '사과가 세 개!');
      expect(ko.countAnswer(ObjectKind.duck, null, 2), '오리가 두 마리!');
      expect(ko.countAnswer(ObjectKind.fish, null, 1), '물고기가 한 마리!');
      expect(ko.countAnswer(ObjectKind.balloon, red, 5), '빨간 풍선이 다섯 개!');
      expect(ko.countAnswer(ObjectKind.star, null, 10), '별이 열 개!');
    });

    test('몇 개 있을까요: 흩어 놓으면 은/는 + 색, 아니면 이/가', () {
      expect(
        ko.howMany(ObjectKind.apple, null, scattered: false),
        '사과가 몇 개 있을까요?',
      );
      expect(
        ko.howMany(ObjectKind.balloon, red, scattered: true),
        '빨간 풍선은 몇 개 있을까요?',
      );
      expect(
        ko.howMany(ObjectKind.fish, null, scattered: true),
        '물고기는 몇 마리 있을까요?',
      );
    });

    test('찾기·틀림·칭찬 문장', () {
      expect(ko.findColored(red, ObjectKind.car), '빨간 자동차를 찾아볼까요?');
      expect(ko.findShape(ShapeKind.star), '별을 찾아볼까요?');
      expect(
        ko.shapeWrong(ShapeKind.triangle, ShapeKind.circle),
        '이건 세모예요. 동그라미를 다시 찾아볼까요?',
      );
      expect(
        ko.shapeWrong(ShapeKind.star, ShapeKind.heart),
        '이건 별이에요. 하트를 다시 찾아볼까요?',
      );
      expect(
        ko.findSize(SizeAsk.small, ObjectKind.duck, superlative: true),
        '가장 작은 오리를 찾아볼까요?',
      );
      expect(ko.colorWrong(blue, red), '이건 파란색이에요. 빨간색을 찾아볼까요?');
      expect(ko.matchPicked(ObjectKind.flower, null), '꽃! 똑같은 꽃을 찾아볼까요?');
      expect(ko.matchFinished(ObjectKind.car, red), '빨간 자동차! 똑같아요! 정말 잘했어요!');
    });

    test('친구 인사: 받침이 있으면 이야', () {
      expect(ko.friendHello(Zodiac.tiger), '나는 호랑이야!');
      expect(ko.friendHello(Zodiac.ox), '나는 소야!');
      expect(ko.friendHello(Zodiac.dragon), '나는 용이야!');
      expect(ko.friendHello(Zodiac.rabbit), '나는 토끼야!');
    });
  });

  group('영어: 관사·복수형', () {
    test('1 balloon / 3 balloons, fish는 그대로', () {
      expect(en.countAnswer(ObjectKind.balloon, null, 1), 'One balloon!');
      expect(en.countAnswer(ObjectKind.balloon, null, 3), 'Three balloons!');
      expect(en.countAnswer(ObjectKind.balloon, red, 3), 'Three red balloons!');
      expect(en.countAnswer(ObjectKind.apple, red, 1), 'One red apple!');
      expect(en.countAnswer(ObjectKind.fish, null, 4), 'Four fish!');
      expect(en.countAnswer(ObjectKind.duck, null, 10), 'Ten ducks!');
      expect(
        en.howMany(ObjectKind.apple, null, scattered: false),
        'How many apples?',
      );
      expect(
        en.howMany(ObjectKind.balloon, red, scattered: true),
        'How many red balloons?',
      );
      expect(
        en.howMany(ObjectKind.balloon, red, scattered: false),
        'How many balloons?',
        reason: '쉬운 문제는 한국어처럼 색을 말하지 않는다',
      );
      expect(
        en.howMany(ObjectKind.fish, null, scattered: true),
        'How many fish?',
      );
    });

    test('조사 없이 짧고 다정한 문장', () {
      expect(
        en.findColored(red, ObjectKind.balloon),
        'Can you find the red balloon?',
      );
      expect(en.findShape(ShapeKind.circle), 'Can you find the circle?');
      expect(
        en.shapeWrong(ShapeKind.triangle, ShapeKind.circle),
        'This is a triangle. Can you find the circle?',
      );
      expect(
        en.findSize(SizeAsk.big, ObjectKind.apple, superlative: true),
        'Can you find the biggest apple?',
      );
      expect(en.colorWrong(blue, red), 'This is blue. Can you find red?');
      expect(en.sayName(ObjectKind.apple), 'Apple!');
      expect(en.sayName(ObjectKind.car, GameColor.pink), 'Pink car!');
      expect(en.matchMatched(ObjectKind.apple, null), 'Apple! They match!');
      expect(for1(en.count), ['One', 'Two', 'Three']);
      expect(en.countUpTo(3), 'One, two, three');
    });

    test('a / an', () {
      expect(en.friendHello(Zodiac.tiger), "I'm a tiger!");
      expect(en.friendHello(Zodiac.iguanodon), "I'm an iguanodon!");
      expect(en.friendHello(Zodiac.ankylosaurus), "I'm an ankylosaurus!");
      expect(EnglishPhrases.article('owl'), 'an');
    });

    test('모든 아이템·친구·탈것·색에 영어 이름이 있고 한글이 없다', () {
      final hangul = RegExp('[가-힣]');
      expect(
        EnglishPhrases.itemIds.toSet(),
        ItemCatalog.all.map((i) => i.id).toSet(),
      );
      final names = [
        for (final i in ItemCatalog.all) en.itemName(i),
        for (final s in ItemSlot.values) en.itemSlot(s),
        for (final t in OutfitTheme.values) en.outfitTheme(t),
        for (final z in Zodiac.values) ...[en.animal(z), en.friendHello(z)],
        for (final v in Vehicles.all) en.vehicleName(v),
        for (final p in Vehicles.paints) ...[
          en.paintName(p),
          en.paintedWith(p),
        ],
        for (final g in GameKind.values) ...[
          en.gameInvite(g),
          en.gameNameLine(g),
        ],
        for (final k in ObjectKind.values) en.sayName(k),
        for (final c in [...GameColor.extended, GameColor.gray])
          en.colorName(c),
        for (final s in ShapeKind.values) en.sayShape(s),
      ];
      for (final n in names) {
        expect(n.trim(), isNotEmpty);
        expect(hangul.hasMatch(n), isFalse, reason: n);
        expect(n, isNot(contains('_')), reason: '아이디가 그대로 나오면 안 된다: $n');
      }
    });

    test('영어 랜덤 이름도 닉네임 규칙에 맞는다', () {
      for (final n in en.randomNames) {
        expect(Nickname.validate(n), isNull, reason: n);
      }
      expect(en.nickname(Nickname.fallback), 'Buddy');
      expect(ko.nickname(Nickname.fallback), Nickname.fallback);
    });
  });

  group('언어 바꾸기', () {
    test('Phrases.current와 데이터 이름이 지금 언어를 따른다', () {
      expect(Phrases.current, same(Phrases.ko));
      final apple = ItemCatalog.all.first;
      expect(apple.name, apple.nameKo);
      expect(GameKind.number.title, '숫자 놀이');
      L10n.use(const Locale('en'));
      expect(Phrases.current, same(Phrases.en));
      expect(apple.name, 'Robot helmet');
      expect(GameKind.number.title, 'Numbers');
      expect(Zodiac.tiger.hello, "I'm a tiger!");
      expect(Vehicles.all.first.name, 'Hot air balloon');
      expect(ObjectKind.apple.sayName(), 'Apple!');
      // 한국어 전용 바로가기는 언어와 상관없이 한국어 (한국어 음성 목록용)
      expect(ObjectKind.apple.ko, '사과');
      expect(GameColor.red.name, '빨간색');
    });

    test('놀이 문제도 영어로 나온다', () {
      L10n.use(const Locale('en'));
      final rng = Random(3);
      for (final st in Stages.number) {
        final q = NumberQuestion.generate(st, rng);
        expect(q.prompt, startsWith('How many '));
        expect(q.answerLine, endsWith('!'));
      }
      for (final st in Stages.color) {
        final q = ColorQuestion.generate(st, rng);
        expect(q.prompt, startsWith('Can you find the '));
      }
    });
  });
}

List<String> for1(String Function(int) f) => [f(1), f(2), f(3)];
