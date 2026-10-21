import 'dart:convert';

import 'save_data.dart';

/// 백업 글자를 읽지 못한 이유
enum BackupError {
  /// 비어 있거나 'ALOK1-'로 시작하지 않는다
  notBackup,

  /// 글자가 빠졌거나 바뀌었다 (체크섬이 맞지 않음, 해독 불가)
  damaged,

  /// 더 새 버전 앱에서 만든 백업이다
  tooNew,
}

/// 백업 글자를 읽은 결과: [data] 또는 [error] 중 하나
class BackupResult {
  const BackupResult.ok(SaveData this.data) : error = null;
  const BackupResult.fail(BackupError this.error) : data = null;

  final SaveData? data;
  final BackupError? error;

  bool get ok => data != null;
}

/// 기기 사이 옮기기용 백업 글자. 서버 없이 복사·붙여 넣기로만 옮긴다.
///
/// 형식: `ALOK1-<본문>-<체크섬>`
/// - 본문: 저장값 JSON을 UTF-8 → base64url(끝의 `=` 없음)로 바꾼 것
/// - 체크섬: 본문 글자의 FNV-1a 32비트 해시 (16진수 8자리)
///
/// 이 기기에만 맞는 값(카메라 거리 보정, 오늘 논 시간)은 넣지 않는다.
class BackupCode {
  BackupCode._();

  static const prefix = 'ALOK1-';

  static String encode(SaveData data) {
    final json = data.toJson()
      ..remove('eyeCalibration')
      ..remove('playDay')
      ..remove('playSeconds')
      ..remove('playBonusMin');
    final body = base64Url
        .encode(utf8.encode(jsonEncode(json)))
        .replaceAll('=', '');
    return '$prefix$body-${checksum(body)}';
  }

  static BackupResult decode(String? text) {
    if (text == null) return const BackupResult.fail(BackupError.notBackup);
    // 메신저·메모장을 거치며 생긴 띄어쓰기·줄바꿈은 무시한다
    final s = text.replaceAll(RegExp(r'\s+'), '');
    if (!s.toUpperCase().startsWith(prefix)) {
      return const BackupResult.fail(BackupError.notBackup);
    }
    final rest = s.substring(prefix.length);
    final dash = rest.lastIndexOf('-');
    if (dash <= 0) return const BackupResult.fail(BackupError.damaged);
    final body = rest.substring(0, dash);
    final sum = rest.substring(dash + 1).toLowerCase();
    if (sum != checksum(body)) {
      return const BackupResult.fail(BackupError.damaged);
    }
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(base64Url.decode(_pad(body))));
    } catch (_) {
      return const BackupResult.fail(BackupError.damaged);
    }
    if (parsed is! Map) return const BackupResult.fail(BackupError.damaged);
    final json = Map<String, Object?>.from(parsed);
    final version = json['version'];
    if (version is! int || version < 0) {
      return const BackupResult.fail(BackupError.damaged);
    }
    if (version > SaveData.currentVersion) {
      return const BackupResult.fail(BackupError.tooNew);
    }
    return BackupResult.ok(SaveData.fromJson(SaveData.migrate(json)));
  }

  /// FNV-1a 32비트 (16진수 8자리). 웹(JS 숫자)에서도 같은 값이 나오도록
  /// 곱셈(× 0x01000193) 대신 자리 옮김의 합으로 계산한다.
  static String checksum(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = (h ^ c) & 0xffffffff;
      h =
          (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) &
          0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String _pad(String b) {
    final r = b.length % 4;
    return r == 0 ? b : b + '=' * (4 - r);
  }

  /// 부모님께 보여 줄 안내 문구
  static String message(BackupError e) => switch (e) {
    BackupError.notBackup => "백업 글자가 아니에요. 'ALOK1-'로 시작하는 글자를 붙여 넣어 주세요.",
    BackupError.damaged => '글자가 일부 빠졌거나 바뀌었어요. 처음부터 끝까지 다시 복사해 주세요.',
    BackupError.tooNew => '더 새 버전 앱에서 만든 백업이에요. 앱을 업데이트한 뒤 다시 해 주세요.',
  };
}
