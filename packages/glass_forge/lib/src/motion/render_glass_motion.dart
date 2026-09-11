import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';

/// Applies a [GlassMotionController]'s live deformation to its child.
///
/// Subscribes to the controller and calls [markNeedsPaint] — never
/// `setState`, never an `AnimatedBuilder`. A spring running at 120 Hz costs
/// one paint per frame of this subtree and zero element rebuilds.
///
/// The transform is applied in [paint] **and** in [applyPaintTransform],
/// which is the half that matters for glass: `RenderGlassShape` re-reads
/// `getTransformTo(layer)` every time it paints and re-registers the
/// resulting basis with the scene, and `getTransformTo` is built out of
/// ancestors' `applyPaintTransform`. Painting the transform without
/// reporting it would move the pixels and leave the refraction behind.
class RenderGlassMotion extends RenderProxyBox {
  /// Creates a motion box driven by a [GlassMotionController].
  RenderGlassMotion({
    required this._controller,
    required this._jiggle,
    required this._pressScale,
  });

  GlassMotionController _controller;
  GlassJiggle _jiggle;
  double _pressScale;

  /// The controller driving this surface.
  GlassMotionController get controller => _controller;
  set controller(GlassMotionController value) {
    if (identical(_controller, value)) {
      return;
    }
    if (attached) {
      _controller.removeListener(markNeedsPaint);
    }
    _controller = value;
    if (attached) {
      _controller.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  /// How velocity becomes squash and stretch.
  GlassJiggle get jiggle => _jiggle;
  set jiggle(GlassJiggle value) {
    if (_jiggle.maxStretch == value.maxStretch &&
        _jiggle.halfSpeed == value.halfSpeed) {
      return;
    }
    _jiggle = value;
    markNeedsPaint();
  }

  /// The scale a fully pressed surface shrinks to.
  double get pressScale => _pressScale;
  set pressScale(double value) {
    if (_pressScale == value) {
      return;
    }
    _pressScale = value;
    markNeedsPaint();
  }

  Matrix4 get _transform {
    if (!hasSize) {
      return Matrix4.identity();
    }
    return glassSurfaceTransform(
      size: size,
      state: _controller.value,
      jiggle: _jiggle,
      pressScale: _pressScale,
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final transform = _transform;
    final asTranslation = MatrixUtils.getAsTranslation(transform);
    if (asTranslation != null) {
      // A surface at rest, or one that is only displaced, needs no layer and
      // no canvas transform at all. This is the state a settled glass
      // surface sits in for the whole time nobody is touching it.
      super.paint(context, offset + asTranslation);
      layer = null;
      return;
    }
    final determinant = transform.determinant();
    if (determinant == 0 || !determinant.isFinite) {
      // A surface pressed all the way to zero scale has no area to paint
      // into, and a singular matrix cannot be inverted for hit testing
      // either. Dropping the layer is what `RenderTransform` does here, for
      // the same reason.
      layer = null;
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Deliberately skips [RenderBox.hitTest]'s `size.contains(position)`
    // gate, the same way `RenderTransform` does: this box keeps its
    // laid-out size while its child paints somewhere else entirely, so a
    // finger resting on a surface that has been dragged forty pixels away
    // is outside these bounds and on the thing it is touching. Keeping the
    // gate is what would make a dragged surface stop responding to the
    // finger still holding it.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (innerResult, innerPosition) {
        return super.hitTestChildren(innerResult, position: innerPosition);
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<GlassMotionState>(
          'state',
          _controller.value,
        ),
      )
      ..add(EnumProperty<GlassMotionPhase>('phase', _controller.phase));
  }
}
