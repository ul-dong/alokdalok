// 녹음할 문장 목록을 tool/voice/lines_<언어>.json 으로 내보낸다.
// 실행: flutter test tool/voice/export_lines_test.dart                 (한국어)
//       VOICE_LOCALE=en flutter test tool/voice/export_lines_test.dart  (영어)
//       (또는 --dart-define=VOICE_LOCALE=en)
//
// 이미 녹음한 문장은 assets/voice/<언어>/manifest.json 의 파일 이름을 그대로 쓰고,
// 새 문장만 다음 번호를 받는다 (번호가 밀려서 엉뚱한 녹음이 나오지 않게).
import 'dart:convert';
import 'dart:io';

import 'package:alokdalok/services/voice_lines.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 내보낼 언어: --dart-define=VOICE_LOCALE, 없으면 환경 변수 VOICE_LOCALE, 없으면 ko
String voiceLocale() {
  const defined = String.fromEnvironment('VOICE_LOCALE');
  final v = defined.isNotEmpty
      ? defined
      : (Platform.environment['VOICE_LOCALE'] ?? 'ko');
  if (!VoiceLines.locales.contains(v)) {
    throw ArgumentError('VOICE_LOCALE=$v (가능: ${VoiceLines.locales})');
  }
  return v;
}

void main() {
  test('export voice lines', () {
    final locale = voiceLocale();
    final lines = VoiceLines.forLocale(locale);
    final manifestFile = File('assets/voice/$locale/manifest.json');
    final old = manifestFile.existsSync()
        ? (jsonDecode(manifestFile.readAsStringSync()) as Map)
              .cast<String, String>()
        : <String, String>{};
    var next = old.values
        .map((f) => int.tryParse(RegExp(r'(\d+)').firstMatch(f)?[1] ?? '') ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final out = [
      for (final text in lines)
        {
          'file': old[text] ?? 'v${(++next).toString().padLeft(4, '0')}.mp3',
          'text': text,
        },
    ];
    File('tool/voice/lines_$locale.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
    debugPrint('$locale: ${lines.length}문장 → tool/voice/lines_$locale.json');
    expect(lines.toSet().length, lines.length);
    expect(out.map((e) => e['file']).toSet().length, out.length);
  });
}
