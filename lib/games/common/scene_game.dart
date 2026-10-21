import 'dart:async' as async;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/slow_clock.dart';

/// 계절 테마. 배경 색과 떨어지는 것(꽃잎·낙엽·눈)이 바뀐다.
enum Season { spring, summer, autumn, winter }

Season seasonOf(DateTime d) => switch (d.month) {
  3 || 4 || 5 => Season.spring,
  6 || 7 || 8 => Season.summer,
  9 || 10 || 11 => Season.autumn,
  _ => Season.winter,
};

/// 단계마다 계절이 바뀐다: 1단계 봄 → 2단계 여름 → 3단계 가을 → 4단계 겨울 → 5단계 다시 봄 …
Season seasonForStage(int stageId) => Season.values[(stageId - 1) % 4];

/// 계절 음악 파일 이름 (assets/audio/music/)
extension SeasonMusic on Season {
  String get track => name;

  String get ko => switch (this) {
    Season.spring => '봄',
    Season.summer => '여름',
    Season.autumn => '가을',
    Season.winter => '겨울',
  };
}

class SeasonLook {
  const SeasonLook({
    required this.skyTop,
    required this.skyBottom,
    required this.grass,
    required this.grassDeep,
    required this.flower,
    required this.falling,
    required this.island,
    required this.mountain,
    required this.sea,
    required this.seaDeep,
    required this.sand,
    required this.path,
    required this.blade,
    required this.tree,
  });

  final Color skyTop, skyBottom, grass, grassDeep, flower;

  /// 먼 섬, 먼 산, 바다, 모래, 길, 풀잎, 나뭇잎 색
  final Color island, mountain, sea, seaDeep, sand, path, blade, tree;

  /// 떨어지는 것 색 (null이면 없음)
  final Color? falling;

  static SeasonLook of(Season s) => switch (s) {
    Season.spring => const SeasonLook(
      skyTop: Palette.skyTop,
      skyBottom: Color(0xFFF1F8FD),
      grass: Palette.grass,
      grassDeep: Palette.grassDeep,
      flower: Color(0xFFF59AB5),
      falling: Color(0xFFF8B8CB),
      island: Color(0xFFD9C9EE),
      mountain: Color(0xFFCDE6C2),
      sea: Palette.sea,
      seaDeep: Palette.seaDeep,
      sand: Palette.sand,
      path: Color(0xFFF0DDB2),
      blade: Color(0xFF79B957),
      // 벚꽃
      tree: Color(0xFFF9C3D3),
    ),
    Season.summer => const SeasonLook(
      skyTop: Color(0xFF94D2F7),
      skyBottom: Color(0xFFE0F4FF),
      grass: Color(0xFF97D46E),
      grassDeep: Color(0xFF74BD55),
      flower: Color(0xFFFFD45C),
      falling: null,
      island: Color(0xFFA9D99A),
      mountain: Color(0xFFB4DFA3),
      sea: Color(0xFF7CC6EC),
      seaDeep: Color(0xFF4FAEDF),
      sand: Color(0xFFF6E2AE),
      path: Color(0xFFF2DDA8),
      blade: Color(0xFF5FA845),
      tree: Color(0xFF6DBE57),
    ),
    Season.autumn => const SeasonLook(
      skyTop: Color(0xFFC9E2F3),
      skyBottom: Color(0xFFFFEEDB),
      grass: Color(0xFFC9D98A),
      grassDeep: Color(0xFFB1C46E),
      flower: Color(0xFFFF9A5A),
      falling: Color(0xFFF2A35E),
      island: Color(0xFFE8C3A8),
      mountain: Color(0xFFF2C79A),
      sea: Color(0xFF8CC6E2),
      seaDeep: Color(0xFF6AAFD3),
      sand: Color(0xFFEFD9AC),
      path: Color(0xFFE9D2A2),
      blade: Color(0xFF9DAF55),
      tree: Color(0xFFF29A4E),
    ),
    Season.winter => const SeasonLook(
      skyTop: Color(0xFFCFE3F3),
      skyBottom: Color(0xFFF4F9FC),
      grass: Color(0xFFF7FAFC),
      grassDeep: Color(0xFFE4EDF4),
      flower: Color(0xFFBFD8EE),
      falling: Color(0xFFFFFFFF),
      island: Color(0xFFE8EEF7),
      mountain: Color(0xFFDDE7F2),
      sea: Color(0xFF9CC9E3),
      seaDeep: Color(0xFF7DB4D6),
      sand: Color(0xFFEDE6DA),
      path: Color(0xFFE3EAF2),
      blade: Color(0xFFC9D8E5),
      tree: Color(0xFF6FA88C),
    ),
  };
}

/// 모든 화면 뒤에 깔리는 Flame 배경 장면: 하늘, 해, 구름, 바다, 등대, 작은 집, 잔디, 새.
/// 움직임은 느리고 부드럽게만 (깜빡임·빠른 변화 없음).
class SceneGame extends FlameGame {
  SceneGame({
    this.season = Season.spring,
    this.groundLevel = .74,
    this.reduceMotion = false,
  });

  /// 기기 설정에서 '동작 줄이기'를 켰으면 떠다니는 장식(새, 꽃잎, 눈)을 넣지 않는다
  final bool reduceMotion;

  final Season season;

  /// 잔디가 시작되는 높이 (화면 높이 비율). 캐릭터가 서 있는 땅.
  final double groundLevel;

  SeasonLook get look => SeasonLook.of(season);
  final _rng = Random(7);

  // ---------- 발열 줄이기 ----------
  // 배경(구름·새·꽃잎)은 천천히 움직이므로 초당 20번만 그린다.
  // 정답 반짝이가 터질 때만 잠깐 초당 60번으로 부드럽게.
  // (모든 장식이 같은 시계(SlowClock)에 맞춰 한꺼번에 그려진다)
  final _clock = Stopwatch();
  int _lastUs = 0;
  bool _foreground = true;
  bool _onSlow = false;
  async.Timer? _fast;

  @override
  void onAttach() {
    super.onAttach();
    paused = true; // 기본 60fps 루프 대신 공용 느린 시계에 맞춰 한 장씩 그린다
    _clock
      ..reset()
      ..start();
    _lastUs = 0;
    if (!_onSlow) {
      SlowClock.instance.addListener(_tick);
      _onSlow = true;
    }
  }

  @override
  void onDetach() {
    if (_onSlow) {
      SlowClock.instance.removeListener(_tick);
      _onSlow = false;
    }
    _fast?.cancel();
    _fast = null;
    super.onDetach();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    _foreground = state == AppLifecycleState.resumed;
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds;
    final dt = (now - _lastUs) / 1e6;
    _lastUs = now;
    if (!_foreground || dt <= 0) return;
    stepEngine(stepTime: min(dt, .1));
  }

  /// 반짝이가 터지는 동안만 60fps로
  void _boostFrames() {
    _fast?.cancel();
    var left = 100; // 약 1.6초
    _fast = async.Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (--left <= 0 || !_onSlow) {
        t.cancel();
        return;
      }
      _tick();
    });
  }

  @override
  Color backgroundColor() => look.skyBottom;

  @override
  Future<void> onLoad() async {
    add(_Landscape(this));
    for (var i = 0; i < 3; i++) {
      add(_Cloud(this, i));
    }
    if (reduceMotion) return;
    add(_Bird(this, 0));
    add(_Bird(this, 1));
    if (look.falling != null) {
      for (var i = 0; i < 9; i++) {
        add(_Falling(this, _rng.nextDouble()));
      }
    }
  }

  /// 정답일 때 부드러운 반짝이 별을 터뜨린다. [at]은 화면 좌표 (없으면 가운데).
  void celebrate([Offset? at]) {
    if (!isLoaded) return;
    _boostFrames();
    final origin = at != null ? Vector2(at.dx, at.dy) : size / 2;
    const colors = [
      Color(0xFFFFD45C),
      Color(0xFFF59AB5),
      Color(0xFF8ED6B5),
      Color(0xFF9FD3F2),
      Color(0xFFFFFFFF),
    ];
    add(
      ParticleSystemComponent(
        position: origin,
        particle: Particle.generate(
          count: 22,
          lifespan: 1.2,
          generator: (i) {
            final a = _rng.nextDouble() * 2 * pi;
            final speed = 120 + _rng.nextDouble() * 160;
            final color = colors[i % colors.length];
            final r = 6 + _rng.nextDouble() * 7;
            return AcceleratedParticle(
              speed: Vector2(cos(a), sin(a) - .4) * speed,
              acceleration: Vector2(0, 260),
              child: ComputedParticle(
                renderer: (canvas, p) {
                  final alpha = (1 - p.progress).clamp(0.0, 1.0);
                  _drawStar(
                    canvas,
                    r * (1 - p.progress * .4),
                    color.withValues(alpha: alpha),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  static void _drawStar(Canvas c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * .48;
      i == 0
          ? p.moveTo(cos(a) * rr, sin(a) * rr)
          : p.lineTo(cos(a) * rr, sin(a) * rr);
    }
    c.drawPath(p..close(), Paint()..color = color);
  }
}

Paint _outline([double w = 3.5]) => Paint()
  ..color = Palette.outline
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

/// 움직이지 않는 풍경 (크기에 맞춰 다시 그림)
class _Landscape extends Component {
  _Landscape(this.game);
  final SceneGame game;
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    if (w <= 0 || h <= 0) return;
    final look = game.look;
    final season = game.season;
    final winter = season == Season.winter;
    final ground = h * game.groundLevel;
    final horizon = ground - h * .13;
    final u = unit(w, h); // 사물 크기 단위

    // 하늘
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon + 2),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [look.skyTop, look.skyBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );

    // 해 (천천히 숨쉬는 빛). 여름은 조금 더 크고 진하게.
    final sun = Offset(w * .16, h * .1);
    final glow = 1 + sin(_t * .8) * .04;
    final sunScale = season == Season.summer ? 1.15 : 1.0;
    canvas.drawCircle(
      sun,
      70 * u * glow * sunScale,
      Paint()..color = const Color(0x40FFF3B0),
    );
    canvas.drawCircle(
      sun,
      48 * u * glow * sunScale,
      Paint()..color = const Color(0x70FFF0A0),
    );
    canvas.drawCircle(
      sun,
      34 * u * sunScale,
      Paint()
        ..color = season == Season.summer
            ? const Color(0xFFFFE27A)
            : const Color(0xFFFFF1A6),
    );

    // 먼 산 (하늘이 넓은 화면을 채운다, 겨울은 눈 모자)
    _mountains(canvas, w, h, horizon, u, look, winter);

    // 먼 섬
    final island = Paint()..color = look.island;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .2, horizon + 2),
        width: w * .42,
        height: 40 * u,
      ),
      island,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .78, horizon + 2),
        width: w * .36,
        height: 34 * u,
      ),
      island,
    );

    // 바다
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, ground - horizon + 4),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [look.sea, look.seaDeep],
        ).createShader(Rect.fromLTWH(0, horizon, w, ground - horizon)),
    );
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final x = (w * (.1 + i * .21) + sin(_t * .6 + i) * 8 * u) % w;
      final y = horizon + (ground - horizon) * (.3 + (i % 3) * .2);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: 30 * u, height: 10 * u),
        pi * 1.1,
        pi * .8,
        false,
        wave,
      );
    }
    // 여름 바다의 작은 돛단배
    if (season == Season.summer) {
      _sailboat(canvas, Offset(w * .55, horizon + (ground - horizon) * .45), u);
    }

    // 모래사장
    final sand = Path()
      ..moveTo(0, ground - 16 * u)
      ..quadraticBezierTo(w * .5, ground - 34 * u, w, ground - 12 * u)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sand, Paint()..color = look.sand);

    // 등대 (오른쪽)
    _lighthouse(canvas, Offset(w * .86, ground - 6 * u), u, winter);
    // 작은 집 (왼쪽 뒤)
    _house(canvas, Offset(w * .2, ground - 10 * u), u, winter);
    // 계절 나무 (집 왼쪽, 넓은 화면은 가운데에도 한 그루)
    _tree(canvas, Offset(w * .065, ground - 2 * u), u * 1.05, look, season);
    if (w > 700) {
      _tree(canvas, Offset(w * .66, ground - 14 * u), u * .8, look, season);
    }

    // 잔디 언덕
    final grass = Path()
      ..moveTo(0, ground + 10 * u)
      ..quadraticBezierTo(w * .25, ground - 6 * u, w * .5, ground + 8 * u)
      ..quadraticBezierTo(w * .78, ground + 20 * u, w, ground + 2 * u)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(grass, Paint()..color = look.grass);

    // 계절 소품 (잔디 위 오른쪽)
    switch (season) {
      case Season.spring:
        break;
      case Season.summer:
        _parasol(canvas, Offset(w * .4, ground + 14 * u), u);
      case Season.autumn:
        _leafPile(canvas, Offset(w * .42, ground + 18 * u), u * 1.4);
      case Season.winter:
        _snowman(canvas, Offset(w * .42, ground + 18 * u), u * 1.3);
    }

    // 모래길 (겨울은 눈 덮인 길)
    final path = Path()
      ..moveTo(0, ground + 46 * u)
      ..quadraticBezierTo(w * .5, ground + 30 * u, w, ground + 50 * u)
      ..lineTo(w, ground + 92 * u)
      ..quadraticBezierTo(w * .5, ground + 72 * u, 0, ground + 88 * u)
      ..close();
    canvas.drawPath(path, Paint()..color = look.path);
    final dash = Paint()
      ..color = Color.lerp(look.path, Palette.outline, .18)!
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;
    for (var x = 20 * u; x < w; x += 46 * u) {
      final y = ground + 62 * u + sin(x / w * pi) * -8 * u;
      canvas.drawLine(Offset(x, y), Offset(x + 18 * u, y), dash);
    }

    // 아래 잔디
    canvas.drawRect(
      Rect.fromLTWH(0, ground + 86 * u, w, h),
      Paint()..color = look.grassDeep,
    );
    final blade = Paint()
      ..color = look.blade
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;
    for (var x = 8 * u; x < w; x += 22 * u) {
      final base = ground + 100 * u + (x * 7 % 13) * u;
      if (winter) {
        // 겨울: 풀잎 대신 작은 눈 더미
        if ((x / (22 * u)).round() % 3 == 0) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, base - 4 * u),
              width: 18 * u,
              height: 7 * u,
            ),
            Paint()..color = Colors.white,
          );
        }
        continue;
      }
      canvas.drawLine(Offset(x, base), Offset(x - 4 * u, base - 14 * u), blade);
      canvas.drawLine(
        Offset(x + 5 * u, base),
        Offset(x + 8 * u, base - 12 * u),
        blade,
      );
    }

    // 꽃 (봄은 튤립, 여름은 해바라기빛, 가을은 낙엽, 겨울은 없음)
    if (winter) return;
    for (final fx in [.08, .37, .63, .93]) {
      final o = Offset(w * fx, ground + 24 * u + (fx * 40 % 10) * u);
      // 꽃은 땅 사물보다 조금 크게 (작으면 점처럼 보인다)
      final fu = u * 1.5;
      if (season == Season.autumn) {
        _leaf(canvas, o, 6 * fu, look.flower, fx * 6);
        _leaf(canvas, o + Offset(10 * fu, 4 * fu), 5 * fu, look.tree, fx * 3);
        continue;
      }
      canvas.drawLine(
        o,
        o + Offset(0, 12 * fu),
        Paint()
          ..color = const Color(0xFF5DA05A)
          ..strokeWidth = 2.5 * fu,
      );
      if (season == Season.spring) {
        // 튤립: 세 갈래 꽃잎
        final t = Path()
          ..moveTo(o.dx - 6 * fu, o.dy - 6 * fu)
          ..lineTo(o.dx - 3 * fu, o.dy - 1 * fu)
          ..lineTo(o.dx, o.dy - 7 * fu)
          ..lineTo(o.dx + 3 * fu, o.dy - 1 * fu)
          ..lineTo(o.dx + 6 * fu, o.dy - 6 * fu)
          ..quadraticBezierTo(o.dx + 7 * fu, o.dy + 4 * fu, o.dx, o.dy + 4 * fu)
          ..quadraticBezierTo(
            o.dx - 7 * fu,
            o.dy + 4 * fu,
            o.dx - 6 * fu,
            o.dy - 6 * fu,
          )
          ..close();
        canvas.drawPath(
          t,
          Paint()..color = fx < .5 ? look.flower : const Color(0xFFF26B5E),
        );
        continue;
      }
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5;
        canvas.drawCircle(
          o + Offset(cos(a), sin(a)) * 5 * fu,
          4 * fu,
          Paint()..color = look.flower,
        );
      }
      canvas.drawCircle(o, 3 * fu, Paint()..color = const Color(0xFFB9824E));
    }
  }

  double unit(double w, double h) => min(w, h * .62) / 400;

  void _mountains(
    Canvas c,
    double w,
    double h,
    double horizon,
    double u,
    SeasonLook look,
    bool winter,
  ) {
    // 하늘이 넓을수록(키 큰 화면) 산이 조금 더 높다
    final peakH = max(40 * u, horizon * .32);
    final peaks = [(.06, .7), (.3, 1.0), (.52, .62), (.72, .9), (.95, .66)];
    final far = Path()..moveTo(0, horizon + 2);
    final shoulder = horizon - peakH * .25;
    for (final (x, hh) in peaks) {
      far.lineTo(w * (x - .1), shoulder);
      far.quadraticBezierTo(
        w * x,
        horizon - peakH * hh * 1.25,
        w * (x + .1),
        shoulder,
      );
    }
    far
      ..lineTo(w, horizon + 2)
      ..close();
    c.drawPath(far, Paint()..color = look.mountain.withValues(alpha: .75));
    if (winter) {
      // 산꼭대기 눈 모자
      c.save();
      c.clipPath(far);
      for (final (x, hh) in peaks) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * x, horizon - peakH * hh * .9),
            width: w * .13,
            height: peakH * hh * .42,
          ),
          Paint()..color = Colors.white,
        );
      }
      c.restore();
    }
  }

  void _tree(Canvas c, Offset base, double u, SeasonLook look, Season s) {
    final th = 120 * u;
    final trunk = RRect.fromRectAndRadius(
      Rect.fromLTWH(base.dx - th * .07, base.dy - th * .52, th * .14, th * .54),
      Radius.circular(th * .04),
    );
    c.drawRRect(trunk, Paint()..color = const Color(0xFFB98A5E));
    c.drawRRect(trunk, _outline(2.5 * u + .5));
    if (s == Season.winter) {
      // 겨울: 눈 덮인 뾰족한 소나무
      for (var i = 0; i < 3; i++) {
        final y = base.dy - th * (.38 + i * .2);
        final half = th * (.36 - i * .08);
        final tier = Path()
          ..moveTo(base.dx - half, y)
          ..lineTo(base.dx, y - th * .3)
          ..lineTo(base.dx + half, y)
          ..close();
        c.drawPath(tier, Paint()..color = look.tree);
        c.drawPath(tier, _outline(2.5 * u + .5));
        final snow = Path()
          ..moveTo(base.dx - half * .45, y - th * .17)
          ..lineTo(base.dx, y - th * .3)
          ..lineTo(base.dx + half * .45, y - th * .17)
          ..quadraticBezierTo(
            base.dx,
            y - th * .13,
            base.dx - half * .45,
            y - th * .17,
          )
          ..close();
        c.drawPath(snow, Paint()..color = Colors.white);
      }
      return;
    }
    final crown = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(base.dx, base.dy - th * .74),
          radius: th * .3,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(base.dx - th * .24, base.dy - th * .56),
          radius: th * .22,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(base.dx + th * .24, base.dy - th * .55),
          radius: th * .23,
        ),
      );
    // 동그라미 세 개를 합친 한 덩어리 (안쪽 겹친 선이 보이지 않게)
    final leaves = _union(crown);
    c.drawPath(leaves, Paint()..color = look.tree);
    c.drawPath(leaves, _outline(2.5 * u + .5));
    // 잎 무늬: 봄은 하얀 꽃송이, 여름은 빨간 열매, 가을은 진한 단풍 점
    final dot = switch (s) {
      Season.spring => Colors.white,
      Season.summer => const Color(0xFFF26B5E),
      _ => const Color(0xFFE0603A),
    };
    for (final o in const [
      Offset(-.1, -.82),
      Offset(.14, -.7),
      Offset(-.28, -.58),
      Offset(.3, -.52),
      Offset(.02, -.6),
    ]) {
      c.drawCircle(
        Offset(base.dx + o.dx * th, base.dy + o.dy * th),
        th * .035,
        Paint()..color = dot,
      );
    }
  }

  void _sailboat(Canvas c, Offset o, double u) {
    final hull = Path()
      ..moveTo(o.dx - 22 * u, o.dy)
      ..lineTo(o.dx + 22 * u, o.dy)
      ..lineTo(o.dx + 15 * u, o.dy + 9 * u)
      ..lineTo(o.dx - 15 * u, o.dy + 9 * u)
      ..close();
    c.drawPath(hull, Paint()..color = const Color(0xFFF26B5E));
    c.drawPath(hull, _outline(2.2 * u + .4));
    c.drawLine(o, o - Offset(0, 36 * u), _outline(2.2 * u + .4));
    final sail = Path()
      ..moveTo(o.dx + 2 * u, o.dy - 34 * u)
      ..lineTo(o.dx + 20 * u, o.dy - 4 * u)
      ..lineTo(o.dx + 2 * u, o.dy - 4 * u)
      ..close();
    c.drawPath(sail, Paint()..color = Colors.white);
    c.drawPath(sail, _outline(2.2 * u + .4));
  }

  void _parasol(Canvas c, Offset o, double u) {
    // 줄무늬 파라솔 + 비치볼
    c.drawLine(o, o - Offset(4 * u, 50 * u), _outline(3 * u + .5));
    final top = o - Offset(4 * u, 50 * u);
    final canopy = Path()
      ..moveTo(top.dx - 34 * u, top.dy + 12 * u)
      ..quadraticBezierTo(
        top.dx,
        top.dy - 22 * u,
        top.dx + 34 * u,
        top.dy + 12 * u,
      )
      ..close();
    c.drawPath(canopy, Paint()..color = const Color(0xFFFFCF4D));
    c.save();
    c.clipPath(canopy);
    for (var i = -1; i <= 1; i += 2) {
      final st = Path()
        ..moveTo(top.dx, top.dy - 14 * u)
        ..lineTo(top.dx + i * 10 * u, top.dy + 14 * u)
        ..lineTo(top.dx + i * 22 * u, top.dy + 14 * u)
        ..close();
      c.drawPath(st, Paint()..color = const Color(0xFFF26B5E));
    }
    c.restore();
    c.drawPath(canopy, _outline(2.5 * u + .5));
    final ball = o + Offset(24 * u, -6 * u);
    c.drawCircle(ball, 8 * u, Paint()..color = Colors.white);
    c.drawArc(
      Rect.fromCircle(center: ball, radius: 8 * u),
      -pi / 2,
      pi * .66,
      true,
      Paint()..color = const Color(0xFF6FB7E8),
    );
    c.drawArc(
      Rect.fromCircle(center: ball, radius: 8 * u),
      pi * .5,
      pi * .66,
      true,
      Paint()..color = const Color(0xFFF26B5E),
    );
    c.drawCircle(ball, 8 * u, _outline(2 * u + .4));
  }

  void _leaf(Canvas c, Offset o, double r, Color color, double turn) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(turn);
    final p = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r, 0, 0, r)
      ..quadraticBezierTo(-r, 0, 0, -r)
      ..close();
    c.drawPath(p, Paint()..color = color);
    c.restore();
  }

  void _leafPile(Canvas c, Offset o, double u) {
    const cols = [Color(0xFFF29A4E), Color(0xFFE0603A), Color(0xFFFFC75A)];
    c.drawOval(
      Rect.fromCenter(center: o, width: 60 * u, height: 18 * u),
      Paint()..color = const Color(0xFFE9A15A),
    );
    for (var i = 0; i < 9; i++) {
      _leaf(
        c,
        o + Offset((i - 4) * 6 * u, -4 * u - (i % 3) * 3 * u),
        6 * u,
        cols[i % 3],
        i * .9,
      );
    }
    // 작은 호박
    final p = o + Offset(36 * u, -4 * u);
    c.drawOval(
      Rect.fromCenter(center: p, width: 22 * u, height: 16 * u),
      Paint()..color = const Color(0xFFF2994A),
    );
    c.drawOval(
      Rect.fromCenter(center: p, width: 22 * u, height: 16 * u),
      _outline(2 * u + .4),
    );
    c.drawLine(
      p - Offset(0, 8 * u),
      p - Offset(-2 * u, 13 * u),
      _outline(2.5 * u + .4)..color = const Color(0xFF6B8E3E),
    );
  }

  void _snowman(Canvas c, Offset o, double u) {
    final body = o - Offset(0, 14 * u);
    final head = o - Offset(0, 38 * u);
    final white = Paint()..color = Colors.white;
    c.drawCircle(body, 17 * u, white);
    c.drawCircle(body, 17 * u, _outline(2.5 * u + .5));
    c.drawCircle(head, 12 * u, white);
    c.drawCircle(head, 12 * u, _outline(2.5 * u + .5));
    // 눈, 당근 코, 볼터치
    final eye = Paint()..color = Palette.outline;
    c.drawCircle(head + Offset(-4 * u, -2 * u), 1.6 * u, eye);
    c.drawCircle(head + Offset(4 * u, -2 * u), 1.6 * u, eye);
    final nose = Path()
      ..moveTo(head.dx - 1.5 * u, head.dy + 1 * u)
      ..lineTo(head.dx + 9 * u, head.dy + 3 * u)
      ..lineTo(head.dx - 1 * u, head.dy + 4 * u)
      ..close();
    c.drawPath(nose, Paint()..color = const Color(0xFFFF9A5A));
    c.drawCircle(
      head + Offset(-7 * u, 4 * u),
      2.4 * u,
      Paint()..color = Palette.catCheek.withValues(alpha: .7),
    );
    // 목도리
    final scarf = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: head + Offset(0, 11 * u),
        width: 26 * u,
        height: 6 * u,
      ),
      Radius.circular(3 * u),
    );
    c.drawRRect(scarf, Paint()..color = const Color(0xFFF26B5E));
    c.drawRRect(scarf, _outline(2 * u + .4));
    // 모자
    final hat = Rect.fromCenter(
      center: head - Offset(0, 13 * u),
      width: 14 * u,
      height: 9 * u,
    );
    c.drawRect(hat, Paint()..color = const Color(0xFF6FB7E8));
    c.drawRect(hat, _outline(2 * u + .4));
  }

  void _lighthouse(Canvas c, Offset base, double u, bool snow) {
    final bw = 42 * u, tw = 30 * u, ht = 120 * u;
    final tower = Path()
      ..moveTo(base.dx - bw / 2, base.dy)
      ..lineTo(base.dx - tw / 2, base.dy - ht)
      ..lineTo(base.dx + tw / 2, base.dy - ht)
      ..lineTo(base.dx + bw / 2, base.dy)
      ..close();
    c.drawPath(tower, Paint()..color = Colors.white);
    c.save();
    c.clipPath(tower);
    for (var i = 0; i < 3; i++) {
      c.drawRect(
        Rect.fromLTWH(
          base.dx - bw,
          base.dy - ht + ht * (.16 + i * .3),
          bw * 2,
          ht * .15,
        ),
        Paint()..color = const Color(0xFFEF7F7A),
      );
    }
    c.restore();
    c.drawPath(tower, _outline(3 * u + .5));
    final lamp = Rect.fromCenter(
      center: Offset(base.dx, base.dy - ht - 12 * u),
      width: tw * .9,
      height: 22 * u,
    );
    c.drawRect(lamp, Paint()..color = const Color(0xFFFFE89A));
    c.drawRect(lamp, _outline(3 * u + .5));
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(base.dx, base.dy - ht),
          width: tw * 1.5,
          height: 7 * u,
        ),
        Radius.circular(3 * u),
      ),
      Paint()..color = const Color(0xFF7A5A48),
    );
    final roof = Path()
      ..moveTo(base.dx - tw * .65, base.dy - ht - 23 * u)
      ..lineTo(base.dx, base.dy - ht - 44 * u)
      ..lineTo(base.dx + tw * .65, base.dy - ht - 23 * u)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFEF7F7A));
    c.drawPath(roof, _outline(3 * u + .5));
    if (snow) {
      final cap = Path()
        ..moveTo(base.dx - tw * .4, base.dy - ht - 30 * u)
        ..lineTo(base.dx, base.dy - ht - 44 * u)
        ..lineTo(base.dx + tw * .4, base.dy - ht - 30 * u)
        ..quadraticBezierTo(
          base.dx,
          base.dy - ht - 26 * u,
          base.dx - tw * .4,
          base.dy - ht - 30 * u,
        )
        ..close();
      c.drawPath(cap, Paint()..color = Colors.white);
    }
  }

  void _house(Canvas c, Offset base, double u, bool snow) {
    final body = Rect.fromLTWH(
      base.dx - 30 * u,
      base.dy - 46 * u,
      60 * u,
      46 * u,
    );
    c.drawRect(body, Paint()..color = Colors.white);
    c.drawRect(body, _outline(3 * u + .5));
    final roof = Path()
      ..moveTo(base.dx - 40 * u, base.dy - 44 * u)
      ..lineTo(base.dx, base.dy - 78 * u)
      ..lineTo(base.dx + 40 * u, base.dy - 44 * u)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF79A9E6));
    c.drawPath(roof, _outline(3 * u + .5));
    if (snow) {
      // 지붕 위 눈 (둥글게 흘러내린 모양)
      final cap = Path()
        ..moveTo(base.dx - 42 * u, base.dy - 44 * u)
        ..lineTo(base.dx, base.dy - 80 * u)
        ..lineTo(base.dx + 42 * u, base.dy - 44 * u)
        ..quadraticBezierTo(
          base.dx + 30 * u,
          base.dy - 50 * u,
          base.dx + 22 * u,
          base.dy - 52 * u,
        )
        ..quadraticBezierTo(
          base.dx,
          base.dy - 66 * u,
          base.dx - 22 * u,
          base.dy - 52 * u,
        )
        ..quadraticBezierTo(
          base.dx - 30 * u,
          base.dy - 48 * u,
          base.dx - 42 * u,
          base.dy - 44 * u,
        )
        ..close();
      c.drawPath(cap, Paint()..color = Colors.white);
      c.drawPath(cap, _outline(2 * u + .4));
    }
    final door = Rect.fromLTWH(
      base.dx + 6 * u,
      base.dy - 26 * u,
      14 * u,
      26 * u,
    );
    c.drawRect(door, Paint()..color = const Color(0xFF9A6A4E));
    c.drawRect(door, _outline(2.5 * u + .5));
    final win = Rect.fromLTWH(
      base.dx - 20 * u,
      base.dy - 34 * u,
      15 * u,
      13 * u,
    );
    c.drawRect(win, Paint()..color = const Color(0xFFFFE89A));
    c.drawRect(win, _outline(2.5 * u + .5));
  }
}

class _Cloud extends Component {
  _Cloud(this.game, this.index);
  final SceneGame game;
  final int index;
  double x = -1;

  @override
  void update(double dt) {
    final w = game.size.x;
    if (w <= 0) return;
    if (x < 0) x = w * (.15 + index * .35);
    x += dt * (8 + index * 3);
    if (x > w + 120) x = -120;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    if (w <= 0) return;
    final u = min(w, h * .62) / 400;
    final y = h * (.17 + (index % 2) * .1) + index * 6;
    final s = (index == 1 ? 1.3 : 1.0) * u;
    final p = Paint()..color = Colors.white.withValues(alpha: .95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 50 * s, y - 2 * s, 100 * s, 30 * s),
        Radius.circular(15 * s),
      ),
      p,
    );
    canvas.drawCircle(Offset(x - 16 * s, y), 22 * s, p);
    canvas.drawCircle(Offset(x + 16 * s, y - 6 * s), 26 * s, p);
  }
}

class _Bird extends Component {
  _Bird(this.game, this.index);
  final SceneGame game;
  final int index;
  double t = 0;

  @override
  void update(double dt) => t += dt;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;
    if (w <= 0) return;
    final u = min(w, h * .62) / 400;
    final x = (w * (.45 + index * .12) + t * 6) % (w + 60) - 30;
    final y = h * (.2 + index * .05) + sin(t * .7 + index) * 6;
    final flap = sin(t * 3 + index * 2) * 4 * u;
    final p = Path()
      ..moveTo(x - 14 * u, y + flap)
      ..quadraticBezierTo(x - 7 * u, y - 8 * u, x, y)
      ..quadraticBezierTo(x + 7 * u, y - 8 * u, x + 14 * u, y + flap);
    canvas.drawPath(p, _outline(2.5 * u + .5)..color = const Color(0xFF6E6A74));
  }
}

/// 꽃잎·낙엽·눈. 천천히 흔들리며 떨어진다.
class _Falling extends Component {
  _Falling(this.game, this.seed);
  final SceneGame game;
  final double seed;
  double y = -1;
  double t = 0;

  @override
  void update(double dt) {
    final h = game.size.y;
    if (h <= 0) return;
    t += dt;
    if (y < 0) y = h * seed;
    y += dt * (18 + seed * 14);
    if (y > h) y = -10;
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    if (w <= 0) return;
    final color = game.look.falling!;
    final x = w * ((seed * 7.3) % 1) + sin(t * .9 + seed * 6) * 18;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(sin(t + seed * 5) * .8);
    if (game.season == Season.winter) {
      canvas.drawCircle(Offset.zero, 4, Paint()..color = color);
    } else {
      canvas.drawOval(
        const Rect.fromLTWH(-6, -3.5, 12, 7),
        Paint()..color = color.withValues(alpha: .9),
      );
    }
    canvas.restore();
  }
}

/// 배경 장면 위젯
class SceneBackground extends StatefulWidget {
  const SceneBackground({
    super.key,
    this.season,
    this.groundLevel = .74,
    this.onReady,
  });

  /// null이면 기기 날짜의 계절
  final Season? season;
  final double groundLevel;
  final ValueChanged<SceneGame>? onReady;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends State<SceneBackground> {
  late SceneGame game = _make();

  SceneGame _make() => SceneGame(
    season: widget.season ?? seasonOf(DateTime.now()),
    groundLevel: widget.groundLevel,
    reduceMotion: WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations,
  );

  @override
  void initState() {
    super.initState();
    widget.onReady?.call(game);
  }

  @override
  void didUpdateWidget(SceneBackground old) {
    super.didUpdateWidget(old);
    if (old.season != widget.season || old.groundLevel != widget.groundLevel) {
      game = _make();
      widget.onReady?.call(game);
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(child: GameWidget(game: game)),
  );
}

/// 여러 동그라미로 만든 경로를 하나로 합친다 (겹친 안쪽 선 없이 외곽선만)
Path _union(Path p) {
  final parts = p
      .computeMetrics()
      .map((m) => m.extractPath(0, m.length))
      .toList();
  if (parts.isEmpty) return p;
  var out = parts.first..close();
  for (final q in parts.skip(1)) {
    out = Path.combine(PathOperation.union, out, q..close());
  }
  return out;
}
