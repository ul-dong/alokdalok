import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../core/palette.dart';
import '../services/eye_guard.dart';
import '../services/game_state.dart';
import '../services/play_clock.dart';
import 'common.dart';

/// 눈 지킴이 경고 화면. 화면이 너무 가깝거나 자세가 비뚤어지면 놀이 위를 덮어서 잠깐 멈추게 한다.
/// 바르게 하면 저절로 사라진다. 부모님은 "계속하기"를 길게 눌러 5분 동안 끌 수 있다.
class EyeGuardOverlay extends StatefulWidget {
  const EyeGuardOverlay({super.key});

  /// 음성 안내를 다시 들려주는 간격
  static const repeatEvery = Duration(seconds: 8);

  /// 한 번의 경고에서 음성 안내를 들려주는 최대 횟수 (처음 1번 + 다시 2번). 그 뒤로는 화면만 조용히.
  static const maxSpeaks = 3;

  @override
  State<EyeGuardOverlay> createState() => _EyeGuardOverlayState();
}

///
/// 카메라를 끄고 켜는 때도 여기서 알려 준다 (발열 줄이기):
/// 앱이 뒤로 가면 끄고, "오늘은 여기까지!"·눈 쉬기 덮개가 떠 있으면 끈다.
class _EyeGuardOverlayState extends State<EyeGuardOverlay>
    with WidgetsBindingObserver {
  EyeGuard? _eye;
  GameState? _state;
  EyeAlert _shown = EyeAlert.none;
  Timer? _repeat;

  /// 이번 경고에서 음성 안내를 들려준 횟수 (경고가 풀리면 0)
  int _spoken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  /// 화면을 누르면 눈 지킴이에게 알린다 (누른 직후에는 카메라 창을 미룬다)
  void _onPointer(PointerEvent e) {
    if (e is PointerDownEvent) _eye?.touched();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.read(context);
    if (!identical(state, _state)) {
      _state?.removeListener(_blockChanged);
      _state = state..addListener(_blockChanged);
    }
    final eye = state.eye;
    if (!identical(eye, _eye)) {
      _eye?.removeListener(_changed);
      _eye = eye..addListener(_changed);
      final life = WidgetsBinding.instance.lifecycleState;
      eye.setForeground(life == null || life == AppLifecycleState.resumed);
    }
    _blockChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final eye = _eye;
    if (eye == null) return;
    switch (s) {
      case AppLifecycleState.resumed:
        eye.setForeground(true);
      case AppLifecycleState.inactive:
        // 알림창을 내리는 등 잠깐일 수 있으니 조금 기다렸다가 끈다
        eye.setForeground(false);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // inactive를 거쳐 끄려고 기다리는 중이어도 기다리지 않고 바로 끈다
        eye.setForeground(false, immediate: true);
    }
  }

  void _blockChanged() {
    final state = _state;
    if (state == null) return;
    state.eye.blocked = state.playBlock != PlayBlock.none;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _state?.removeListener(_blockChanged);
    _eye?.removeListener(_changed);
    _repeat?.cancel();
    super.dispose();
  }

  void _changed() {
    final a = _eye!.alert;
    if (a == _shown) return;
    final state = AppScope.read(context);
    final was = _shown;
    setState(() => _shown = a);
    _repeat?.cancel();
    _repeat = null;
    if (a == EyeAlert.none) {
      _spoken = 0;
      // 쉬어 가기로 넘어간 것이면 그쪽 덮개가 안내한다
      if (was != EyeAlert.none && !_eye!.resting) {
        state.audio.say('잘했어요! 다시 놀아요.');
      }
      return;
    }
    // 8초마다 다시 들려주되, 한 번의 경고에서 최대 3번까지만 (그 뒤로는 화면만)
    bool speak() {
      if (_spoken >= EyeGuardOverlay.maxSpeaks) return false;
      _spoken++;
      state.audio.say(
        a == EyeAlert.tooClose
            ? '화면이 너무 가까워요. 조금 뒤로 가 볼까요?'
            : '바르게 앉아서 봐요. 화면을 똑바로 봐 주세요.',
      );
      return _spoken < EyeGuardOverlay.maxSpeaks;
    }

    if (!speak()) return;
    _repeat = Timer.periodic(EyeGuardOverlay.repeatEvery, (t) {
      if (!speak()) {
        t.cancel();
        if (identical(_repeat, t)) _repeat = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _shown;
    return IgnorePointer(
      ignoring: a == EyeAlert.none,
      child: AnimatedOpacity(
        opacity: a == EyeAlert.none ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: a == EyeAlert.none ? const SizedBox.expand() : _card(a),
      ),
    );
  }

  Widget _card(EyeAlert a) {
    final close = a == EyeAlert.tooClose;
    return Material(
      // 완전히 가린다 (아래 놀이 화면은 멈춰 있다)
      color: const Color(0xFFFFF6E5),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: LayoutBuilder(
                  builder: (context, c) => Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CharacterView(
                          equipped: AppScope.of(context).equipped,
                          size: (c.maxHeight / 1.25).clamp(80.0, 260.0),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            close
                                ? Icons.zoom_out_map_rounded
                                : Icons.accessibility_new_rounded,
                            size: 56,
                            color: Palette.coinDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FitBox(
                      child: Text(
                        close ? '화면이 너무 가까워요!' : '바르게 앉아서 봐요!',
                        style: const TextStyle(
                          fontSize: 44,
                          color: Palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FitBox(
                      child: Text(
                        close
                            ? '한 뼘 더 뒤로 가면 다시 놀 수 있어요'
                            : '화면을 똑바로 보면 다시 놀 수 있어요',
                        style: const TextStyle(
                          fontSize: 26,
                          color: Palette.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ParentContinue(onDone: () => _eye?.snooze()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아이가 실수로 누르지 않게 2초 동안 길게 눌러야 하는 "계속하기"
class _ParentContinue extends StatefulWidget {
  const _ParentContinue({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ParentContinue> createState() => _ParentContinueState();
}

class _ParentContinueState extends State<_ParentContinue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            widget.onDone();
            _c.value = 0;
          }
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp: (_) => _c.reverse(),
    onTapCancel: () => _c.reverse(),
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Palette.creamDeep, width: 2),
          gradient: LinearGradient(
            colors: [Palette.yellowSoft, Colors.white],
            stops: [_c.value, _c.value],
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          '부모님: 길게 눌러 계속하기',
          style: TextStyle(fontSize: TextSizes.body, color: Palette.textSoft),
        ),
      ),
    ),
  );
}

/// 눈 지킴이에게 "이 화면이 보인다"고 알려 준다 ([EyeGuard.showScreen]).
///
/// - [EyeScreen.child]: 아이 화면. 앱 맨 아래(홈·첫 실행 화면)에 하나 두면, 그 위에 올라오는
///   놀이터·단계 고르기·내 캐릭터·상점·꾸미기·놀이·결과 화면이 모두 아이 화면이 된다.
/// - [EyeScreen.parent]: 설정·부모 확인. 떠 있는 동안은 카메라를 끈다 (1초 기다렸다가).
class EyeWatch extends StatefulWidget {
  const EyeWatch({super.key, required this.kind, required this.child});

  final EyeScreen kind;
  final Widget child;

  @override
  State<EyeWatch> createState() => _EyeWatchState();
}

class _EyeWatchState extends State<EyeWatch> {
  EyeGuard? _eye;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final eye = AppScope.maybeRead(context)?.eye;
    if (identical(eye, _eye)) return;
    _eye?.hideScreen(this);
    _eye = eye?..showScreen(this, widget.kind);
  }

  @override
  void didUpdateWidget(EyeWatch old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _eye?.showScreen(this, widget.kind);
  }

  @override
  void dispose() {
    _eye?.hideScreen(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
