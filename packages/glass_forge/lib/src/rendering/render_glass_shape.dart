import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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

  /// The transform-to-layer [_syncGeometryIfTransformChanged] last observed
  /// at paint time.
  ///
  /// Deliberately not the same value [performLayout]'s own [_syncGeometry]
  /// registers: layout can call it mid-layout, before an ancestor like
  /// `Padding`, `Align` or `Positioned` has assigned this frame's offset for
  /// its child (most of them assign it only *after* laying that child out,
  /// i.e. after this shape's own `performLayout` already ran), so comparing
  /// straight against that value here would treat routine settling as a
  /// real move. [_justSyncedFromLayout] is what tells paint to adopt
  /// whatever layout registered as this baseline, once, without re-deriving
  /// or re-registering it.
  Matrix4? _lastSyncedTransform;

  /// Whether [performLayout] registered this shape's geometry since the
  /// last paint.
  ///
  /// True for exactly one paint after every `performLayout` — the one where
  /// [_syncGeometryIfTransformChanged] should trust that registration as-is
  /// (see [_lastSyncedTransform]) rather than compare against it.
  bool _justSyncedFromLayout = false;

  /// Whether a post-frame callback to repaint [_layer] is already queued.
  bool _layerRepaintScheduled = false;

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
      _leaveGroup();
    }
    _group = value;
    if (attached) {
      _joinGroup();
    }
    _syncGeometry();
  }

  void _joinGroup() {
    _group?.add(this);
    _group?.addListener(_onGroupChanged);
  }

  void _leaveGroup() {
    _group?.removeListener(_onGroupChanged);
    _group?.remove(this);
  }

  /// Re-derives this shape's marker when group membership or blend changes
  /// out from under it.
  ///
  /// This is the whole reason [group] is a listenable: if this shape's own
  /// group's first member unmounts, *this* shape may become first without a
  /// single property of its own changing — nothing else would ever prompt it
  /// to re-sync.
  void _onGroupChanged() => _syncGeometry();

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
    _joinGroup();
    _layer = _findAncestorLayer();
    _syncGeometry();
  }

  @override
  void detach() {
    _layer?.scene.unregister(this);
    _layer?.markNeedsPaint();
    _layer = null;
    _lastSyncedTransform = null;
    _justSyncedFromLayout = false;
    _leaveGroup();
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
    _registerGeometry(target, getTransformTo(target));
    _justSyncedFromLayout = true;
    target.markNeedsPaint();
  }

  void _registerGeometry(RenderGlassLayer target, Matrix4 transform) {
    target.scene.register(
      this,
      ShapeGeometry.resolve(
        shape: _shape,
        size: size,
        toLayer: transform,
        devicePixelRatio: target.devicePixelRatio,
        blendMarker: _blendMarker,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _syncGeometryIfTransformChanged();
    // In place. Deliberately ordinary.
    super.paint(context, offset);
  }

  /// Catches a move [performLayout] did not.
  ///
  /// `Align` only repositions at paint time, and Flutter skips a child's own
  /// `performLayout` whenever its incoming constraints are unchanged —
  /// exactly what happens when `Positioned` (inside a `Stack`) changes only
  /// this shape's offset. Neither retriggers [_syncGeometry], so without
  /// this check this shape's registered geometry freezes wherever it was
  /// first laid out, forever, no matter how its content later moves. `paint`
  /// runs on every frame that content is actually asked to redraw, so
  /// comparing [getTransformTo] against [_lastSyncedTransform] here is what
  /// actually catches it.
  ///
  /// Always registers the freshly-read transform here, never the stale one
  /// [performLayout] saw — `getTransformTo` read from *inside* a shape's own
  /// `performLayout` can be missing an ancestor's contribution entirely: for
  /// a `Positioned` child, `RenderStack.performLayout` lays the child out
  /// *before* assigning `childParentData.offset` for this pass, so the
  /// shape's own `performLayout` runs while that offset still holds its
  /// previous value (`Offset.zero` on the very first layout). Silently
  /// keeping that stale value as authoritative — which an earlier version of
  /// this method did, treating the first post-layout paint as "just a
  /// baseline" — left a shape's registered geometry permanently wrong
  /// whenever nothing moved it a second time to trigger a correction.
  ///
  /// [_justSyncedFromLayout] still matters, but only for whether this
  /// schedules an extra repaint (see [_scheduleLayerRepaint]'s doc), not for
  /// whether it registers: forcing an extra frame unconditionally on every
  /// first post-layout paint is what broke a retained-clip-chain test that
  /// pumps exactly once and reads pixels straight off it. Registering the
  /// correct geometry costs nothing extra there — `_refreshMatte` was always
  /// going to read whatever the scene holds by the time it next runs, this
  /// just makes sure that is the right value instead of the wrong one.
  ///
  /// `RenderObject.markNeedsPaint` asserts it is never called while the
  /// pipeline owner is already painting, which is exactly the phase this
  /// runs in, so a genuine correction cannot repaint [_layer] synchronously
  /// either — [_scheduleLayerRepaint] defers that to the next frame, so the
  /// layer's matte catches up one frame late rather than never.
  void _syncGeometryIfTransformChanged() {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    final transform = getTransformTo(target);
    final needsExtraRepaint = !_justSyncedFromLayout;
    _justSyncedFromLayout = false;
    if (_lastSyncedTransform == transform) {
      return;
    }
    _lastSyncedTransform = transform;
    _registerGeometry(target, transform);
    if (needsExtraRepaint) {
      _scheduleLayerRepaint(target);
    }
  }

  void _scheduleLayerRepaint(RenderGlassLayer target) {
    if (_layerRepaintScheduled) {
      return;
    }
    _layerRepaintScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _layerRepaintScheduled = false;
      if (attached && identical(_layer, target)) {
        target.markNeedsPaint();
      }
    });
  }
}
