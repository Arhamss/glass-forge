import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
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
    this._lift,
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

  /// Whether this shape is in its pass's scene: painted, or composited
  /// from an earlier paint, where it really is.
  ///
  /// False from attach until the first paint, and again for every stretch
  /// in which it is attached and laid out but not drawn -- under an
  /// `Opacity` at zero, in an `IndexedStack`'s hidden children, in a lazy
  /// list's cache region. The layer keeps such a shape's registration, so
  /// its pass is ready the frame it appears, but leaves it out of the
  /// matte, the clusters and the diagnostics. See
  /// [syncGeometryIfSubtreePaintMissedIt] for how "not drawn" is told from
  /// "drawn from a repaint boundary's retained layer".
  bool _placed = false;

  /// Holds the empty layer this shape leaves where it paints, when a repaint
  /// boundary sits between it and [_layer]. See [_PlacementMarker].
  final LayerHandle<_PlacementMarker> _marker = LayerHandle<_PlacementMarker>();

  /// Whether a post-frame check of [_marker] is already queued.
  bool _placementCheckScheduled = false;

  /// Which of [_layer]'s subtree paints this shape last read its transform
  /// in, or null if it has not read one since it attached.
  ///
  /// The layer sweeps whatever this does not match after its subtree has
  /// painted — see [syncGeometryIfSubtreePaintMissedIt].
  int? _readInSubtreePaint;

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

  /// What lifts this shape's glass toward its lit version, or null for
  /// none. See `GlassLiftScope`.
  ///
  /// Handled exactly like [presence]: the animation's identity is part of
  /// this shape's pass key, and a value tick reaches the layer as a
  /// uniform through [_onLiftChanged] without re-sorting any pass.
  Animation<double>? get lift => _lift;
  Animation<double>? _lift;
  set lift(Animation<double>? value) {
    if (identical(_lift, value)) {
      return;
    }
    if (attached) {
      _lift?.removeListener(_onLiftChanged);
    }
    _lift = value;
    if (attached) {
      value?.addListener(_onLiftChanged);
    }
    _syncGeometry();
  }

  void _onLiftChanged() {
    _layer?.updateShapeLift(this, _lift!.value);
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
    _lift?.addListener(_onLiftChanged);
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
    _readInSubtreePaint = null;
    _placed = false;
    _marker.layer?.remove();
    _marker.layer = null;
    _leaveGroup();
    _presence?.removeListener(_onPresenceChanged);
    _lift?.removeListener(_onLiftChanged);
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
  /// Nor is one rendered from where a shape lays out and is then not
  /// painted -- a lazy list's rows in the cache region, built and laid out
  /// ahead of the viewport and skipped by `RenderSliverMultiBoxAdaptor.paint`,
  /// or anything under an `Opacity` at zero. Registration keeps such a shape
  /// in its pass's *assignment*, so the pass is pushed the frame it first
  /// paints, but [_placed] keeps it out of the pass's *scene* until then, and
  /// [syncGeometryIfSubtreePaintMissedIt] takes it back out when it stops
  /// being drawn. The placeholder still has to be nothing rather than a
  /// guess: registering the identity puts it at the layer's own origin,
  /// which was a phantom refraction in the corner of the screen before
  /// [_placed] existed, and is still what the layer's whole-layer registry
  /// and its diagnostics would read. Hence [_nowhereYet].
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
  /// resolves an empty basis and an empty box at the layer's origin — the
  /// shape registers, taking its place in the layer's pass assignment
  /// alongside its material and blend group, and is held out of the matte
  /// until its first paint says where it is. `Matrix4.zero` on its own will
  /// not do: `MatrixUtils.transformPoint` divides by the w row, so a fully zero
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
      placed: _placed,
      liftScope: _lift,
      lift: _lift?.value ?? 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _syncGeometryIfTransformChanged();
    final target = _layer;
    if (target != null &&
        !target.isSubtreeContext(context) &&
        _hasRepaintBoundaryBelow(target)) {
      final marker = _marker.layer ??= _PlacementMarker(
        _schedulePlacementCheck,
      );
      context.addLayer(marker);
    } else {
      _marker.layer?.remove();
      _marker.layer = null;
    }
    // In place. Deliberately ordinary.
    super.paint(context, offset);
  }

  /// Whether a repaint boundary sits between this shape and [target].
  ///
  /// Where one does, the boundary can put this shape on screen from its
  /// retained layer without this shape painting at all, so "did not paint"
  /// stops meaning "not drawn". That is the one case [_marker] exists for.
  ///
  /// [paint] asks only when it was not handed [target]'s own subtree
  /// context (`RenderGlassLayer.isSubtreeContext`), which already rules a
  /// boundary out, so a shape moving directly under its layer never walks.
  /// Not cached across attach and detach: whether an ancestor is a boundary
  /// can change with neither -- `ImageFiltered` is one only while enabled
  /// -- and a stale "no" here would withdraw a shape its boundary is still
  /// drawing. A cache of that kind failed the test that pins this.
  bool _hasRepaintBoundaryBelow(RenderGlassLayer target) {
    GlassRenderCounters.instance.recordBoundaryWalk();
    for (
      var node = parent;
      node != null && !identical(node, target);
      node = node.parent
    ) {
      if (node.isRepaintBoundary) {
        return true;
      }
    }
    return false;
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
  ///
  /// [placed] is whether the shape is on screen: true from [paint], and
  /// whatever [syncGeometryIfSubtreePaintMissedIt] found for a shape that
  /// missed its layer's paint. A change in it registers even when the
  /// transform has not moved, and never otherwise.
  void _syncGeometryIfTransformChanged({bool placed = true}) {
    final target = _layer;
    if (target == null || !hasSize || !attached) {
      return;
    }
    _readInSubtreePaint = target.subtreePaint;
    final transform = getTransformTo(target);
    final wasPlaceholder = _justSyncedFromLayout;
    final wasPlaced = _placed;
    final needsExtraRepaint = !wasPlaceholder && !target.isPaintingSubtree;
    _justSyncedFromLayout = false;
    _placed = placed;
    if (_lastSyncedTransform == transform &&
        !wasPlaceholder &&
        wasPlaced == placed) {
      return;
    }
    _lastSyncedTransform = transform;
    _registerGeometry(target, transform);
    if (needsExtraRepaint) {
      _scheduleLayerRepaint(target);
    }
  }

  /// Reads this shape's transform on [target]'s behalf, if this shape did
  /// not already read it inside the subtree paint [target] has just made --
  /// or takes it out of its pass, if it is not on screen at all.
  ///
  /// A shape can miss that paint for two opposite reasons, and this is
  /// where they are told apart.
  ///
  /// **It is on screen, drawn from a repaint boundary's retained layer.**
  /// A shape moves without painting whenever something between it and the
  /// layer moves it and a repaint boundary in between absorbs the repaint --
  /// every row of a `ListView` is wrapped in one, and a scroll re-lays out
  /// nothing, so a scrolled row neither lays out nor paints. Nothing else
  /// would ever ask it where it went, and what it holds is where it was
  /// when it last painted. See `RenderGlassLayer._resyncShapesThatDidNotPaint`
  /// for why the moment straight after the subtree paint is the one to ask
  /// in, and what asking costs.
  ///
  /// **It is not on screen.** An ancestor laid it out and then chose not to
  /// paint it: `Opacity` at zero, `Offstage`, an `IndexedStack`'s other
  /// children, a lazy list's cache region. Left in its pass, it would stay
  /// in the matte wherever it last registered -- a refraction with nothing
  /// over it, and a member of whichever cluster sits there.
  ///
  /// With no repaint boundary between this shape and [target], only the
  /// second is possible: [target] painted its subtree, so everything in it
  /// that anything painted, painted. With one in between, [_marker] says
  /// which: it sits in the boundary's retained layer, so it hangs from the
  /// layer tree [target] has just painted into -- [subtreeRoot] -- exactly
  /// when that boundary was composited into it this frame. A layer that
  /// was not is dropped from its old parent when that parent repaints, so
  /// the walk up from [_marker] ends somewhere else.
  ///
  /// Either way the transform is re-read, so the layer's whole-layer
  /// registry holds where the shape really is even while it is out of its
  /// pass -- a row scrolled into the cache region is at -130, not where it
  /// was last drawn.
  ///
  /// Cheap when there is nothing to do: one identity check and one integer
  /// comparison, no walk. A shape that did take part in that paint has
  /// already registered this frame's transform and is left alone. A shape
  /// that has **never** painted is left alone too: it has never been placed,
  /// so there is nothing to withdraw, and it has no transform to re-read
  /// that is not a guess.
  void syncGeometryIfSubtreePaintMissedIt(
    RenderGlassLayer target,
    Layer Function() subtreeRoot,
  ) {
    if (!identical(_layer, target) ||
        _lastSyncedTransform == null ||
        _readInSubtreePaint == target.subtreePaint) {
      return;
    }
    final marker = _marker.layer;
    _syncGeometryIfTransformChanged(
      placed: marker != null && identical(_rootOf(marker), subtreeRoot()),
    );
  }

  static Layer _rootOf(Layer layer) {
    var node = layer;
    for (var up = node.parent; up != null; up = up.parent) {
      node = up;
    }
    return node;
  }

  /// Checks, once this frame is composited, whether [_marker] being moved
  /// in or out of the layer tree changed whether this shape is on screen,
  /// and has [_layer] repaint if it did.
  ///
  /// [syncGeometryIfSubtreePaintMissedIt] only runs when [_layer] paints,
  /// and a repaint boundary between the two can hide or show this shape
  /// without it: an `Opacity` inside a list row reaching zero repaints the
  /// row and nothing above it. Without this, the matte would keep this
  /// shape, or keep missing it, until something else made the layer paint.
  ///
  /// After the frame, not now: the marker is detached and re-attached every
  /// time its boundary's layer is re-appended, which is every frame a
  /// scrolling list repaints, so only the settled tree says anything. And
  /// only a mismatch repaints, so a repaint that settles it asks for no
  /// other.
  void _schedulePlacementCheck() {
    if (_placementCheckScheduled) {
      return;
    }
    _placementCheckScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _placementCheckScheduled = false;
      final marker = _marker.layer;
      final target = _layer;
      if (marker == null || target == null || !attached) {
        return;
      }
      if (marker.attached != _placed) {
        target.markNeedsPaint();
      }
    });
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

/// An empty layer a shape adds where it paints, so the layer tree can say
/// later whether that paint is still on screen.
///
/// It draws nothing and costs one split in its boundary's picture, which is
/// why a shape adds it only where a repaint boundary sits between it and its
/// glass layer -- the one case where "did not paint this frame" and "not on
/// screen" come apart. See
/// `RenderGlassShape.syncGeometryIfSubtreePaintMissedIt`.
class _PlacementMarker extends ContainerLayer {
  _PlacementMarker(this._onMoved);

  final VoidCallback _onMoved;

  @override
  void attach(Object owner) {
    super.attach(owner);
    _onMoved();
  }

  @override
  void detach() {
    super.detach();
    _onMoved();
  }
}
