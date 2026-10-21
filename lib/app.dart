import 'package:flutter/material.dart';

import 'core/palette.dart';
import 'screens/zodiac_picker_screen.dart';
import 'screens/home_screen.dart';
import 'services/game_state.dart';
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
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Jua',
          scaffoldBackgroundColor: Palette.skyBottom,
          // 화면 전환은 짧은 페이드 (눈이 피로한 미끄러짐·번쩍임 없이)
          pageTransitionsTheme: fadePageTransitions,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.pink,
            surface: Palette.cream,
          ),
          textTheme: const TextTheme().apply(
            bodyColor: Palette.text,
            displayColor: Palette.text,
          ),
        ),
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
                        child!,
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.nicknameChosen) {
      return const ZodiacPickerScreen(onboarding: true);
    }
    return const HomeScreen();
  }
}
