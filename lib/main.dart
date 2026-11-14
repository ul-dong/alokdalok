import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'l10n/l10n.dart';
import 'services/audio_service.dart';
import 'services/device_heat.dart';
import 'services/game_state.dart';
import 'services/perf_monitor.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 렉·터치 진단 (설정 '부모님께'를 길게 누르면 보이는 칸): 프레임 시간과 최근 누름
  PerfMonitor.instance.start();

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
    // 기기 열·절전·배터리 (눈 지킴이 창 주기 백오프). 웹은 열 정보가 없다.
    unawaited(DeviceHeat.instance.bind());
  }

  final audio = DeviceAudio();
  final state = GameState(storage: PrefsStorage(), audio: audio);
  await state.load();
  // 녹음 팩·기기 음성을 처음부터 맞는 언어로 연다 (앱이 뜬 뒤에는 MaterialApp이 다시 알려 준다)
  state.applyLocale(
    AppLanguage.resolve(
      state.language,
      WidgetsBinding.instance.platformDispatcher.locales,
    ),
  );
  await audio.init();

  runApp(AlokdalokApp(state: state));
}
