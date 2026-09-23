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
    this._presence,
    this._material,
  });

  GlassShape _shape;
  BlendGroupLink? _group;
  GlassMaterial? _material;
  RenderGlassLayer? _layer;

  /// The transform-to-layer [_syncGeometryIfTransformChanged] last observed
  /// at paint time, and the only transform this shape has ever really read.
  ///
  /// Paint is the one phase where [getTransformTo] both *may* be called and
  /// *answers correctly* — see [_syncGeometry] for why layout is neither —
  /// so this doubles as the baseline a later paint compares against and as
  /// the placeholder [_syncGeometry] re-registers while it waits for one.
  Matrix4? _lastSyncedTransform;

  /// Whether [_syncGeometry] registered a placeholder transform since the
  /// last paint.
  ///
  /// True for exactly one paint after every [_syncGeometry] — the one where
  /// [_syncGeometryIfTransformChanged] must register whatever it reads even
  /// if that equals [_lastSyncedTransform], because what the layer is
  /// holding right now is the placeholder, not that baseline.
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

  /// Tells the layer this shape exists, with what it will render as — and
  /// deliberately **without** reading where it is.
  ///
  /// Everything here that the layer acts on before it paints is settled by
  /// now: which shapes exist, each one's material, each one's blend group,
  /// and what drives its presence. `RenderGlassLayer.paint` decides which
  /// passes to push from exactly those, before a single child paints, which
  /// is why this has to run from [performLayout], [attach] and the setters
  /// rather than wait for paint. A shape that only announced itself at
  /// paint time would be a frame late into its own pass.
  ///
  /// Where it is, though, is not knowable here. Every caller of this can run
  /// inside a layout pass — [performLayout] by definition, [attach] and the
  /// setters whenever a lazy sliver builds its children from inside its own
  /// `performLayout` — and `getTransformTo` walks this shape's ancestors
  /// calling `applyPaintTransform` on each, which mid-layout is both illegal
  /// and wrong:
  ///
  ///  * **Illegal.** `RenderBox.size` asserts `hasSize` against an ancestor
  ///    that has not been laid out yet — a `Transform` (Material's stretch
  ///    overscroll indicator is one), a `FittedBox` — and asserts
  ///    `sizeAccessAllowed` against one that *has* a size but is not in its
  ///    own layout scope, which is every ancestor above a relayout boundary
  ///    during a scroll. `RenderSliverMultiBoxAdaptor` meanwhile reads the
  ///    child's `layoutOffset`, which it assigns only *after* laying that
  ///    child out, and null-checks it. Three exception shapes, one cause.
  ///  * **Wrong.** Even where it does not throw it answers with the previous
  ///    frame's offsets: `Padding`, `Align`, `Positioned` and `Column` all
  ///    assign a child's offset after laying that child out, so a walk from
  ///    inside this shape's own `performLayout` cannot see this frame's.
  ///
  /// So the transform is read in exactly one place — [paint], the only phase
  /// where the walk is both permitted and correct. What goes in here is a
  /// placeholder: the last transform paint read, or [_nowhereYet] for a
  /// shape that has never painted. [_justSyncedFromLayout] then makes the
  /// next paint register what it reads unconditionally, even if it matches
  /// [_lastSyncedTransform], because the layer is holding the placeholder.
  ///
  /// In the ordinary case no placeholder is ever rendered from.
  /// `RenderObject.layout` ends with `markNeedsPaint`, so a shape that laid
  /// out paints in the same frame; the layer bakes its mattes only *after*
  /// its subtree paints (see `RenderGlassLayer._pushBackdropPasses`); and
  /// nothing between those two points reads a shape's transform. Where a
  /// repaint boundary means the layer itself does not paint, it bakes
  /// nothing that frame either, and [_scheduleLayerRepaint] brings it along.
  ///
  /// The case that does render from one is a shape that lays out and then is
  /// never painted — a lazy list's rows in the cache region, which are built
  /// and laid out ahead of the viewport and skipped by
  /// `RenderSliverMultiBoxAdaptor.paint`. Re-registering the last transform
  /// is right for those: it is where the shape was when it last painted, and
  /// holding still is what it does. A shape that has *never* painted has no
  /// such answer and must not invent one — registering the identity puts it
  /// at the layer's own origin, which is a phantom refraction in the corner
  /// of the screen, seen in exactly this case while writing this fix. Hence
  /// [_nowhereYet].
  void _syncGeometry() {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    _registerGeometry(target, _lastSyncedTransform ?? _nowhereYet);
    _justSyncedFromLayout = true;
    target.markNeedsPaint();
  }

  /// The placeholder transform for a shape that has never painted.
  ///
  /// Deliberately singular: zero in the linear part, so `ShapeGeometry`
  /// resolves an empty basis and the shader's coverage term collapses — the
  /// shape registers, taking its place in the layer's pass assignment
  /// alongside its material and blend group, and draws nothing until its
  /// first paint says where it is. `Matrix4.zero` on its own will not do:
  /// `MatrixUtils.transformPoint` divides by the w row, so a fully zero
  /// matrix resolves an origin of NaN rather than of nothing.
  static final Matrix4 _nowhereYet = Matrix4.zero()..setEntry(3, 3, 1);

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
  /// This is also the *only* place the transform is read at all: [paint] is
  /// the one phase where walking ancestors is both permitted and correct,
  /// for the reasons set out on [_syncGeometry]. So a paint that follows a
  /// [_syncGeometry] has to register what it reads even when that equals
  /// [_lastSyncedTransform], because what the layer holds at that moment is
  /// the placeholder that call left, not this baseline —
  /// [_justSyncedFromLayout] is what says so. Silently keeping a stale value
  /// as authoritative — which an earlier version of this method did,
  /// treating the first post-layout paint as "just a baseline" — left a
  /// shape's registered geometry permanently wrong whenever nothing moved it
  /// a second time to trigger a correction.
  ///
  /// [_justSyncedFromLayout] does not, however, force an extra repaint:
  /// forcing an extra frame unconditionally on every first post-layout paint
  /// is what broke a retained-clip-chain test that pumps exactly once and
  /// reads pixels straight off it. It does not need to — [_syncGeometry]
  /// marked the layer for paint itself, so the layer is already coming.
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
    final wasPlaceholder = _justSyncedFromLayout;
    final needsExtraRepaint = !wasPlaceholder && !target.isPaintingSubtree;
    _justSyncedFromLayout = false;
    if (_lastSyncedTransform == transform && !wasPlaceholder) {
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
