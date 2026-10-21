import 'dart:math';

import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
import '../character/character_view.dart';
import '../character/zodiac.dart';
import '../core/palette.dart';
import '../games/common/scene_game.dart';
import '../services/audio_service.dart';
import '../widgets/common.dart';
import '../widgets/paged_grid.dart' show GridRows;
import 'nickname_screen.dart';

/// 친구 고르기 (12지신 / 공룡 탭). 첫 실행이면 고른 뒤 이름 짓기로, 아니면 바로 돌아간다.
class ZodiacPickerScreen extends StatefulWidget {
  const ZodiacPickerScreen({super.key, this.onboarding = false});

  final bool onboarding;

  /// 고른 친구 이름표 (테스트용)
  static const namePlateKey = ValueKey('friend-name-plate');

  @override
  State<ZodiacPickerScreen> createState() => _ZodiacPickerScreenState();
}

class _ZodiacPickerScreenState extends State<ZodiacPickerScreen> {
  late Zodiac selected = AppScope.read(context).zodiac;
  late FriendGroup group = selected.group;
  int cheer = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onboarding) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) AppScope.read(context).audio.say('안녕! 함께 놀 친구를 골라 볼까요?');
      });
    }
  }

  void _pick(Zodiac z) {
    setState(() {
      selected = z;
      cheer++;
    });
    AppScope.read(context).audio.say(z.hello);
  }

  Future<void> _done() async {
    final state = AppScope.read(context);
    await state.setZodiac(selected);
    state.audio.play(Sfx.buy);
    if (!mounted) return;
    if (widget.onboarding) {
      Navigator.of(context)
          .push(softRoute(const NicknameScreen(onboarding: true)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LandscapePage(
      background: const SceneBackground(groundLevel: .8),
      child: Row(
        children: [
          // 왼쪽: 고른 친구 크게 + 큰 이름표
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    if (!widget.onboarding)
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: '뒤로',
                        size: 60,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    const Spacer(),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _NamePlate(text: selected.look.animal),
                        const SizedBox(height: 6),
                        CharacterView(
                          zodiac: selected,
                          equipped: state.equipped,
                          cheer: cheer,
                          size: ((c.maxHeight - 76) / 1.2).clamp(60.0, 300.0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PillButton(
                  width: double.infinity,
                  height: 64,
                  color: Palette.pink,
                  edge: const Color(0xFFD9799A),
                  sound: null,
                  onTap: _done,
                  semanticLabel: widget.onboarding ? '이 친구로 할래요' : '바꾸기',
                  child: FitBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.onboarding ? '이 친구로 할래요' : '이 친구로 바꾸기',
                          style: const TextStyle(
                            fontSize: TextSizes.title,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 오른쪽: 한 쪽에 6마리씩 크게, 양옆 큰 화살표와 쪽 점으로 넘긴다
          Expanded(
            flex: 7,
            child: CreamCard(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Column(
                children: [
                  // 12지신 / 공룡 탭
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        for (final (g, label) in const [
                          (FriendGroup.zodiac, '12지신'),
                          (FriendGroup.dino, '공룡'),
                        ]) ...[
                          if (g == FriendGroup.dino) const SizedBox(width: 8),
                          Expanded(
                            child: PillButton(
                              height: 52,
                              color: group == g ? Palette.pink : Colors.white,
                              edge: group == g
                                  ? const Color(0xFFD9799A)
                                  : Palette.creamDeep,
                              semanticLabel: label,
                              onTap: () => setState(() => group = g),
                              child: FitBox(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: TextSizes.title,
                                    color: group == g
                                        ? Colors.white
                                        : Palette.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FriendPager(
                      key: ValueKey(group),
                      friends: ZodiacInfo.of(group),
                      selected: selected,
                      onPick: _pick,
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

/// 친구 고르기 판: 한 쪽에 [perPage]마리(3×2)를 얼굴만 크게 보여 주고,
/// 양옆의 큰 화살표와 아래 쪽 점으로 넘긴다 (밀어서 넘기지 않는다).
/// 처음에는 지금 고른 친구가 있는 쪽을 연다.
class FriendPager extends StatefulWidget {
  const FriendPager({
    super.key,
    required this.friends,
    required this.selected,
    required this.onPick,
  });

  final List<Zodiac> friends;
  final Zodiac selected;
  final ValueChanged<Zodiac> onPick;

  static const cols = 3;
  static const rows = 2;
  static const perPage = cols * rows;

  /// 양옆 화살표 크기 (손가락이 닿기 쉬운 세로로 긴 단추)
  static const arrowSize = Size(52, 88);

  @override
  State<FriendPager> createState() => _FriendPagerState();
}

class _FriendPagerState extends State<FriendPager> {
  late int page =
      max(0, widget.friends.indexOf(widget.selected)) ~/ FriendPager.perPage;

  int get pages => (widget.friends.length / FriendPager.perPage).ceil();

  void _go(int to) {
    setState(() => page = to.clamp(0, pages - 1));
  }

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    final first = page * FriendPager.perPage;
    final last = min(widget.friends.length, first + FriendPager.perPage);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _TallArrow(
                forward: false,
                enabled: page > 0,
                onTap: () => _go(page - 1),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 정사각형 칸 3×2를 가능한 한 크게
                    final side = min(
                      (c.maxWidth - gap * (FriendPager.cols - 1)) /
                          FriendPager.cols,
                      (c.maxHeight - gap * (FriendPager.rows - 1)) /
                          FriendPager.rows,
                    ).floorToDouble();
                    return Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: GridRows(
                          key: ValueKey(page),
                          first: first,
                          last: last,
                          cols: FriendPager.cols,
                          cellWidth: side,
                          cellHeight: side,
                          gap: gap,
                          itemBuilder: (i) {
                            final z = widget.friends[i];
                            return ZodiacTile(
                              zodiac: z,
                              selected: z == widget.selected,
                              onTap: () => widget.onPick(z),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: gap),
              _TallArrow(
                forward: true,
                enabled: page < pages - 1,
                onTap: () => _go(page + 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        PageDots(count: pages, current: page),
      ],
    );
  }
}

/// 몇 번째 쪽인지 보여 주는 점 (지금 쪽은 길고 진하게)
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${current + 1}쪽 / $count쪽',
    child: SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: i == current ? 30 : 14,
              height: 14,
              decoration: BoxDecoration(
                color: i == current ? Palette.pink : Palette.creamDeep,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
        ],
      ),
    ),
  );
}

/// 세로로 긴 큰 화살표 (52×88). 더 넘길 쪽이 없으면 흐려진다.
class _TallArrow extends StatelessWidget {
  const _TallArrow({
    required this.forward,
    required this.enabled,
    required this.onTap,
  });

  final bool forward;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: enabled ? 1 : .3,
    child: Pressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: forward ? '다음 쪽' : '앞 쪽',
      child: Container(
        width: FriendPager.arrowSize.width,
        height: FriendPager.arrowSize.height,
        decoration: BoxDecoration(
          color: Palette.yellow,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: const [
            BoxShadow(color: Palette.coinDeep, offset: Offset(0, 5)),
          ],
        ),
        child: Icon(
          forward ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          size: 38,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: ZodiacPickerScreen.namePlateKey,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
    decoration: BoxDecoration(
      color: Palette.cream,
      borderRadius: BorderRadius.circular(Radii.lg),
      boxShadow: const [
        BoxShadow(color: Palette.creamDeep, offset: Offset(0, 4)),
      ],
    ),
    // 칸 안에는 이름을 쓰지 않으니, 고른 친구 이름을 여기에 크게 쓴다
    child: FitBox(
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontSize: TextSizes.hero,
          color: Palette.text,
          height: 1.15,
        ),
      ),
    ),
  );
}

/// 동물 한 칸: 이름 글씨 없이 얼굴을 크게 (이름은 누르면 말해 주고 왼쪽 이름표에 크게 쓴다)
class ZodiacTile extends StatelessWidget {
  const ZodiacTile({
    super.key,
    required this.zodiac,
    required this.selected,
    required this.onTap,
  });

  final Zodiac zodiac;
  final bool selected;
  final VoidCallback onTap;

  /// 칸에 보여 줄 얼굴 영역 (200 x 240 좌표계): 귀·뿔부터 턱 아래까지
  static const face = Rect.fromLTWH(6, -2, 188, 168);

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: zodiac.look.animal,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? Palette.yellowSoft : Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: selected ? Palette.yellow : Palette.creamDeep,
          width: selected ? 5 : 3,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md - 6),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: face.width,
            height: face.height,
            child: OverflowBox(
              minWidth: 200,
              maxWidth: 200,
              minHeight: 240,
              maxHeight: 240,
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: -face.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 240,
                  child: CustomPaint(
                    painter: AnimalPainter(zodiac: zodiac, items: const {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
