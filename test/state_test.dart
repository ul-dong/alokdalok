import 'dart:convert';

import 'package:alokdalok/character/nickname.dart';
import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/common/korean_numbers.dart';

import 'dart:math';

import 'package:alokdalok/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameState> fresh([StorageService? storage]) async {
  final s = GameState(
    storage: storage ?? MemoryStorage(),
    audio: RecordingAudio(),
  );
  await s.load();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('코인 보상', () {
    test('정답 보상이 지급되고 첫 시도면 별도 받는다', () async {
      final s = await fresh();
      final start = s.coins;
      expect(await s.rewardCorrect(firstTry: true), Economy.correctFirstTry);
      expect(s.coins, start + Economy.correctFirstTry);
      expect(s.stars, 1);
      expect(await s.rewardCorrect(firstTry: false), Economy.correctAfterRetry);
      expect(
        s.coins,
        start + Economy.correctFirstTry + Economy.correctAfterRetry,
      );
      expect(s.stars, 1);
    });

    test('한 판 완료: 첫 놀이 보너스·새 단계 보너스는 한 번만, 다음 단계가 열린다', () async {
      final s = await fresh();
      final c0 = s.coins;
      final r1 = await s.completeSession(GameKind.number, 1);
      expect(r1.firstPlay, Economy.firstPlayBonus);
      expect(r1.newStage, Economy.newStageBonus);
      expect(r1.unlockedStage, 2);
      expect(s.unlockedStage(GameKind.number), 2);
      expect(s.unlockedStage(GameKind.color), 1, reason: '다른 놀이는 그대로');
      expect(s.coins, c0 + r1.total);

      final r2 = await s.completeSession(GameKind.number, 1);
      expect(r2.firstPlay, 0);
      expect(r2.newStage, 0);
      expect(r2.unlockedStage, isNull);
      expect(r2.total, Economy.sessionComplete, reason: '반복해도 기본 보상은 받는다');
    });

    test('마지막 단계를 끝내도 없는 단계가 열리지 않는다', () async {
      final s = await fresh();
      for (var i = 1; i <= s.stageCount(GameKind.color); i++) {
        await s.completeSession(GameKind.color, i);
      }
      expect(s.unlockedStage(GameKind.color), s.stageCount(GameKind.color));
    });
  });

  group('상점과 꾸미기', () {
    test('코인이 부족하면 살 수 없고 코인·보유 목록이 바뀌지 않는다', () async {
      final s = await fresh();
      final expensive = ItemCatalog.all.firstWhere((i) => i.price > s.coins);
      final before = s.coins;
      expect(await s.purchase(expensive.id), PurchaseResult.notEnoughCoins);
      expect(s.coins, before);
      expect(s.owns(expensive.id), isFalse);
    });

    test('사면 코인이 줄고 영구 보유, 다시 살 수 없다', () async {
      final s = await fresh();
      final cap = ItemCatalog.byId('ribbon_pink')!;
      final before = s.coins;
      expect(await s.purchase(cap.id), PurchaseResult.ok);
      expect(s.coins, before - cap.price);
      expect(s.owns(cap.id), isTrue);
      expect(s.equipped[ItemSlot.accessory], cap.id, reason: '사자마자 입혀 준다');
      expect(await s.purchase(cap.id), PurchaseResult.alreadyOwned);
      expect(s.coins, before - cap.price);
      expect(await s.purchase('없는_아이템'), PurchaseResult.unknownItem);
    });

    test('여러 부위를 조합하고, 같은 부위는 교체되며, 벗기·처음 모습이 된다', () async {
      final s = await fresh();
      await s.completeSession(GameKind.number, 1); // 코인 모으기
      for (var i = 0; i < 80; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      for (final id in [
        'bone_head',
        'suit_cave',
        'sandal_cave',
        'ribbon_pink',
        'club_cave',
        'cap_police',
      ]) {
        expect(await s.purchase(id), PurchaseResult.ok, reason: id);
      }
      expect(s.equipped.length, 5, reason: '머리·옷·신발·장식·등 동시 장착');
      expect(s.equipped[ItemSlot.head], 'cap_police');
      expect(await s.equip('bone_head'), isTrue);
      expect(s.equipped[ItemSlot.head], 'bone_head');

      await s.toggleEquip('bone_head');
      expect(s.equipped.containsKey(ItemSlot.head), isFalse);
      await s.unequip(ItemSlot.outfit);
      expect(s.equipped.containsKey(ItemSlot.outfit), isFalse);
      await s.resetOutfit();
      expect(s.equipped, isEmpty);
      expect(s.owned.length, 6, reason: '벗어도 보유는 유지');
    });

    test('가지지 않은 아이템은 장착할 수 없다', () async {
      final s = await fresh();
      expect(await s.equip('crown_gold'), isFalse);
      expect(s.equipped, isEmpty);
    });

    test('모든 아이템 데이터가 유효하다 (id 중복 없음, 가격 양수, 색 있음)', () {
      final ids = ItemCatalog.all.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final i in ItemCatalog.all) {
        expect(i.price, greaterThan(0));
        expect(i.colors, isNotEmpty);
      }
      for (final slot in ItemSlot.values) {
        expect(ItemCatalog.bySlot(slot), isNotEmpty, reason: slot.name);
      }
    });
  });

  group('닉네임과 설정', () {
    test('잘못된 닉네임은 저장되지 않고, 올바르면 저장된다', () async {
      final s = await fresh();
      expect(s.nickname, Nickname.fallback);
      expect(s.nicknameChosen, isFalse);
      expect(await s.setNickname('별 이!'), isFalse);
      expect(s.nickname, Nickname.fallback);
      expect(await s.setNickname('구름이'), isTrue);
      expect(s.nickname, '구름이');
      expect(s.nicknameChosen, isTrue);
    });

    test('건너뛰면 기본 닉네임', () async {
      final s = await fresh();
      await s.skipNickname();
      expect(s.nicknameChosen, isTrue);
      expect(s.nickname, Nickname.fallback);
    });

    test('음성·효과음 끄면 실제로 재생되지 않는다', () async {
      final s = await fresh();
      final audio = s.audio as RecordingAudio;
      await audio.play(Sfx.correct);
      await audio.say('안녕');
      await s.setSfx(false);
      await s.setVoice(false);
      await audio.play(Sfx.correct);
      await audio.say('안녕');
      expect(audio.played, [Sfx.correct]);
      expect(audio.spoken, ['안녕']);
      await s.setSfx(true);
      await audio.play(Sfx.tap);
      expect(audio.played.last, Sfx.tap);
    });
  });

  group('저장과 복구', () {
    test('앱을 다시 켜도(새 GameState) 코인·아이템·진행·닉네임·설정이 유지된다', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      await a.setNickname('콩이');
      await a.completeSession(GameKind.number, 1);
      await a.completeSession(GameKind.color, 1);
      await a.completeSession(GameKind.color, 2);
      await a.purchase('ribbon_pink');
      await a.setVoice(false);

      final b = await fresh(PrefsStorage()); // 재실행
      expect(b.nickname, '콩이');
      expect(b.coins, a.coins);
      expect(b.owns('ribbon_pink'), isTrue);
      expect(b.equipped[ItemSlot.accessory], 'ribbon_pink');
      expect(b.unlockedStage(GameKind.number), 2);
      expect(b.unlockedStage(GameKind.color), 3);
      expect(b.clearedStages(GameKind.color), {1, 2});
      expect(b.voiceOn, isFalse);
      expect(b.sfxOn, isTrue);
      expect(b.audio.voiceOn, isFalse, reason: '불러온 설정이 오디오에 적용');
    });

    test('저장값이 깨진 JSON이면 기본값', () {
      final d = SaveData.decode('{not json');
      expect(d.coins, Economy.startingCoins);
      expect(d.nickname, Nickname.fallback);
      expect(SaveData.decode('[1,2]').coins, Economy.startingCoins);
      expect(SaveData.decode('').coins, Economy.startingCoins);
    });

    test('일부 항목만 손상되면 그 항목만 기본값으로 복구', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': SaveData.currentVersion,
          'nickname': '!!!',
          'nicknameChosen': true,
          'coins': -50,
          'owned': ['crown_gold', 'ghost_item', 7],
          'equipped': {
            'head': 'crown_gold',
            'outfit': 'dress_princess',
            'shoes': 'crown_gold',
          },
          'numberStageUnlocked': 99,
          'colorStageUnlocked': 2,
          'numberStageCleared': [1, 42],
          'voiceOn': 'yes',
          'sfxOn': false,
        }),
      );
      expect(d.nickname, Nickname.fallback);
      expect(d.nicknameChosen, isTrue);
      expect(d.coins, Economy.startingCoins);
      expect(d.owned, {'crown_gold'});
      expect(d.equipped, {
        ItemSlot.head: 'crown_gold',
      }, reason: '없는 아이템·다른 부위 장착은 버린다');
      expect(d.numberStageUnlocked, 1);
      expect(d.colorStageUnlocked, 2);
      expect(d.numberStageCleared, {1});
      expect(d.voiceOn, isTrue);
      expect(d.sfxOn, isFalse);
    });

    test('버전 1(고양이 시절) 저장값은 호랑이로 옮기고 친구 고르기를 다시 보여 준다', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 1,
          'nickname': '콩이',
          'nicknameChosen': true,
          'coins': 33,
        }),
      );
      expect(d.zodiac, Zodiac.tiger);
      expect(d.nickname, '콩이', reason: '이름은 그대로');
      expect(d.coins, 33);
      expect(d.nicknameChosen, isFalse);
      final again = SaveData.decode(d.encode());
      expect(again.zodiac, Zodiac.tiger);
    });

    test('고른 동물이 저장되고, 알 수 없는 값은 기본값', () async {
      final s = await fresh();
      await s.setZodiac(Zodiac.dragon);
      final storage = s.storage as MemoryStorage;
      expect(SaveData.decode(storage.raw).zodiac, Zodiac.dragon);
      expect(
        SaveData.decode(jsonEncode({'version': 2, 'zodiac': 'unicorn'})).zodiac,
        Zodiac.tiger,
      );
    });

    test('버전 없는 예전 저장값도 마이그레이션되어 읽힌다', () {
      final d = SaveData.decode(jsonEncode({'nickname': '보리', 'coins': 30}));
      expect(d.nickname, '보리');
      expect(d.coins, 30);
      expect(jsonDecode(d.encode())['version'], SaveData.currentVersion);
    });

    test('기기 저장소의 값이 문자열이 아닌 형식으로 손상돼도 앱이 멈추지 않는다', () async {
      SharedPreferences.setMockInitialValues({PrefsStorage.key: 12345});
      final s = await fresh(PrefsStorage());
      expect(s.coins, Economy.startingCoins);
      await s.rewardCorrect(firstTry: true);
      final again = await fresh(PrefsStorage());
      expect(
        again.coins,
        Economy.startingCoins + Economy.correctFirstTry,
        reason: '덮어써서 정상 저장',
      );
    });

    test('본 저장값이 깨지면 직전 백업으로 복구', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      await a.rewardCorrect(firstTry: true); // 1차 저장
      await a.rewardCorrect(firstTry: true); // 2차 저장 → 1차가 백업
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsStorage.key, '{{깨짐');
      final b = await fresh(PrefsStorage());
      expect(b.coins, Economy.startingCoins + Economy.correctFirstTry);
    });

    test('기록 모두 지우기', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      await a.setNickname('토리');
      await a.purchase('ribbon_pink');
      await a.resetAll();
      expect(a.nickname, Nickname.fallback);
      expect(a.owned, isEmpty);
      expect(a.nicknameChosen, isFalse);
      final b = await fresh(PrefsStorage());
      expect(b.owned, isEmpty);
    });
  });

  group('옷 테마와 이전 아이템', () {
    test('옷 테마 17가지, 모두 아이템과 대표 그림이 있다', () {
      expect(OutfitTheme.values.map((t) => t.label).toList(), [
        '로봇',
        '공주',
        '소방관',
        '경찰',
        '군인',
        '원시인',
        '우주비행사',
        '의사',
        '요리사',
        '농부',
        '기관사',
        '해적',
        '마법사',
        '공룡',
        '슈퍼히어로',
        '축구선수',
        '발레리나',
      ]);
      for (final t in OutfitTheme.values) {
        expect(
          ItemCatalog.byTheme(t).length,
          greaterThanOrEqualTo(3),
          reason: t.label,
        );
        expect(ItemCatalog.byId(t.sampleId)?.theme, t, reason: t.label);
        // 한 테마 안에서 같은 부위가 겹치지 않아 한 벌로 다 입을 수 있다
        final slots = ItemCatalog.byTheme(t).map((i) => i.slot).toList();
        expect(slots.toSet().length, slots.length, reason: t.label);
      }
      for (final id in ItemCatalog.retired.keys) {
        expect(
          ItemCatalog.exists(id),
          isFalse,
          reason: '없앤 아이템 id를 다시 쓰면 환불이 겹친다: $id',
        );
      }
    });

    test('버전 2 저장값의 없어진 아이템은 산 값만큼 코인으로 돌려준다', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 2,
          'nicknameChosen': true,
          'zodiac': 'rabbit',
          'coins': 7,
          'owned': ['cap_red', 'tee_stripe', 'ribbon_pink'],
          'equipped': {'head': 'cap_red', 'accessory': 'ribbon_pink'},
        }),
      );
      expect(d.coins, 7 + 10 + 10);
      expect(d.owned, {'ribbon_pink'});
      expect(d.equipped, {ItemSlot.accessory: 'ribbon_pink'});
    });
  });

  group('탈것과 스티커', () {
    Future<GameState> rich() async {
      final s = await fresh();
      for (var i = 0; i < 60; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      return s;
    }

    test('탈것 7종(종류별 한 대)은 코인으로 사고, 사면 바로 탄다', () async {
      final s = await rich();
      final before = s.coins;
      expect(
        Vehicles.all.map((v) => v.kind).toSet(),
        VehicleKind.values.toSet(),
      );
      expect(Vehicles.all.length, VehicleKind.values.length, reason: '종류별 한 대');
      for (final v in Vehicles.all) {
        expect(Vehicles.paintExists(v.defaultPaint), isTrue, reason: v.id);
      }
      expect(await s.buyVehicle('car'), PurchaseResult.ok);
      expect(s.coins, before - Vehicles.byId('car')!.price);
      expect(s.ownsVehicle('car'), isTrue);
      expect(s.ride, 'car');
      expect(await s.buyVehicle('car'), PurchaseResult.alreadyOwned);
      expect(await s.buyVehicle('ufo'), PurchaseResult.unknownItem);
      await s.setRide(null);
      expect(s.ride, isNull);
      await s.setRide('rocket'); // 안 산 탈것은 못 탄다
      expect(s.ride, isNull);
    });

    test('코인이 모자라면 탈것을 살 수 없다', () async {
      final s = await fresh();
      expect(await s.buyVehicle('rocket'), PurchaseResult.notEnoughCoins);
      expect(s.ownsVehicle('rocket'), isFalse);
    });

    test('스티커는 산 탈것에만, 최대 12개까지 붙고 지울 수 있다', () async {
      final s = await rich();
      const st = PlacedSticker(
        kind: StickerKind.star,
        color: 0xFFFFCF4D,
        x: .5,
        y: .6,
      );
      expect(await s.addSticker('bicycle', st), isFalse, reason: '안 산 차');
      await s.buyVehicle('bicycle');
      for (var i = 0; i < Vehicles.maxStickers; i++) {
        expect(await s.addSticker('bicycle', st), isTrue);
      }
      expect(await s.addSticker('bicycle', st), isFalse, reason: '가득 참');
      await s.removeSticker('bicycle', 0);
      expect(s.stickersOf('bicycle').length, Vehicles.maxStickers - 1);
      await s.clearStickers('bicycle');
      expect(s.stickersOf('bicycle'), isEmpty);
    });

    test('탈것·스티커는 저장되고, 손상된 스티커 값은 버린다', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      for (var i = 0; i < 60; i++) {
        await a.rewardCorrect(firstTry: true);
      }
      await a.buyVehicle('airplane');
      await a.addSticker(
        'airplane',
        const PlacedSticker(
          kind: StickerKind.heart,
          color: 0xFFF58BB0,
          x: .4,
          y: .5,
        ),
      );
      final b = await fresh(PrefsStorage());
      expect(b.ride, 'airplane');
      expect(b.stickersOf('airplane').single.kind, StickerKind.heart);

      final d = SaveData.decode(
        jsonEncode({
          'version': SaveData.currentVersion,
          'owned': ['car'],
          'ride': 'rocket',
          'stickers': {
            'car': [
              {'k': 'star', 'c': 4294954829, 'x': .5, 'y': .5},
              {'k': 'nope', 'c': 1, 'x': .5, 'y': .5},
              'garbage',
            ],
            'ghost': [
              {'k': 'star', 'c': 1, 'x': .5, 'y': .5},
            ],
          },
        }),
      );
      expect(d.ride, isNull, reason: '안 가진 탈것은 탈 수 없음');
      expect(d.stickers.keys, ['car']);
      expect(d.stickers['car']!.length, 1);
    });

    test('색은 코인 10개로 사고, 산 색은 모든 탈것에 칠한다. 처음 색은 공짜', () async {
      final s = await rich();
      await s.buyVehicle('car');
      await s.buyVehicle('rocket');
      expect(s.paintOf('car').id, 'paint_red', reason: '자동차 기본 색');
      expect(s.paintOf('rocket').id, 'paint_white');
      expect(await s.setPaint('car', 'paint_blue'), isFalse, reason: '안 산 색');
      expect(
        await s.setPaint('car', 'paint_white'),
        isFalse,
        reason: '우주선 기본 색은 자동차엔 안 됨',
      );
      final before = s.coins;
      expect(await s.buyPaint('car', 'paint_blue'), PurchaseResult.ok);
      expect(s.coins, before - Vehicles.paintPrice);
      expect(
        await s.buyPaint('car', 'paint_blue'),
        PurchaseResult.alreadyOwned,
      );
      expect(await s.buyPaint('car', 'paint_gold'), PurchaseResult.unknownItem);
      expect(await s.setPaint('car', 'paint_blue'), isTrue);
      expect(
        await s.setPaint('rocket', 'paint_blue'),
        isFalse,
        reason: '색은 탈것마다 따로 산다',
      );
      expect(await s.buyPaint('rocket', 'paint_blue'), PurchaseResult.ok);
      expect(await s.setPaint('rocket', 'paint_blue'), isTrue);
      expect(s.paintOf('car').id, 'paint_blue');
      expect(
        await s.setPaint('car', 'paint_red'),
        isTrue,
        reason: '기본 색으로 되돌리기',
      );
      expect(await s.setPaint('tank', 'paint_blue'), isFalse, reason: '안 산 탈것');
    });

    test('코인이 모자라면 색을 살 수 없다', () async {
      final s = await fresh();
      for (var i = 0; i < 30; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      await s.buyVehicle('kickboard');
      final colors = [
        'paint_red',
        'paint_blue',
        'paint_green',
        'paint_black',
        'paint_white',
        'paint_purple',
        'paint_orange',
        'paint_yellow',
      ];
      var last = PurchaseResult.ok;
      for (final c in colors) {
        last = await s.buyPaint('kickboard', c);
        if (last != PurchaseResult.ok) break;
      }
      expect(last, PurchaseResult.notEnoughCoins);
      expect(s.coins, lessThan(Vehicles.paintPrice));
      expect(s.ownsPaint('kickboard', 'paint_red'), isTrue);
    });

    test('칠한 색은 다시 켜도 유지된다', () async {
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      for (var i = 0; i < 40; i++) {
        await a.rewardCorrect(firstTry: true);
      }
      await a.buyVehicle('tank');
      await a.buyPaint('tank', 'paint_pink');
      await a.setPaint('tank', 'paint_pink');
      final b = await fresh(PrefsStorage());
      expect(b.paintOf('tank').id, 'paint_pink');
      expect(b.ownsPaint('tank', 'paint_pink'), isTrue);
    });

    test('버전 3의 색깔별 탈것은 종류별 탈것 + 색으로 바뀌고, 겹친 탈것은 코인으로 돌려준다', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 3,
          'nicknameChosen': true,
          'coins': 5,
          'owned': ['car_red', 'car_blue', 'rocket_purple', 'ribbon_pink'],
          'ride': 'car_blue',
          'voiceStyle': 'child',
          'stickers': {
            'car_red': [
              {'k': 'star', 'c': 1, 'x': .5, 'y': .6},
            ],
            'car_blue': [
              {'k': 'heart', 'c': 1, 'x': .4, 'y': .6},
            ],
            'rocket_purple': [
              {'k': 'moon', 'c': 1, 'x': .5, 'y': .5},
            ],
          },
        }),
      );
      expect(d.owned, {
        'car',
        'rocket',
        'paint_blue',
        'paint_purple',
        'ribbon_pink',
      });
      expect(d.ride, 'car');
      expect(d.paints['car'], 'paint_blue', reason: '타고 있던 파란 차의 색');
      expect(d.paints['rocket'], 'paint_purple');
      // 빨간 자동차(40)는 자동차가 이미 있고 빨강은 기본 색이라 40개를 모두 돌려준다
      expect(d.coins, 5 + 40);
      expect(d.stickers['car']!.length, 2, reason: '두 차의 스티커를 합친다');
      expect(d.stickers['rocket']!.single.kind, StickerKind.moon);
      expect(d.voiceStyle, 'pack', reason: '무서운 높은 목소리 대신 녹음 목소리로');
    });
  });

  group('목소리', () {
    test('기기 음성은 음높이를 바꾸지 않고, 기본은 녹음 목소리', () async {
      for (final web in [true, false]) {
        expect(DeviceAudio.tone('teacher', web: web).pitch, 1.0);
        expect(DeviceAudio.tone('pack', web: web).pitch, 1.0);
      }
      SharedPreferences.setMockInitialValues({});
      final a = await fresh(PrefsStorage());
      expect(a.voiceStyle, 'pack');
      await a.setVoiceStyle('teacher');
      expect(a.audio.voiceStyle, 'teacher');
      await a.setVoiceStyle('robot'); // 모르는 값은 무시
      await a.setMusic(false);
      final b = await fresh(PrefsStorage());
      expect(b.voiceStyle, 'teacher');
      expect(b.musicOn, isFalse);
      expect(b.audio.musicOn, isFalse);
      expect(
        SaveData.decode('{"version":5}').musicOn,
        isTrue,
        reason: '예전 저장값은 음악 켜짐',
      );
      final v4 = SaveData.decode(
        jsonEncode({'version': 4, 'voiceStyle': 'teacher'}),
      );
      expect(v4.voiceStyle, 'pack', reason: '녹음 목소리가 생겨서 한 번 바꿔 준다');
    });
  });

  group('녹음 음성 팩', () {
    final lines = VoiceLines.all();
    final pack = VoicePack({
      for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3',
    });

    test('앱이 하는 말은 녹음 조각으로 모두 나눠진다', () {
      final samples = <String>[
        '같이 세어 볼까요? ${KoreanNumbers.countUpTo(7)}',
        '정말 잘했어요! 코인을 받았어요.',
        '스티커가 가득 찼어요. 지우개로 떼어 볼까요?',
        '안녕! 오늘은 뭐 하고 놀까?',
        '이건 빨간색이에요. 갈색을 찾아볼까요?',
        '노란색! 정말 잘했어요!',
        '흰색은 코인 10개가 필요해요. 놀이하면서 모아 볼까요?',
        '분홍색으로 칠했어요!',
        '별이, 반가워!',
        for (final z in Zodiac.values) z.hello,
        for (final i in ItemCatalog.all) '${i.name}, 정말 멋져요!',
        for (final v in Vehicles.all) '${v.name}, 출발!',
      ];
      // 모든 단계의 숫자·색깔 문제 문장
      for (final stage in Stages.number) {
        final rng = Random(stage.id);
        for (var k = 0; k < 200; k++) {
          final q = NumberQuestion.generate(stage, rng);
          samples
            ..add(q.prompt)
            ..add('${q.answerLine} 정말 잘했어요!');
        }
      }
      for (final stage in Stages.color) {
        final rng = Random(stage.id);
        for (var k = 0; k < 200; k++) {
          samples.add(ColorQuestion.generate(stage, rng).prompt);
        }
      }
      for (final t in samples) {
        expect(pack.plan(t), isNotNull, reason: t);
      }
    });

    test('조각 나누기: 쉼표 뒤는 쉬고, 없는 말(아이 이름)은 기기 음성으로', () {
      final count = pack.plan('같이 세어 볼까요? 하나, 둘, 셋')!;
      expect(count.length, 4);
      expect(count[2].pauseBefore, VoicePack.commaPause);
      final answer = pack.plan('빨간 풍선이 세 개! 정말 잘했어요!')!;
      expect(answer.length, 3);
      expect(answer[1].pauseBefore, VoicePack.shortPause);
      expect(pack.plan('하랑이, 반가워!'), isNull);
      expect(VoicePack(const {}).plan('안녕!'), isNull);
      // 단어 중간에서 끊지 않는다 ("안녕!" 다음에 글자가 붙어 있으면 안 됨)
      expect(VoicePack(const {'안녕': 'a.mp3'}).plan('안녕하세요'), isNull);
    });
  });
}
