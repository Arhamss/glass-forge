import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/material/glass_material.dart';
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
  RenderGlassShape({
    required this._shape,
    required this._group,
    this._material,
  });

  GlassShape _shape;
  BlendGroupLink? _group;
  GlassMaterial? _material;
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

  /// The material this shape renders with, or null to inherit the layer's.
  ///
  /// An override does not get its own `BackdropFilter`: the layer groups its
  /// shapes by material and pushes one pass per distinct one, so N materials
  /// cost N passes rather than one per shape. A shape inside a blend group
  /// cannot have its own material at all — see
  /// `RenderGlassLayer._reassignPasses`.
  GlassMaterial? get material => _material;
  set material(GlassMaterial? value) {
    if (_material == value) {
      return;
    }
    _material = value;
    // The group's opening marker does not move with this: a group renders
    // with one material regardless, so its members' markers are unaffected.
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

  /// What drives this shape's presence, or null for fully present.
  ///
  /// The animation's *identity* is what the layer keys this shape's pass
  /// by — see `RenderGlassLayer`'s `_PassKey` — so a value tick here never
  /// re-registers this shape into a different pass. Only a changed driver
  /// does, through [_syncGeometry] below, because that is a genuine change
  /// of which pass this shape belongs to.
  Animation<double>? get presence => _presence;
  Animation<double>? _presence;
  set presence(Animation<double>? value) {
    if (identical(_presence, value)) {
      return;
    }
    if (attached) {
      _presence?.removeListener(_onPresenceChanged);
    }
    _presence = value;
    if (attached) {
      value?.addListener(_onPresenceChanged);
    }
    // A changed *driver* re-keys the pass, unlike a changed value.
    _syncGeometry();
  }

  /// Reports this frame's presence value to the layer without re-syncing
  /// this shape's full geometry.
  ///
  /// Fires from the animation phase, before paint, so the value the layer
  /// folds into its pass at the top of `paint` is always this frame's.
  void _onPresenceChanged() {
    _layer?.updateShapePresence(this, _presence!.value);
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
  ///
  /// What the marker carries is the smooth-min's own width, which is not
  /// the number the caller gave. [BlendGroupLink.blend] is the widest gap
  /// that merges, in logical pixels. The shader's quadratic smooth-min
  /// lowers the surface by at most a quarter of its width, so a gap closes
  /// when half of it is under that: width = 2 x blend. And it goes in
  /// physical pixels, like every other length the shader folds with.
  ///
  /// Both used to be missing. The logical value went through unscaled,
  /// four to six times too narrow on a 2-3x phone: a gap the Blend screen
  /// said would bridge did not, or bridged through a pinched thread, and
  /// the fold's cull -- which trusts the same width -- dropped shapes the
  /// merge still needed.
  double _blendMarker(double devicePixelRatio) {
    final link = _group;
    if (link == null) {
      return encodeBlendMarker(startsGroup: true, blend: 0);
    }
    return encodeBlendMarker(
      startsGroup: link.isFirst(this),
      blend: 2 * link.blend * devicePixelRatio,
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _joinGroup();
    _presence?.addListener(_onPresenceChanged);
    _layer = _findAncestorLayer();
    _syncGeometry();
  }

  @override
  void detach() {
    _layer?.unregisterShape(this);
    _layer?.markNeedsPaint();
    _layer = null;
    _lastSyncedTransform = null;
    _justSyncedFromLayout = false;
    _leaveGroup();
    _presence?.removeListener(_onPresenceChanged);
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
    target.registerShape(
      this,
      ShapeGeometry.resolve(
        shape: _shape,
        size: size,
        toLayer: transform,
        devicePixelRatio: target.devicePixelRatio,
        blendMarker: _blendMarker(target.devicePixelRatio),
      ),
      _material,
      _group,
      _presence,
      _presence?.value ?? 1.0,
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
  ///
  /// That deferral is now the exception rather than the rule. The layer
  /// bakes its mattes *after* painting its subtree, so a shape painting
  /// inside that call has already been seen by the time the matte is baked
  /// and needs nothing extra — which is what
  /// `RenderGlassLayer.isPaintingSubtree` reports. It is still reachable,
  /// and still required, when a repaint boundary sits between the layer and
  /// this shape: the boundary repaints its own subtree without the layer
  /// painting at all, so this shape can move with nothing upstream of it
  /// running. Without the deferral that move would never reach a matte.
  void _syncGeometryIfTransformChanged() {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    final transform = getTransformTo(target);
    final needsExtraRepaint =
        !_justSyncedFromLayout && !target.isPaintingSubtree;
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
