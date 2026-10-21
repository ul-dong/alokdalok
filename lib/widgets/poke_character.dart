import 'dart:math';

import 'package:flutter/material.dart';

import '../character/zodiac.dart';
import '../core/slow_clock.dart';
import 'common.dart';

/// 캐릭터를 콕 눌렀을 때 하는 짧은 몸짓
enum PokeMotion {
  /// 폴짝 뛰기
  hop,

  /// 좌우로 흔들기
  wiggle,

  /// 몸을 쭉 늘렸다 줄이기
  stretch,
}

/// 캐릭터 그림을 감싸서, 누르면 한 번 짧게 움직이고 귀여운 소리를 낸다.
///
/// - 누를 때마다 [PokeMotion]이 폴짝 → 흔들 → 쭉 순서로 번갈아 나온다.
/// - 약 0.8초 동안 한 번만 움직이고 멈춘다 (계속 도는 움직임 없음).
///   움직임은 공용 20fps 시계([SlowClock])의 박자로만 그린다.
/// - 누를 때마다 `poke.wav`를 내고, 두 번에 한 번은 "안녕!", "나는 호랑이야!" 같은 짧은 말을 한다.
/// - 터치 칸은 감싼 그림 전체이고, 그림이 작아도 [minTouch] 이상으로 잡는다.
///   몸짓은 그림만 움직이고 터치 칸은 그대로라서 옆 버튼과 겹치지 않는다.
/// - 그림 코드(CharacterView)는 건드리지 않는다.
class PokeCharacter extends StatefulWidget {
  const PokeCharacter({
    super.key,
    required this.child,
    this.semanticLabel = '내 친구',
    this.zodiac,
    this.onPoke,
    this.talk = true,
  });

  /// 캐릭터 그림 (보통 CharacterView)
  final Widget child;
  final String semanticLabel;

  /// "나는 ○○야!"에 쓸 동물 (없으면 지금 고른 동물)
  final Zodiac? zodiac;

  /// 누를 때 더 할 일 (없어도 된다)
  final VoidCallback? onPoke;

  /// false면 말은 하지 않고 소리만 낸다
  final bool talk;

  /// 한 번 움직이는 시간
  static const duration = Duration(milliseconds: 800);

  /// 가장 작은 터치 칸 (사양: 60px 이상)
  static const minTouch = 60.0;

  /// 가끔 하는 짧은 말 (녹음 문장 목록에도 들어 있다). 동물 이름 인사는 [Zodiac.hello].
  static const lines = ['안녕!', '간지러워!', '같이 놀자!', '또 만져 줘!'];

  /// [n]번째(0부터) 누름의 몸짓
  static PokeMotion motionFor(int n) =>
      PokeMotion.values[n % PokeMotion.values.length];

  /// [n]번째(0부터) 누름에 하는 말. 두 번에 한 번만 말하고(null이면 소리만),
  /// 말할 때는 "안녕!" → "나는 ○○야!" → "간지러워!" → "같이 놀자!" → "또 만져 줘!" 순서로 돈다.
  static String? lineFor(int n, Zodiac zodiac) {
    if (n.isOdd) return null;
    final k = (n ~/ 2) % (lines.length + 1);
    if (k == 0) return lines[0];
    if (k == 1) return zodiac.hello;
    return lines[k - 1];
  }

  @override
  State<PokeCharacter> createState() => PokeCharacterState();
}

class PokeCharacterState extends State<PokeCharacter> {
  static final int _totalTicks =
      PokeCharacter.duration.inMilliseconds ~/
      SlowClock.interval.inMilliseconds;

  int _count = 0;
  PokeMotion _motion = PokeMotion.hop;

  /// 움직임이 시작된 뒤 지난 시계 박자 수 (-1이면 멈춰 있다)
  int _tick = -1;
  bool _listening = false;

  /// 지금 움직이는 중인지 (테스트 확인용)
  bool get moving => _tick >= 0;

  /// 지금(또는 마지막) 몸짓 (테스트 확인용)
  PokeMotion get motion => _motion;

  /// 지금까지 누른 횟수 (테스트 확인용)
  int get pokes => _count;

  void _listen(bool on) {
    if (on == _listening) return;
    _listening = on;
    on
        ? SlowClock.instance.addListener(_onClock)
        : SlowClock.instance.removeListener(_onClock);
  }

  void _onClock() {
    if (!mounted) return;
    setState(() {
      _tick++;
      if (_tick >= _totalTicks) {
        _tick = -1;
        _listen(false);
      }
    });
  }

  void _poke() {
    final state = AppScope.read(context);
    final n = _count++;
    state.audio.playPoke();
    if (widget.talk) {
      final line = PokeCharacter.lineFor(n, widget.zodiac ?? state.zodiac);
      if (line != null) state.audio.say(line);
    }
    widget.onPoke?.call();
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      _motion = PokeCharacter.motionFor(n);
      if (calm) return;
      _tick = 0;
      _listen(true);
    });
  }

  @override
  void dispose() {
    _listen(false);
    super.dispose();
  }

  /// 0..1 진행에서 위로 뛰는 높이 (그림 높이에 대한 비율, 폴짝 뛰기만)
  static double liftFor(PokeMotion m, double t) =>
      m == PokeMotion.hop ? .16 * sin(pi * t) : 0;

  /// 0..1 진행에 맞는 몸짓 변환 (그림 아래 가운데를 기준으로)
  static Matrix4 transformFor(PokeMotion m, double t) {
    switch (m) {
      case PokeMotion.hop:
        // 뛰기 전·내려앉을 때 살짝 눌린다
        final squash = t < .15
            ? 1 - .08 * sin(pi * t / .15)
            : (t > .85 ? 1 - .08 * sin(pi * (t - .85) / .15) : 1.0);
        return Matrix4.diagonal3Values(1 / squash, squash, 1);
      case PokeMotion.wiggle:
        // 좌우로 두 번 흔들고 점점 잦아든다
        return Matrix4.rotationZ(sin(t * 4 * pi) * .16 * (1 - t));
      case PokeMotion.stretch:
        // 위로 쭉 늘었다가 납작하게 줄어든 뒤 제자리
        final sy = 1 + .2 * sin(2 * pi * t) * (1 - .4 * t);
        return Matrix4.diagonal3Values(1 / sqrt(sy), sy, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = moving ? _tick / _totalTicks : 0.0;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _poke,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: PokeCharacter.minTouch,
            minHeight: PokeCharacter.minTouch,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            // 멈춰 있을 때도 같은 모양의 위젯 트리를 유지해서 캐릭터 상태가 새로 만들어지지 않게 한다
            child: FractionalTranslation(
              translation: Offset(0, moving ? -liftFor(_motion, t) : 0),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: moving
                    ? transformFor(_motion, t)
                    : Matrix4.identity(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
