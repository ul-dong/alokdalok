import '../l10n/en/voice_lines_en.dart';
import '../l10n/ko/voice_lines_ko.dart';

/// 녹음 음성 팩에 들어가는 문장 목록 (언어별).
///
/// - 한국어: lib/l10n/ko/voice_lines_ko.dart → assets/voice/ko (MeloTTS로 녹음함)
/// - 영어: lib/l10n/en/voice_lines_en.dart → assets/voice/en (아직 녹음 없음, 기기 음성으로 읽는다)
///
/// 목록 내보내기: `VOICE_LOCALE=en flutter test tool/voice/export_lines_test.dart`,
/// 녹음: `tool/gen_voice.command en`. 녹음이 없는 문장은 기기 음성(TTS)으로 말한다.
class VoiceLines {
  VoiceLines._();

  /// 녹음 팩이 있는(또는 만들 수 있는) 언어
  static const locales = ['ko', 'en'];

  /// [locale] 언어의 전체 목록 (중복 없음, 순서 고정)
  static List<String> forLocale(String locale) => switch (locale) {
    'en' => EnVoiceLines.all(),
    _ => KoVoiceLines.all(),
  };

  /// 한국어 전체 목록 (예전 이름 그대로)
  static List<String> all() => KoVoiceLines.all();

  /// 한국어 놀이 문제 통문장
  static List<String> sentences() => KoVoiceLines.sentences();

  /// 통째로 쓰는 한국어 문장
  static List<String> get fixed => KoVoiceLines.fixed;
}

/// 녹음 음성 팩: 문장 → 파일 목록. 문장을 앞에서부터 가장 긴 조각으로 맞춰 나간다.
class VoicePack {
  /// [files]: 문장 → 파일 이름 (manifest.json). [folder]: 파일이 있는 곳 (assets/ 아래)
  VoicePack(Map<String, String> files, {this.folder = defaultFolder})
    : _files = files {
    _maxLen = files.keys.fold(0, (m, k) => k.length > m ? k.length : m);
  }

  /// 한국어 녹음 팩 자리
  static const defaultFolder = 'voice/ko';

  /// [locale] 언어 녹음 팩 자리: voice/ko, voice/en
  static String folderOf(String locale) => 'voice/$locale';

  final Map<String, String> _files;

  /// 녹음 파일이 있는 곳 (assets/ 아래, 예: voice/ko)
  final String folder;
  late final int _maxLen;

  bool get isEmpty => _files.isEmpty;

  /// 모든 녹음 파일 이름
  Iterable<String> get files => _files.values.toSet();

  /// 모든 녹음 파일 경로 (assets/ 아래, 예: voice/ko/v0001.mp3)
  Iterable<String> get assets => files.map((f) => '$folder/$f');

  /// 조각 사이 쉼: 한 문장 안은 짧게, 문장이 끝난 뒤(. ! ?)는 숨 쉬듯, 쉼표 뒤는 숫자 세기 박자
  static const shortPause = Duration(milliseconds: 60);
  static const sentencePause = Duration(milliseconds: 280);
  static const commaPause = Duration(milliseconds: 380);

  static bool _endsSentence(String s) =>
      s.endsWith('.') || s.endsWith('!') || s.endsWith('?');

  /// [text]를 녹음 조각으로 나눈다. 하나라도 녹음이 없으면 null (기기 음성으로 말한다).
  List<VoiceClip>? plan(String text) {
    if (_files.isEmpty) return null;
    final clips = <VoiceClip>[];
    var i = 0;
    var comma = false;
    String? prev;
    while (true) {
      // 조각 사이의 띄어쓰기·쉼표는 건너뛴다
      while (i < text.length && (text[i] == ' ' || text[i] == ',')) {
        if (text[i] == ',') comma = true;
        i++;
      }
      if (i >= text.length) break;
      String? hit;
      final end = (i + _maxLen).clamp(0, text.length);
      for (var j = end; j > i; j--) {
        final key = text.substring(i, j);
        if (_files.containsKey(key)) {
          // 단어 중간에서 끊기지 않게: 조각 뒤는 끝이거나 띄어쓰기/쉼표여야 한다
          if (j == text.length || text[j] == ' ' || text[j] == ',') {
            hit = key;
            break;
          }
        }
      }
      if (hit == null) return null;
      clips.add(
        VoiceClip(
          _files[hit]!,
          folder: folder,
          pauseBefore: clips.isEmpty
              ? Duration.zero
              : comma
              ? commaPause
              : (_endsSentence(prev!) ? sentencePause : shortPause),
        ),
      );
      prev = hit;
      comma = false;
      i += hit.length;
    }
    return clips.isEmpty ? null : clips;
  }
}

class VoiceClip {
  const VoiceClip(
    this.file, {
    this.pauseBefore = Duration.zero,
    this.folder = VoicePack.defaultFolder,
  });

  /// 파일 이름 (v0001.mp3)
  final String file;
  final Duration pauseBefore;

  /// 파일이 있는 곳 (voice/ko)
  final String folder;

  /// assets/ 아래 경로 (voice/ko/v0001.mp3)
  String get asset => '$folder/$file';
}
