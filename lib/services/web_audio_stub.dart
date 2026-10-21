// 휴대폰·태블릿 앱에서는 Web Audio를 쓰지 않는다 (audioplayers로 재생).
class WebAudioEngine {
  bool get supported => false;
  bool get unlocked => false;
  void init() {}
  Future<void> preload(List<String> urls) async {}
  Future<bool> playClips(List<String> urls, List<double> pauses) async => false;
  void stopVoice({bool keepToken = false}) {}
  Future<void> playMusic(String url) async {}
  void stopMusic() {}
}
