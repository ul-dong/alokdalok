// lib/ 안에 한국어 문자열이 남았는지 찾는다. 화면·말 문구는 ARB(lib/l10n/app_*.arb)나
// 문장 조립기(lib/l10n/<언어>/)로 옮겨야 다른 언어에서도 바뀐다.
// 한국어로 남아도 되는 곳은 아래 허용 목록에 이유와 함께 적는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 파일 전체를 허용 (이유)
const allowedFiles = {
  // 한국어 구현: 조사·수 세기·한국어 음성 문장 목록
  'lib/l10n/ko/': '한국어 문장 조립기와 한국어 음성 목록',
  // 언어 고르기에서 언어 이름은 그 언어로 쓴다 ("한국어")
  'lib/l10n/l10n.dart': '언어 이름(한국어)',
  // 한국어 원본 이름 자료. 다른 언어 이름은 lib/l10n/<언어>/ 문장 조립기가 id로 찾는다
  'lib/data/item_catalog.dart': '아이템 한국어 원본 이름',
  'lib/data/vehicles.dart': '탈것·물감 한국어 원본 이름',
  'lib/character/zodiac.dart': '친구 한국어 원본 이름',
  // 한국어 랜덤 이름, 기본 닉네임(저장값), 한글 비속어 거르기, 한글 허용 규칙
  'lib/character/nickname.dart': '한국어 이름 자료·비속어 거르기',
  // 부모님께 칸을 길게 누르면 열리는 개발 진단 칸 (한국어 전용)
  'lib/screens/settings_diagnostics.dart': '개발 진단 칸',
  // 진단 칸에만 보이는 값 (기기 열 이름, 누름 대상 이름)
  'lib/services/device_heat.dart': '진단 칸 값',
  'lib/services/perf_monitor.dart': '진단 칸 값',
};

/// 파일 안에서 이 문자열만 허용 (이유)
const allowedLiterals = {
  'lib/services/eye_guard.dart': {
    // offReason: 진단 칸에만 보이는 카메라 꺼진 이유
    '이 기기에서 쓸 수 없음', '기기가 뜨거움', '설정에서 꺼짐', r'오류: $error',
    '앱이 뒤에 있음', '쉬어 가기 중', '눈 쉬기, 오늘은 여기까지 덮개',
    '부모님 화면 (설정, 부모 확인)', '멈춤 화면', '아이 화면이 없음', '켜는 중',
  },
  // 진단 칸의 카메라 방식 이름과 개발 로그
  'lib/services/eye_sensor_io.dart': {
    '카메라 유지 (stopImageStream)',
    '창마다 끄기 (dispose)',
    r'눈 지킴이: ${sec.round()}초 동안 창 $_windows번, 카메라 프레임 $_frames장 ($mode)',
  },
  'lib/services/eye_sensor_web.dart': {
    '영상 멈춤 (video.pause)',
    '창마다 끄기 (스트림 종료)',
  },
  // 기기에 있는 한국어 목소리 이름(Chrome)을 찾는 말
  'lib/services/audio_service.dart': {'google 한국'},
};

final _hangul = RegExp('[가-힣]');

/// Dart 소스에서 주석을 빼고 문자열 글자만 꺼낸다 (줄 번호와 함께)
List<(int, String)> stringLiterals(String src) {
  final out = <(int, String)>[];
  var i = 0, line = 1;
  while (i < src.length) {
    final c = src[i];
    if (c == '\n') line++;
    if (src.startsWith('//', i)) {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      final stop = end < 0 ? src.length : end + 2;
      line += '\n'.allMatches(src.substring(i, stop)).length;
      i = stop;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final triple = src.startsWith(c * 3, i);
      final q = triple ? c * 3 : c;
      final start = i + q.length;
      var j = start;
      while (j < src.length && !src.startsWith(q, j)) {
        if (!raw && src[j] == r'\') j++;
        j++;
      }
      final text = src.substring(start, j.clamp(start, src.length));
      out.add((line, text));
      line += '\n'.allMatches(text).length;
      i = j + q.length;
      continue;
    }
    i++;
  }
  return out;
}

void main() {
  test('lib/ 안의 한국어 문자열은 ARB·문장 조립기·허용 목록에만 있다', () {
    final found = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((p) => !p.startsWith('lib/l10n/gen/'))
            .toList()
          ..sort();
    for (final path in files) {
      if (allowedFiles.keys.any((a) => path == a || path.startsWith(a))) {
        continue;
      }
      final allowed = allowedLiterals[path] ?? const <String>{};
      for (final (line, text) in stringLiterals(
        File(path).readAsStringSync(),
      )) {
        if (_hangul.hasMatch(text) && !allowed.contains(text)) {
          found.add('$path:$line  $text');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: '한국어 문자열이 남았어요. ARB로 옮기거나 허용 목록에 이유를 적어 주세요.',
    );
  });

  test('찾기 도구 자체 점검: 주석은 빼고 문자열만 찾는다', () {
    const src = '''
// '주석'
final a = '사과'; // '뒤 주석'
/* '막는 주석' */
final b = "r'원시'";
final c = r'원시 \$x';
''';
    final texts = [for (final (_, t) in stringLiterals(src)) t];
    expect(texts, ['사과', "r'원시'", '원시 \$x']);
  });

  test('허용 목록의 파일·문자열은 실제로 있다 (지운 뒤 남은 허용 없음)', () {
    for (final f in allowedFiles.keys) {
      final ok = f.endsWith('/')
          ? Directory(f).existsSync()
          : File(f).existsSync();
      expect(ok, isTrue, reason: f);
    }
    for (final e in allowedLiterals.entries) {
      final texts = {
        for (final (_, t) in stringLiterals(File(e.key).readAsStringSync())) t,
      };
      for (final lit in e.value) {
        expect(texts, contains(lit), reason: '${e.key}: $lit');
      }
    }
  });
}
