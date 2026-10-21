import 'dart:convert';
import 'dart:math';

import 'package:alokdalok/core/economy.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/backup_code.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/play_clock.dart';
import 'package:alokdalok/services/save_data.dart';
import 'package:alokdalok/services/storage_service.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:alokdalok/widgets/parental_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// 가짜 시계: [advance]로만 시간이 흐른다
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 10, 21, 9);
  DateTime now;
  DateTime call() => now;
}

/// [d] 동안 [step]마다 tick (앱의 1초 타이머 대신)
void playFor(
  PlayClock p,
  FakeClock c,
  Duration d, {
  Duration step = const Duration(seconds: 5),
}) {
  var left = d;
  while (left > Duration.zero) {
    final s = left < step ? left : step;
    c.now = c.now.add(s);
    p.tick();
    left -= s;
  }
}

Future<GameState> stateAt(FakeClock c, [StorageService? storage]) async {
  final s = GameState(
    storage: storage ?? MemoryStorage(),
    audio: RecordingAudio(),
    now: c.call,
  );
  await s.load();
  return s;
}

/// 체크섬이 맞는 백업 글자를 직접 만든다 (버전·본문을 바꿔 보기 위해)
String craft(Object? json) {
  final body = base64Url
      .encode(utf8.encode(jsonEncode(json)))
      .replaceAll('=', '');
  return '${BackupCode.prefix}$body-${BackupCode.checksum(body)}';
}

void main() {
  group('하루 놀이 시간', () {
    late FakeClock c;
    late PlayClock p;
    setUp(() {
      c = FakeClock();
      // 눈 쉬기는 따로 시험하므로 여기서는 멀리 둔다
      p = PlayClock(now: c.call, limitMinutes: 10, breakMinutes: 120);
      p.tick();
    });

    test('기본값은 10분, 선택지는 제한 없음·10·15·20·30·45·60분', () {
      expect(SafetyRules.defaultLimit, 10);
      expect(SafetyRules.limitChoices, [0, 10, 15, 20, 30, 45, 60]);
      expect(PlayClock(now: c.call).limitMinutes, 10);
    });

    test('10분 놀면 "오늘은 여기까지!", 그 뒤로는 시간이 늘지 않는다', () {
      playFor(p, c, const Duration(minutes: 9, seconds: 55));
      expect(p.block, PlayBlock.none);
      expect(p.remaining, const Duration(seconds: 5));
      playFor(p, c, const Duration(seconds: 5));
      expect(p.block, PlayBlock.limit);
      playFor(p, c, const Duration(minutes: 30));
      expect(p.used, const Duration(minutes: 10));
      expect(p.block, PlayBlock.limit);
    });

    test('부모 확인 뒤 15분 더: 풀렸다가 15분 뒤 다시 막힌다', () {
      playFor(p, c, const Duration(minutes: 12));
      expect(p.block, PlayBlock.limit);
      p.extend();
      expect(p.bonusMinutes, 15);
      expect(p.block, PlayBlock.none);
      expect(p.remaining, const Duration(minutes: 15));
      playFor(p, c, const Duration(minutes: 14, seconds: 55));
      expect(p.block, PlayBlock.none);
      playFor(p, c, const Duration(seconds: 5));
      expect(p.block, PlayBlock.limit);
    });

    test('다음 날이 되면 다시 풀리고 더 받은 시간도 0', () {
      playFor(p, c, const Duration(minutes: 10));
      p.extend();
      playFor(p, c, const Duration(minutes: 15));
      expect(p.block, PlayBlock.limit);
      c.now = DateTime(2026, 10, 22, 7);
      expect(p.tick(), isTrue, reason: '막힘이 풀렸다고 알린다');
      expect(p.block, PlayBlock.none);
      expect(p.used, Duration.zero);
      expect(p.bonusMinutes, 0);
      expect(p.day, '2026-10-22');
    });

    test('자정을 넘겨 놀아도 새 날 시간으로 센다', () {
      c.now = DateTime(2026, 10, 21, 23, 55);
      p.tick();
      playFor(p, c, const Duration(minutes: 9));
      expect(p.day, '2026-10-22');
      expect(
        p.used,
        lessThanOrEqualTo(const Duration(minutes: 4, seconds: 5)),
        reason: '자정 앞의 시간은 어제 몫',
      );
      expect(p.block, PlayBlock.none);
    });

    test('제한 없음이면 오래 놀아도 막히지 않는다 (눈 쉬기는 따로)', () {
      p.limitMinutes = 0;
      for (var i = 0; i < 6; i++) {
        playFor(p, c, const Duration(minutes: 20));
        expect(p.block, isNot(PlayBlock.limit));
        playFor(p, c, SafetyRules.breakLength);
      }
      expect(p.remaining, isNull);
      expect(p.allowance, isNull);
    });

    test('설정에서 시간을 늘리면 바로 풀린다', () {
      playFor(p, c, const Duration(minutes: 10));
      expect(p.block, PlayBlock.limit);
      p.limitMinutes = 30;
      expect(p.block, PlayBlock.none);
      expect(p.remaining, const Duration(minutes: 20));
    });

    test('앱이 뒤로 가 있는 동안은 세지 않는다', () {
      playFor(p, c, const Duration(minutes: 3));
      p.pause();
      c.now = c.now.add(const Duration(hours: 2));
      p.tick();
      expect(p.used, const Duration(minutes: 3));
      p.resume();
      playFor(p, c, const Duration(minutes: 1));
      expect(p.used, const Duration(minutes: 4));
    });

    test('타이머가 오래 멈췄다 돌면(기기 잠자기) 그 틈은 세지 않는다', () {
      c.now = c.now.add(const Duration(minutes: 40));
      p.tick();
      expect(p.used, Duration.zero);
      expect(p.block, PlayBlock.none);
    });

    test('저장한 오늘 기록은 같은 날에만 되살린다', () {
      final q = PlayClock(now: c.call);
      q.restore(day: '2026-10-21', usedSeconds: 400, bonusMinutes: 15);
      expect(q.used, const Duration(seconds: 400));
      expect(q.bonusMinutes, 15);
      q.restore(day: '2026-10-20', usedSeconds: 400, bonusMinutes: 15);
      expect(q.used, Duration.zero);
      expect(q.bonusMinutes, 0);
      q.restore(day: null, usedSeconds: 99);
      expect(q.used, Duration.zero);
    });
  });

  group('눈 쉬기', () {
    late FakeClock c;
    late PlayClock p;
    setUp(() {
      c = FakeClock();
      p = PlayClock(now: c.call, limitMinutes: 0);
      p.tick();
    });

    test('기본 10분 이어서 놀면 20초 쉬고, 끝나면 저절로 사라진다', () {
      expect(p.breakMinutes, 10);
      expect(SafetyRules.breakLength, const Duration(seconds: 20));
      playFor(p, c, const Duration(minutes: 9, seconds: 55));
      expect(p.block, PlayBlock.none);
      playFor(p, c, const Duration(seconds: 5));
      expect(p.block, PlayBlock.eyeBreak);
      expect(p.breakLeft, const Duration(seconds: 20));
      playFor(p, c, const Duration(seconds: 10));
      expect(p.breakLeft, const Duration(seconds: 10));
      final used = p.used;
      playFor(p, c, const Duration(seconds: 10));
      expect(p.block, PlayBlock.none);
      expect(p.continuous, Duration.zero, reason: '쉬었으니 처음부터');
      expect(p.used, used, reason: '쉬는 시간은 놀이 시간이 아니다');
    });

    test('20분 간격이면 10분에는 쉬지 않는다', () {
      p.breakMinutes = 20;
      playFor(p, c, const Duration(minutes: 15));
      expect(p.block, PlayBlock.none);
      playFor(p, c, const Duration(minutes: 5));
      expect(p.block, PlayBlock.eyeBreak);
    });

    test('5분 이상 앱을 안 보면 쉰 것으로 친다', () {
      playFor(p, c, const Duration(minutes: 8));
      p.pause();
      c.now = c.now.add(const Duration(minutes: 5));
      p.resume();
      expect(p.continuous, Duration.zero);
      playFor(p, c, const Duration(minutes: 8));
      expect(p.block, PlayBlock.none);
    });

    test('5분보다 짧게 나갔다 오면 이어서 센다', () {
      playFor(p, c, const Duration(minutes: 8));
      p.pause();
      c.now = c.now.add(const Duration(minutes: 4, seconds: 59));
      p.resume();
      expect(p.continuous, const Duration(minutes: 8));
      playFor(p, c, const Duration(minutes: 2));
      expect(p.block, PlayBlock.eyeBreak);
    });

    test('쉬는 중에 5분 넘게 나갔다 오면 쉬기도 끝난다', () {
      playFor(p, c, const Duration(minutes: 10));
      expect(p.block, PlayBlock.eyeBreak);
      p.pause();
      c.now = c.now.add(const Duration(minutes: 6));
      expect(p.resume(), isTrue);
      expect(p.block, PlayBlock.none);
    });

    test('"오늘은 여기까지!"가 20초 넘게 떠 있었으면 눈도 쉰 것으로 친다', () {
      p.limitMinutes = 10;
      p.breakMinutes = 20;
      playFor(p, c, const Duration(minutes: 10));
      expect(p.block, PlayBlock.limit);
      expect(p.continuous, const Duration(minutes: 10));
      playFor(p, c, const Duration(seconds: 25));
      expect(p.continuous, Duration.zero);
      p.extend();
      playFor(p, c, const Duration(minutes: 14));
      expect(p.block, PlayBlock.none, reason: '연장한 뒤 곧바로 눈 쉬기가 끼지 않는다');
    });

    test('놀이 시간이 끝나는 순간에는 눈 쉬기보다 "오늘은 여기까지"가 먼저', () {
      p.limitMinutes = 10;
      playFor(p, c, const Duration(minutes: 10));
      expect(p.block, PlayBlock.limit);
    });
  });

  group('GameState 놀이 시간', () {
    test('논 시간과 더 받은 시간은 저장되어 다시 켜도 이어지고, 다음 날 풀린다', () async {
      final c = FakeClock();
      final storage = MemoryStorage();
      final a = await stateAt(c, storage);
      a.tickPlay();
      for (var i = 0; i < 120; i++) {
        c.now = c.now.add(const Duration(seconds: 5));
        a.tickPlay();
      }
      expect(a.playBlock, PlayBlock.limit);
      await a.extendPlay();
      expect(a.playBlock, PlayBlock.none);
      a.pausePlay();

      final b = await stateAt(c, storage);
      expect(b.play.used, const Duration(minutes: 10));
      expect(b.play.bonusMinutes, 15);

      c.now = DateTime(2026, 10, 22, 8);
      final d = await stateAt(c, storage);
      expect(d.play.used, Duration.zero);
      expect(d.play.bonusMinutes, 0);
    });

    test('설정 값은 선택지 안에서만 바뀌고 시계에 바로 적용된다', () async {
      final s = await stateAt(FakeClock());
      await s.setPlayLimit(45);
      await s.setPlayLimit(7);
      expect(s.playLimitMin, 45);
      expect(s.play.limitMinutes, 45);
      await s.setEyeBreak(20);
      await s.setEyeBreak(30);
      expect(s.eyeBreakMin, 20);
      expect(s.play.breakMinutes, 20);
      await s.setEyeDistance(40);
      await s.setEyeDistance(12);
      expect(s.eyeDistanceCm, 40);
      expect(s.eye.tooCloseCm, 40);
      expect(s.eye.clearCm, 44);
    });

    test('기본값: 눈 보호·놀이 시간·부모 확인 모두 켜짐', () async {
      final s = await stateAt(FakeClock());
      expect(s.eyeGuardOn, isTrue);
      expect(s.playLimitMin, 10);
      expect(s.eyeBreakMin, 10);
      expect(s.parentGateOn, isTrue);
      expect(s.eyeDistanceCm, 30);
    });
  });

  group('저장 버전 6', () {
    test('버전 번호는 6이고, 단계 목록 길이와 같다', () {
      expect(SaveData.currentVersion, 6);
      expect(SaveData.steps.length, SaveData.currentVersion);
    });

    test('버전 5 저장값: 꺼 둔 눈 보호를 켜고 새 설정은 기본값', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 5,
          'nickname': '보리',
          'nicknameChosen': true,
          'coins': 42,
          'eyeGuardOn': false,
          'voiceStyle': 'pack',
        }),
      );
      expect(d.coins, 42);
      expect(d.eyeGuardOn, isTrue);
      expect(d.playLimitMin, 10);
      expect(d.eyeBreakMin, 10);
      expect(d.parentGateOn, isTrue);
      expect(d.eyeDistanceCm, 30);
      expect(d.playDay, isNull);
      expect(d.playSeconds, 0);
      expect(jsonDecode(d.encode())['version'], 6);
    });

    test('버전 6에서 부모님이 끈 설정은 그대로 둔다', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 6,
          'eyeGuardOn': false,
          'playLimitMin': 0,
          'eyeBreakMin': 20,
          'parentGateOn': false,
          'eyeDistanceCm': 35,
          'playDay': '2026-10-21',
          'playSeconds': 321,
          'playBonusMin': 15,
        }),
      );
      expect(d.eyeGuardOn, isFalse);
      expect(d.playLimitMin, 0);
      expect(d.eyeBreakMin, 20);
      expect(d.parentGateOn, isFalse);
      expect(d.eyeDistanceCm, 35);
      expect(d.playDay, '2026-10-21');
      expect(d.playSeconds, 321);
      expect(d.playBonusMin, 15);
    });

    test('새 필드가 손상되면 그 항목만 기본값', () {
      final d = SaveData.decode(
        jsonEncode({
          'version': 6,
          'coins': 33,
          'eyeGuardOn': 'yes',
          'playLimitMin': 13,
          'eyeBreakMin': -1,
          'parentGateOn': 1,
          'eyeDistanceCm': 3,
          'playDay': 'yesterday',
          'playSeconds': 500,
          'playBonusMin': 'x',
        }),
      );
      expect(d.coins, 33);
      expect(d.eyeGuardOn, isTrue);
      expect(d.playLimitMin, 10);
      expect(d.eyeBreakMin, 10);
      expect(d.parentGateOn, isTrue);
      expect(d.eyeDistanceCm, 30);
      expect(d.playDay, isNull);
      expect(d.playSeconds, 0, reason: '날짜를 모르면 논 시간도 버린다');
      expect(d.playBonusMin, 0);
    });

    test('버전 없는 아주 예전 저장값도 6까지 차례로 옮겨진다', () {
      final d = SaveData.decode(
        jsonEncode({'nickname': '콩이', 'coins': 20, 'voiceStyle': 'teacher'}),
      );
      expect(d.coins, 20);
      expect(d.voiceStyle, 'pack');
      expect(d.eyeGuardOn, isTrue);
      expect(d.nicknameChosen, isFalse, reason: '버전 1→2 단계도 돈다');
    });

    test('마이그레이션은 여러 번 돌아도 결과가 같다 (정리 단계 끼워 넣기 대비)', () {
      final old = <String, Object?>{
        'version': 3,
        'coins': 50,
        'owned': ['car', 'ribbon_pink'],
        'ride': 'car',
      };
      final once = SaveData.migrate(Map.of(old));
      final twice = SaveData.migrate(Map.of(once));
      expect(jsonEncode(twice), jsonEncode(once));
      expect(once['version'], SaveData.currentVersion);
      expect(SaveData.repairs, isA<List<SaveStep>>());
    });

    test('미래 버전 저장값도 앱을 멈추지 않고 아는 항목만 읽는다', () {
      final d = SaveData.decode(
        jsonEncode({'version': 99, 'coins': 77, 'eyeGuardOn': false}),
      );
      expect(d.coins, 77);
      expect(d.eyeGuardOn, isFalse);
    });

    test('새 필드가 저장·불러오기를 거쳐도 유지된다', () {
      final d = SaveData.initial()
        ..playLimitMin = 45
        ..eyeBreakMin = 20
        ..parentGateOn = false
        ..eyeDistanceCm = 25
        ..playDay = '2026-10-21'
        ..playSeconds = 90
        ..playBonusMin = 15;
      final e = SaveData.decode(d.encode());
      expect(e.playLimitMin, 45);
      expect(e.eyeBreakMin, 20);
      expect(e.parentGateOn, isFalse);
      expect(e.eyeDistanceCm, 25);
      expect(e.playDay, '2026-10-21');
      expect(e.playSeconds, 90);
      expect(e.playBonusMin, 15);
    });
  });

  group('백업 글자', () {
    Future<GameState> rich() async {
      final s = await stateAt(FakeClock());
      await s.setNickname('하늘');
      for (var i = 0; i < 40; i++) {
        await s.rewardCorrect(firstTry: true);
      }
      await s.purchase('ribbon_pink');
      await s.buyVehicle('car');
      await s.addSticker(
        'car',
        const PlacedSticker(
          kind: StickerKind.star,
          color: 0xFFFFCF4D,
          x: .4,
          y: .6,
        ),
      );
      await s.setPlayLimit(30);
      await s.setEyeBreak(20);
      await s.setEyeDistance(35);
      await s.setVoice(false);
      await s.completeSession(GameKind.number, 1);
      return s;
    }

    test("'ALOK1-'로 시작하고, 다른 기기에서 그대로 되살아난다", () async {
      final a = await rich();
      final code = a.exportBackup();
      expect(code, startsWith('ALOK1-'));
      expect(code, isNot(contains('=')));

      final b = await stateAt(FakeClock());
      expect(await b.restoreBackup(code), isNull);
      expect(b.nickname, '하늘');
      expect(b.coins, a.coins);
      expect(b.owned, a.owned);
      expect(b.equipped, a.equipped);
      expect(b.ride, 'car');
      expect(b.stickersOf('car').single.kind, StickerKind.star);
      expect(b.unlockedStage(GameKind.number), 2);
      expect(b.playLimitMin, 30);
      expect(b.eyeBreakMin, 20);
      expect(b.eyeDistanceCm, 35);
      expect(b.eye.tooCloseCm, 35);
      expect(b.voiceOn, isFalse);
      expect(b.audio.voiceOn, isFalse, reason: '되살린 설정이 바로 적용');
      expect(
        SaveData.decode((b.storage as MemoryStorage).raw).nickname,
        '하늘',
        reason: '복구한 기록이 기기에 저장된다',
      );
    });

    test('기기에만 맞는 값(카메라 보정·오늘 논 시간)은 백업에 넣지 않는다', () {
      final d = SaveData.initial()
        ..eyeCalibration = .2
        ..playDay = '2026-10-21'
        ..playSeconds = 500;
      final r = BackupCode.decode(BackupCode.encode(d));
      expect(r.ok, isTrue);
      expect(r.data!.eyeCalibration, isNull);
      expect(r.data!.playDay, isNull);
      expect(r.data!.playSeconds, 0);
    });

    test('복사하며 생긴 띄어쓰기·줄바꿈은 무시한다', () async {
      final a = await rich();
      final code = a.exportBackup();
      final messy =
          '  ${code.substring(0, 20)}\n${code.substring(20, 50)} '
          '${code.substring(50)}\n';
      expect(BackupCode.decode(messy).ok, isTrue);
    });

    test('백업 글자가 아니면 부드럽게 거절한다', () {
      for (final bad in [
        null,
        '',
        '   ',
        'hello',
        '{"coins": 9999}',
        'ALOK2-abc-12345678',
      ]) {
        expect(
          BackupCode.decode(bad).error,
          BackupError.notBackup,
          reason: '$bad',
        );
      }
    });

    test('글자가 빠지거나 바뀌면 체크섬으로 알아챈다', () async {
      final code = (await rich()).exportBackup();
      expect(BackupCode.decode('ALOK1-').error, BackupError.damaged);
      expect(BackupCode.decode('ALOK1-abc').error, BackupError.damaged);
      expect(
        BackupCode.decode(code.substring(0, code.length - 15)).error,
        BackupError.damaged,
      );
      // 본문 한 글자 바꾸기
      final i = 20;
      final swapped = code[i] == 'A' ? 'B' : 'A';
      final tampered = code.replaceRange(i, i + 1, swapped);
      expect(BackupCode.decode(tampered).error, BackupError.damaged);
      // 체크섬은 맞지만 JSON이 아닌 본문
      const junk = 'bm90LWpzb24';
      expect(
        BackupCode.decode('ALOK1-$junk-${BackupCode.checksum(junk)}').error,
        BackupError.damaged,
      );
      expect(BackupCode.decode(craft([1, 2])).error, BackupError.damaged);
      expect(
        BackupCode.decode(craft({'coins': 3})).error,
        BackupError.damaged,
        reason: '버전이 없으면 백업이 아니다',
      );
    });

    test('더 새 버전 앱의 백업은 거절하고, 예전 버전 백업은 옮겨서 받는다', () {
      expect(
        BackupCode.decode(craft({'version': SaveData.currentVersion + 1}))
            .error,
        BackupError.tooNew,
      );
      final old = BackupCode.decode(
        craft({'version': 5, 'coins': 61, 'eyeGuardOn': false}),
      );
      expect(old.ok, isTrue);
      expect(old.data!.coins, 61);
      expect(old.data!.eyeGuardOn, isTrue);
    });

    test('잘못된 글자로 복구하면 지금 기록은 그대로', () async {
      final s = await rich();
      final before = (s.storage as MemoryStorage).raw;
      final coins = s.coins;
      expect(
        await s.restoreBackup('ALOK1-망가진글자-00000000'),
        BackupError.damaged,
      );
      expect(await s.restoreBackup('안녕하세요'), BackupError.notBackup);
      expect(s.coins, coins);
      expect((s.storage as MemoryStorage).raw, before);
    });

    test('백업 안의 값도 범위를 검사한다 (코인 상한, 없는 아이템)', () {
      final r = BackupCode.decode(
        craft({
          'version': 6,
          'coins': 1 << 40,
          'owned': ['ribbon_pink', 'ghost'],
        }),
      );
      expect(r.data!.coins, Economy.startingCoins);
      expect(r.data!.owned, {'ribbon_pink'});
      expect(ItemCatalog.exists('ribbon_pink'), isTrue);
    });

    test('체크섬은 표준 FNV-1a 32비트 값과 같다 (웹·앱 같은 값)', () {
      expect(BackupCode.checksum(''), '811c9dc5');
      expect(BackupCode.checksum('a'), 'e40c292c');
      expect(BackupCode.checksum('foobar'), 'bf9cf968');
    });

    test('각 문구가 있다', () {
      for (final e in BackupError.values) {
        expect(BackupCode.message(e), isNotEmpty);
      }
    });
  });

  group('모양·크기·짝 놀이 진행 (트랙 B 필드)', () {
    test('v6 저장·불러오기와 ALOK1- 백업 왕복에 모두 들어간다', () async {
      final s = await stateAt(FakeClock());
      await s.completeSession(GameKind.shape, 1);
      await s.completeSession(GameKind.shape, 2);
      await s.completeSession(GameKind.size, 1);
      await s.completeSession(GameKind.match, 1);

      final saved = SaveData.decode((s.storage as MemoryStorage).raw);
      expect(saved.shapeStageUnlocked, 3);
      expect(saved.shapeStageCleared, {1, 2});
      expect(saved.sizeStageUnlocked, 2);
      expect(saved.sizeStageCleared, {1});
      expect(saved.matchStageUnlocked, 2);
      expect(saved.matchStageCleared, {1});

      final b = await stateAt(FakeClock());
      expect(await b.restoreBackup(s.exportBackup()), isNull);
      for (final g in [GameKind.shape, GameKind.size, GameKind.match]) {
        expect(b.unlockedStage(g), s.unlockedStage(g), reason: g.name);
        expect(b.clearedStages(g), s.clearedStages(g), reason: g.name);
      }
    });

    test('예전(v5) 저장값·백업에는 없으니 1단계부터, 범위 밖 값은 버린다', () {
      final old = SaveData.decode(jsonEncode({'version': 5, 'coins': 12}));
      expect(old.shapeStageUnlocked, 1);
      expect(old.sizeStageCleared, isEmpty);
      final r = BackupCode.decode(
        craft({
          'version': 6,
          'shapeStageUnlocked': 999,
          'matchStageCleared': [1, 999, 'x'],
        }),
      );
      expect(r.data!.shapeStageUnlocked, 1);
      expect(r.data!.matchStageCleared, {1});
    });
  });

  group('부모 확인 문제', () {
    test('두 수는 언제나 6~9 (합 12~18)', () {
      final r = Random(1);
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        final (a, b) = ParentalGate.makeQuestion(r);
        expect(a, inInclusiveRange(6, 9));
        expect(b, inInclusiveRange(6, 9));
        seen
          ..add(a)
          ..add(b);
      }
      expect(seen, {6, 7, 8, 9});
      expect(ParentalGate.answerOf('7 + 8'), 15);
    });
  });

  test('새 안내 문장은 녹음 조각으로 나눠진다', () {
    final lines = VoiceLines.all();
    final pack = VoicePack({
      for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3',
    });
    for (final t in [
      '오늘은 여기까지! 내일 또 만나요.',
      '창밖 먼 곳을 봐요.',
      '잘 쉬었어요! 다시 놀아요.',
      '부모님을 불러 주세요.',
      '15분 더 놀 수 있어요.',
    ]) {
      expect(pack.plan(t), isNotNull, reason: t);
    }
  });
}
