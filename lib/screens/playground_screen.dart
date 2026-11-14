import 'package:flutter/material.dart';

import '../character/character_view.dart';
import '../core/palette.dart';
import '../data/game_kinds.dart';
import '../l10n/l10n.dart';
import '../services/game_state.dart';
import '../widgets/common.dart';
import 'playground_art.dart';
import 'stage_picker.dart';
import '../widgets/poke_character.dart';

/// 놀이터: 목록 대신 놀이터 그림에서 놀이 내용물 그림을 눌러 놀이를 고른다.
/// 1·2·3 계단 미끄럼틀=숫자, 풍선 다발=색깔, 도형 블록=모양, 큰 공·작은 공=크기,
/// 양말 한 켤레=짝 맞추기. 그림마다 그림 이름표와 깬 단계만큼 별이 있고, 내 캐릭터도 서 있다.
/// 짧게 누르면 들어가고, 길게([LongPress.sayName]) 누르면 "숫자 놀이야!"처럼 이름만 말한다.
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

  /// 들어오면 한 문장만 말한다. 홈의 "놀이터 가기" 버튼은 이름을 읽지 않아서
  /// 버튼 이름이 반쯤 나오다 끊겨 "놀이… 놀이터에 왔어요"처럼 겹쳐 들리지 않는다.
  static String get greeting => L10n.current.playground_greetingSay;

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> with ScreenMusic {
  @override
  String get musicTrack => 'home';

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

  void _sayName(GameKind kind) =>
      AppScope.read(context).audio.say(kind.nameLine);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LandscapePage(
      background: LayoutBuilder(
        builder: (context, c) => CustomPaint(
          size: c.biggest,
          painter: PlaygroundBackgroundPainter(
            groundLevel: PlaygroundBackgroundPainter.groundFor(c.biggest),
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.home_rounded,
                  label: context.l10n.common_home,
                  size: 60,
                  speakLabel: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FitBox(
                    alignment: Alignment.centerLeft,
                    child: TitleChip(context.l10n.playground_title),
                  ),
                ),
                const Spacer(),
                FitBox(
                  child: CountBadge(
                    icon: const CoinIcon(),
                    value: state.coins,
                    label: context.l10n.common_coins,
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
                        child: PokeCharacter(
                          child: CharacterView(
                            equipped: state.equipped,
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
                            onLongPress: () => _sayName(kind),
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

/// 놀이 하나: 위에 깬 단계만큼 별, 가운데 놀이 내용물 그림, 아래 그림 이름표
class PlaygroundRide extends StatelessWidget {
  const PlaygroundRide({
    super.key,
    required this.kind,
    required this.stars,
    required this.onTap,
    this.onLongPress,
  });

  final GameKind kind;
  final int stars;
  final VoidCallback onTap;

  /// 길게 누르기: 놀이 이름 듣기
  final VoidCallback? onLongPress;

  static const _starRow = 24.0;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    onLongPress: onLongPress,
    semanticLabel: kind.title,
    child: LayoutBuilder(
      builder: (context, c) {
        // 그림은 정사각형 칸에 그리고, 별은 그림 바로 위에 단다
        // 이름표는 넓은 화면에서 조금 더 크게
        final tagH = (c.maxWidth * .26).clamp(44.0, 56.0).toDouble();
        final room = c.maxHeight - _starRow - tagH - 4;
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
              child: CustomPaint(painter: PlayItemPainter(kind)),
            ),
            const SizedBox(height: 4),
            RideNameTag(kind: kind, height: tagH),
          ],
        );
      },
    ),
  );
}

/// 그림 이름표: 놀이를 나타내는 작은 그림 + 놀이 이름
class RideNameTag extends StatelessWidget {
  const RideNameTag({super.key, required this.kind, this.height = 44});
  final GameKind kind;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: Gaps.sm),
    decoration: BoxDecoration(
      color: kind.tint,
      borderRadius: BorderRadius.circular(height / 2),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: Depth.flat(kind.accent.withValues(alpha: .55)),
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
            style: const TextStyle(
              fontSize: TextSizes.body,
              color: Palette.text,
            ),
          ),
        ],
      ),
    ),
  );
}
