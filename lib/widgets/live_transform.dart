import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [listenable]이 알릴 때마다 [transform]으로 자식을 옮기거나 늘려서 다시 그린다.
/// 위젯을 다시 만들지(setState) 않고 그리기만 다시 한다.
///
/// 왜 필요한가 (렉 줄이기): 위젯이 LayoutBuilder 안에서 setState를 하면, 그 LayoutBuilder가
/// 다시 배치(layout)되고 배치가 바뀐 칸은 모두 다시 그려진다. 홈의 캐릭터처럼 초당 20번 숨쉬는
/// 그림이 setState로 움직이면 버튼, 글자, 배경 칸까지 화면 전체를 초당 20번 다시 배치하고 그렸다
/// (test/perf_test.dart). 이 위젯으로 움직이면 이 칸만 다시 그린다.
///
/// - [transform]은 칸 크기를 받아 변환을 돌려준다 (null이면 그대로).
/// - 누르는 칸(hit test)은 옮기지 않는다: 움직임이 작아서 아이가 누르는 자리는 그대로다.
class LiveTransform extends SingleChildRenderObjectWidget {
  const LiveTransform({
    super.key,
    required this.listenable,
    required this.transform,
    super.child,
  });

  final Listenable listenable;
  final Matrix4? Function(Size size) transform;

  @override
  RenderLiveTransform createRenderObject(BuildContext context) =>
      RenderLiveTransform(listenable: listenable, transform: transform);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiveTransform renderObject,
  ) {
    renderObject
      ..listenable = listenable
      ..transform = transform;
  }
}

class RenderLiveTransform extends RenderProxyBox {
  RenderLiveTransform({
    required Listenable listenable,
    required Matrix4? Function(Size size) transform,
  }) : _listenable = listenable, // ignore: prefer_initializing_formals
       _transform = transform; // ignore: prefer_initializing_formals

  Listenable _listenable;
  set listenable(Listenable v) {
    if (identical(v, _listenable)) return;
    if (attached) _listenable.removeListener(markNeedsPaint);
    _listenable = v;
    if (attached) _listenable.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Matrix4? Function(Size size) _transform;
  set transform(Matrix4? Function(Size size) v) {
    if (identical(v, _transform)) return;
    _transform = v;
    markNeedsPaint();
  }

  /// 지금 변환 (테스트 확인용, 그대로면 null)
  @visibleForTesting
  Matrix4? get currentTransform => _transform(size);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _listenable.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final m = _transform(size);
    if (m == null) {
      layer = null;
      context.paintChild(c, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      m,
      (context, offset) => context.paintChild(c, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final m = _transform(size);
    if (m != null) transform.multiply(m);
  }
}

/// [size] 칸의 [origin](0..1 비율 자리)을 기준으로 [m]을 적용하는 변환
Matrix4 transformAround(Size size, Alignment origin, Matrix4 m) {
  final o = origin.alongSize(size);
  return Matrix4.translationValues(o.dx, o.dy, 0)
    ..multiply(m)
    ..multiply(Matrix4.translationValues(-o.dx, -o.dy, 0));
}
