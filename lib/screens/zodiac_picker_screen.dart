import 'package:flutter/material.dart';

import '../character/animal_painter.dart';
import '../character/character_view.dart';
import '../character/zodiac.dart';
import '../core/palette.dart';
import '../games/common/scene_game.dart';
import '../services/audio_service.dart';
import '../widgets/common.dart';
import 'nickname_screen.dart';

/// 친구 고르기 (12지신 / 공룡 탭). 첫 실행이면 고른 뒤 이름 짓기로, 아니면 바로 돌아간다.
class ZodiacPickerScreen extends StatefulWidget {
  const ZodiacPickerScreen({super.key, this.onboarding = false});

  final bool onboarding;

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
          // 왼쪽: 고른 친구 크게
          Expanded(
            flex: 4,
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
                          size: ((c.maxHeight - 70) / 1.2).clamp(60.0, 230.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 오른쪽: 12마리 고르기
          Expanded(
            flex: 6,
            child: CreamCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                                    fontSize: 24,
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
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const cols = 4, rows = 3, gap = 8.0;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;
                        final h = (c.maxHeight - gap * (rows - 1)) / rows;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final z in ZodiacInfo.of(group))
                              SizedBox(
                                width: w,
                                height: h,
                                child: ZodiacTile(
                                  zodiac: z,
                                  selected: z == selected,
                                  onTap: () => _pick(z),
                                ),
                              ),
                          ],
                        );
                      },
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
                              fontSize: 24,
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
          ),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.text});
  final String text;

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
    child: Text(
      text,
      style: const TextStyle(fontSize: 24, color: Palette.text),
    ),
  );
}

/// 동물 한 칸 (얼굴이 잘 보이도록 위쪽을 확대)
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

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: zodiac.look.animal,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? Palette.yellowSoft : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? Palette.yellow : Palette.creamDeep,
          width: selected ? 5 : 3,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.75),
                child: SizedBox(
                  width: 200,
                  height: 170,
                  child: OverflowBox(
                    maxHeight: 240,
                    alignment: Alignment.topCenter,
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
          FitBox(
            child: Text(
              zodiac.look.animal,
              style: const TextStyle(fontSize: 16, color: Palette.text),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    ),
  );
}
