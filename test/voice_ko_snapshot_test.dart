// 한국어 녹음 조각 선택 스냅숏: 다국어 구조로 바꾸기 전 코드로 만든
// test/fixtures/voice_ko_snapshot.json 과 지금 결과가 완전히 같은지 본다.
// (어떤 문장이 어떤 mp3 조합·쉼으로 재생되는지, 놀이 문제 문장, 음성 문장 목록과 순서)
//
// 스냅숏을 다시 만들 때만: UPDATE_VOICE_SNAPSHOT=1 flutter test test/voice_ko_snapshot_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/game_kinds.dart';
import 'package:alokdalok/data/game_objects.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/common/korean_numbers.dart';
import 'package:alokdalok/games/match_game/match_round.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/shape_game/shape_round.dart';
import 'package:alokdalok/games/size_game/size_round.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = 'test/fixtures/voice_ko_snapshot.json';
const _manifest = 'assets/voice/manifest.json';

/// 놀이에서 실제로 만들어지는 문장 (단계마다 여러 씨앗으로 문제 5개씩)
List<String> roundLines() {
  final out = <String>[];
  for (var seed = 0; seed < 12; seed++) {
    for (final st in Stages.number) {
      final rng = Random(seed * 100 + st.id);
      NumberQuestion? prev;
      for (var i = 0; i < 5; i++) {
        final q = NumberQuestion.generate(st, rng, previous: prev);
        out
          ..add(q.label)
          ..add(q.prompt)
          ..add(q.answerLine)
          ..add(q.kind.sayName())
          ..add(q.kind.sayName(q.color));
        for (final o in q.scene) {
          out.add(o.kind.sayName(o.color));
        }
        prev = q;
      }
    }
    for (final st in Stages.color) {
      final rng = Random(seed * 100 + st.id);
      ColorQuestion? prev;
      for (var i = 0; i < 5; i++) {
        final q = ColorQuestion.generate(st, rng, previous: prev);
        out.add(q.prompt);
        prev = q;
      }
    }
    for (final st in Stages.shape) {
      final rng = Random(seed * 100 + st.id);
      ShapeQuestion? prev;
      for (var i = 0; i < 5; i++) {
        final q = ShapeQuestion.generate(st, rng, previous: prev);
        out
          ..add(q.prompt)
          ..add(q.praise);
        for (var c = 0; c < q.choices.length; c++) {
          out.add(q.wrongLine(c));
        }
        prev = q;
      }
    }
    for (final st in Stages.size) {
      final rng = Random(seed * 100 + st.id);
      SizeQuestion? prev;
      for (var i = 0; i < 5; i++) {
        final q = SizeQuestion.generate(st, rng, previous: prev);
        out
          ..add(q.prompt)
          ..add(q.wrongLine)
          ..add(q.praise)
          ..add(q.kind.sayName(q.color));
        prev = q;
      }
    }
    for (final st in Stages.match) {
      final rng = Random(seed * 100 + st.id);
      MatchBoard? prev;
      for (var i = 0; i < 3; i++) {
        final b = MatchBoard.generate(st, rng, previous: prev);
        out.add(MatchBoard.prompt);
        for (var c = 0; c < b.cards.length; c++) {
          out
            ..add(b.labelOf(c))
            ..add(b.pickedLine(c))
            ..add(b.wrongLine(c))
            ..add(b.matchedLine(c));
        }
        prev = b;
      }
    }
  }
  return out;
}

/// 그 밖에 코드가 조립하는 말
List<String> miscLines() => [
  for (var n = 1; n <= 10; n++) ...[
    KoreanNumbers.count(n),
    KoreanNumbers.countUpTo(n),
    KoreanNumbers.pieces(n),
    KoreanNumbers.pieces(n, '마리'),
  ],
  for (final k in ObjectKind.values) ...[
    k.ko,
    k.subject,
    k.topic,
    k.object,
    k.counter,
    k.sayName(),
    for (final c in [...GameColor.extended, GameColor.gray]) k.sayName(c),
  ],
  for (final c in [...GameColor.extended, GameColor.gray]) ...[
    c.name,
    c.adjective,
  ],
  for (final s in ShapeKind.values) ...[s.ko, s.object, s.thisIs],
  for (final a in SizeAsk.values) a.adjective,
  for (final z in Zodiac.values) z.hello,
  for (final g in GameKind.values) ...[g.invite, g.nameLine],
];

Map<String, Object?> build() {
  final manifest = (jsonDecode(File(_manifest).readAsStringSync()) as Map)
      .cast<String, String>();
  final pack = VoicePack(manifest);
  final lines = VoiceLines.all();
  final rounds = roundLines();
  final misc = miscLines();
  final texts = <String>{...manifest.keys, ...lines, ...rounds, ...misc};
  return {
    'lines': lines,
    'sentences': VoiceLines.sentences(),
    'rounds': rounds,
    'misc': misc,
    'plans': {
      for (final t in texts)
        t: pack
            .plan(t)
            ?.map((c) => '${c.file}+${c.pauseBefore.inMilliseconds}')
            .join(' '),
    },
  };
}

void main() {
  test('한국어 녹음 조각 선택이 다국어 구조 전과 완전히 같다', () {
    final now = build();
    final file = File(_fixture);
    if (Platform.environment['UPDATE_VOICE_SNAPSHOT'] == '1') {
      file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(now));
    }
    final before = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    for (final key in ['lines', 'sentences', 'rounds', 'misc']) {
      expect(now[key], before[key], reason: key);
    }
    final a = before['plans'] as Map<String, Object?>;
    final b = now['plans'] as Map<String, Object?>;
    expect(b.keys.toSet(), a.keys.toSet());
    var compared = 0, recorded = 0;
    for (final t in a.keys) {
      expect(b[t], a[t], reason: t);
      compared++;
      if (a[t] != null) recorded++;
    }
    // 녹음 문장 1044개 전부 + 놀이에서 만들어지는 문장
    expect(compared, greaterThanOrEqualTo(1044));
    expect(recorded, greaterThanOrEqualTo(1044));
  });
}
