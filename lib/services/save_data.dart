import 'dart:convert';
import 'dart:math';

import '../character/nickname.dart';
import '../character/zodiac.dart';
import '../core/economy.dart';
import '../data/item_catalog.dart';
import '../data/stages.dart';
import '../data/vehicles.dart';
import 'play_clock.dart';

/// 저장값 JSON (마이그레이션 단계가 주고받는 형식)
typedef SaveJson = Map<String, Object?>;

/// 저장값 한 단계 변환
typedef SaveStep = SaveJson Function(SaveJson json);

/// 기기에 저장하는 모든 진행 데이터. 저장 형식이 바뀌면 [currentVersion]을 올리고
/// [SaveData.migrate]에 변환 단계를 추가한다 (연령 모드, 프로필 기능 대비).
class SaveData {
  SaveData({
    required this.nickname,
    required this.nicknameChosen,
    required this.zodiac,
    required this.coins,
    required this.owned,
    required this.equipped,
    required this.numberStageUnlocked,
    required this.colorStageUnlocked,
    required this.numberStageCleared,
    required this.colorStageCleared,
    required this.sessionsPlayed,
    required this.stars,
    required this.voiceOn,
    required this.sfxOn,
    this.musicOn = true,
    this.eyeGuardOn = true,
    this.eyeCalibration,
    this.eyeDistanceCm = SafetyRules.defaultEyeDistance,
    this.playLimitMin = SafetyRules.defaultLimit,
    this.eyeBreakMin = SafetyRules.defaultBreak,
    this.parentGateOn = true,
    this.playDay,
    this.playSeconds = 0,
    this.playBonusMin = 0,
    required this.ride,
    required this.stickers,
    required this.paints,
    required this.voiceStyle,
  });

  static const int currentVersion = 6;

  String nickname;

  /// 첫 실행 닉네임 화면을 지나갔는지 (건너뛰기 포함)
  bool nicknameChosen;

  /// 고른 12지신 캐릭터 (v2부터)
  Zodiac zodiac;
  int coins;
  Set<String> owned;
  Map<ItemSlot, String> equipped;
  int numberStageUnlocked;
  int colorStageUnlocked;
  Set<int> numberStageCleared;
  Set<int> colorStageCleared;
  int sessionsPlayed;
  int stars;
  bool voiceOn;
  bool sfxOn;

  /// 배경 음악 (없던 예전 저장값은 켜짐)
  bool musicOn;

  /// 눈 보호 (앞카메라로 거리·자세 확인). 기본 켜짐 (v6부터), 부모님이 설정에서 끈다.
  bool eyeGuardOn;

  /// 30cm에서 잰 얼굴 크기 (부모님이 맞춘 기준, 없으면 기본 계산)
  double? eyeCalibration;

  /// 눈 보호 거리 (cm): 이보다 가까우면 경고 (v6부터, 부모님이 조절)
  int eyeDistanceCm;

  /// 하루 놀이 시간 (분, 0이면 제한 없음. v6부터)
  int playLimitMin;

  /// 눈 쉬기 간격 (분, v6부터)
  int eyeBreakMin;

  /// 설정 들어가기·놀이 시간 늘리기 전에 부모 확인 (v6부터, 기본 켜짐)
  bool parentGateOn;

  /// 오늘 놀이 기록: 날짜(yyyy-mm-dd), 논 시간(초), 부모님이 더 준 시간(분). v6부터.
  /// 기기마다 따로 세므로 백업에는 넣지 않는다.
  String? playDay;
  int playSeconds;
  int playBonusMin;

  /// 타고 다니는 탈것 id (없으면 걸어 다님, v3부터)
  String? ride;

  /// 탈것별로 붙인 스티커 (v3부터)
  Map<String, List<PlacedSticker>> stickers;

  /// 탈것별로 칠한 색 id (v4부터). 없으면 그 탈것의 기본 색.
  Map<String, String> paints;

  /// 목소리 종류: 'pack'(녹음 목소리, 기본값) 또는 'teacher'(기기 음성)
  String voiceStyle;

  static const voiceStyles = ['pack', 'teacher'];

  /// 가진 꾸미기 아이템 / 탈것 (둘 다 [owned]에 함께 저장)
  bool ownsVehicle(String id) => owned.contains(id) && Vehicles.exists(id);

  /// 이 탈것에 이 색을 칠할 수 있는지 (기본 색은 공짜, 나머지는 그 탈것용으로 산 색).
  /// 예전 버전에서 산 색(모든 탈것 공용)은 그대로 쓸 수 있게 둔다.
  bool canPaint(String vehicleId, String paintId) {
    final v = Vehicles.byId(vehicleId);
    if (v == null || !Vehicles.paintExists(paintId)) return false;
    return v.defaultPaint == paintId ||
        owned.contains(Vehicles.paintKey(vehicleId, paintId)) ||
        owned.contains(paintId);
  }

  factory SaveData.initial() => SaveData(
    nickname: Nickname.fallback,
    nicknameChosen: false,
    zodiac: Zodiac.tiger,
    coins: Economy.startingCoins,
    owned: {},
    equipped: {},
    numberStageUnlocked: 1,
    colorStageUnlocked: 1,
    numberStageCleared: {},
    colorStageCleared: {},
    sessionsPlayed: 0,
    stars: 0,
    voiceOn: true,
    sfxOn: true,
    ride: null,
    stickers: {},
    paints: {},
    voiceStyle: 'pack',
  );

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'nickname': nickname,
    'nicknameChosen': nicknameChosen,
    'zodiac': zodiac.name,
    'coins': coins,
    'owned': owned.toList()..sort(),
    'equipped': {for (final e in equipped.entries) e.key.name: e.value},
    'numberStageUnlocked': numberStageUnlocked,
    'colorStageUnlocked': colorStageUnlocked,
    'numberStageCleared': numberStageCleared.toList()..sort(),
    'colorStageCleared': colorStageCleared.toList()..sort(),
    'sessionsPlayed': sessionsPlayed,
    'stars': stars,
    'voiceOn': voiceOn,
    'sfxOn': sfxOn,
    'musicOn': musicOn,
    'eyeGuardOn': eyeGuardOn,
    if (eyeCalibration != null) 'eyeCalibration': eyeCalibration,
    'eyeDistanceCm': eyeDistanceCm,
    'playLimitMin': playLimitMin,
    'eyeBreakMin': eyeBreakMin,
    'parentGateOn': parentGateOn,
    if (playDay != null) 'playDay': playDay,
    'playSeconds': playSeconds,
    'playBonusMin': playBonusMin,
    'ride': ride,
    'stickers': {
      for (final e in stickers.entries)
        e.key: [for (final st in e.value) st.toJson()],
    },
    'paints': paints,
    'voiceStyle': voiceStyle,
  };

  String encode() => jsonEncode(toJson());

  /// 저장 문자열을 읽는다. 비어 있거나 깨져 있으면 기본값을 돌려준다.
  /// 일부 항목만 손상된 경우 그 항목만 기본값으로 바꾸고 나머지는 살린다.
  static SaveData decode(String? raw) {
    if (raw == null || raw.isEmpty) return SaveData.initial();
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return SaveData.initial();
    }
    if (parsed is! Map) return SaveData.initial();
    return fromJson(migrate(Map<String, Object?>.from(parsed)));
  }

  /// 예전 버전 저장값을 최신 형식으로 바꾼다.
  ///
  /// 1) [steps]: 저장 버전마다 한 번씩 도는 변환. `steps[n]`은 버전 n 저장값을 n+1로 바꾼다.
  ///    저장 형식이 바뀌면 [currentVersion]을 올리고 여기에 한 단계를 더한다.
  /// 2) [repairs]: 버전과 상관없이 읽을 때마다 도는 정리 단계. 여러 번 돌아도 결과가
  ///    같아야 한다(멱등). 예: 없어진 탈것의 스티커·색을 새 탈것으로 옮기기.
  ///    새 정리 단계는 [repairs] 목록 끝에 함수 하나를 더하면 된다.
  static SaveJson migrate(SaveJson json) {
    var version = _int(json['version'], 0, 0, 1 << 30);
    while (version < currentVersion) {
      json = steps[version](json);
      version++;
      json = {...json, 'version': version};
    }
    for (final repair in repairs) {
      json = repair({...json});
    }
    return json;
  }

  /// 버전 올림 단계. 인덱스 n = 버전 n → n+1. 길이는 항상 [currentVersion].
  static const List<SaveStep> steps = [
    _v0to1,
    _v1to2,
    _v2to3,
    _v3to4,
    _v4to5,
    _v5to6,
  ];

  /// 매번 도는 정리 단계 (버전과 무관, 멱등)
  static const List<SaveStep> repairs = [];

  // 버전 0: 버전 번호가 없던 초기 개발 형식. 필드 구조는 1과 같다.
  static SaveJson _v0to1(SaveJson json) => {...json};

  // 버전 1: 고양이 캐릭터 시절. 12지신이 생기면서 가장 닮은 호랑이로 옮기고,
  // 동물을 직접 고를 수 있도록 첫 화면(닉네임·동물 고르기)을 한 번 더 보여 준다.
  static SaveJson _v1to2(SaveJson json) => {
    ...json,
    'zodiac': Zodiac.tiger.name,
    'nicknameChosen': false,
  };

  // 버전 2: 옷이 6가지 테마(로봇·공주·소방관·경찰·군인·원시인)로 바뀌면서 없어진 아이템은
  // 산 값만큼 코인으로 돌려준다. 계속 있는 아이템(로봇 슈트, 왕관 등)은 그대로 가진다.
  static SaveJson _v2to3(SaveJson json) {
    final owned = json['owned'];
    var refund = 0;
    if (owned is List) {
      for (final id in owned.whereType<String>()) {
        refund += ItemCatalog.retired[id] ?? 0;
      }
    }
    final coins = json['coins'];
    final out = {...json};
    if (refund > 0 && coins is int) out['coins'] = coins + refund;
    return out;
  }

  // 버전 3: 색깔별 탈것(빨간 자동차, 파란 자동차…)이 "종류별 한 대 + 색칠"로 바뀌었다.
  // 예전 탈것은 같은 종류의 새 탈것과 그 색으로 바꾸고, 같은 종류를 두 대 샀다면
  // 두 번째 탈것 값에서 색칠 값을 뺀 만큼 코인으로 돌려준다. 스티커는 합친다(최대 12장).
  // 높게 올린 '아이 목소리'가 무섭게 들려서 톤을 바꿨다. 모두 기본 목소리로 돌린다.
  static SaveJson _v3to4(SaveJson json) => {
    ..._migrateVehicles(json),
    'voiceStyle': 'teacher',
  };

  // 버전 4: 무료 음성 모델로 녹음한 목소리가 생겼다. 모두 녹음 목소리로 바꾼다.
  static SaveJson _v4to5(SaveJson json) => {...json, 'voiceStyle': 'pack'};

  // 버전 5: 아이 안전 설정이 생겼다. 눈 보호·놀이 시간·부모 확인은 모두 기본 켜짐이라
  // 예전에 기본값(꺼짐)으로 두었던 눈 보호도 켠다. 새 설정은 기본값으로 채운다.
  static SaveJson _v5to6(SaveJson json) => {
    ...json,
    'eyeGuardOn': true,
    'eyeDistanceCm': SafetyRules.defaultEyeDistance,
    'playLimitMin': SafetyRules.defaultLimit,
    'eyeBreakMin': SafetyRules.defaultBreak,
    'parentGateOn': true,
  };

  static SaveJson _migrateVehicles(SaveJson json) {
    final out = {...json};
    final owned = json['owned'];
    if (owned is! List) return out;
    final newOwned = <Object?>[];
    final paints = <String, String>{};
    var refund = 0;
    // 지금 타고 있던 탈것의 색이 그 종류의 색이 되도록 먼저 처리한다
    final oldRide = json['ride'];
    final ids = owned.whereType<String>().toList()
      ..sort((a, b) => a == oldRide ? -1 : (b == oldRide ? 1 : 0));
    for (final id in ids) {
      final m = Vehicles.legacy[id];
      if (m == null) {
        newOwned.add(id);
        continue;
      }
      final (vehicle, paint, price) = m;
      final v = Vehicles.byId(vehicle)!;
      final isDefault = paint == v.defaultPaint;
      if (!isDefault) newOwned.add(paint);
      if (newOwned.contains(vehicle)) {
        // 같은 종류 두 번째 탈것: 색칠로 바뀐 만큼을 뺀 나머지를 돌려준다
        refund += max(0, price - (isDefault ? 0 : Vehicles.paintPrice));
      } else {
        newOwned.add(vehicle);
        paints[vehicle] = paint;
      }
    }
    out['owned'] = newOwned;
    out['paints'] = paints;
    if (oldRide is String && Vehicles.legacy.containsKey(oldRide)) {
      out['ride'] = Vehicles.legacy[oldRide]!.$1;
    }
    final stickers = json['stickers'];
    if (stickers is Map) {
      final merged = <String, List<Object?>>{};
      for (final e in stickers.entries) {
        final key = e.key;
        final to = key is String ? (Vehicles.legacy[key]?.$1 ?? key) : key;
        if (to is! String || e.value is! List) continue;
        merged.putIfAbsent(to, () => []).addAll(e.value as List);
      }
      out['stickers'] = merged;
    }
    final coins = json['coins'];
    if (refund > 0 && coins is int) out['coins'] = coins + refund;
    return out;
  }

  static SaveData fromJson(Map<String, Object?> json) {
    final d = SaveData.initial();
    final maxNumber = Stages.number.length;
    final maxColor = Stages.color.length;

    d.nickname = Nickname.sanitize(json['nickname']);
    d.zodiac = ZodiacInfo.parse(json['zodiac']);
    d.nicknameChosen = json['nicknameChosen'] is bool
        ? json['nicknameChosen'] as bool
        : d.nicknameChosen;
    d.coins = _int(json['coins'], d.coins, 0, Economy.maxCoins);

    final owned = json['owned'];
    if (owned is List) {
      d.owned = owned
          .whereType<String>()
          .where(
            (id) =>
                ItemCatalog.exists(id) ||
                Vehicles.exists(id) ||
                Vehicles.paintExists(id) ||
                Vehicles.paintKeyValid(id),
          )
          .toSet();
    }

    final equipped = json['equipped'];
    if (equipped is Map) {
      for (final slot in ItemSlot.values) {
        final id = equipped[slot.name];
        final item = id is String ? ItemCatalog.byId(id) : null;
        // 존재하고, 가지고 있고, 부위가 맞는 아이템만 장착 상태로 복구
        if (item != null && item.slot == slot && d.owned.contains(item.id)) {
          d.equipped[slot] = item.id;
        }
      }
    }

    d.numberStageUnlocked = _int(json['numberStageUnlocked'], 1, 1, maxNumber);
    d.colorStageUnlocked = _int(json['colorStageUnlocked'], 1, 1, maxColor);
    d.numberStageCleared = _intSet(json['numberStageCleared'], 1, maxNumber);
    d.colorStageCleared = _intSet(json['colorStageCleared'], 1, maxColor);
    d.sessionsPlayed = _int(json['sessionsPlayed'], 0, 0, 1 << 30);
    d.stars = _int(json['stars'], 0, 0, 1 << 30);
    d.voiceOn = json['voiceOn'] is bool ? json['voiceOn'] as bool : true;
    d.sfxOn = json['sfxOn'] is bool ? json['sfxOn'] as bool : true;
    d.musicOn = json['musicOn'] is bool ? json['musicOn'] as bool : true;
    d.eyeGuardOn = json['eyeGuardOn'] is bool
        ? json['eyeGuardOn'] as bool
        : true;
    final cal = json['eyeCalibration'];
    d.eyeCalibration = cal is num && cal > 0 && cal < 1 ? cal.toDouble() : null;
    d.eyeDistanceCm = _choice(
      json['eyeDistanceCm'],
      SafetyRules.eyeDistanceChoices,
      SafetyRules.defaultEyeDistance,
    );
    d.playLimitMin = _choice(
      json['playLimitMin'],
      SafetyRules.limitChoices,
      SafetyRules.defaultLimit,
    );
    d.eyeBreakMin = _choice(
      json['eyeBreakMin'],
      SafetyRules.breakChoices,
      SafetyRules.defaultBreak,
    );
    d.parentGateOn = json['parentGateOn'] is bool
        ? json['parentGateOn'] as bool
        : true;
    final day = json['playDay'];
    d.playDay = day is String && _dayPattern.hasMatch(day) ? day : null;
    d.playSeconds = d.playDay == null
        ? 0
        : _int(json['playSeconds'], 0, 0, 24 * 60 * 60);
    d.playBonusMin = d.playDay == null
        ? 0
        : _int(json['playBonusMin'], 0, 0, 24 * 60);
    final ride = json['ride'];
    d.ride = ride is String && d.ownsVehicle(ride) ? ride : null;
    final stickers = json['stickers'];
    if (stickers is Map) {
      for (final e in stickers.entries) {
        final id = e.key;
        if (id is! String || !d.ownsVehicle(id) || e.value is! List) continue;
        final list = (e.value as List)
            .map(PlacedSticker.fromJson)
            .whereType<PlacedSticker>()
            .take(Vehicles.maxStickers)
            .toList();
        if (list.isNotEmpty) d.stickers[id] = list;
      }
    }
    final paints = json['paints'];
    if (paints is Map) {
      for (final e in paints.entries) {
        final id = e.key, paint = e.value;
        if (id is String &&
            paint is String &&
            d.ownsVehicle(id) &&
            d.canPaint(id, paint)) {
          d.paints[id] = paint;
        }
      }
    }
    final vs = json['voiceStyle'];
    d.voiceStyle = vs is String && voiceStyles.contains(vs) ? vs : 'pack';
    return d;
  }

  static int _int(Object? v, int fallback, int min, int max) {
    if (v is int && v >= min && v <= max) return v;
    return fallback;
  }

  static int _choice(Object? v, List<int> choices, int fallback) =>
      v is int && choices.contains(v) ? v : fallback;

  static final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static Set<int> _intSet(Object? v, int min, int max) {
    if (v is! List) return {};
    return v.whereType<int>().where((x) => x >= min && x <= max).toSet();
  }
}
