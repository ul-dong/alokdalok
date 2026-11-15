import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_lines.dart';
import 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio.dart';

/// 효과음 종류. 파일은 assets/audio/sfx/ 에 있고 tool/generate_sfx.py로 다시 만들 수 있다.
enum Sfx { correct, tryAgain, tap, coin, fanfare, buy, stamp, poke }

extension SfxFile on Sfx {
  String get asset => switch (this) {
    Sfx.correct => 'audio/sfx/correct.wav',
    Sfx.tryAgain => 'audio/sfx/try_again.wav',
    Sfx.tap => 'audio/sfx/tap.wav',
    Sfx.coin => 'audio/sfx/coin.wav',
    Sfx.fanfare => 'audio/sfx/fanfare.wav',
    Sfx.buy => 'audio/sfx/buy.wav',
    Sfx.stamp => 'audio/sfx/stamp.wav',
    Sfx.poke => 'audio/sfx/poke.wav',
  };
}

/// 음성 안내와 효과음. 켜기/끄기는 GameState가 [voiceOn], [sfxOn]으로 넘겨준다.
abstract class AudioService {
  bool voiceOn = true;
  bool sfxOn = true;

  /// 'pack'(녹음 목소리, 기본) 또는 'teacher'(기기 목소리)
  String _voiceStyle = 'pack';
  String get voiceStyle => _voiceStyle;
  set voiceStyle(String v) {
    if (v == _voiceStyle) return;
    _voiceStyle = v;
    onVoiceStyleChanged();
  }

  /// 목소리 종류가 바뀌었을 때 (기기 구현에서 톤을 다시 맞춘다)
  void onVoiceStyleChanged() {}

  /// 말하는 언어 ('ko', 'en'). 앱이 화면 언어에 맞춰 바꾼다 (`GameState.applyLocale`).
  String _locale = 'ko';
  String get locale => _locale;
  set locale(String v) {
    if (v == _locale) return;
    _locale = v;
    onLocaleChanged();
  }

  /// 언어가 바뀌었을 때 (기기 구현에서 녹음 팩과 기기 음성 언어를 바꾼다)
  void onLocaleChanged() {}

  /// 한국어 음성 합성을 쓸 수 있는지 (기기·브라우저에 따라 다름)
  bool get voiceAvailable;

  Future<void> init();
  Future<void> play(Sfx sfx);
  Future<void> say(String text);
  Future<void> stopVoice();

  /// 지금 살아 있는 소리 플레이어 수 (설정 진단 칸: 계속 늘면 새는 것)
  AudioPlayerCounts get playerCounts => const AudioPlayerCounts();

  /// 캐릭터를 콕 눌렀을 때 나는 귀여운 소리 (assets/audio/sfx/poke.wav)
  Future<void> playPoke() => play(Sfx.poke);

  /// 배경 음악 켜기/끄기 (설정)
  bool _musicOn = true;
  bool get musicOn => _musicOn;
  set musicOn(bool v) {
    if (v == _musicOn) return;
    _musicOn = v;
    final t = currentTrack;
    if (t == null || _musicHeld) return;
    v ? startMusic(t) : endMusic();
  }

  /// 덮개(눈 지킴이 경고·눈 쉬기·쉬어 가기·오늘은 여기까지)가 화면을 가리는 동안 배경 음악을 멈춘다.
  /// 풀리면 지금 화면의 곡을 다시 튼다. 음성 안내와 효과음은 그대로 나온다.
  bool _musicHeld = false;
  bool get musicHeld => _musicHeld;
  set musicHeld(bool v) {
    if (v == _musicHeld) return;
    _musicHeld = v;
    final t = currentTrack;
    if (t == null || !musicOn) return;
    v ? endMusic() : startMusic(t);
  }

  /// 화면마다 원하는 곡을 쌓아 둔다. 맨 위 화면의 곡이 나오고, 그 화면이 닫히면 아래 화면 곡으로 돌아간다.
  /// (메인 → 놀이 → 다시 메인이면 메인 음악이 다시 나온다)
  final List<(int, String)> _musicStack = [];
  int _musicOwner = 0;

  String? get currentTrack => _musicStack.isEmpty ? null : _musicStack.last.$2;

  /// 곡 한 바퀴의 정확한 길이(초) = 16마디 × 4박 × 60 / BPM.
  /// tool/generate_music.py의 BPM과 같아야 한다. 웹에서 반복 이음매를 정확히 맞추는 데 쓴다.
  static const Map<String, double> musicLoopSeconds = {
    'spring': 3840 / 112,
    'summer': 3840 / 120,
    'autumn': 3840 / 96,
    'winter': 3840 / 104,
    'home': 3840 / 100,
    'shop': 3840 / 112,
  };

  /// 곡 이름: 'spring', 'summer', 'autumn', 'winter', 'home', 'shop'.
  /// 돌려주는 번호로 [stopMusic]을 부른다.
  int playMusic(String track) {
    final id = ++_musicOwner;
    _musicStack.add((id, track));
    // 이미 같은 곡이 나오고 있으면 그대로 둔다
    if (musicOn && !_musicHeld) startMusic(track);
    return id;
  }

  void stopMusic([int? owner]) {
    if (owner == null) {
      _musicStack.clear();
    } else {
      _musicStack.removeWhere((e) => e.$1 == owner);
    }
    final t = currentTrack;
    if (t == null) {
      endMusic();
    } else if (musicOn && !_musicHeld) {
      startMusic(t);
    }
  }

  @protected
  Future<void> startMusic(String track);
  @protected
  Future<void> endMusic();
}

/// 기기 음성 합성(TTS) 중 앱이 쓰는 부분 (앱은 flutter_tts, 테스트는 가짜)
abstract class SpeechEngine {
  Future<dynamic> isLanguageAvailable(String language);
  Future<dynamic> setLanguage(String language);
  Future<dynamic> get getVoices;
  Future<dynamic> setVoice(Map<String, String> voice);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setVolume(double volume);
  Future<dynamic> awaitSpeakCompletion(bool on);
  Future<dynamic> speak(String text);
  Future<dynamic> stop();
}

/// flutter_tts (Android TTS 엔진 / iOS AVSpeechSynthesizer / 웹 Web Speech API)
class FlutterTtsEngine implements SpeechEngine {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<dynamic> isLanguageAvailable(String language) =>
      _tts.isLanguageAvailable(language);
  @override
  Future<dynamic> setLanguage(String language) => _tts.setLanguage(language);
  @override
  Future<dynamic> get getVoices => _tts.getVoices;
  @override
  Future<dynamic> setVoice(Map<String, String> voice) => _tts.setVoice(voice);
  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);
  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);
  @override
  Future<dynamic> setVolume(double volume) => _tts.setVolume(volume);
  @override
  Future<dynamic> awaitSpeakCompletion(bool on) =>
      _tts.awaitSpeakCompletion(on);
  @override
  Future<dynamic> speak(String text) => _tts.speak(text);
  @override
  Future<dynamic> stop() => _tts.stop();
}

/// 말 하나를 내는 방법: 녹음 조각([clips]) 또는 기기 음성([ttsLanguage])
class SpeechRoute {
  const SpeechRoute({this.clips, required this.ttsLanguage});

  /// 녹음 조각 (없으면 기기 음성으로 말한다)
  final List<VoiceClip>? clips;

  /// 기기 음성 언어 (ko-KR, en-US)
  final String ttsLanguage;

  bool get usesTts => clips == null;
}

/// 실제 기기용 구현.
/// - 효과음: audioplayers로 WAV 재생
/// - 음성: 녹음 팩(assets/voice/<언어>/)이 있으면 녹음 조각, 없거나 그 문장이 없으면
///   기기 음성(TTS). 영어도 녹음 팩(assets/voice/en)이 있고, 녹음 없는 문장만 en-US 기기 음성.
class DeviceAudio extends AudioService {
  DeviceAudio({
    SpeechEngine? tts,
    ClipPlayer Function()? clipPlayer,
    AssetBundle? bundle,
  }) : _tts = tts ?? FlutterTtsEngine(),
       _bundle = bundle ?? rootBundle,
       _clips = ClipQueue(clipPlayer ?? _NativeClip.new);

  final SpeechEngine _tts;
  final AssetBundle _bundle;
  final Map<Sfx, AudioPlayer> _players = {};
  bool _voiceAvailable = false;
  bool _initDone = false;

  /// 지금 언어의 녹음 음성 팩 (assets/voice/<언어>/). 없거나 비어 있으면 기기 음성만 쓴다.
  VoicePack? _pack;
  int _voiceToken = 0;
  final WebAudioEngine _web = WebAudioEngine();

  /// 앱 배경 음악 플레이어 (쓸 때 만든다)
  late final AudioPlayer _music = AudioPlayer();
  static const double _musicVolume = .3;

  /// 목소리가 나올 때 음악을 이만큼으로 줄인다 (웹과 같다)
  static const double _duckRatio = .35;
  bool _ducked = false;
  double _musicLevel = 0;
  int _fadeToken = 0;

  double get _musicTarget => _musicVolume * (_ducked ? _duckRatio : 1);

  /// 앱: 음악 볼륨을 조금씩 바꿔 부드럽게 커지고 작아지게 한다. 새 페이드가 시작되면 앞의 것은 멈춘다.
  Future<void> _fadeMusicTo(double to, Duration d) async {
    final token = ++_fadeToken;
    final from = _musicLevel;
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(d ~/ steps);
      if (token != _fadeToken) return;
      _musicLevel = from + (to - from) * i / steps;
      try {
        await _music.setVolume(_musicLevel);
      } catch (_) {}
    }
  }

  /// 말하는 동안 음악 줄이기 (덕킹)
  void _duck(bool on) {
    if (_ducked == on) return;
    _ducked = on;
    if (kIsWeb) {
      _web.duck(on);
    } else if (_nativeTrack != null) {
      unawaited(
        _fadeMusicTo(_musicTarget, Duration(milliseconds: on ? 250 : 600)),
      );
    }
  }

  @override
  bool get voiceAvailable => _voiceAvailable || (_pack?.isEmpty == false);

  /// 녹음 목소리를 쓸 수 있는지
  bool get hasVoicePack => _pack?.isEmpty == false;

  /// 지금 언어의 녹음 팩 (테스트·진단용)
  VoicePack? get voicePack => _pack;

  /// 기기 음성 언어 이름 (ko → ko-KR, en → en-US)
  static String ttsLanguage(String locale) => switch (locale) {
    'en' => 'en-US',
    _ => 'ko-KR',
  };

  /// [locale] 언어의 녹음 팩을 읽는다 (assets/voice/<언어>/manifest.json).
  /// 파일이 없거나 비어 있거나 깨져 있으면 빈 팩 → 그 언어는 모두 기기 음성으로 말한다.
  static Future<VoicePack> loadVoicePack(
    AssetBundle bundle,
    String locale,
  ) async {
    final folder = VoicePack.folderOf(locale);
    try {
      final raw = await bundle.loadString(
        'assets/$folder/manifest.json',
        cache: false,
      );
      final map = jsonDecode(raw);
      if (map is Map) {
        return VoicePack({
          for (final e in map.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        }, folder: folder);
      }
    } catch (e) {
      debugPrint('voice pack $locale: $e');
    }
    return VoicePack(const {}, folder: folder);
  }

  /// 말 하나를 어떻게 낼지: 녹음 조각이 다 있으면 조각, 아니면 그 언어 기기 음성.
  /// ('teacher' 목소리를 고르면 녹음이 있어도 기기 음성)
  static SpeechRoute route(
    VoicePack? pack,
    String text, {
    required String style,
    required String locale,
  }) => SpeechRoute(
    clips: style == 'teacher' ? null : pack?.plan(text),
    ttsLanguage: ttsLanguage(locale),
  );

  /// 이 언어로 지금 말할 수 있게 준비한다: 녹음 팩을 읽고 기기 음성 언어·목소리를 맞춘다.
  /// (처음 [init]과 언어가 바뀔 때. 테스트는 init 대신 이것만 부른다)
  Future<void> prepareVoice() {
    final run = _prepared = _prepareVoice(locale);
    return run;
  }

  Future<void>? _prepared;

  /// 마지막 [prepareVoice]가 끝날 때 끝난다
  Future<void> get voiceReady => _prepared ?? Future<void>.value();

  Future<void> _prepareVoice(String forLocale) async {
    final pack = await loadVoicePack(_bundle, forLocale);
    if (forLocale != locale) return; // 그 사이 언어가 또 바뀌었다
    _pack = pack;
    if (kIsWeb && !pack.isEmpty) {
      // 놀이를 시작하기 전에 녹음 조각을 조금씩 미리 받아 둔다
      unawaited(_web.preload(pack.assets.map(_voiceUrl).toList()));
    }
    final lang = ttsLanguage(forLocale);
    try {
      final available = await _tts.isLanguageAvailable(lang);
      // 웹은 목소리 목록이 늦게 로드되어 false가 나올 수 있어 일단 시도한다
      _voiceAvailable = kIsWeb || available == true || available == 1;
      await _tts.setLanguage(lang);
      await _pickFriendlyVoice(forLocale);
      await _applyTone();
      await _tts.setVolume(0.85);
      await _tts.awaitSpeakCompletion(true); // say()가 말이 끝날 때 끝나도록
    } catch (e) {
      debugPrint('tts init: $e');
      _voiceAvailable = false;
    }
  }

  @override
  void onLocaleChanged() {
    if (!_initDone) return; // init이 지금 언어로 준비한다
    unawaited(stopVoice());
    unawaited(prepareVoice());
  }

  @override
  Future<void> init() async {
    if (_initDone) return;
    _initDone = true;
    try {
      // 효과음이 음성 안내를 끊지 않도록 함께 재생
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      debugPrint('audio context: $e');
    }
    if (kIsWeb) {
      _web.init();
    } else {
      try {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setVolume(0);
      } catch (_) {}
    }
    await prepareVoice();
  }

  /// 목소리 톤. 기기 음성 합성(TTS)은 음높이를 많이 올리면 기계음이 일그러져 오히려 무섭게
  /// 들린다. 그래서 'teacher'(기본 목소리)는 원래 음높이 그대로 조금 천천히,
  /// 'child'(밝은 목소리)는 아주 살짝만 올린다. 진짜 어린이 목소리는 녹음 파일이 필요하다.
  /// 플랫폼마다 속도 기준이 다르다 (웹 1.0 = 보통, 모바일 0.5 = 보통).
  static ({double pitch, double rate}) tone(
    String style, {
    required bool web,
  }) => switch (style) {
    'child' => (pitch: web ? 1.15 : 1.12, rate: web ? 0.95 : 0.47),
    _ => (pitch: 1.0, rate: web ? 0.9 : 0.44),
  };

  Future<void> _applyTone() async {
    final t = tone(voiceStyle, web: kIsWeb);
    await _tts.setPitch(t.pitch);
    await _tts.setSpeechRate(t.rate);
  }

  @override
  void onVoiceStyleChanged() {
    if (_initDone) _applyTone();
  }

  /// 기기에 있는 그 언어 목소리 중 부드러운 여성 목소리를 우선 고른다.
  Future<void> _pickFriendlyVoice(String forLocale) async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final voices =
          [
                for (final v in raw)
                  if (v is Map)
                    {for (final e in v.entries) '${e.key}': '${e.value}'},
              ]
              .where(
                (v) => (v['locale'] ?? '').toLowerCase().startsWith(forLocale),
              )
              .toList();
      if (voices.isEmpty) return;
      // 영어는 미국 영어(en-US) 목소리를 먼저
      int score(Map<String, String> v) =>
          voiceScore(v['name'] ?? '', locale: forLocale) +
          (forLocale == 'en' &&
                  (v['locale'] ?? '').toLowerCase().replaceAll('_', '-') ==
                      'en-us'
              ? 5
              : 0);
      voices.sort((a, b) => score(b).compareTo(score(a)));
      final best = voices.first;
      await _tts.setVoice({'name': best['name']!, 'locale': best['locale']!});
      debugPrint('tts voice: ${best['name']}');
    } catch (e) {
      debugPrint('tts voice pick: $e');
    }
  }

  /// 목소리 이름으로 점수를 매긴다 (높을수록 우선). 테스트를 위해 공개.
  static int voiceScore(String name, {String locale = 'ko'}) {
    final n = name.toLowerCase();
    if (locale == 'en') return _englishVoiceScore(n);
    const preferred = [
      'sunhi', // Edge 자연스러운 여성 음성
      'google 한국', 'google korean', // Chrome 여성 음성
      'yuna', // iOS/macOS 여성 음성
      'ko-kr-x-ism', 'ko-kr-x-kob', // Android Google 여성 음성
      'heami', // Windows 여성 음성
      'female', 'sora', 'jimin', 'seoyeon',
    ];
    const avoid = [
      'injoon',
      'hyunsu',
      'bongjin',
      'gookmin',
      'ko-kr-x-koc',
      'ko-kr-x-kod',
      'male',
    ];
    for (var i = 0; i < preferred.length; i++) {
      if (n.contains(preferred[i])) return 100 - i;
    }
    for (final a in avoid) {
      if (n.contains(a) && !n.contains('female')) return -10;
    }
    return n.contains('natural') || n.contains('neural') ? 20 : 0;
  }

  /// 영어 목소리: 부드러운 여성 목소리 우선
  static int _englishVoiceScore(String n) {
    const preferred = [
      'aria', 'jenny', 'ana', // Edge 자연스러운 여성 음성
      'google us english', // Chrome
      'samantha', // iOS/macOS
      'en-us-x-sfg', 'en-us-x-iob', 'en-us-x-tpc', // Android Google 여성 음성
      'zira', // Windows
      'female',
    ];
    const avoid = ['guy', 'david', 'mark', 'fred', 'en-us-x-iom', 'male'];
    for (var i = 0; i < preferred.length; i++) {
      if (n.contains(preferred[i])) return 100 - i;
    }
    for (final a in avoid) {
      if (n.contains(a) && !n.contains('female')) return -10;
    }
    return n.contains('natural') || n.contains('neural') ? 20 : 0;
  }

  @override
  AudioPlayerCounts get playerCounts => kIsWeb
      ? AudioPlayerCounts(
          sfx: _players.length,
          music: 0,
          clips: 0,
          webDecoded: _web.decodedCount,
          webFiles: _web.fileCount,
        )
      : AudioPlayerCounts(sfx: _players.length, music: 1, clips: _clips.alive);

  @override
  Future<void> play(Sfx sfx) async {
    if (!sfxOn) return;
    try {
      final player = _players[sfx] ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.setVolume(0.8);
      await player.play(AssetSource(sfx.asset));
    } catch (e) {
      debugPrint('sfx $sfx: $e');
    }
  }

  /// 웹: 녹음 조각 주소 (voice/ko/v0001.mp3 → assets/assets/voice/ko/v0001.mp3)
  static String _voiceUrl(String asset) => 'assets/assets/$asset';

  @override
  Future<void> say(String text) async {
    if (!voiceOn) return;
    final token = ++_voiceToken;
    final clips = route(_pack, text, style: voiceStyle, locale: locale).clips;
    try {
      await _tts.stop();
    } catch (_) {}
    if (clips != null) {
      if (kIsWeb) {
        final ok = await _web.playClips(
          [for (final c in clips) _voiceUrl(c.asset)],
          [for (final c in clips) c.pauseBefore.inMilliseconds / 1000],
        );
        if (ok) return;
      } else {
        await _clips.play(clips, duck: _duck);
        return;
      }
    } else if (kIsWeb) {
      _web.stopVoice();
    } else {
      await _clips.stop(); // 기기 음성으로 말하기 전에 녹음 조각을 멈춘다
    }
    if (!_voiceAvailable || token != _voiceToken) return;
    _duck(true);
    try {
      await _tts.speak(text); // 말이 끝날 때 끝난다 (awaitSpeakCompletion)
    } catch (e) {
      debugPrint('tts speak: $e');
    } finally {
      if (token == _voiceToken) _duck(false);
    }
  }

  /// 앱(안드로이드·iOS): 녹음 조각 플레이어 ([ClipQueue]가 만들고 반드시 정리한다)
  final ClipQueue _clips;

  @override
  Future<void> startMusic(String track) async {
    if (kIsWeb) {
      await _web.playMusic(
        'assets/assets/audio/music/$track.mp3',
        loopSeconds: AudioService.musicLoopSeconds[track],
      );
      return;
    }
    if (_nativeTrack == track) return;
    _nativeTrack = track;
    try {
      if (_musicLevel > 0) {
        // 앞 곡은 스르르 줄인 뒤 바꾼다
        await _fadeMusicTo(0, const Duration(milliseconds: 400));
        if (_nativeTrack != track) return;
      }
      _fadeToken++;
      _musicLevel = 0;
      await _music.stop();
      await _music.play(AssetSource('audio/music/$track.mp3'), volume: 0);
      if (_nativeTrack != track) return;
      unawaited(_fadeMusicTo(_musicTarget, const Duration(milliseconds: 1500)));
    } catch (e) {
      debugPrint('music: $e');
    }
  }

  @override
  Future<void> endMusic() async {
    if (kIsWeb) {
      _web.stopMusic();
      return;
    }
    _nativeTrack = null;
    if (_musicLevel > 0) {
      await _fadeMusicTo(0, const Duration(milliseconds: 600));
    }
    if (_nativeTrack != null) return; // 그 사이 다른 곡이 시작됨
    try {
      await _music.stop();
    } catch (_) {}
  }

  String? _nativeTrack;

  @override
  Future<void> stopVoice() async {
    _voiceToken++;
    _duck(false);
    _web.stopVoice();
    await _clips.stop();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// 살아 있는 소리 플레이어 수 ([AudioService.playerCounts])
class AudioPlayerCounts {
  const AudioPlayerCounts({
    this.sfx = 0,
    this.music = 0,
    this.clips = 0,
    this.webDecoded,
    this.webFiles,
  });

  /// 효과음 플레이어 (종류마다 하나씩, 최대 [Sfx.values] 개)
  final int sfx;

  /// 배경 음악 플레이어 (앱 1개)
  final int music;

  /// 녹음 조각 플레이어 (말하는 동안만, 말이 끝나면 0)
  final int clips;

  /// 웹: 풀어 둔 소리 수, 받아 둔 소리 파일 수
  final int? webDecoded, webFiles;

  int get total => sfx + music + clips;
}

/// 녹음 조각 하나를 트는 플레이어 (앱은 audioplayers, 테스트는 가짜)
abstract class ClipPlayer {
  /// 조각을 불러 둔다 (assets/ 아래 경로)
  Future<void> load(String asset);

  /// 틀고, 끝날 때까지 기다린다
  Future<void> play();

  /// 멈추고 놓는다 (네이티브 플레이어를 돌려준다)
  Future<void> dispose();
}

class _NativeClip implements ClipPlayer {
  final AudioPlayer _p = AudioPlayer();

  @override
  Future<void> load(String asset) async {
    await _p.setReleaseMode(ReleaseMode.stop);
    await _p.setSource(AssetSource(asset));
  }

  @override
  Future<void> play() async {
    final done = _p.onPlayerComplete.first;
    await _p.resume();
    await done;
  }

  @override
  Future<void> dispose() async {
    try {
      await _p.stop();
    } catch (_) {}
    await _p.dispose();
  }
}

/// 녹음 조각들을 모두 먼저 불러온 뒤 차례로 틀어서 사이가 벌어지지 않게 한다 (앱).
///
/// 플레이어는 말 하나마다 만들고, 말이 끝나거나 다음 말이 시작되거나 멈추면 반드시 놓는다.
/// (예전에는 앞의 말이 아직 조각을 불러오는 중에 다음 말이 시작되면 그 플레이어들을 아무도
/// 놓지 않아서 네이티브 플레이어가 쌓였다: 캐릭터를 연달아 콕콕 누르거나 화면을 빨리 넘길 때.)
class ClipQueue {
  ClipQueue(this._create);
  final ClipPlayer Function() _create;
  final Set<ClipPlayer> _live = {};
  int _token = 0;

  /// 지금 살아 있는 조각 플레이어 수
  int get alive => _live.length;

  /// 한 조각이 끝나기를 이만큼까지만 기다린다
  static const clipTimeout = Duration(seconds: 8);

  /// 앞의 말을 멈추고 [clips]를 차례로 튼다. 다른 말이 시작되거나 [stop]하면 그만둔다.
  /// [duck]은 트는 동안 음악을 줄이고(true) 끝나면 돌려놓는다(false).
  Future<void> play(
    List<VoiceClip> clips, {
    void Function(bool on)? duck,
  }) async {
    final token = ++_token;
    bool current() => token == _token;
    await _release(_live.toList());
    final mine = <ClipPlayer>[];
    var ducked = false;
    try {
      for (final c in clips) {
        if (!current()) return;
        final p = _create();
        _live.add(p);
        mine.add(p);
        await p.load(c.asset);
      }
      if (!current()) return;
      duck?.call(ducked = true);
      for (var i = 0; i < clips.length; i++) {
        if (!current()) return;
        if (clips[i].pauseBefore > Duration.zero) {
          await Future<void>.delayed(clips[i].pauseBefore);
          if (!current()) return;
        }
        await mine[i].play().timeout(clipTimeout);
      }
    } catch (e) {
      debugPrint('voice clips: $e');
    } finally {
      if (ducked && current()) duck?.call(false);
      await _release(mine);
    }
  }

  /// 지금 말을 멈추고 플레이어를 모두 놓는다
  Future<void> stop() async {
    _token++;
    await _release(_live.toList());
  }

  Future<void> _release(List<ClipPlayer> players) async {
    for (final p in players) {
      if (!_live.remove(p)) continue; // 이미 놓았다
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

/// 테스트용: 무엇을 재생했는지 기록만 한다.
class RecordingAudio extends AudioService {
  final List<Sfx> played = [];
  final List<String> spoken = [];

  @override
  bool get voiceAvailable => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> play(Sfx sfx) async {
    if (sfxOn) played.add(sfx);
  }

  @override
  Future<void> say(String text) async {
    if (voiceOn) spoken.add(text);
  }

  @override
  Future<void> stopVoice() async {}

  /// 지금 나오는 곡 (테스트 확인용)
  String? music;

  @override
  Future<void> startMusic(String track) async => music = track;

  @override
  Future<void> endMusic() async => music = null;
}
