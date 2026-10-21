import 'dart:async';

import 'package:flutter/foundation.dart';

import '../character/nickname.dart';
import '../character/zodiac.dart';
import '../core/economy.dart';
import '../data/item_catalog.dart';
import '../data/stages.dart';
import '../data/vehicles.dart';
import 'audio_service.dart';
import 'backup_code.dart';
import 'eye_guard.dart';
import 'play_clock.dart';
import 'save_data.dart';
import 'storage_service.dart';

/// 놀이 종류. 이 값 하나로 단계 고르기·놀이 화면을 연다 (`games/game_entry.dart`).
enum GameKind { number, color, shape, size, match }

extension GameKindInfo on GameKind {
  /// 화면에 쓰는 이름 (부모님용 보조 글자)
  String get title => switch (this) {
    GameKind.number => '숫자 놀이',
    GameKind.color => '색깔 놀이',
    GameKind.shape => '모양 놀이',
    GameKind.size => '크기 놀이',
    GameKind.match => '짝 맞추기',
  };

  /// 단계 수
  int get stageCount => switch (this) {
    GameKind.number => Stages.number.length,
    GameKind.color => Stages.color.length,
    GameKind.shape => Stages.shape.length,
    GameKind.size => Stages.size.length,
    GameKind.match => Stages.match.length,
  };
}

enum PurchaseResult { ok, alreadyOwned, notEnoughCoins, unknownItem }

/// 한 판을 끝냈을 때 받은 보상 내역
class SessionReward {
  const SessionReward({
    required this.complete,
    required this.firstPlay,
    required this.newStage,
    required this.unlockedStage,
  });

  final int complete;
  final int firstPlay;
  final int newStage;

  /// 새로 열린 단계 번호 (없으면 null)
  final int? unlockedStage;

  int get total => complete + firstPlay + newStage;
}

/// 앱 전체 상태. 화면은 이 객체만 바라보고, 저장은 이 객체가 책임진다.
class GameState extends ChangeNotifier {
  GameState({
    required this.storage,
    required this.audio,
    EyeGuard? eyeGuard,
    DateTime Function()? now,
  }) : eye = eyeGuard ?? EyeGuard(),
       play = PlayClock(now: now);

  final StorageService storage;
  final AudioService audio;

  /// 눈 지킴이 (화면 거리·자세)
  final EyeGuard eye;

  /// 하루 놀이 시간·눈 쉬기 시계
  final PlayClock play;

  SaveData _d = SaveData.initial();
  bool _loaded = false;

  bool get loaded => _loaded;
  String get nickname => _d.nickname;
  bool get nicknameChosen => _d.nicknameChosen;
  Zodiac get zodiac => _d.zodiac;
  int get coins => _d.coins;
  int get stars => _d.stars;
  Set<String> get owned => Set.unmodifiable(_d.owned);
  Map<ItemSlot, String> get equipped => Map.unmodifiable(_d.equipped);
  bool get voiceOn => _d.voiceOn;
  bool get sfxOn => _d.sfxOn;
  int get sessionsPlayed => _d.sessionsPlayed;

  int unlockedStage(GameKind g) => switch (g) {
    GameKind.number => _d.numberStageUnlocked,
    GameKind.color => _d.colorStageUnlocked,
    GameKind.shape => _d.shapeStageUnlocked,
    GameKind.size => _d.sizeStageUnlocked,
    GameKind.match => _d.matchStageUnlocked,
  };
  Set<int> clearedStages(GameKind g) => Set.unmodifiable(_cleared(g));
  int stageCount(GameKind g) => g.stageCount;

  Set<int> _cleared(GameKind g) => switch (g) {
    GameKind.number => _d.numberStageCleared,
    GameKind.color => _d.colorStageCleared,
    GameKind.shape => _d.shapeStageCleared,
    GameKind.size => _d.sizeStageCleared,
    GameKind.match => _d.matchStageCleared,
  };

  void _setUnlocked(GameKind g, int stage) => switch (g) {
    GameKind.number => _d.numberStageUnlocked = stage,
    GameKind.color => _d.colorStageUnlocked = stage,
    GameKind.shape => _d.shapeStageUnlocked = stage,
    GameKind.size => _d.sizeStageUnlocked = stage,
    GameKind.match => _d.matchStageUnlocked = stage,
  };

  bool owns(String itemId) => _d.owned.contains(itemId);

  Future<void> load() async {
    _d = await storage.load();
    _applyAudio();
    _applySafety();
    play.restore(
      day: _d.playDay,
      usedSeconds: _d.playSeconds,
      bonusMinutes: _d.playBonusMin,
    );
    eye.calibration = _d.eyeCalibration;
    if (_d.eyeGuardOn && eye.supported) unawaited(eye.start());
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit() async {
    notifyListeners();
    await storage.save(_d);
  }

  void _applyAudio() {
    audio.voiceOn = _d.voiceOn;
    audio.sfxOn = _d.sfxOn;
    audio.voiceStyle = _d.voiceStyle;
    audio.musicOn = _d.musicOn;
  }

  void _applySafety() {
    eye.tooCloseCm = _d.eyeDistanceCm.toDouble();
    play
      ..limitMinutes = _d.playLimitMin
      ..breakMinutes = _d.eyeBreakMin;
  }

  bool get musicOn => _d.musicOn;

  bool get eyeGuardOn => _d.eyeGuardOn;

  Future<void> setEyeGuard(bool on) async {
    _d.eyeGuardOn = on;
    on ? await eye.start() : await eye.stop();
    await _commit();
  }

  /// 지금 거리를 30cm 기준으로 저장. 얼굴이 안 보이면 false.
  Future<bool> calibrateEye() async {
    final v = eye.calibrateNow();
    if (v == null) return false;
    _d.eyeCalibration = v;
    await _commit();
    return true;
  }

  Future<void> resetEyeCalibration() async {
    _d.eyeCalibration = null;
    eye.calibration = null;
    await _commit();
  }

  Future<void> setMusic(bool on) async {
    _d.musicOn = on;
    _applyAudio();
    await _commit();
  }

  String get voiceStyle => _d.voiceStyle;

  Future<void> setVoiceStyle(String style) async {
    if (!SaveData.voiceStyles.contains(style)) return;
    _d.voiceStyle = style;
    _applyAudio();
    await _commit();
  }

  // ---------- 캐릭터 ----------

  Future<void> setZodiac(Zodiac z) async {
    if (_d.zodiac == z) return;
    _d.zodiac = z;
    await _commit();
  }

  // ---------- 닉네임 ----------

  /// 규칙에 맞으면 저장하고 true. 아니면 아무것도 바꾸지 않고 false.
  Future<bool> setNickname(String value) async {
    if (!Nickname.isValid(value)) return false;
    _d.nickname = value;
    _d.nicknameChosen = true;
    await _commit();
    return true;
  }

  /// 첫 실행 닉네임 화면을 건너뛰면 기본 닉네임을 쓴다.
  Future<void> skipNickname() async {
    _d.nicknameChosen = true;
    await _commit();
  }

  // ---------- 코인과 보상 ----------

  /// 정답 보상. 오답에는 이 함수를 부르지 않으므로 코인이 줄어드는 경우는 없다.
  Future<int> rewardCorrect({required bool firstTry}) async {
    final amount = firstTry
        ? Economy.correctFirstTry
        : Economy.correctAfterRetry;
    _d.coins = (_d.coins + amount).clamp(0, Economy.maxCoins);
    if (firstTry) _d.stars += 1;
    await _commit();
    return amount;
  }

  /// 한 판 완료 보상과 다음 단계 열기.
  Future<SessionReward> completeSession(GameKind game, int stageId) async {
    final firstPlay = _d.sessionsPlayed == 0 ? Economy.firstPlayBonus : 0;
    final cleared = _cleared(game);
    final newStage = cleared.contains(stageId) ? 0 : Economy.newStageBonus;
    cleared.add(stageId);

    int? unlocked;
    final next = stageId + 1;
    if (next <= stageCount(game) && unlockedStage(game) < next) {
      _setUnlocked(game, next);
      unlocked = next;
    }

    final reward = SessionReward(
      complete: Economy.sessionComplete,
      firstPlay: firstPlay,
      newStage: newStage,
      unlockedStage: unlocked,
    );
    _d.sessionsPlayed += 1;
    _d.coins = (_d.coins + reward.total).clamp(0, Economy.maxCoins);
    await _commit();
    return reward;
  }

  // ---------- 상점과 꾸미기 ----------

  bool canAfford(String itemId) {
    final item = ItemCatalog.byId(itemId);
    return item != null && _d.coins >= item.price;
  }

  /// 게임 코인으로만 산다. 현금 결제는 없다.
  Future<PurchaseResult> purchase(String itemId) async {
    final item = ItemCatalog.byId(itemId);
    if (item == null) return PurchaseResult.unknownItem;
    if (_d.owned.contains(itemId)) return PurchaseResult.alreadyOwned;
    if (_d.coins < item.price) return PurchaseResult.notEnoughCoins;
    _d.coins -= item.price;
    _d.owned.add(itemId);
    _d.equipped[item.slot] = itemId; // 사자마자 입혀 준다
    await _commit();
    return PurchaseResult.ok;
  }

  // ---------- 탈것과 스티커 ----------

  String? get ride => _d.ride;
  bool ownsVehicle(String id) => _d.ownsVehicle(id);
  List<PlacedSticker> stickersOf(String vehicleId) =>
      List.unmodifiable(_d.stickers[vehicleId] ?? const []);

  /// 탈것도 게임 코인으로만 산다. 타는 것은 "탑승!"을 눌러야 한다 ([setRide]).
  Future<PurchaseResult> buyVehicle(String id) async {
    final v = Vehicles.byId(id);
    if (v == null) return PurchaseResult.unknownItem;
    if (_d.owned.contains(id)) return PurchaseResult.alreadyOwned;
    if (_d.coins < v.price) return PurchaseResult.notEnoughCoins;
    _d.coins -= v.price;
    _d.owned.add(id);
    await _commit();
    return PurchaseResult.ok;
  }

  /// 이 탈것에 지금 칠해진 색
  VehiclePaint paintOf(String vehicleId) {
    final v = Vehicles.byId(vehicleId);
    final id = _d.paints[vehicleId];
    if (id != null) return Vehicles.paintById(id)!;
    return v == null ? Vehicles.paints.first : Vehicles.defaultPaintOf(v);
  }

  /// 이 탈것용으로 이 색을 가졌는지 (기본 색 포함)
  bool ownsPaint(String vehicleId, String paintId) =>
      _d.canPaint(vehicleId, paintId);
  bool canPaint(String vehicleId, String paintId) =>
      _d.canPaint(vehicleId, paintId);

  /// 색을 코인으로 산다. 탈것마다 색깔별로 따로 산다.
  Future<PurchaseResult> buyPaint(String vehicleId, String paintId) async {
    if (!Vehicles.paintExists(paintId) || !_d.ownsVehicle(vehicleId)) {
      return PurchaseResult.unknownItem;
    }
    if (_d.canPaint(vehicleId, paintId)) return PurchaseResult.alreadyOwned;
    if (_d.coins < Vehicles.paintPrice) return PurchaseResult.notEnoughCoins;
    _d.coins -= Vehicles.paintPrice;
    _d.owned.add(Vehicles.paintKey(vehicleId, paintId));
    await _commit();
    return PurchaseResult.ok;
  }

  /// 탈것 색칠하기. 가진 탈것에, 칠할 수 있는 색만. 칠했으면 true.
  Future<bool> setPaint(String vehicleId, String paintId) async {
    if (!_d.ownsVehicle(vehicleId) || !_d.canPaint(vehicleId, paintId)) {
      return false;
    }
    _d.paints[vehicleId] = paintId;
    await _commit();
    return true;
  }

  /// 탈것에 타기 / 내리기 (null이면 걸어 다님)
  Future<void> setRide(String? id) async {
    if (id != null && !_d.ownsVehicle(id)) return;
    _d.ride = id;
    await _commit();
  }

  /// 스티커 붙이기. 가진 탈것에만, 최대 [Vehicles.maxStickers]장. 붙였으면 true.
  Future<bool> addSticker(String vehicleId, PlacedSticker sticker) async {
    if (!_d.ownsVehicle(vehicleId)) return false;
    final list = _d.stickers.putIfAbsent(vehicleId, () => []);
    if (list.length >= Vehicles.maxStickers) return false;
    list.add(sticker);
    await _commit();
    return true;
  }

  Future<void> removeSticker(String vehicleId, int index) async {
    final list = _d.stickers[vehicleId];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _commit();
  }

  Future<void> clearStickers(String vehicleId) async {
    if (_d.stickers.remove(vehicleId) != null) await _commit();
  }

  /// 가지고 있는 아이템만 장착할 수 있다. 같은 부위의 아이템은 바뀐다.
  Future<bool> equip(String itemId) async {
    final item = ItemCatalog.byId(itemId);
    if (item == null || !_d.owned.contains(itemId)) return false;
    _d.equipped[item.slot] = itemId;
    await _commit();
    return true;
  }

  Future<void> unequip(ItemSlot slot) async {
    if (_d.equipped.remove(slot) != null) await _commit();
  }

  /// 장착 중이면 벗고, 아니면 입는다.
  Future<void> toggleEquip(String itemId) async {
    final item = ItemCatalog.byId(itemId);
    if (item == null) return;
    if (_d.equipped[item.slot] == itemId) {
      await unequip(item.slot);
    } else {
      await equip(itemId);
    }
  }

  /// 기본 모습으로 (아이템은 그대로 보유)
  Future<void> resetOutfit() async {
    _d.equipped.clear();
    await _commit();
  }

  // ---------- 설정 ----------

  Future<void> setVoice(bool on) async {
    _d.voiceOn = on;
    _applyAudio();
    if (!on) await audio.stopVoice();
    await _commit();
  }

  Future<void> setSfx(bool on) async {
    _d.sfxOn = on;
    _applyAudio();
    await _commit();
  }

  // ---------- 아이 안전 (부모님 설정) ----------

  int get eyeDistanceCm => _d.eyeDistanceCm;
  int get playLimitMin => _d.playLimitMin;
  int get eyeBreakMin => _d.eyeBreakMin;
  bool get parentGateOn => _d.parentGateOn;

  /// 눈 보호 거리 (cm). 선택지에 없는 값은 무시.
  Future<void> setEyeDistance(int cm) async {
    if (!SafetyRules.eyeDistanceChoices.contains(cm)) return;
    _d.eyeDistanceCm = cm;
    _applySafety();
    await _commit();
  }

  /// 하루 놀이 시간 (분, 0 = 제한 없음). 선택지에 없는 값은 무시.
  Future<void> setPlayLimit(int minutes) async {
    if (!SafetyRules.limitChoices.contains(minutes)) return;
    _d.playLimitMin = minutes;
    _applySafety();
    await _commit();
  }

  /// 눈 쉬기 간격 (분). 선택지에 없는 값은 무시.
  Future<void> setEyeBreak(int minutes) async {
    if (!SafetyRules.breakChoices.contains(minutes)) return;
    _d.eyeBreakMin = minutes;
    _applySafety();
    await _commit();
  }

  Future<void> setParentGate(bool on) async {
    _d.parentGateOn = on;
    await _commit();
  }

  /// 지금 놀이를 막고 있는 것 (놀이 시간 끝 / 눈 쉬기)
  PlayBlock get playBlock => play.block;

  int _savedPlaySeconds = 0;

  /// 1초마다 부른다 (덮개 위젯). 막는 상태가 바뀌면 화면에 알리고,
  /// 논 시간은 30초마다 저장한다.
  void tickPlay() {
    final changed = play.tick();
    _syncPlay(force: changed);
    if (changed) notifyListeners();
  }

  /// 앱이 뒤로 갔다 / 돌아왔다
  void pausePlay() {
    play.pause();
    _syncPlay(force: true);
  }

  void resumePlay() {
    if (play.resume()) notifyListeners();
    _syncPlay();
  }

  /// 부모 확인 뒤 15분 더 놀기
  Future<void> extendPlay() async {
    play.extend();
    _syncPlay(force: true);
    notifyListeners();
  }

  /// 오늘 논 기록을 저장값에 옮기고, 많이 바뀌었으면(또는 [force]) 저장한다.
  /// 화면 전체를 다시 그리지 않도록 알리지 않고 저장만 한다.
  void _syncPlay({bool force = false}) {
    final secs = play.used.inSeconds;
    final changed =
        _d.playDay != play.day || _d.playBonusMin != play.bonusMinutes;
    _d
      ..playDay = play.day
      ..playSeconds = secs
      ..playBonusMin = play.bonusMinutes;
    if (force || changed || (secs - _savedPlaySeconds).abs() >= 30) {
      _savedPlaySeconds = secs;
      unawaited(storage.save(_d));
    }
  }

  // ---------- 백업 ----------

  /// 다른 기기로 옮기는 'ALOK1-' 백업 글자
  String exportBackup() => BackupCode.encode(_d);

  /// 백업 글자로 복구한다. 잘못된 글자면 아무것도 바꾸지 않고 이유를 돌려준다.
  Future<BackupError?> restoreBackup(String text) async {
    final r = BackupCode.decode(text);
    final data = r.data;
    if (data == null) return r.error;
    // 이 기기에만 맞는 값(카메라 보정, 오늘 논 시간)은 지금 기기 것을 그대로 쓴다
    data
      ..eyeCalibration = _d.eyeCalibration
      ..playDay = _d.playDay
      ..playSeconds = _d.playSeconds
      ..playBonusMin = _d.playBonusMin;
    _d = data;
    _applyAudio();
    _applySafety();
    _applyEyeRunning();
    await _commit();
    return null;
  }

  /// 저장값의 눈 보호 켜짐/꺼짐에 맞춰 카메라를 켜거나 끈다
  void _applyEyeRunning() {
    eye.calibration = _d.eyeCalibration;
    if (_d.eyeGuardOn && eye.supported && !eye.running) {
      unawaited(eye.start());
    } else if (!_d.eyeGuardOn && eye.running) {
      unawaited(eye.stop());
    }
  }

  /// 부모용: 모든 진행 기록 지우기
  Future<void> resetAll() async {
    await storage.clear();
    _d = SaveData.initial();
    _applyAudio();
    _applySafety();
    _applyEyeRunning();
    await _commit();
  }
}
