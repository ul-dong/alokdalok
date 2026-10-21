import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../character/zodiac.dart';
import '../core/palette.dart';
import '../games/common/scene_game.dart';
import '../services/game_state.dart';
import '../shop/shop_screen.dart';
import '../widgets/common.dart';
import '../widgets/parental_gate.dart';
import 'character_screen.dart';
import 'playground_art.dart';
import 'playground_screen.dart';
import 'settings_screen.dart';
import '../widgets/poke_character.dart';

/// 메인 화면 (가로). 왼쪽에 내 캐릭터, 오른쪽에 큰 버튼 세 개
/// (놀이터 가기 · 내 캐릭터 · 꾸미기 상점). 구석의 작은 톱니바퀴는 부모 확인을 거쳐 설정으로.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const playgroundLabel = '놀이터 가기';
  static const characterLabel = '내 캐릭터';
  static const shopLabel = '꾸미기 상점';
  static const settingsLabel = '설정';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ScreenMusic {
  @override
  String get musicTrack => 'home';

  static bool _greeted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greeted) {
      _greeted = true;
      final state = AppScope.read(context);
      Future.delayed(
        const Duration(milliseconds: 600),
        () => state.audio.say('안녕! 오늘은 뭐 하고 놀까?'),
      );
    }
  }

  void _go(Widget page) => Navigator.of(context).push(softRoute(page));

  /// 톱니바퀴: 부모 확인을 거쳐 설정으로
  Future<void> _openSettings() async {
    if (await confirmParent(context) && mounted) _go(const SettingsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopScope(
      canPop: false, // 뒤로 가기 실수로 앱이 꺼지지 않게
      child: LandscapePage(
        background: const SceneBackground(groundLevel: .8),
        child: Row(
          children: [
            // 왼쪽: 내 캐릭터 (왼쪽 위는 다른 화면의 "집으로" 자리라 비워 둔다)
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final charSize = ((c.maxHeight - 60) / 1.2)
                            .clamp(60.0, min(320.0, c.maxWidth * .8))
                            .toDouble();
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _NamePill(
                              name: state.nickname,
                              animal: state.zodiac.look.animal,
                            ),
                            const SizedBox(height: Gaps.sm),
                            PokeCharacter(
                              semanticLabel: '내 친구 쓰다듬기',
                              child: CharacterView(
                                equipped: state.equipped,
                                size: charSize,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // 오른쪽: 큰 버튼 세 개 (놀이터 가기 · 내 캐릭터 · 꾸미기 상점)
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CountBadge(
                        icon: const StarIcon(),
                        value: state.stars,
                        label: '별',
                      ),
                      const SizedBox(width: Gaps.md),
                      CountBadge(
                        icon: const CoinIcon(),
                        value: state.coins,
                        label: '코인',
                      ),
                    ],
                  ),
                  const SizedBox(height: Gaps.lg),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      width: double.infinity,
                      child: _MenuTile(
                        label: HomeScreen.playgroundLabel,
                        color: const Color(0xFFD3F1E2),
                        art: const _PlaygroundArt(),
                        onTap: () => _go(const PlaygroundScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gaps.lg),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: HomeScreen.characterLabel,
                            color: const Color(0xFFD9ECFB),
                            art: _FaceArt(zodiac: state.zodiac),
                            onTap: () => _go(const CharacterScreen()),
                          ),
                        ),
                        const SizedBox(width: Gaps.lg),
                        Expanded(
                          child: _MenuTile(
                            label: HomeScreen.shopLabel,
                            color: const Color(0xFFFFEFC2),
                            art: const _ShopArt(),
                            onTap: () => _go(const ShopScreen()),
                          ),
                        ),
                        const SizedBox(width: Gaps.sm),
                        // 오른쪽 아래 구석의 작은 톱니바퀴: 다른 화면의 왼쪽 위
                        // "집으로/뒤로" 버튼과 겹치지 않는 자리 (두 번 눌러도 부모 확인이 뜨지 않게)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: _SettingsCorner(onTap: _openSettings),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Depth.edge + 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설정 톱니바퀴: 눈에 덜 띄는 작은 그림, 누르는 칸은 60px
class _SettingsCorner extends StatelessWidget {
  const _SettingsCorner({required this.onTap});
  final VoidCallback onTap;

  static const touch = 60.0;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: HomeScreen.settingsLabel,
    child: SizedBox.square(
      dimension: touch,
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.settings_rounded,
            size: 26,
            color: Palette.textSoft,
          ),
        ),
      ),
    ),
  );
}

class _NamePill extends StatelessWidget {
  const _NamePill({required this.name, required this.animal});
  final String name;
  final String animal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    decoration: chipDecoration(),
    child: FitBox(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(
                fontSize: TextSizes.title,
                color: Palette.text,
              ),
            ),
            TextSpan(
              text: '  $animal',
              style: const TextStyle(
                fontSize: TextSizes.small,
                color: Palette.textSoft,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.color,
    required this.art,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    speak: label,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: Depth.raised(Depth.edgeOf(color)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // 큰 화면에서는 그림과 글자도 같이 커진다 (빈 칸이 생기지 않게)
          final labelH = (c.maxHeight * .2).clamp(26.0, 46.0);
          final pad = (c.maxHeight * .06).clamp(4.0, 16.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * .7),
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(fit: BoxFit.contain, child: art),
                ),
                SizedBox(height: pad * .4),
                SizedBox(
                  height: labelH,
                  child: FitBox(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: labelH * .72,
                        color: Palette.text,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 놀이터 가기 그림: 미끄럼틀과 그네
class _PlaygroundArt extends StatelessWidget {
  const _PlaygroundArt();

  @override
  Widget build(BuildContext context) => SizedBox(
    // 큰 화면에서는 크게, 작은 화면에서는 FitBox가 줄인다
    width: 480,
    height: 200,
    child: Row(
      children: [
        for (final k in const [GameKind.number, GameKind.color, GameKind.size])
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: EquipmentPainter(k),
            ),
          ),
      ],
    ),
  );
}

class _FaceArt extends StatelessWidget {
  const _FaceArt({required this.zodiac});
  final Zodiac zodiac;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 100,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 거울처럼 둥근 무대 위에 선 내 친구
        Positioned(
          bottom: 0,
          child: Container(
            width: 96,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        Positioned(
          bottom: 6,
          child: CharacterView(
            zodiac: zodiac,
            equipped: AppScope.of(context).equipped,
            size: 78,
          ),
        ),
        const Positioned(right: 6, top: 4, child: _Sparkle(size: 18)),
        const Positioned(left: 8, top: 22, child: _Sparkle(size: 12)),
      ],
    ),
  );
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _SparklePainter()),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    final p = Path()
      ..moveTo(o.dx, 0)
      ..quadraticBezierTo(o.dx, o.dy, s.width, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, s.height)
      ..quadraticBezierTo(o.dx, o.dy, 0, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, 0)
      ..close();
    c.drawPath(p, Paint()..color = Palette.yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopArt extends StatelessWidget {
  const _ShopArt();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 120,
    height: 100,
    child: CustomPaint(painter: ShopStallPainter()),
  );
}

/// 꾸미기 상점 그림: 줄무늬 차양 아래 옷걸이에 걸린 옷과 모자, 앞에 금화
class ShopStallPainter extends CustomPainter {
  const ShopStallPainter();

  @override
  void paint(Canvas c, Size s) {
    final u = min(s.width / 120, s.height / 100);
    c.save();
    c.translate((s.width - 120 * u) / 2, (s.height - 100 * u) / 2);
    c.scale(u);
    final ol = Paint()
      ..color = Palette.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color col) => Paint()..color = col;

    // 가게 몸통
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 30, 92, 64),
      const Radius.circular(8),
    );
    c.drawRRect(body, fill(const Color(0xFFFFF8EA)));
    c.drawRRect(body, ol);
    // 옷걸이 봉
    c.drawLine(const Offset(24, 46), const Offset(96, 46), ol);
    // 원피스 (분홍)
    final dress = Path()
      ..moveTo(36, 48)
      ..lineTo(44, 48)
      ..lineTo(50, 78)
      ..lineTo(28, 78)
      ..close();
    c.drawPath(dress, fill(Palette.pink));
    c.drawPath(dress, ol);
    // 티셔츠 (하늘)
    final shirt = Path()
      ..moveTo(60, 48)
      ..lineTo(76, 48)
      ..lineTo(84, 56)
      ..lineTo(79, 60)
      ..lineTo(77, 58)
      ..lineTo(77, 76)
      ..lineTo(59, 76)
      ..lineTo(59, 58)
      ..lineTo(57, 60)
      ..lineTo(52, 56)
      ..close();
    c.drawPath(shirt, fill(const Color(0xFF6FB7E8)));
    c.drawPath(shirt, ol);
    // 차양 (빨강·흰 줄무늬 물결)
    final awning = Path()..moveTo(8, 18);
    awning
      ..lineTo(112, 18)
      ..lineTo(112, 30);
    for (var i = 6; i >= 0; i--) {
      final x0 = 8 + i * (104 / 7);
      awning.arcToPoint(
        Offset(x0, 30),
        radius: const Radius.circular(7.5),
        clockwise: true,
      );
    }
    awning.close();
    c.drawPath(awning, fill(const Color(0xFFF26B5E)));
    c.save();
    c.clipPath(awning);
    for (var i = 0; i < 7; i += 2) {
      c.drawRect(
        Rect.fromLTWH(8 + i * (104 / 7), 10, 104 / 7, 30),
        fill(Colors.white),
      );
    }
    c.restore();
    c.drawPath(awning, ol);
    // 지붕 띠
    final top = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 8, 112, 12),
      const Radius.circular(6),
    );
    c.drawRRect(top, fill(Palette.yellow));
    c.drawRRect(top, ol);
    // 금화
    const o = Offset(98, 82);
    c.drawCircle(o, 13, fill(Palette.coinDeep));
    c.drawCircle(o, 11, fill(Palette.coin));
    c.drawCircle(o, 13, ol);
    c.drawLine(
      const Offset(98, 77),
      const Offset(98, 88),
      ol..strokeWidth = 2.4,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
