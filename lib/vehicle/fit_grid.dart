import 'dart:math';

import 'package:flutter/widgets.dart';

/// 탈것 칸을 밀어서 보지 않고 한 화면에 모두 보이게 놓는다.
/// 칸 수를 1줄부터 늘려 보며 칸이 가장 커지는 배치를 고른다.
class FitGrid extends StatelessWidget {
  const FitGrid({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.aspect = 1.3,
    this.maxWidth = 220,
    this.gap = 10,
  });

  final int count;

  /// 칸의 가로 / 세로
  final double aspect;

  /// 칸 너비 상한 (큰 화면에서 너무 커지지 않게)
  final double maxWidth;
  final double gap;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// [count]개를 [box]에 넣을 때 가장 큰 칸 너비
  static double tileWidth(
    int count,
    Size box, {
    double aspect = 1.3,
    double gap = 10,
  }) {
    var best = 0.0;
    for (var cols = 1; cols <= count; cols++) {
      final rows = (count + cols - 1) ~/ cols;
      final w = (box.width - gap * (cols - 1)) / cols;
      final h = (box.height - gap * (rows - 1)) / rows;
      best = max(best, min(w, h * aspect));
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = min(
        maxWidth,
        tileWidth(count, c.biggest, aspect: aspect, gap: gap),
      ).floorToDouble();
      return Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: w,
                height: (w / aspect).floorToDouble(),
                child: itemBuilder(context, i),
              ),
          ],
        ),
      );
    },
  );
}
