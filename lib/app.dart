import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/slow_clock.dart';
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
