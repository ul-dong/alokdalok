import 'dart:convert';
import 'dart:math';

import '../character/nickname.dart';
import '../character/zodiac.dart';
import '../core/economy.dart';
import '../data/item_catalog.dart';
import '../data/stages.dart';
import '../data/vehicles.dart';

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
    this.eyeGuardOn = false,
    this.eyeCalibration,
    required this.ride,
    required this.stickers,
    required this.paints,
    required this.voiceStyle,
  });

  static const int currentVersion = 5;

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

  /// 눈 지킴이 (앞카메라로 거리·자세 확인). 부모님이 설정에서 켠다.
  bool eyeGuardOn;

  /// 30cm에서 잰 얼굴 크기 (부모님이 맞춘 기준, 없으면 기본 계산)
  double? eyeCalibration;

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
  static Map<String, Object?> migrate(Map<String, Object?> json) {
    var version = _int(json['version'], 0, 0, 1 << 30);
    // 버전 0: 버전 번호가 없던 초기 개발 형식. 필드 구조는 1과 같다.
    if (version < 1) {
      json = {...json, 'version': 1};
      version = 1;
    }
    // 버전 1: 고양이 캐릭터 시절. 12지신이 생기면서 가장 닮은 호랑이로 옮기고,
    // 동물을 직접 고를 수 있도록 첫 화면(닉네임·동물 고르기)을 한 번 더 보여 준다.
    if (version < 2) {
      json = {
        ...json,
        'version': 2,
        'zodiac': Zodiac.tiger.name,
        'nicknameChosen': false,
      };
      version = 2;
    }
    // 버전 2: 옷이 6가지 테마(로봇·공주·소방관·경찰·군인·원시인)로 바뀌면서 없어진 아이템은
    // 산 값만큼 코인으로 돌려준다. 계속 있는 아이템(로봇 슈트, 왕관 등)은 그대로 가진다.
    if (version < 3) {
      final owned = json['owned'];
      var refund = 0;
      if (owned is List) {
        for (final id in owned.whereType<String>()) {
          refund += ItemCatalog.retired[id] ?? 0;
        }
      }
      final coins = json['coins'];
      json = {...json, 'version': 3};
      if (refund > 0 && coins is int) json['coins'] = coins + refund;
      version = 3;
    }
    // 버전 3: 색깔별 탈것(빨간 자동차, 파란 자동차…)이 "종류별 한 대 + 색칠"로 바뀌었다.
    // 예전 탈것은 같은 종류의 새 탈것과 그 색으로 바꾸고, 같은 종류를 두 대 샀다면
    // 두 번째 탈것 값에서 색칠 값을 뺀 만큼 코인으로 돌려준다. 스티커는 합친다(최대 12장).
    if (version < 4) {
      json = _migrateVehicles(json);
      // 높게 올린 '아이 목소리'가 무섭게 들려서 톤을 바꿨다. 모두 기본 목소리로 돌린다.
      json['voiceStyle'] = 'teacher';
      version = 4;
    }
    // 버전 4: 무료 음성 모델로 녹음한 목소리가 생겼다. 모두 녹음 목소리로 바꾼다.
    if (version < 5) {
      json = {...json, 'version': 5, 'voiceStyle': 'pack'};
      version = 5;
    }
    // 버전과 상관없이: 없어진 탈것(자전거·킥보드)이 남아 있으면 기차·열기구로 옮긴다.
    // 몇 번을 돌려도 결과가 같다 (옮긴 뒤에는 없어진 id가 남지 않는다).
    json = _moveRetiredVehicles(json);
    return json;
  }

  /// 없어진 탈것을 [Vehicles.retired]의 새 탈것으로 옮긴다: 가진 탈것, 타는 탈것,
  /// 붙인 스티커(새 탈것에 이미 있으면 합침), 칠한 색, 그 탈것용으로 산 색('paint_x@bicycle').
  /// 없어진 탈것의 처음 색(공짜)을 칠해 두었는데 새 탈것의 처음 색과 다르면 그 색을 선물한다.
  static Map<String, Object?> _moveRetiredVehicles(Map<String, Object?> json) {
    String? moved(Object? id) => id is String ? Vehicles.retired[id]?.$1 : null;
    // 'paint_red@bicycle' → 'paint_red@train'
    String? movedPaintKey(String key) {
      final i = key.indexOf('@');
      if (i <= 0) return null;
      final to = moved(key.substring(i + 1));
      return to == null ? null : Vehicles.paintKey(to, key.substring(0, i));
    }

    final out = {...json};
    var changed = false;

    final owned = json['owned'];
    final newOwned = <Object?>[];
    if (owned is List) {
      for (final id in owned) {
        final to = moved(id) ?? (id is String ? movedPaintKey(id) : null);
        if (to != null) changed = true;
        final v = to ?? id;
        if (!newOwned.contains(v)) newOwned.add(v);
      }
    }

    final paints = json['paints'];
    if (paints is Map) {
      final newPaints = <Object?, Object?>{};
      // 새 탈것에 이미 칠한 색이 있으면 그 색을 둔다
      for (final e in paints.entries) {
        if (moved(e.key) == null) newPaints[e.key] = e.value;
      }
      for (final e in paints.entries) {
        final to = moved(e.key);
        if (to == null) continue;
        changed = true;
        final paint = e.value;
        newPaints.putIfAbsent(to, () => paint);
        final free = Vehicles.retired[e.key]!.$2;
        final target = Vehicles.byId(to);
        if (paint == free &&
            target != null &&
            target.defaultPaint != free &&
            owned is List) {
          final key = Vehicles.paintKey(to, free);
          if (!newOwned.contains(key)) newOwned.add(key);
        }
      }
      out['paints'] = newPaints;
    }
    if (owned is List) out['owned'] = newOwned;

    final ride = moved(json['ride']);
    if (ride != null) {
      out['ride'] = ride;
      changed = true;
    }

    final stickers = json['stickers'];
    if (stickers is Map && stickers.keys.any((k) => moved(k) != null)) {
      final merged = <Object?, Object?>{};
      for (final e in stickers.entries) {
        if (moved(e.key) == null) merged[e.key] = e.value;
      }
      for (final e in stickers.entries) {
        final to = moved(e.key);
        if (to == null || e.value is! List) continue;
        final have = merged[to];
        merged[to] = [if (have is List) ...have, ...(e.value as List)];
      }
      out['stickers'] = merged;
      changed = true;
    }
    return changed ? out : json;
  }

  static Map<String, Object?> _migrateVehicles(Map<String, Object?> json) {
    final out = {...json, 'version': 4};
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
    d.eyeGuardOn = json['eyeGuardOn'] == true;
    final cal = json['eyeCalibration'];
    d.eyeCalibration = cal is num && cal > 0 && cal < 1 ? cal.toDouble() : null;
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

  static Set<int> _intSet(Object? v, int min, int max) {
    if (v is! List) return {};
    return v.whereType<int>().where((x) => x >= min && x <= max).toSet();
  }
}
