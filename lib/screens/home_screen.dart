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

  int _cheer = 0;
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
            // 왼쪽: 구석의 작은 톱니바퀴 + 내 캐릭터
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.settings_rounded,
                        label: HomeScreen.settingsLabel,
                        size: 60,
                        onTap: _openSettings,
                      ),
                      const Spacer(),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final charSize = ((c.maxHeight - 56) / 1.2).clamp(
                          60.0,
                          240.0,
                        );
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _NamePill(
                              name: state.nickname,
                              animal: state.zodiac.look.animal,
                            ),
                            const SizedBox(height: 4),
                            Pressable(
                              semanticLabel: '내 친구 쓰다듬기',
                              onTap: () {
                                setState(() => _cheer++);
                                state.audio.say('안녕!');
                              },
                              child: CharacterView(
                                equipped: state.equipped,
                                cheer: _cheer,
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
                      const SizedBox(width: 10),
                      CountBadge(
                        icon: const CoinIcon(),
                        value: state.coins,
                        label: '코인',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      width: double.infinity,
                      child: _MenuTile(
                        label: HomeScreen.playgroundLabel,
                        color: const Color(0xFFD6F2E4),
                        edge: const Color(0xFFA9DCC2),
                        art: const _PlaygroundArt(),
                        onTap: () => _go(const PlaygroundScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: HomeScreen.characterLabel,
                            color: const Color(0xFFDCEEFB),
                            edge: const Color(0xFFAFD3EE),
                            art: _FaceArt(zodiac: state.zodiac),
                            onTap: () => _go(const CharacterScreen()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MenuTile(
                            label: HomeScreen.shopLabel,
                            color: const Color(0xFFFFF0C4),
                            edge: const Color(0xFFF0D88A),
                            art: const _ShopArt(),
                            onTap: () => _go(const ShopScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamePill extends StatelessWidget {
  const _NamePill({required this.name, required this.animal});
  final String name;
  final String animal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    decoration: BoxDecoration(
      color: Palette.cream,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: Palette.creamDeep, offset: Offset(0, 4)),
      ],
    ),
    child: FitBox(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(fontSize: 24, color: Palette.text),
            ),
            TextSpan(
              text: '  $animal',
              style: const TextStyle(fontSize: 16, color: Palette.textSoft),
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
    required this.edge,
    required this.art,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color edge;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    speak: label,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(color: edge, offset: const Offset(0, 6)),
          const BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: FitBox(child: art)),
          const SizedBox(height: 2),
          FitBox(
            child: Text(
              label,
              style: const TextStyle(fontSize: 22, color: Palette.text),
            ),
          ),
        ],
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
    width: 70,
    height: 70,
    child: CharacterView(
      zodiac: zodiac,
      equipped: AppScope.of(context).equipped,
      size: 58,
    ),
  );
}

class _ShopArt extends StatelessWidget {
  const _ShopArt();

  @override
  Widget build(BuildContext context) => const Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(Icons.checkroom_rounded, size: 64, color: Color(0xFFD9A43A)),
      Positioned(right: -10, bottom: -4, child: CoinIcon(size: 30)),
    ],
  );
}
