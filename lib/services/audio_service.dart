import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_lines.dart';
import 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio.dart';

/// 효과음 종류. 파일은 assets/audio/sfx/ 에 있고 tool/generate_sfx.py로 다시 만들 수 있다.
enum Sfx { correct, tryAgain, tap, coin, fanfare, buy, stamp }

extension SfxFile on Sfx {
  String get asset => switch (this) {
    Sfx.correct => 'audio/sfx/correct.wav',
    Sfx.tryAgain => 'audio/sfx/try_again.wav',
    Sfx.tap => 'audio/sfx/tap.wav',
    Sfx.coin => 'audio/sfx/coin.wav',
    Sfx.fanfare => 'audio/sfx/fanfare.wav',
    Sfx.buy => 'audio/sfx/buy.wav',
    Sfx.stamp => 'audio/sfx/stamp.wav',
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

  /// 한국어 음성 합성을 쓸 수 있는지 (기기·브라우저에 따라 다름)
  bool get voiceAvailable;

  Future<void> init();
  Future<void> play(Sfx sfx);
  Future<void> say(String text);
  Future<void> stopVoice();

  /// 배경 음악 켜기/끄기 (설정)
  bool _musicOn = true;
  bool get musicOn => _musicOn;
  set musicOn(bool v) {
    if (v == _musicOn) return;
    _musicOn = v;
    final t = currentTrack;
    if (t == null) return;
    v ? startMusic(t) : endMusic();
  }

  /// 화면마다 원하는 곡을 쌓아 둔다. 맨 위 화면의 곡이 나오고, 그 화면이 닫히면 아래 화면 곡으로 돌아간다.
  /// (메인 → 놀이 → 다시 메인이면 메인 음악이 다시 나온다)
  final List<(int, String)> _musicStack = [];
  int _musicOwner = 0;

  String? get currentTrack => _musicStack.isEmpty ? null : _musicStack.last.$2;

  /// 곡 이름: 'spring', 'summer', 'autumn', 'winter', 'home', 'shop'.
  /// 돌려주는 번호로 [stopMusic]을 부른다.
  int playMusic(String track) {
    final id = ++_musicOwner;
    _musicStack.add((id, track));
    if (musicOn) startMusic(track); // 이미 같은 곡이 나오고 있으면 그대로 둔다
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
    } else if (musicOn) {
      startMusic(t);
    }
  }

  @protected
  Future<void> startMusic(String track);
  @protected
  Future<void> endMusic();
}

/// 실제 기기용 구현.
/// - 효과음: audioplayers로 WAV 재생
/// - 음성: flutter_tts (Android TTS 엔진 / iOS AVSpeechSynthesizer / 웹 Web Speech API)
class DeviceAudio extends AudioService {
  final FlutterTts _tts = FlutterTts();
  final Map<Sfx, AudioPlayer> _players = {};
  bool _voiceAvailable = false;
  bool _initDone = false;

  /// 녹음 음성 팩 (assets/voice/). 없거나 비어 있으면 기기 음성만 쓴다.
  VoicePack? _pack;
  int _voiceToken = 0;
  final WebAudioEngine _web = WebAudioEngine();
  final AudioPlayer _music = AudioPlayer();
  static const double _musicVolume = .3;

  @override
  bool get voiceAvailable => _voiceAvailable || (_pack?.isEmpty == false);

  /// 녹음 목소리를 쓸 수 있는지
  bool get hasVoicePack => _pack?.isEmpty == false;

  Future<void> _loadPack() async {
    try {
      final raw = await rootBundle.loadString('assets/voice/manifest.json');
      final map = jsonDecode(raw);
      if (map is Map) {
        _pack = VoicePack({
          for (final e in map.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        });
      }
    } catch (e) {
      debugPrint('voice pack: $e');
    }
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
    await _loadPack();
    if (kIsWeb) {
      _web.init();
      final pack = _pack;
      if (pack != null && !pack.isEmpty) {
        // 놀이를 시작하기 전에 녹음 조각을 조금씩 미리 받아 둔다
        unawaited(_web.preload(pack.files.map(_voiceUrl).toList()));
      }
    } else {
      try {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setVolume(_musicVolume);
      } catch (_) {}
    }
    try {
      final available = await _tts.isLanguageAvailable('ko-KR');
      // 웹은 목소리 목록이 늦게 로드되어 false가 나올 수 있어 일단 시도한다
      _voiceAvailable = kIsWeb || available == true || available == 1;
      await _tts.setLanguage('ko-KR');
      await _pickFriendlyVoice();
      await _applyTone();
      await _tts.setVolume(0.85);
      await _tts.awaitSpeakCompletion(true); // say()가 말이 끝날 때 끝나도록
    } catch (e) {
      debugPrint('tts init: $e');
      _voiceAvailable = false;
    }
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

  /// 기기에 있는 한국어 목소리 중 부드러운 여성 목소리를 우선 고른다.
  Future<void> _pickFriendlyVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;
      final voices =
          [
                for (final v in raw)
                  if (v is Map)
                    {for (final e in v.entries) '${e.key}': '${e.value}'},
              ]
              .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('ko'))
              .toList();
      if (voices.isEmpty) return;
      voices.sort(
        (a, b) =>
            voiceScore(b['name'] ?? '').compareTo(voiceScore(a['name'] ?? '')),
      );
      final best = voices.first;
      await _tts.setVoice({'name': best['name']!, 'locale': best['locale']!});
      debugPrint('tts voice: ${best['name']}');
    } catch (e) {
      debugPrint('tts voice pick: $e');
    }
  }

  /// 목소리 이름으로 점수를 매긴다 (높을수록 우선). 테스트를 위해 공개.
  static int voiceScore(String name) {
    final n = name.toLowerCase();
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

  static String _voiceUrl(String file) => 'assets/assets/voice/$file';

  @override
  Future<void> say(String text) async {
    if (!voiceOn) return;
    final token = ++_voiceToken;
    final clips = voiceStyle == 'teacher' ? null : _pack?.plan(text);
    try {
      await _tts.stop();
    } catch (_) {}
    if (clips != null) {
      if (kIsWeb) {
        final ok = await _web.playClips(
          [for (final c in clips) _voiceUrl(c.file)],
          [for (final c in clips) c.pauseBefore.inMilliseconds / 1000],
        );
        if (ok) return;
      } else {
        await _playClipsNative(clips, token);
        return;
      }
    } else if (kIsWeb) {
      _web.stopVoice();
    }
    if (!_voiceAvailable || token != _voiceToken) return;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('tts speak: $e');
    }
  }

  /// 앱(안드로이드·iOS): 조각을 모두 먼저 불러온 뒤 차례로 틀어서 사이가 벌어지지 않게 한다.
  final List<AudioPlayer> _clipPlayers = [];

  Future<void> _playClipsNative(List<VoiceClip> clips, int token) async {
    await _disposeClipPlayers();
    final players = <AudioPlayer>[];
    try {
      for (final c in clips) {
        final p = AudioPlayer();
        players.add(p);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('voice/${c.file}'));
      }
      if (token != _voiceToken) return;
      _clipPlayers.addAll(players);
      await _music.setVolume(_musicVolume * .35);
      for (var i = 0; i < clips.length; i++) {
        if (token != _voiceToken) return;
        if (clips[i].pauseBefore > Duration.zero) {
          await Future<void>.delayed(clips[i].pauseBefore);
          if (token != _voiceToken) return;
        }
        final done = players[i].onPlayerComplete.first;
        await players[i].resume();
        await done.timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint('voice clips: $e');
    } finally {
      if (token == _voiceToken) {
        try {
          await _music.setVolume(_musicVolume);
        } catch (_) {}
      }
    }
  }

  Future<void> _disposeClipPlayers() async {
    final old = List.of(_clipPlayers);
    _clipPlayers.clear();
    for (final p in old) {
      try {
        await p.stop();
        await p.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> startMusic(String track) async {
    if (kIsWeb) {
      await _web.playMusic('assets/assets/audio/music/$track.mp3');
      return;
    }
    if (_nativeTrack == track) return;
    _nativeTrack = track;
    try {
      await _music.stop();
      await _music.setVolume(_musicVolume);
      await _music.play(AssetSource('audio/music/$track.mp3'));
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
    try {
      await _music.stop();
    } catch (_) {}
  }

  String? _nativeTrack;

  @override
  Future<void> stopVoice() async {
    _voiceToken++;
    _web.stopVoice();
    await _disposeClipPlayers();
    try {
      await _tts.stop();
    } catch (_) {}
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
