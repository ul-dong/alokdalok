import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../core/palette.dart';
import '../data/game_kinds.dart';
import '../services/game_state.dart';
import '../widgets/common.dart';
import 'playground_art.dart';
import 'stage_picker.dart';

/// 놀이터: 목록 대신 놀이터 그림에서 기구를 눌러 놀이를 고른다.
/// 미끄럼틀=숫자, 그네=색깔, 모래놀이터=모양, 시소=크기, 회전목마=짝 맞추기.
/// 기구마다 그림 이름표와 깬 단계만큼 별이 있고, 내 캐릭터도 놀이터에 서 있다.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  /// 놀이터에 놓는 순서 (왼쪽부터)
  static const order = [
    GameKind.number,
    GameKind.color,
    GameKind.shape,
    GameKind.size,
    GameKind.match,
  ];

  static const greeting = '놀이터에 왔어요! 어디에서 놀까요?';

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> with ScreenMusic {
  @override
  String get musicTrack => 'home';

  int _cheer = 0;

  @override
  void initState() {
    super.initState();
    final audio = AppScope.read(context).audio;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) audio.say(PlaygroundScreen.greeting);
    });
  }

  void _open(GameKind kind) {
    final state = AppScope.read(context);
    state.audio.say(kind.invite);
    Navigator.of(context).push(softRoute(StagePicker(game: kind)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LandscapePage(
      background: const CustomPaint(
        painter: PlaygroundBackgroundPainter(groundLevel: .5),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.home_rounded,
                  label: '집으로',
                  size: 60,
                  speakLabel: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: FitBox(
                    alignment: Alignment.centerLeft,
                    child: CreamCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 8,
                      ),
                      radius: 26,
                      child: Text(
                        '놀이터',
                        style: TextStyle(fontSize: 28, color: Palette.text),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FitBox(
                  child: CountBadge(
                    icon: const CoinIcon(),
                    value: state.coins,
                    label: '코인',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final charSize = (c.maxHeight * .62 / 1.2).clamp(50.0, 210.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 내 캐릭터가 놀이터 입구에 서 있다
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Pressable(
                          semanticLabel: '내 친구',
                          speak: '안녕!',
                          onTap: () => setState(() => _cheer++),
                          child: CharacterView(
                            equipped: state.equipped,
                            cheer: _cheer,
                            size: charSize,
                          ),
                        ),
                      ),
                    ),
                    for (final kind in PlaygroundScreen.order)
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: PlaygroundRide(
                            kind: kind,
                            stars: state.clearedStages(kind).length,
                            onTap: () => _open(kind),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 놀이 기구 하나: 위에 깬 단계만큼 별, 가운데 기구 그림, 아래 그림 이름표
class PlaygroundRide extends StatelessWidget {
  const PlaygroundRide({
    super.key,
    required this.kind,
    required this.stars,
    required this.onTap,
  });

  final GameKind kind;
  final int stars;
  final VoidCallback onTap;

  static const _starRow = 24.0;
  static const _tagH = 44.0;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: '${kind.equipment} ${kind.title}',
    child: LayoutBuilder(
      builder: (context, c) {
        // 기구는 정사각형 칸에 그리고, 별은 기구 바로 위에 단다
        final room = c.maxHeight - _starRow - _tagH - 4;
        final art = room.clamp(0.0, c.maxWidth * 1.1);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: _starRow,
              child: stars == 0
                  ? null
                  : FitBox(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < stars; i++)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1),
                              child: StarIcon(size: 22),
                            ),
                        ],
                      ),
                    ),
            ),
            SizedBox(
              width: c.maxWidth,
              height: art,
              child: CustomPaint(painter: EquipmentPainter(kind)),
            ),
            const SizedBox(height: 4),
            RideNameTag(kind: kind),
          ],
        );
      },
    ),
  );
}

/// 그림 이름표: 놀이를 나타내는 작은 그림 + 놀이 이름
class RideNameTag extends StatelessWidget {
  const RideNameTag({super.key, required this.kind});
  final GameKind kind;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: kind.tint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [
        BoxShadow(
          color: kind.accent.withValues(alpha: .55),
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: FitBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 30,
            child: CustomPaint(painter: GameBadgePainter(kind)),
          ),
          const SizedBox(width: 4),
          Text(
            kind.title,
            style: const TextStyle(fontSize: 18, color: Palette.text),
          ),
        ],
      ),
    ),
  );
}
