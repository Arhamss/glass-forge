import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// Registers one shape with its layer, and paints its child in place.
///
/// Painting in place is the whole point. Upstream makes `paint` a no-op
/// behind an `// ignore: must_call_super` and paints children later from the
/// layer, which is why its children are invisible until shaders load, always
/// land at the layer's z-position, vanish inside a Hero flight or `toImage`,
/// and refract one frame behind their own content.
class RenderGlassShape extends RenderProxyBox {
  /// Creates a glass shape render object.
  RenderGlassShape({required this._shape, required this._group});

  GlassShape _shape;
  BlendGroupLink? _group;
  RenderGlassLayer? _layer;

  /// The shape to render.
  GlassShape get shape => _shape;
  set shape(GlassShape value) {
    if (_shape == value) {
      return;
    }
    _shape = value;
    _syncGeometry();
    markNeedsPaint();
  }

  /// The blend group this shape joins, if any.
  ///
  /// Ungrouped shapes still share the layer's single capture; they simply
  /// never smooth-min into a neighbour, which is what an absent group means
  /// to the shader.
  BlendGroupLink? get group => _group;
  set group(BlendGroupLink? value) {
    if (identical(_group, value)) {
      return;
    }
    if (attached) {
      _group?.remove(this);
    }
    _group = value;
    if (attached) {
      _group?.add(this);
    }
    _syncGeometry();
  }

  /// The marker this shape's geometry carries, derived from group
  /// membership: whoever [BlendGroupLink.isFirst] names opens the group.
  double get _blendMarker {
    final link = _group;
    if (link == null) {
      return encodeBlendMarker(startsGroup: true, blend: 0);
    }
    return encodeBlendMarker(
      startsGroup: link.isFirst(this),
      blend: link.blend,
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _group?.add(this);
    _layer = _findAncestorLayer();
    _syncGeometry();
  }

  @override
  void detach() {
    _layer?.scene.unregister(this);
    _layer?.markNeedsPaint();
    _layer = null;
    _group?.remove(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _syncGeometry();
  }

  /// Walks the render tree for the nearest enclosing [RenderGlassLayer].
  ///
  /// The widget layer only tracks *whether* an enclosing layer exists (via
  /// `GlassLayerScope`, for the orphan check); the render object it actually
  /// registers into is found here, in the render tree itself, which is the
  /// one structure guaranteed to match how this shape will really paint.
  RenderGlassLayer? _findAncestorLayer() {
    var node = parent;
    while (node != null) {
      if (node is RenderGlassLayer) {
        return node;
      }
      node = node.parent;
    }
    return null;
  }

  void _syncGeometry() {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    target.scene.register(
      this,
      ShapeGeometry.resolve(
        shape: _shape,
        size: size,
        toLayer: getTransformTo(target),
        devicePixelRatio: target.devicePixelRatio,
        blendMarker: _blendMarker,
      ),
    );
    target.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // In place. Deliberately ordinary.
    super.paint(context, offset);
  }
}
