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
  });

  final Color skyTop, skyBottom, grass, grassDeep, flower;

  /// 떨어지는 것 색 (null이면 없음)
  final Color? falling;

  static SeasonLook of(Season s) => switch (s) {
    Season.spring => const SeasonLook(
      skyTop: Palette.skyTop,
      skyBottom: Palette.skyBottom,
      grass: Palette.grass,
      grassDeep: Palette.grassDeep,
      flower: Color(0xFFF59AB5),
      falling: Color(0xFFF8B8CB),
    ),
    Season.summer => const SeasonLook(
      skyTop: Color(0xFFA9DBF8),
      skyBottom: Color(0xFFE2F5FF),
      grass: Color(0xFF97D46E),
      grassDeep: Color(0xFF74BD55),
      flower: Color(0xFFFFD45C),
      falling: null,
    ),
    Season.autumn => const SeasonLook(
      skyTop: Color(0xFFCFE6F5),
      skyBottom: Color(0xFFFFF1DE),
      grass: Color(0xFFBFD77E),
      grassDeep: Color(0xFFA6C267),
      flower: Color(0xFFFF9A5A),
      falling: Color(0xFFF2A35E),
    ),
    Season.winter => const SeasonLook(
      skyTop: Color(0xFFD5E8F5),
      skyBottom: Color(0xFFF4F9FC),
      grass: Color(0xFFF3F7FA),
      grassDeep: Color(0xFFDDE8F0),
      flower: Color(0xFFBFD8EE),
      falling: Color(0xFFFFFFFF),
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
    final ground = h * game.groundLevel;
    final horizon = ground - h * .13;
    final u = min(w, h * .62) / 400; // 사물 크기 단위

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

    // 해 (천천히 숨쉬는 빛)
    final sun = Offset(w * .16, h * .1);
    final glow = 1 + sin(_t * .8) * .04;
    canvas.drawCircle(
      sun,
      70 * u * glow,
      Paint()..color = const Color(0x40FFF3B0),
    );
    canvas.drawCircle(
      sun,
      48 * u * glow,
      Paint()..color = const Color(0x70FFF0A0),
    );
    canvas.drawCircle(sun, 34 * u, Paint()..color = const Color(0xFFFFF1A6));

    // 먼 섬
    final island = Paint()..color = Palette.lavender.withValues(alpha: .8);
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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.sea, Palette.seaDeep],
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

    // 모래사장
    final sand = Path()
      ..moveTo(0, ground - 16 * u)
      ..quadraticBezierTo(w * .5, ground - 34 * u, w, ground - 12 * u)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sand, Paint()..color = Palette.sand);

    // 등대 (오른쪽)
    _lighthouse(canvas, Offset(w * .86, ground - 6 * u), u);
    // 작은 집 (왼쪽 뒤)
    _house(canvas, Offset(w * .2, ground - 10 * u), u);

    // 잔디 언덕
    final grass = Path()
      ..moveTo(0, ground + 10 * u)
      ..quadraticBezierTo(w * .25, ground - 6 * u, w * .5, ground + 8 * u)
      ..quadraticBezierTo(w * .78, ground + 20 * u, w, ground + 2 * u)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(grass, Paint()..color = look.grass);

    // 모래길
    final path = Path()
      ..moveTo(0, ground + 46 * u)
      ..quadraticBezierTo(w * .5, ground + 30 * u, w, ground + 50 * u)
      ..lineTo(w, ground + 92 * u)
      ..quadraticBezierTo(w * .5, ground + 72 * u, 0, ground + 88 * u)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF0DDB2));
    final dash = Paint()
      ..color = const Color(0xFFDCC392)
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
      ..color = Color.lerp(look.grassDeep, Colors.black, .1)!
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;
    for (var x = 8 * u; x < w; x += 22 * u) {
      final base = ground + 100 * u + (x * 7 % 13) * u;
      canvas.drawLine(Offset(x, base), Offset(x - 4 * u, base - 14 * u), blade);
      canvas.drawLine(
        Offset(x + 5 * u, base),
        Offset(x + 8 * u, base - 12 * u),
        blade,
      );
    }

    // 꽃
    for (final fx in [.08, .37, .63, .93]) {
      final o = Offset(w * fx, ground + 24 * u + (fx * 40 % 10) * u);
      canvas.drawLine(
        o,
        o + Offset(0, 12 * u),
        Paint()
          ..color = const Color(0xFF5DA05A)
          ..strokeWidth = 2.5 * u,
      );
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5;
        canvas.drawCircle(
          o + Offset(cos(a), sin(a)) * 5 * u,
          4 * u,
          Paint()..color = look.flower,
        );
      }
      canvas.drawCircle(o, 3 * u, Paint()..color = const Color(0xFFFFE08A));
    }
  }

  void _lighthouse(Canvas c, Offset base, double u) {
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
  }

  void _house(Canvas c, Offset base, double u) {
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
