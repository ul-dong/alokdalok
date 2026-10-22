import 'package:flutter/material.dart';

import 'core/app_theme.dart';
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
      child: MaterialApp(
        title: '알록달록 꼬마 놀이터',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // 글자 크기 설정이 너무 크면 버튼이 깨지므로 1.3배까지만 따른다
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
            ),
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
      ),
    );
  }
}

/// 처음 실행이면 닉네임 화면, 아니면 메인 화면
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  /// 화면이 바뀌는 페이드 길이 (softRoute와 같다)
  static const fadeDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // 첫 실행 화면이 끝나 홈으로 바뀔 때도 다른 화면 전환처럼 짧은 페이드로 (갑자기 바뀌지 않게)
    return AnimatedSwitcher(
      duration: RootGate.fadeDuration,
      child: state.nicknameChosen
          ? const HomeScreen(key: ValueKey('home'))
          : const ZodiacPickerScreen(
              key: ValueKey('onboarding'),
              onboarding: true,
            ),
    );
  }
}

/// 놀이 시간·눈 쉬기·눈 지킴이 덮개가 화면을 가리는 동안은 뒤 화면의 움직임(배경 장면,
/// 캐릭터 숨쉬기, 애니메이션)을 멈춘다. 안 보이는 장면을 계속 다시 그리지 않게 (발열 줄이기).
class _StillWhenCovered extends StatelessWidget {
  const _StillWhenCovered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return ListenableBuilder(
      listenable: Listenable.merge([state, state.eye]),
      builder: (context, child) => TickerMode(
        enabled:
            state.playBlock == PlayBlock.none &&
            state.eye.alert == EyeAlert.none,
        child: child!,
      ),
      child: child,
    );
  }
}
