import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/slow_clock.dart';
import 'l10n/l10n.dart';
import 'screens/zodiac_picker_screen.dart';
import 'screens/home_screen.dart';
import 'services/eye_guard.dart';
import 'services/game_state.dart';
import 'services/play_clock.dart';
import 'widgets/common.dart';
import 'widgets/eye_guard_overlay.dart';
import 'widgets/play_guard_overlay.dart';
import 'widgets/screen_fit.dart';

class AlokdalokApp extends StatelessWidget {
  const AlokdalokApp({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // 언어 설정(자동/한국어/English)이 바뀌면 앱 전체를 그 언어로 다시 그린다
      child: ValueListenableBuilder<String>(
        valueListenable: state.languageSetting,
        builder: (context, language, _) => _app(language),
      ),
    );
  }

  Widget _app(String language) => MaterialApp(
    onGenerateTitle: (context) => L10n.of(context).app_title,
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    // 'auto'면 기기(웹은 브라우저) 언어, 지원하지 않는 언어면 한국어
    locale: language == AppLanguage.auto ? null : Locale(language),
    supportedLocales: AppLanguage.supported,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    localeListResolutionCallback: (locales, _) =>
        AppLanguage.resolve(AppLanguage.auto, locales),
    // 글자 크기 설정이 너무 크면 버튼이 깨지므로 1.3배까지만 따른다
    builder: (context, child) {
      // 화면 밖 문장(놀이 문제)과 목소리도 같은 언어로
      state.applyLocale(Localizations.localeOf(context));
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
        // 가로 전용 앱: 세로 창이면 돌려 달라는 안내만 보여 준다
        child: mq.size.width < mq.size.height
            ? const RotateHint()
            // 높이 340 미만이면 화면 전체(덮개 포함)를 340 높이로 그려서 줄인다
            : MinHeightScaler(
                child: Stack(
                  children: [
                    _StillWhenCovered(child: child!),
                    // 놀이 시간 끝("오늘은 여기까지!")·눈 쉬기("창밖 먼 곳을 봐요") 덮개
                    const Positioned.fill(child: PlayGuardOverlay()),
                    // 화면이 너무 가깝거나 자세가 비뚤어지면 덮는 안내 (눈 지킴이)
                    const Positioned.fill(child: EyeGuardOverlay()),
                  ],
                ),
              ),
      );
    },
    home: const RootGate(),
  );
}

/// 처음 실행이면 닉네임 화면, 아니면 메인 화면
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  /// 화면이 바뀌는 페이드 길이 (softRoute와 같다)
  static const fadeDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // 눈 지킴이: 홈·첫 실행 화면과 그 위에 올라오는 아이 화면(놀이터·단계 고르기·내 캐릭터·상점·
    // 꾸미기·놀이·결과)에서 카메라를 켠다. 설정·부모 확인·멈춤 화면이 뜨면 끈다.
    return EyeWatch(
      kind: EyeScreen.child,
      child: AnimatedSwitcher(
        duration: RootGate.fadeDuration,
        child: state.nicknameChosen
            ? const HomeScreen(key: ValueKey('home'))
            : const ZodiacPickerScreen(
                key: ValueKey('onboarding'),
                onboarding: true,
              ),
      ),
    );
  }
}

/// 덮개(눈 지킴이 경고, 눈 쉬기, 쉬어 가기, "오늘은 여기까지!")가 화면을 가리는 동안은 밑단을 멈춘다.
/// 덮개는 완전히 불투명해서 아래가 안 보이므로 계속 그릴 이유가 없다 (발열 줄이기).
///
/// - 뒤 화면: TickerMode를 꺼서 Flame 장면(`SceneGame.frozen` → 엔진 멈춤, 한 장도 안 그림),
///   캐릭터 숨쉬기, 애니메이션을 멈춘다.
/// - 공용 20fps 시계(`SlowClock.held`)를 멈춘다 (덮개 위 장식도 함께 멈춤).
/// - 배경 음악(`AudioService.musicHeld`)을 멈춘다. 음성 안내는 그대로 나온다.
/// 덮개가 사라지면 모두 되돌린다.
class _StillWhenCovered extends StatefulWidget {
  const _StillWhenCovered({required this.child});
  final Widget child;

  /// 지금 덮개가 화면을 가리고 있는지
  static bool covered(GameState s) =>
      s.playBlock != PlayBlock.none || s.eye.alert != EyeAlert.none;

  @override
  State<_StillWhenCovered> createState() => _StillWhenCoveredState();
}

class _StillWhenCoveredState extends State<_StillWhenCovered> {
  GameState? _state;
  Listenable? _both;
  bool _covered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.read(context);
    if (identical(s, _state)) return;
    _both?.removeListener(_changed);
    _state = s;
    _both = Listenable.merge([s, s.eye])..addListener(_changed);
    _changed();
  }

  void _changed() {
    final s = _state;
    if (s == null) return;
    final c = _StillWhenCovered.covered(s);
    if (c == _covered) return;
    _hold(s, c);
    if (mounted) setState(() {});
  }

  void _hold(GameState s, bool on) {
    _covered = on;
    SlowClock.instance.held = on;
    s.audio.musicHeld = on;
  }

  @override
  void dispose() {
    _both?.removeListener(_changed);
    final s = _state;
    if (s != null && _covered) _hold(s, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: !_covered, child: widget.child);
}
