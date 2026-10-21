import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'save_data.dart';

/// 기기 내부 저장소. Android/iOS는 SharedPreferences(UserDefaults),
/// Web은 브라우저 localStorage에 저장된다. 서버 전송은 없다.
abstract class StorageService {
  Future<SaveData> load();
  Future<void> save(SaveData data);
  Future<void> clear();
}

class PrefsStorage implements StorageService {
  static const key = 'alokdalok_save';
  static const backupKey = 'alokdalok_save_backup';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// 값이 문자열이 아니게 손상된 경우(다른 형식으로 덮어씀 등) 예외 대신 null.
  String? _safeGet(SharedPreferences p, String k) {
    try {
      return p.getString(k);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SaveData> load() async {
    try {
      final p = await _p;
      final raw = _safeGet(p, key);
      if (raw != null && _parses(raw)) return SaveData.decode(raw);
      // 본 저장값이 없거나 읽을 수 없으면 직전 백업으로 시도
      final backup = _safeGet(p, backupKey);
      if (backup != null && _parses(backup)) return SaveData.decode(backup);
      return SaveData.initial();
    } catch (_) {
      // 저장소 자체를 열 수 없어도 앱은 기본값으로 시작한다
      return SaveData.initial();
    }
  }

  @override
  Future<void> save(SaveData data) async {
    try {
      final p = await _p;
      final current = _safeGet(p, key);
      if (current != null && _parses(current)) {
        await p.setString(backupKey, current);
      }
      await p.setString(key, data.encode());
    } catch (_) {
      // 저장 실패(저장 공간 부족 등)는 놀이를 막지 않는다
    }
  }

  @override
  Future<void> clear() async {
    final p = await _p;
    await p.remove(key);
    await p.remove(backupKey);
  }

  bool _parses(String raw) {
    try {
      return jsonDecode(raw) is Map;
    } catch (_) {
      return false;
    }
  }
}

/// 테스트용 메모리 저장소
class MemoryStorage implements StorageService {
  String? raw;

  @override
  Future<SaveData> load() async => SaveData.decode(raw);

  @override
  Future<void> save(SaveData data) async => raw = data.encode();

  @override
  Future<void> clear() async => raw = null;
}
