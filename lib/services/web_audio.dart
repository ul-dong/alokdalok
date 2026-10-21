// 웹(특히 아이패드·아이폰 Safari)용 소리 엔진.
//
// Safari는 화면을 누른 직후가 아니면 <audio> 재생을 막아서, 녹음 조각을 하나씩 이어 틀면
// 두 번째 조각부터 막히거나 늦게 나왔다. Web Audio는 처음 한 번 터치로 "잠금 해제"하면
// 그 뒤로는 언제든 재생할 수 있고, 조각들을 정확한 시각에 예약해 끊김 없이 이어 붙일 수 있다.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class WebAudioEngine {
  web.AudioContext? _ctx;
  web.GainNode? _voiceGain;
  web.GainNode? _musicGain;
  final Map<String, Future<web.AudioBuffer?>> _cache = {};
  final List<web.AudioBufferSourceNode> _voiceNodes = [];
  web.AudioBufferSourceNode? _musicNode;
  web.GainNode? _trackGain; // 곡마다 따로: 부드럽게 커지고 작아지기
  String? _musicUrl;
  double? _musicLoop;
  final double _musicVolume = .32;
  bool _ducked = false;
  int _token = 0;
  Timer? _unduck;

  bool get supported => true;

  /// 첫 터치 때 오디오를 깨운다. 아이폰 무음 스위치와 상관없이 소리가 나게 한다(지원 기기만).
  void init() {
    try {
      final nav = web.window.navigator as JSObject;
      final session = nav.getProperty<JSAny?>('audioSession'.toJS);
      if (session != null) {
        (session as JSObject).setProperty('type'.toJS, 'playback'.toJS);
      }
    } catch (_) {}
    void unlock(web.Event _) => _unlock();
    for (final type in ['pointerdown', 'touchend', 'keydown', 'click']) {
      web.document.addEventListener(type, unlock.toJS, true.toJS);
    }
  }

  Future<void>? _resuming;

  /// 오디오 상자만 만든다 (소리 파일을 미리 풀어 두는 데 필요, 터치 없이도 가능)
  web.AudioContext _context() {
    var ctx = _ctx;
    if (ctx == null) {
      ctx = web.AudioContext();
      _ctx = ctx;
      _voiceGain = ctx.createGain()..connect(ctx.destination);
      _musicGain = ctx.createGain()..connect(ctx.destination);
      _musicGain!.gain.value = _musicVolume;
    }
    return ctx;
  }

  /// 터치할 때: 오디오를 깨운다. 깨어나면 기다리던 음악을 튼다.
  void _unlock() {
    final ctx = _context();
    if (ctx.state == 'running') return;
    // iOS: 터치 안에서 아주 짧은 무음을 한 번 틀어야 완전히 열린다
    try {
      final silent = ctx.createBuffer(1, 1, 22050);
      final src = ctx.createBufferSource()..buffer = silent;
      src.connect(ctx.destination);
      src.start();
    } catch (_) {}
    _resuming ??= ctx.resume().toDart.then((_) {
      _resuming = null;
      final want = _musicUrl;
      if (want != null && _musicNode == null) {
        _musicUrl = null;
        playMusic(want, loopSeconds: _musicLoop);
      }
    }, onError: (_) => _resuming = null);
  }

  /// 지금 바로 소리를 낼 수 있으면 true. 막 깨우는 중이면 잠깐 기다린다.
  Future<bool> _ready() async {
    final ctx = _context();
    if (ctx.state == 'running') return true;
    final r = _resuming;
    if (r != null) {
      try {
        await r.timeout(const Duration(milliseconds: 600));
      } catch (_) {}
    }
    return ctx.state == 'running';
  }

  bool get unlocked => _ctx != null && _ctx!.state == 'running';

  Future<web.AudioBuffer?> _load(String url) => _cache[url] ??= _fetch(url);

  Future<web.AudioBuffer?> _fetch(String url) async {
    try {
      final ctx = _context();
      final res = await web.window.fetch(url.toJS).toDart;
      if (!res.ok) return null;
      final bytes = await res.arrayBuffer().toDart;
      return await ctx.decodeAudioData(bytes).toDart;
    } catch (_) {
      _cache.remove(url);
      return null;
    }
  }

  /// 녹음 조각들을 미리 받아 둔다 (조금씩, 놀이를 방해하지 않게).
  Future<void> preload(List<String> urls) async {
    for (var i = 0; i < urls.length; i += 6) {
      await Future.wait(urls.skip(i).take(6).map(_load));
    }
  }

  /// 조각들을 [pauses] 간격으로 이어 재생한다. 하나라도 못 불러오면 false.
  Future<bool> playClips(List<String> urls, List<double> pauses) async {
    final token = ++_token;
    stopVoice(keepToken: true);
    final ctx = _context();
    // 아직 한 번도 터치하지 않아 소리가 잠겨 있으면 미뤄 두지 않고 건너뛴다
    // (미뤄 두면 한참 뒤 엉뚱한 때에 나온다)
    if (!await _ready()) return true;
    final buffers = await Future.wait(urls.map(_load));
    if (token != _token) return true; // 그 사이 다른 말이 시작됨
    if (buffers.any((b) => b == null)) return false;
    if (ctx.state != 'running') return true;
    var t = ctx.currentTime + .03;
    for (var i = 0; i < buffers.length; i++) {
      t += pauses[i];
      final src = ctx.createBufferSource()..buffer = buffers[i];
      src.connect(_voiceGain!);
      src.start(t);
      _voiceNodes.add(src);
      t += buffers[i]!.duration;
    }
    duck(true);
    _unduck?.cancel();
    final left = Duration(
      milliseconds: ((t - ctx.currentTime) * 1000).round() + 150,
    );
    _unduck = Timer(left, () => duck(false));
    // 말이 다 끝날 때까지 기다린다 (그래야 다음 화면이 말을 끊지 않는다)
    await Future<void>.delayed(left);
    return true;
  }

  void stopVoice({bool keepToken = false}) {
    if (!keepToken) {
      _token++;
      // 말을 멈추면 줄여 둔 음악도 바로 돌려놓는다
      _unduck?.cancel();
      if (_ducked) duck(false);
    }
    for (final n in _voiceNodes) {
      try {
        n.stop();
      } catch (_) {}
    }
    _voiceNodes.clear();
  }

  // ---------------- 배경 음악 ----------------

  /// [loopSeconds]: 곡 한 바퀴의 정확한 길이. MP3는 앞뒤에 아주 짧은 빈 소리가 붙을 수 있는데,
  /// 브라우저가 이것을 지우지 않으면 반복할 때마다 '툭' 끊긴다. 그럴 때만 반복 구간을 잘라 맞춘다.
  Future<void> playMusic(String url, {double? loopSeconds}) async {
    if (_musicUrl == url && _musicNode != null) return;
    stopMusic();
    _musicUrl = url;
    _musicLoop = loopSeconds;
    final ctx = _context();
    final buf = await _load(url);
    if (buf == null || _musicUrl != url) return;
    if (ctx.state != 'running') return; // 터치해서 깨어나면 그때 튼다 (_unlock)
    final src = ctx.createBufferSource()
      ..buffer = buf
      ..loop = true;
    if (loopSeconds != null) _fitLoop(src, buf, loopSeconds);
    final gain = ctx.createGain()..connect(_musicGain!);
    src.connect(gain);
    // 부드럽게 커지기 (목소리 때문에 줄이는 것은 _musicGain이 따로 맡는다)
    final now = ctx.currentTime;
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(1, now + 1.5);
    src.start();
    _musicNode = src;
    _trackGain = gain;
  }

  /// 디코딩된 곡이 원래 길이보다 길면(브라우저가 MP3 앞뒤의 빈 소리를 지우지 않은 경우),
  /// 앞의 빈 소리(LAME 표준: 인코더 576 + 디코더 529 = 1105샘플)를 건너뛰고 정확한 길이만 반복한다.
  static void _fitLoop(
    web.AudioBufferSourceNode src,
    web.AudioBuffer buf,
    double loopSeconds,
  ) {
    final extra = buf.duration - loopSeconds;
    if (extra < .002 || extra > .2) return;
    const mp3Delay = 1105 / 44100;
    final lead = extra >= mp3Delay ? mp3Delay : 0.0;
    src
      ..loopStart = lead
      ..loopEnd = lead + loopSeconds;
  }

  /// 음악을 부드럽게 줄이며 끈다 (곡을 바꿀 때도 앞 곡이 스르르 사라진다)
  void stopMusic() {
    _musicUrl = null;
    final node = _musicNode;
    final gain = _trackGain;
    _musicNode = null;
    _trackGain = null;
    if (node == null) return;
    final ctx = _ctx;
    if (ctx == null || gain == null || ctx.state != 'running') {
      try {
        node.stop();
      } catch (_) {}
      return;
    }
    final now = ctx.currentTime;
    final g = gain.gain;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value, now);
    g.linearRampToValueAtTime(0, now + .6);
    try {
      node.stop(now + .65);
    } catch (_) {}
  }

  double get _target => _ducked ? _musicVolume * .35 : _musicVolume;

  /// 말할 때는 음악을 작게 (녹음 조각은 자동, 기기 음성은 AudioService가 부른다)
  void duck(bool on) {
    _ducked = on;
    final ctx = _ctx;
    if (ctx == null || _musicGain == null) return;
    final g = _musicGain!.gain;
    final now = ctx.currentTime;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value, now);
    g.linearRampToValueAtTime(_target, now + (on ? .25 : .6));
  }
}
