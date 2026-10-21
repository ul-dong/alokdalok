import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../character/zodiac.dart';
import '../core/palette.dart';
import '../data/game_objects.dart';
import '../games/common/object_art.dart';
import '../games/common/scene_game.dart';
import '../services/game_state.dart';
import '../shop/shop_screen.dart';
import '../widgets/common.dart';
import '../data/vehicles.dart';
import '../vehicle/garage_screen.dart';
import '../vehicle/vehicle_painter.dart';
import 'bag_screen.dart';
import 'character_screen.dart';
import 'settings_screen.dart';
import 'stage_picker.dart';

/// 메인 화면 (가로). 왼쪽에 내 캐릭터, 오른쪽에 큰 그림 메뉴.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopScope(
      canPop: false, // 뒤로 가기 실수로 앱이 꺼지지 않게
      child: LandscapePage(
        background: const SceneBackground(groundLevel: .8),
        child: Row(
          children: [
            // 왼쪽: 캐릭터
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.settings_rounded,
                        label: '설정',
                        size: 60,
                        onTap: () => _go(const SettingsScreen()),
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
            // 오른쪽: 메뉴
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: '숫자 놀이',
                            color: const Color(0xFFFFD9E3),
                            edge: const Color(0xFFF2B4C6),
                            art: const _NumberArt(),
                            onTap: () {
                              state.audio.say('숫자 놀이를 해 볼까요?');
                              _go(const StagePicker(game: GameKind.number));
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MenuTile(
                            label: '색깔 놀이',
                            color: const Color(0xFFD6F2E4),
                            edge: const Color(0xFFA9DCC2),
                            art: const _ColorArt(),
                            onTap: () {
                              state.audio.say('색깔 놀이를 해 볼까요?');
                              _go(const StagePicker(game: GameKind.color));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: '내 캐릭터',
                            color: const Color(0xFFDCEEFB),
                            edge: const Color(0xFFAFD3EE),
                            art: _FaceArt(zodiac: state.zodiac),
                            onTap: () => _go(const CharacterScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MenuTile(
                            label: '꾸미기 상점',
                            color: const Color(0xFFFFF0C4),
                            edge: const Color(0xFFF0D88A),
                            art: const _ShopArt(),
                            onTap: () => _go(const ShopScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MenuTile(
                            label: '내 가방',
                            color: const Color(0xFFE9E1F7),
                            edge: const Color(0xFFC9BCE6),
                            art: const _BagArt(),
                            onTap: () => _go(const BagScreen()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MenuTile(
                            label: '탈것 꾸미기',
                            color: const Color(0xFFFFE1EA),
                            edge: const Color(0xFFF2B5C8),
                            art: const _CarArt(),
                            onTap: () => _go(const GarageScreen()),
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

class _NumberArt extends StatelessWidget {
  const _NumberArt();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 3; i++)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$i',
              style: const TextStyle(
                fontSize: 34,
                color: Color(0xFFE0607E),
                height: 1,
              ),
            ),
            ObjectIcon(ObjectKind.apple, size: 40 + i * 2.0),
          ],
        ),
    ],
  );
}

class _ColorArt extends StatelessWidget {
  const _ColorArt();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final c in const [GameColor.red, GameColor.yellow, GameColor.blue])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ObjectIcon(ObjectKind.balloon, color: c.color, size: 58),
        ),
    ],
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

class _BagArt extends StatelessWidget {
  const _BagArt();

  @override
  Widget build(BuildContext context) => const Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(Icons.backpack_rounded, size: 64, color: Color(0xFFF2826F)),
      Positioned(right: -10, bottom: -4, child: StarIcon(size: 28)),
    ],
  );
}

/// 탈것 꾸미기 타일 그림: 별·하트 스티커가 붙은 빨간 자동차
class _CarArt extends StatelessWidget {
  const _CarArt();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 80,
    child: CustomPaint(
      painter: VehiclePainter(
        vehicle: Vehicles.byId('car')!,
        stickers: const [
          PlacedSticker(
            kind: StickerKind.star,
            color: 0xFFFFCF4D,
            x: .3,
            y: .62,
          ),
          PlacedSticker(
            kind: StickerKind.heart,
            color: 0xFFF58BB0,
            x: .62,
            y: .66,
          ),
        ],
      ),
    ),
  );
}
