// 음성 언어별 분리: assets/voice/<언어>/, 녹음이 없는 언어는 기기 음성(TTS)으로 자동 대체.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alokdalok/character/zodiac.dart';
import 'package:alokdalok/data/game_kinds.dart';
import 'package:alokdalok/data/item_catalog.dart';
import 'package:alokdalok/data/stages.dart';
import 'package:alokdalok/data/vehicles.dart';
import 'package:alokdalok/games/color_game/color_round.dart';
import 'package:alokdalok/games/match_game/match_round.dart';
import 'package:alokdalok/games/number_game/number_round.dart';
import 'package:alokdalok/games/shape_game/shape_round.dart';
import 'package:alokdalok/games/size_game/size_round.dart';
import 'package:alokdalok/l10n/l10n.dart';
import 'package:alokdalok/l10n/phrases.dart';
import 'package:alokdalok/services/audio_service.dart';
import 'package:alokdalok/services/game_state.dart';
import 'package:alokdalok/services/voice_lines.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// 말한 것만 적어 두는 기기 음성
class FakeTts implements SpeechEngine {
  String? language;
  final spoken = <String>[];
  bool available = true;

  @override
  Future<dynamic> isLanguageAvailable(String l) async => available;
  @override
  Future<dynamic> setLanguage(String l) async => language = l;
  @override
  Future<dynamic> get getVoices async => [
    {'name': 'Yuna', 'locale': 'ko-KR'},
    {'name': 'Samantha', 'locale': 'en-US'},
  ];
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {}
  @override
  Future<dynamic> setPitch(double pitch) async {}
  @override
  Future<dynamic> setSpeechRate(double rate) async {}
  @override
  Future<dynamic> setVolume(double volume) async {}
  @override
  Future<dynamic> awaitSpeakCompletion(bool on) async {}
  @override
  Future<dynamic> speak(String text) async => spoken.add(text);
  @override
  Future<dynamic> stop() async {}
}

/// 불러온 녹음 조각 경로만 적어 두는 플레이어
class FakeClip implements ClipPlayer {
  FakeClip(this.log);
  final List<String> log;

  @override
  Future<void> load(String asset) async => log.add(asset);
  @override
  Future<void> play() async {}
  @override
  Future<void> dispose() async {}
}

/// 파일이 하나도 없는 에셋 묶음 (manifest를 못 읽는 경우)
class EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('없음: $key');
}

Map<String, String> koManifest() => (jsonDecode(
  File('assets/voice/ko/manifest.json').readAsStringSync(),
) as Map).cast<String, String>();

/// [lines]를 다 녹음했다고 치고 만든 팩
VoicePack fakePack(List<String> lines) =>
    VoicePack({for (var i = 0; i < lines.length; i++) lines[i]: 'v$i.mp3'});

/// 지금 언어로 놀이에서 실제로 만들어지는 말
List<String> runtimeLines() {
  final p = Phrases.current;
  final out = <String>[];
  final rng = Random(7);
  for (var seed = 0; seed < 4; seed++) {
    for (final st in Stages.number) {
      NumberQuestion? prev;
      for (var i = 0; i < 5; i++) {
        final q = NumberQuestion.generate(st, rng, previous: prev);
        out
          ..add(q.prompt)
          ..add(q.answerLine)
          ..add(p.sayName(q.kind, q.color))
          ..add('${p.count(q.count)}, ${L10n.current.game_praiseSay}');
        prev = q;
      }
    }
    for (final st in Stages.color) {
      final q = ColorQuestion.generate(st, rng);
      out
        ..add(q.prompt)
        ..add(p.colorPraise(q.target.color));
      for (final c in q.choices) {
        if (c.color.id != q.target.color.id) {
          out.add(p.colorWrong(c.color, q.target.color));
        }
      }
    }
    for (final st in Stages.shape) {
      final q = ShapeQuestion.generate(st, rng);
      out
        ..add(q.prompt)
        ..add(q.praise)
        ..add(p.sayShape(q.shape));
      for (var c = 0; c < q.choices.length; c++) {
        if (c != q.answerIndex) out.add(q.wrongLine(c));
      }
    }
    for (final st in Stages.size) {
      final q = SizeQuestion.generate(st, rng);
      out
        ..add(q.prompt)
        ..add(q.wrongLine)
        ..add(p.sayName(q.kind, q.color));
    }
    for (final st in Stages.match) {
      final b = MatchBoard.generate(st, rng);
      for (var c = 0; c < b.cards.length; c++) {
        out
          ..add(b.pickedLine(c))
          ..add(b.wrongLine(c))
          ..add(b.matchedLine(c))
          ..add(b.finishedLine(c))
          ..add(p.exclaim(b.labelOf(c)));
      }
    }
  }
  final l = L10n.current;
  for (final name in p.randomNames) {
    out.add(l.nickname_greetSay(name));
  }
  for (final i in ItemCatalog.all) {
    out
      ..add(i.name)
      ..add(l.shop_boughtSay(i.name));
  }
  for (final v in Vehicles.all) {
    out
      ..add(v.name)
      ..add(l.shop_boughtSay(v.name));
  }
  for (final c in Vehicles.paints) {
    out
      ..add(c.name)
      ..add(p.paintedWith(c))
      ..add(p.paintNeedsCoinsAsk(c, Vehicles.paintPrice));
  }
  for (final z in Zodiac.values) {
    out.add(z.hello);
  }
  for (final g in GameKind.values) {
    out
      ..add(g.invite)
      ..add(g.nameLine);
  }
  return out;
}

/// ARB에서 말하는 문장([음성] 표시)의 값
List<String> spokenArbValues(String code) {
  final ko = jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync()) as Map;
  final arb =
      jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map;
  return [
    for (final k in ko.keys.whereType<String>())
      if (!k.startsWith('@') &&
          ((ko['@$k'] as Map?)?['description'] as String? ?? '').startsWith(
            '[음성]',
          ) &&
          !(arb[k] as String).contains('{'))
        arb[k] as String,
  ];
}

void main() {
  tearDown(() => L10n.use(AppLanguage.fallback));

  group('언어별 녹음 팩 자리', () {
    test('한국어 녹음은 assets/voice/ko, 영어는 빈 manifest만 있다', () {
      final ko = koManifest();
      expect(ko.length, greaterThanOrEqualTo(1044));
      for (final f in ko.values.toSet()) {
        expect(File('assets/voice/ko/$f').existsSync(), isTrue, reason: f);
      }
      // 예전 자리(assets/voice/*.mp3)에는 아무것도 남지 않았다
      expect(
        Directory('assets/voice')
            .listSync()
            .whereType<File>()
            .map((f) => f.path),
        isEmpty,
      );
      final en = jsonDecode(
        File('assets/voice/en/manifest.json').readAsStringSync(),
      ) as Map;
      expect(en, isEmpty, reason: '영어 음성은 아직 만들지 않는다');
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/voice/ko/'));
      expect(pubspec, contains('- assets/voice/en/'));
    });

    test('녹음 조각 경로는 언어 폴더를 담는다 (파일 이름 규칙 v0001은 그대로)', () {
      final pack = VoicePack(koManifest(), folder: VoicePack.folderOf('ko'));
      final clips = pack.plan('정말 잘했어요!')!;
      expect(clips.single.file, 'v0002.mp3');
      expect(clips.single.asset, 'voice/ko/v0002.mp3');
      expect(pack.assets.first, startsWith('voice/ko/v'));
    });

    testWidgets('앱 에셋에서 읽기: 한국어는 녹음 팩, 영어는 빈 팩', (t) async {
      final ko = await t.runAsync(
        () => DeviceAudio.loadVoicePack(rootBundle, 'ko'),
      );
      final en = await t.runAsync(
        () => DeviceAudio.loadVoicePack(rootBundle, 'en'),
      );
      expect(ko!.isEmpty, isFalse);
      expect(ko.folder, 'voice/ko');
      expect(en!.isEmpty, isTrue);
      expect(en.folder, 'voice/en');
    });

    test('manifest가 없거나 깨져도 빈 팩 (멈추지 않는다)', () async {
      final pack = await DeviceAudio.loadVoicePack(EmptyBundle(), 'fr');
      expect(pack.isEmpty, isTrue);
      expect(pack.plan('Bonjour'), isNull);
    });
  });

  test('웹 서비스 워커: 예전 앱이 찾는 옛 음성 경로를 ko 폴더로 돌려준다', () {
    final sw = File('web/offline_sw.js').readAsStringSync();
    final literal = RegExp(r'const LEGACY_VOICE = /(.+)/;').firstMatch(sw)![1]!;
    final legacy = RegExp(literal.replaceAll(r'\/', '/'));
    String? moved(String path) {
      final m = legacy.firstMatch(path);
      return m == null
          ? null
          : path.replaceFirst(legacy, '/assets/assets/voice/ko/${m[1]}');
    }

    expect(
      moved('/alokdalok/assets/assets/voice/v0001.mp3'),
      '/alokdalok/assets/assets/voice/ko/v0001.mp3',
    );
    expect(
      moved('/alokdalok/assets/assets/voice/manifest.json'),
      '/alokdalok/assets/assets/voice/ko/manifest.json',
    );
    expect(moved('/alokdalok/assets/assets/voice/ko/v0001.mp3'), isNull);
    expect(moved('/alokdalok/assets/assets/voice/en/manifest.json'), isNull);
    expect(sw, contains('legacyVoice(url)'));
  });

  group('녹음이 없으면 기기 음성(TTS)으로', () {
    test('route: 한국어 녹음 문장은 조각, 영어는 en-US 기기 음성', () {
      final ko = VoicePack(koManifest());
      final r1 = DeviceAudio.route(ko, '정말 잘했어요!', style: 'pack', locale: 'ko');
      expect(r1.usesTts, isFalse);
      final r2 = DeviceAudio.route(
        VoicePack(const {}, folder: 'voice/en'),
        'Great job!',
        style: 'pack',
        locale: 'en',
      );
      expect(r2.usesTts, isTrue);
      expect(r2.ttsLanguage, 'en-US');
      // 녹음이 없는 한국어 문장(아이 이름 등)은 한국어 기기 음성
      final r3 = DeviceAudio.route(ko, '김철수야', style: 'pack', locale: 'ko');
      expect(r3.usesTts, isTrue);
      expect(r3.ttsLanguage, 'ko-KR');
      // 기기 목소리를 고르면 녹음이 있어도 기기 음성
      expect(
        DeviceAudio.route(
          ko,
          '정말 잘했어요!',
          style: 'teacher',
          locale: 'ko',
        ).usesTts,
        isTrue,
      );
    });

    testWidgets('DeviceAudio: 한국어는 녹음 조각, 영어로 바꾸면 TTS(en-US)로 말한다', (t) async {
      final tts = FakeTts();
      final loaded = <String>[];
      final audio = DeviceAudio(tts: tts, clipPlayer: () => FakeClip(loaded));
      await t.runAsync(() async {
        await audio.prepareVoice();
        expect(tts.language, 'ko-KR');
        expect(audio.hasVoicePack, isTrue);
        await audio.say('정말 잘했어요!');
        expect(loaded, ['voice/ko/v0002.mp3']);
        expect(tts.spoken, isEmpty);

        // 녹음 없는 한국어 문장은 한국어 기기 음성
        await audio.say('보리야 안녕');
        expect(tts.spoken, ['보리야 안녕']);

        audio.locale = 'en';
        await audio.prepareVoice();
        expect(tts.language, 'en-US');
        expect(audio.hasVoicePack, isFalse);
        expect(audio.voiceAvailable, isTrue);
        loaded.clear();
        await audio.say('Great job!');
        expect(loaded, isEmpty, reason: '영어 녹음 조각은 없다');
        expect(tts.spoken.last, 'Great job!');

        // 다시 한국어로 오면 녹음 조각
        audio.locale = 'ko';
        await audio.prepareVoice();
        await audio.say('정말 잘했어요!');
        expect(loaded, ['voice/ko/v0002.mp3']);
      });
    });

    testWidgets('기기에 그 언어 음성이 없으면 voiceAvailable이 false (설정에 안내)', (t) async {
      final tts = FakeTts()..available = false;
      final audio = DeviceAudio(tts: tts, clipPlayer: () => FakeClip([]));
      audio.locale = 'en';
      await t.runAsync(audio.prepareVoice);
      expect(audio.voiceAvailable, isFalse);
    });

    test('영어 목소리 고르기: 부드러운 여성 목소리 우선', () {
      expect(
        DeviceAudio.voiceScore('Samantha', locale: 'en'),
        greaterThan(DeviceAudio.voiceScore('Fred', locale: 'en')),
      );
      expect(
        DeviceAudio.voiceScore('Microsoft Aria Online (Natural)', locale: 'en'),
        greaterThan(
          DeviceAudio.voiceScore('Microsoft Guy Online', locale: 'en'),
        ),
      );
    });
  });

  group('언어별 문장 목록', () {
    test('한국어 목록은 그대로 (기존 VoiceLines.all과 같다)', () {
      expect(VoiceLines.forLocale('ko'), VoiceLines.all());
      expect(VoiceLines.forLocale('xx'), VoiceLines.all());
    });

    test('영어 목록: 중복 없고 한글 없음', () {
      final en = VoiceLines.forLocale('en');
      expect(en.toSet().length, en.length);
      final hangul = RegExp('[가-힣]');
      for (final l in en) {
        expect(hangul.hasMatch(l), isFalse, reason: l);
      }
    });

    for (final code in VoiceLines.locales) {
      test('$code: 놀이·화면에서 하는 말은 모두 그 언어 목록으로 녹음할 수 있다', () {
        L10n.use(Locale(code));
        final pack = fakePack(VoiceLines.forLocale(code));
        final missing = <String>{
          for (final s in [...runtimeLines(), ...spokenArbValues(code)])
            if (pack.plan(s) == null) s,
        };
        expect(missing, isEmpty);
      });
    }
  });
}
