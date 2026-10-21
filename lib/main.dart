import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/audio_service.dart';
import 'services/game_state.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 번들 폰트(Jua, SIL OFL 1.1) 라이선스를 앱 라이선스 화면에 등록
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/licenses/Jua-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Jua font'], text);
  });

  // 가로 화면 전용 (아이가 화면을 가까이 들여다보지 않도록). 웹은 세로일 때 돌려 달라는 안내를 띄운다.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  final audio = DeviceAudio();
  final state = GameState(storage: PrefsStorage(), audio: audio);
  await Future.wait([state.load(), audio.init()]);

  runApp(AlokdalokApp(state: state));
}
