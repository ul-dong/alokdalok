import 'dart:math';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import 'common.dart';

/// 칸 배치 계산 결과
@immutable
class GridPlan {
  const GridPlan({
    required this.cols,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.paged,
  });

  final int cols;
  final int rows;
  final double cellWidth;
  final double cellHeight;

  /// 한 화면에 다 안 들어가서 화살표로 쪽을 넘기는지
  final bool paged;

  int get perPage => cols * rows;

  int pagesFor(int count) => paged ? (count / perPage).ceil() : 1;

  @override
  String toString() =>
      'GridPlan($cols x $rows, ${cellWidth.toStringAsFixed(1)} x '
      '${cellHeight.toStringAsFixed(1)}, paged: $paged)';
}

/// 칸 [count]개를 [area]에 가장 크게 놓는 줄·칸 수 (쪽 넘기기 없이 한 화면에 다).
/// 놀이 보기 칸(`QuizGrid`)이 쓴다. [aspect]는 칸의 높이/너비 비율.
/// 1~[maxRows]줄 중 칸이 가장 크게 나오는 배치를 고른다 (놀이 보기는 [TileGrid.quizMaxRows]줄).
/// 칸 수가 많아 [maxRows]줄로는 한 줄에 7칸을 넘게 되면 그 이상도 본다.
/// (최소 칸 크기를 지키며 넘치면 쪽을 나누는 것은 [PagedGrid.plan])
class TileGrid {
  const TileGrid(this.rows, this.cols, this.tile);
  final int rows;
  final int cols;

  /// 칸 너비 (높이는 tile * aspect)
  final double tile;

  static TileGrid fit(
    int count,
    Size area, {
    double aspect = 1,
    double gap = 12,
    double maxTile = double.infinity,
    int maxRows = 99,
  }) {
    var best = const TileGrid(1, 1, 0);
    // 한 줄에 7칸을 넘기면 너무 잘아지므로, 그만큼은 줄을 더 쓸 수 있게 한다
    final rowLimit = max(maxRows, (count / 7).ceil());
    for (var rows = 1; rows <= min(count, rowLimit); rows++) {
      final cols = (count / rows).ceil();
      // 줄 수를 늘려도 빈 줄이 생기면 건너뛴다
      if ((rows - 1) * cols >= count) continue;
      final w = (area.width - gap * (cols - 1)) / cols;
      final h = (area.height - gap * (rows - 1)) / rows / aspect;
      final tile = min(min(w, h), maxTile).floorToDouble();
      if (tile > best.tile + .5) best = TileGrid(rows, cols, tile);
    }
    return TileGrid(best.rows, best.cols, max(0, best.tile));
  }

  /// 놀이 보기·카드의 줄 수 한계 (1~3줄)
  static const quizMaxRows = 3;

  @override
  String toString() => 'TileGrid($rows x $cols, $tile)';
}

/// 칸 [first]~[last]-1을 [cols]칸씩 줄지어 놓는다 (칸 크기 고정, 사이 [gap]).
/// 앱의 모든 격자([PagedGrid], 놀이 보기 `QuizGrid`)가 이 배치 하나를 쓴다.
class GridRows extends StatelessWidget {
  const GridRows({
    super.key,
    this.first = 0,
    required this.last,
    required this.cols,
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
    required this.itemBuilder,
  });

  final int first;
  final int last;
  final int cols;
  final double cellWidth;
  final double cellHeight;
  final double gap;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var r = 0; first + r * cols < last; r++)
        Padding(
          padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var i = first + r * cols;
                i < min(last, first + (r + 1) * cols);
                i++
              ) ...[
                if (i > first + r * cols) SizedBox(width: gap),
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: itemBuilder(i),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

/// 옆으로 밀기 대신 쓰는 격자. 화면 크기에 맞춰 칸 크기를 자동으로 고르고,
/// 칸이 너무 많으면 양옆의 큰 화살표로 한 쪽씩 넘긴다. (아이는 밀어서 더 본다는 걸 모른다)
class PagedGrid extends StatefulWidget {
  const PagedGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minCellWidth = 72,
    this.minCellHeight = 72,
    this.maxCellWidth = double.infinity,
    this.maxCellHeight = double.infinity,
    this.maxRows = 99,
    this.gap = 10,
    this.initialIndex = 0,
    this.arrowSize = 64,
    this.arrowBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minCellWidth;
  final double minCellHeight;
  final double maxCellWidth;
  final double maxCellHeight;
  final int maxRows;
  final double gap;

  /// 처음에 보일 칸 (이 칸이 있는 쪽을 연다)
  final int initialIndex;
  final double arrowSize;

  /// 화살표 모양을 바꿀 때 (없으면 기본 [PageArrow]). 크기·이름("앞 쪽"/"다음 쪽")은 같게 만든다.
  final PageArrowBuilder? arrowBuilder;

  /// 칸 배치를 고른다. 다 들어가면 화살표 없이, 아니면 화살표 자리를 빼고 계산한다.
  static GridPlan plan({
    required Size area,
    required int count,
    double minCellWidth = 72,
    double minCellHeight = 72,
    double maxCellWidth = double.infinity,
    double maxCellHeight = double.infinity,
    int maxRows = 99,
    double gap = 10,
    double arrowSize = 64,
  }) {
    final n = max(1, count);
    int fit(double space, double minCell) =>
        max(1, ((space + gap) / (minCell + gap)).floor());
    double cell(double space, int k, double maxCell) =>
        min(maxCell, (space - gap * (k - 1)) / k);

    final rowsMax = min(maxRows, fit(area.height, minCellHeight));
    final colsMax = fit(area.width, minCellWidth);
    if (colsMax * rowsMax >= n) {
      // 다 들어간다: 칸이 가장 크게 나오는 줄 수를 고른다
      GridPlan? best;
      double bestScore = -1;
      for (var r = 1; r <= rowsMax; r++) {
        final c = (n / r).ceil();
        if (c > colsMax) continue;
        final w = cell(area.width, c, maxCellWidth);
        final h = cell(area.height, r, maxCellHeight);
        final score = min(w / minCellWidth, h / minCellHeight);
        if (score > bestScore + 1e-6) {
          bestScore = score;
          best = GridPlan(
            cols: c,
            rows: r,
            cellWidth: w,
            cellHeight: h,
            paged: false,
          );
        }
      }
      return best!;
    }
    // 쪽 넘기기: 양옆에 화살표 자리
    final inner = max(minCellWidth, area.width - 2 * (arrowSize + gap));
    final cols = fit(inner, minCellWidth);
    final rows = rowsMax;
    return GridPlan(
      cols: cols,
      rows: rows,
      cellWidth: cell(inner, cols, maxCellWidth),
      cellHeight: cell(area.height, rows, maxCellHeight),
      paged: true,
    );
  }

  @override
  State<PagedGrid> createState() => _PagedGridState();
}

class _PagedGridState extends State<PagedGrid> {
  int? _page;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final plan = PagedGrid.plan(
        area: Size(c.maxWidth, c.maxHeight),
        count: widget.itemCount,
        minCellWidth: widget.minCellWidth,
        minCellHeight: widget.minCellHeight,
        maxCellWidth: widget.maxCellWidth,
        maxCellHeight: widget.maxCellHeight,
        maxRows: widget.maxRows,
        gap: widget.gap,
        arrowSize: widget.arrowSize,
      );
      final pages = plan.pagesFor(widget.itemCount);
      final int page = min(
        max(0, pages - 1),
        max(0, _page ?? widget.initialIndex ~/ max(1, plan.perPage)),
      );
      final first = plan.paged ? page * plan.perPage : 0;
      final last = min(widget.itemCount, first + plan.perPage);

      final grid = GridRows(
        key: ValueKey(page),
        first: first,
        last: last,
        cols: plan.cols,
        cellWidth: plan.cellWidth,
        cellHeight: plan.cellHeight,
        gap: widget.gap,
        itemBuilder: (i) => widget.itemBuilder(context, i),
      );

      final body = AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: grid,
      );
      if (!plan.paged) return Center(child: body);

      final arrow = widget.arrowBuilder ?? PageArrow.new;
      return Row(
        children: [
          arrow(
            forward: false,
            size: widget.arrowSize,
            enabled: page > 0,
            onTap: () => setState(() => _page = page - 1),
          ),
          SizedBox(width: widget.gap),
          Expanded(child: Center(child: body)),
          SizedBox(width: widget.gap),
          arrow(
            forward: true,
            size: widget.arrowSize,
            enabled: page < pages - 1,
            onTap: () => setState(() => _page = page + 1),
          ),
        ],
      );
    },
  );
}

/// 쪽 넘기는 화살표를 만드는 함수 ([PageArrow.new]와 같은 모양)
typedef PageArrowBuilder = Widget Function({
  Key? key,
  required bool forward,
  required VoidCallback onTap,
  bool enabled,
  double size,
});

/// 쪽 넘기는 큰 화살표. 더 넘길 쪽이 없으면 흐려진다.
class PageArrow extends StatelessWidget {
  const PageArrow({
    super.key,
    required this.forward,
    required this.onTap,
    this.enabled = true,
    this.size = 64,
  });

  final bool forward;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: enabled ? 1 : .3,
    child: Pressable(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: forward ? '다음 쪽' : '앞 쪽',
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Palette.yellow,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Palette.coinDeep, offset: Offset(0, 5))],
        ),
        child: Icon(
          forward ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          size: size * .6,
          color: Colors.white,
        ),
      ),
    ),
  );
}
