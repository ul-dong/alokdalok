import 'package:flutter/material.dart';

import '../character/item_thumb.dart';
import '../core/palette.dart';
import '../data/item_catalog.dart';
import '../games/common/scene_game.dart';
import '../widgets/common.dart';

/// 내 가방 (가로): 왼쪽에 모은 코인·별, 오른쪽에 가진 아이템.
class BagScreen extends StatelessWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = ItemCatalog.all.where((i) => state.owns(i.id)).toList();
    return LandscapePage(
      background: const SceneBackground(groundLevel: .92),
      child: Row(
        children: [
          Expanded(
            flex: 3,
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
                    const SizedBox(width: 10),
                    const Expanded(
                      child: FitBox(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '내 가방',
                          style: TextStyle(
                            fontSize: TextSizes.heading,
                            color: Palette.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _Stat(
                    icon: const CoinIcon(size: 52),
                    value: state.coins,
                    label: '코인',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _Stat(
                    icon: const StarIcon(size: 50),
                    value: state.stars,
                    label: '별',
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 7,
            child: CreamCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.backpack_rounded,
                        color: Palette.pink,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${mine.length} / ${ItemCatalog.all.length}',
                        style: const TextStyle(
                          fontSize: TextSizes.label,
                          color: Palette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: mine.isEmpty
                        ? const Center(
                            child: Text(
                              '놀이로 코인을 모아\n상점에서 골라 보세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: TextSizes.label,
                                color: Palette.textSoft,
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 104,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemCount: mine.length,
                            itemBuilder: (_, i) => Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: FitBox(
                                child: ItemThumb(item: mine[i], size: 80),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final Widget icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: CreamCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Center(
        child: FitBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(
                '$value',
                style: const TextStyle(fontSize: 40, color: Palette.text),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
