import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../data/game_objects.dart';
import '../data/stages.dart';
import '../games/common/journey_trail.dart';
import '../games/common/object_art.dart';
import '../games/common/scene_game.dart';
import '../games/game_entry.dart';
import '../services/game_state.dart';
import '../widgets/common.dart';

/// 단계 고르기 (가로로 카드, 많으면 옆으로 밀기 + 아래에 골인 지점까지 가는 길). 글자 없이도 고를 수 있게 단계마다 사과·풍선 개수를 그림으로 보여 준다.
class StagePicker extends StatelessWidget {
  const StagePicker({super.key, required this.game});

  final GameKind game;

  void _start(BuildContext context, int stageId) {
    openGame(context, game, stageId);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unlocked = state.unlockedStage(game);
    final cleared = state.clearedStages(game);
    final count = state.stageCount(game);
    final isNumber = game == GameKind.number;

    return LandscapePage(
      background: const SceneBackground(groundLevel: .86),
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.home_rounded,
                label: '집으로',
                size: 60,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              CreamCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                radius: 26,
                child: Text(
                  game.title,
                  style: const TextStyle(fontSize: 28, color: Palette.text),
                ),
              ),
              const Spacer(),
              CountBadge(
                icon: const CoinIcon(),
                value: state.coins,
                label: '코인',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // 3장까지는 화면을 꽉 채우고, 더 많으면 옆으로 밀어서 본다
                const gap = 16.0;
                final double cardW = count <= 3
                    ? (c.maxWidth - gap * (count - 1)) / count
                    : min(
                        (c.maxWidth - gap * 2.5) / 3.4,
                        c.maxHeight * .95,
                      ).clamp(120.0, 420.0);
                final double start = ((unlocked - 2) * (cardW + gap)).clamp(
                  0.0,
                  max(0.0, count * (cardW + gap) - gap - c.maxWidth),
                );
                return ListView.separated(
                  controller: ScrollController(initialScrollOffset: start),
                  scrollDirection: Axis.horizontal,
                  physics: count <= 3
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: count,
                  separatorBuilder: (_, _) => const SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    final id = i + 1;
                    return SizedBox(
                      width: cardW,
                      child: _StageCard(
                        id: id,
                        open: id <= unlocked,
                        cleared: cleared.contains(id),
                        highlight: id == unlocked,
                        art:
                            stageArt(game, id) ??
                            (isNumber
                                ? _NumberStageArt(Stages.number[id - 1])
                                : _ColorStageArt(Stages.color[id - 1])),
                        onTap: () {
                          if (id <= unlocked) {
                            _start(context, id);
                          } else {
                            state.audio.say('앞 단계를 먼저 놀아 볼까요?');
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // 단계를 깰 때마다 내 친구가 앞으로! 다 깨면 골인 지점에 도착
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: (MediaQuery.sizeOf(context).height * .24).clamp(
                60.0,
                130.0,
              ),
              child: JourneyTrail(
                total: count,
                done: cleared.length.clamp(0, count),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.id,
    required this.open,
    required this.cleared,
    required this.highlight,
    required this.art,
    required this.onTap,
  });

  final int id;
  final bool open;
  final bool cleared;
  final bool highlight;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: '$id단계${open ? '' : ' 아직 열리지 않음'}',
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.cream,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: highlight ? Palette.yellow : Colors.white,
          width: highlight ? 5 : 3,
        ),
        boxShadow: const [
          BoxShadow(color: Palette.creamDeep, offset: Offset(0, 6)),
          BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: open ? Palette.pinkSoft : Palette.creamDeep,
                  shape: BoxShape.circle,
                ),
                child: open
                    ? Text(
                        '$id',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Color(0xFFE0607E),
                        ),
                      )
                    : const Icon(
                        Icons.lock_rounded,
                        size: 28,
                        color: Palette.textSoft,
                      ),
              ),
              const Spacer(),
              if (cleared) const StarIcon(size: 40),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: open ? 1 : .4,
                    child: FitBox(child: art),
                  ),
                ),
                // 단계마다 계절이 바뀐다 (배경과 음악도 그 계절)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    switch (seasonForStage(id)) {
                      Season.spring => Icons.local_florist_rounded,
                      Season.summer => Icons.wb_sunny_rounded,
                      Season.autumn => Icons.eco_rounded,
                      Season.winter => Icons.ac_unit_rounded,
                    },
                    size: 30,
                    color: open
                        ? switch (seasonForStage(id)) {
                            Season.spring => const Color(0xFFF59AB5),
                            Season.summer => const Color(0xFFFFB13B),
                            Season.autumn => const Color(0xFFE07A3F),
                            Season.winter => const Color(0xFF6FB7E8),
                          }
                        : Palette.creamDeep,
                    semanticLabel: seasonForStage(id).ko,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _NumberStageArt extends StatelessWidget {
  const _NumberStageArt(this.stage);
  final NumberStage stage;

  @override
  Widget build(BuildContext context) {
    if (stage.scattered) return _mixed();
    final rows = stage.max > 5
        ? [5, stage.max - 5]
        : (stage.max > 3 ? [3, stage.max - 3] : [stage.max]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < n; i++)
                const ObjectIcon(ObjectKind.apple, size: 44),
            ],
          ),
      ],
    );
  }
}

extension on _NumberStageArt {
  /// 섞어서 세는 단계: 여러 사물·색이 섞인 작은 그림 + 돋보기
  Widget _mixed() {
    final kinds = stage.objects.take(max(1, stage.kindsShown)).toList();
    final colors = stage.colors.take(max(1, stage.colorsShown)).toList();
    final sample = [
      for (var i = 0; i < 6; i++)
        (
          kinds[(i * 7 ~/ 3) % kinds.length],
          colors.isEmpty ? null : colors[(i * 5 ~/ 2) % colors.length].color,
        ),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in [sample.sublist(0, 3), sample.sublist(3)])
              Padding(
                padding: EdgeInsets.only(
                  left: row == sample.sublist(3) ? 26 : 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (k, col) in row)
                      ObjectIcon(k, color: col, size: 44),
                  ],
                ),
              ),
          ],
        ),
        const Positioned(
          right: -18,
          bottom: -10,
          child: Icon(Icons.search_rounded, size: 40, color: Palette.text),
        ),
      ],
    );
  }
}

class _ColorStageArt extends StatelessWidget {
  const _ColorStageArt(this.stage);
  final ColorStage stage;

  @override
  Widget build(BuildContext context) {
    final colors = stage.colors;
    final rows = colors.length > 3
        ? [colors.sublist(0, 3), colors.sublist(3)]
        : [colors];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in row)
                ObjectIcon(ObjectKind.balloon, color: c.color, size: 52),
            ],
          ),
      ],
    );
  }
}
