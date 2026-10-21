// 녹음할 문장 목록을 tool/voice/lines.json 으로 내보낸다.
// 실행: flutter test tool/voice/export_lines_test.dart
//
// 이미 녹음한 문장은 assets/voice/manifest.json 의 파일 이름을 그대로 쓰고,
// 새 문장만 다음 번호를 받는다 (번호가 밀려서 엉뚱한 녹음이 나오지 않게).
import 'dart:convert';
import 'dart:io';

import 'package:alokdalok/services/voice_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export voice lines', () {
    final lines = VoiceLines.all();
    final manifestFile = File('assets/voice/manifest.json');
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
    File('tool/voice/lines.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(out),
    );
    expect(lines.toSet().length, lines.length);
    expect(out.map((e) => e['file']).toSet().length, out.length);
  });
}
