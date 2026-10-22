import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../widgets/common.dart';
import '../../widgets/listen_again_button.dart';
import '../../widgets/paged_grid.dart';
import 'game_frame.dart';

export '../../widgets/paged_grid.dart' show GridRows, TileGrid;

/// 문제 글 크기: 카드 높이에 비례해 키운다 (휴대폰 28 → 태블릿 약 40).
double quizPromptSize(double cardHeight) =>
    (cardHeight * .072).clamp(TextSizes.heading, 46.0).toDouble();

/// 문제 줄(문제 글 + 다시 듣기) 높이: 카드 높이에 비례
double quizHeaderHeight(double cardHeight) =>
    (cardHeight * .12).clamp(52.0, 72.0).toDouble();

/// 문제 카드: 왼쪽에 큰 노란 "다시 듣기"와 그림 힌트(견본), 오른쪽에 문제 글(부모님용)과 보기.
class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.prompt,
    required this.onReplay,
    required this.body,
    this.hint,
    this.hintId,
    this.coinPopAmount = 0,
    this.coinPopTrigger = 0,
  });

  final String prompt;
  final VoidCallback onReplay;

  /// 보기 영역 (남은 공간을 다 쓴다)
  final Widget body;

  /// 그림 힌트·견본 (null이면 비워 둔다). 크기는 [QuizHintBox]가 맞춘다.
  final Widget? hint;

  /// 힌트가 바뀌었는지 알아보는 값 (바뀔 때만 다시 튀어나온다)
  final Object? hintId;
  final int coinPopAmount;
  final int coinPopTrigger;

  static const replaySize = 62.0;

  @override
  Widget build(BuildContext context) => CreamCard(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    child: LayoutBuilder(
      builder: (context, c) {
        final replay = min(replaySize, c.maxHeight);
        // 힌트 칸: 다시 듣기 아래 남은 높이만큼 정사각형 (자리는 늘 비워 둬서 보기가 흔들리지 않게)
        final side = (c.maxHeight - replay - 8)
            .clamp(replay, max(replay, min(200.0, c.maxWidth * .2)))
            .toDouble();
        // 낮은 화면에서는 문제 글(부모님용)을 빼고 보기를 크게 (문제는 목소리로 듣는다)
        final showText = c.maxHeight >= 180;
        return Row(
          children: [
            SizedBox(
              width: side,
              child: Column(
                children: [
                  ReplayButton(size: replay, onTap: onReplay),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: hint == null
                            ? const SizedBox.shrink(key: ValueKey('none'))
                            : SizedBox.square(
                                key: ValueKey(hintId ?? 'hint'),
                                dimension: max(
                                  0,
                                  min(side, c.maxHeight - replay - 8),
                                ),
                                child: hint,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // 보기 묶음이 카드(판) 가운데에 오도록 왼쪽 줄 폭을 알려 준다
              child: QuizCenter(
                leftInset: side + 12,
                child: Column(
                  children: [
                    if (showText) ...[
                      // 큰 화면에서는 문제 글도 조금 크게 (숫자·색깔 놀이 제목과 같은 크기까지)
                      SizedBox(
                        height: (c.maxHeight * .1).clamp(32.0, 60.0),
                        width: double.infinity,
                        child: FitBox(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: quizPromptSize(c.maxHeight),
                              color: Palette.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Gaps.sm),
                    ],
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: body),
                          Positioned(
                            top: 0,
                            right: 4,
                            child: CoinPop(
                              amount: coinPopAmount,
                              trigger: coinPopTrigger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// [QuizCard]의 보기 칸이 카드 왼쪽에서 [leftInset]만큼 떨어져 있다는 것을 [QuizGrid]에 알려 준다.
/// 보기 칸 안에서 그냥 가운데에 놓으면 왼쪽 "다시 듣기" 줄 때문에 카드 묶음이 판 가운데보다
/// 오른쪽(1280 화면에서 약 100px)으로 치우친다.
class QuizCenter extends InheritedWidget {
  const QuizCenter({super.key, required this.leftInset, required super.child});

  final double leftInset;

  static double insetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuizCenter>()?.leftInset ?? 0;

  @override
  bool updateShouldNotify(QuizCenter old) => old.leftInset != leftInset;
}

/// 힌트·견본을 담는 모래빛 둥근 판
/// [say]가 있으면 누를 때 그 이름을 말해 준다 (예: "동그라미!").
class QuizHintBox extends StatelessWidget {
  const QuizHintBox({super.key, required this.child, this.label, this.say});
  final Widget child;
  final String? label;

  /// 누르면 말할 이름 (null이면 눌러도 아무 일 없음)
  final String? say;

  @override
  Widget build(BuildContext context) {
    final box = _box();
    return say == null
        ? Semantics(label: label, child: box)
        : SayName(name: say!, semanticLabel: label, child: box);
  }

  Widget _box() => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Palette.yellow, width: 3),
    ),
    child: child,
  );
}

/// 큰 노란 "다시 듣기" 버튼 (62px). 6초마다 한 번 통통 튀어 눈에 띈다.
/// 앱 공용 [ListenAgainButton](공용 20fps 시계, 튈 때만 다시 그림)을 그대로 쓴다.
class ReplayButton extends StatelessWidget {
  const ReplayButton({super.key, required this.onTap, this.size = 62});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ListenAgainButton(onTap: onTap, size: size);
}

/// 보기 칸 하나: 누르면 살짝 작아지고, 틀리면 흔들리며 흐려지고, 두 번 틀리면 정답이 빛난다.
class QuizTile extends StatelessWidget {
  const QuizTile({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.faded = false,
    this.glow = false,
    this.selected = false,
    this.done = false,
    this.wobble = 0,
    this.enabled = true,
    this.color = Palette.cream,
  });

  final double width;
  final double height;
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool faded;
  final bool glow;

  /// 골라 둔 카드 (짝 맞추기)
  final bool selected;

  /// 이미 맞춘 카드 (짝 맞추기)
  final bool done;
  final int wobble;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = min(width, height) * .2;
    final borderColor = glow
        ? Palette.yellow
        : selected
        ? Palette.pink
        : done
        ? Palette.mint
        : Colors.white;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      padding: EdgeInsets.all(min(width, height) * .07),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE9F7EF) : color,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: borderColor, width: glow || selected ? 6 : 4),
        boxShadow: [
          const BoxShadow(color: Palette.creamDeep, offset: Offset(0, 5)),
          if (glow)
            const BoxShadow(
              color: Color(0x88FFD45C),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          if (selected)
            const BoxShadow(
              color: Color(0x66F59AB5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          const BoxShadow(
            color: Palette.panelShadow,
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: faded ? .35 : 1,
        child: child,
      ),
    );
    return Pressable(
      onTap: onTap,
      enabled: enabled,
      sound: null,
      semanticLabel: semanticLabel,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(wobble),
        tween: Tween(begin: wobble == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (_, t, child) => Transform.rotate(
          angle: sin(t * pi * 4) * (1 - t) * .12,
          child: child,
        ),
        child: card,
      ),
    );
  }
}

/// [TileGrid]대로 보기를 가운데에 놓는다 (배치는 공용 [GridRows]).
class QuizGrid extends StatelessWidget {
  const QuizGrid({
    super.key,
    required this.count,
    required this.builder,
    this.aspect = 1,
    this.gap = 12,
    this.maxTile = double.infinity,
  });

  final int count;
  final double aspect;
  final double gap;
  final double maxTile;

  /// (위치, 칸 너비, 칸 높이) → 보기
  final Widget Function(int index, double w, double h) builder;

  /// 카드 묶음 중심이 판 중심에서 벗어나도 되는 거리
  static const centerSlack = 16.0;

  /// 가운데로 모으느라 칸을 줄이는 것은 칸이 이만큼 이상 클 때만 (태블릿).
  /// 휴대폰에서는 칸 크기를 지키고, 남는 자리 안에서만 가운데로 옮긴다.
  static const shrinkToCenterFrom = 120.0;

  @override
  Widget build(BuildContext context) {
    final inset = QuizCenter.insetOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        TileGrid fit(double width) => TileGrid.fit(
          count,
          Size(width, c.maxHeight),
          aspect: aspect,
          gap: gap,
          maxTile: maxTile,
          maxRows: TileGrid.quizMaxRows,
        );
        var g = fit(c.maxWidth);
        if (inset > 0) {
          // 판 가운데 기준으로 좌우가 같은 폭 (+ 조금의 여유) 안에 넣어 본다
          final centered = fit(c.maxWidth - inset + 2 * centerSlack);
          if (centered.tile >= shrinkToCenterFrom &&
              centered.tile >= g.tile * .75) {
            g = centered;
          }
        }
        final w = g.tile, h = g.tile * aspect;
        final gridW = g.cols * w + gap * (g.cols - 1);
        final free = c.maxWidth - gridW;
        // 판(카드 전체) 가운데에 오게 하되 보기 칸 밖으로는 나가지 않게
        final left = ((c.maxWidth + inset) / 2 - gridW / 2 - inset).clamp(
          0.0,
          max(0.0, free),
        );
        return Align(
          alignment: Alignment(free > 0 ? 2 * left / free - 1 : 0, 0),
          child: GridRows(
            last: count,
            cols: g.cols,
            cellWidth: w,
            cellHeight: h,
            gap: gap,
            itemBuilder: (i) => builder(i, w, h),
          ),
        );
      },
    );
  }
}
