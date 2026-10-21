import 'package:flutter/material.dart';

/// 화면 높이가 [minHeight]보다 낮으면 앱 전체를 [minHeight] 높이로 그린 뒤 통째로 줄인다.
/// (아주 낮은 가로 휴대폰에서도 버튼·글자가 잘리지 않게. 사양: 높이 340 미만이면 전체 축소)
class MinHeightScaler extends StatelessWidget {
  const MinHeightScaler({
    super.key,
    required this.child,
    this.minHeight = defaultMinHeight,
  });

  static const defaultMinHeight = 340.0;

  final Widget child;
  final double minHeight;

  /// 이 화면 크기에서 줄이는 배율 (1이면 그대로)
  static double scaleFor(Size size, {double minHeight = defaultMinHeight}) =>
      size.height <= 0 || size.height >= minHeight
      ? 1
      : size.height / minHeight;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = scaleFor(mq.size, minHeight: minHeight);
    if (scale == 1) return child;
    final logical = mq.size / scale;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: logical.width,
        maxWidth: logical.width,
        minHeight: logical.height,
        maxHeight: logical.height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: MediaQuery(
            // 노치·홈 인디케이터 여백은 실제 크기를 지키도록 같은 비율로 키운다
            data: mq.copyWith(
              size: logical,
              padding: mq.padding / scale,
              viewPadding: mq.viewPadding / scale,
              viewInsets: mq.viewInsets / scale,
              systemGestureInsets: mq.systemGestureInsets / scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 모든 화면 전환을 짧은 페이드로 (MaterialPageRoute도 미끄러지지 않게)
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

const fadePageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadePageTransitionsBuilder(),
    TargetPlatform.iOS: FadePageTransitionsBuilder(),
    TargetPlatform.macOS: FadePageTransitionsBuilder(),
    TargetPlatform.windows: FadePageTransitionsBuilder(),
    TargetPlatform.linux: FadePageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadePageTransitionsBuilder(),
  },
);
