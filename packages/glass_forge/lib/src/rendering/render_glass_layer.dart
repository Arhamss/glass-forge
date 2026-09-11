import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/composition/retained_clip_chain.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// Un-does the registry's "register the shipped accelerated producers once"
/// guard, so a test can observe registration happening fresh, paired with
/// [ProducerRegistry.debugReset]. Test-only.
///
/// Kept here as a delegating shim: the guard itself moved to
/// [ProducerRegistry] when the tier engine's capability probe became a
/// second caller that needs the list populated, and callers of this name
/// should not have to care which file holds the flag.
@visibleForTesting
void debugResetAcceleratedProducerRegistration() {
  ProducerRegistry.debugReset();
}

/// One backdrop pass: every shape in this layer that renders with the same
/// material, and the single filter they share.
///
/// Grouping is by material rather than by shape because a backdrop filter is
/// the expensive thing, not a shape. N materials cost N passes; the common
/// case of one material still costs exactly one, which is what the
/// `GlassComposition` invariant is really about.
class _GlassPass {
  _GlassPass(this.material);

  /// The material every shape in [scene] renders with.
  final GlassMaterial material;

  /// Just this pass's shapes, in registration order.
  ///
  /// Deliberately separate from [RenderGlassLayer.scene], which stays the
  /// whole layer's registry: the matte a pass bakes has to contain its own
  /// shapes and nothing else. The geometry shader folds whatever array it is
  /// handed with a smooth-min, so a foreign shape in that array is a foreign
  /// bulge in this pass's surface -- and its coverage would then be filled
  /// with the wrong material.
  final GlassScene scene = GlassScene();

  final GlassComposition composition = GlassComposition();

  /// The matte baked for [scene], if any.
  MatteGeneration? matte;

  /// The `(revision, generation, request)` triple [matte] was last asked
  /// for under. See [RenderGlassLayer._refreshMatte].
  int? refreshedRevision;
  int? refreshedGeneration;
  MatteRequest? refreshedRequest;
}

/// What one registered shape asked for, and which pass it currently sits in.
class _ShapeRecord {
  _ShapeRecord({
    required this.geometry,
    required this.declared,
    required this.group,
  });

  ShapeGeometry geometry;

  /// The material this shape declared, or null to inherit the layer's.
  GlassMaterial? declared;

  /// The blend group this shape joined, held only for identity.
  Object? group;

  /// The pass this shape is currently registered into.
  GlassMaterial? assigned;
}

/// Owns one backdrop capture per distinct material, and the scene they are
/// shaped by.
///
/// Always built as soon as a `GlassLayer` widget is, regardless of whether
/// its shaders have finished loading — unlike upstream, which withholds its
/// whole layer (and therefore every descendant's registration point) until
/// then. [paint] simply skips the backdrop passes while
/// [ShaderLibrary.isReady] is false, painting the subtree unglassed; the
/// warm-up callback started in the constructor repaints once shaders land.
/// A geometry producer not yet ready for other reasons (an accelerated
/// producer's own shader bundle still loading) degrades differently and more
/// mildly: [_refreshMatte] gets back a null matte, the shader binds a
/// transparent placeholder for it, and the pass renders its frost with no
/// refraction until the producer catches up.
class RenderGlassLayer extends RenderProxyBox {
  /// Creates a glass layer.
  RenderGlassLayer({
    required this._material,
    required GeometryTier tier,
    required this._devicePixelRatio,
  }) : _tier = tier,
       _producer = _selectProducer(tier) {
    unawaited(_warmUp());
  }

  /// Registers the accelerated producers, then selects one for [tier].
  ///
  /// Registration has to happen before [ProducerRegistry.select] runs, so
  /// it is folded into the same static call the constructor's initializer
  /// list uses for `_producer` -- an initializer list has no earlier point
  /// to hook a side effect into.
  static GeometryProducer _selectProducer(GeometryTier tier) {
    ProducerRegistry.ensureAcceleratedRegistered();
    return ProducerRegistry.select(tier: tier);
  }

  /// Every shape belonging to this layer, in registration order.
  ///
  /// The whole layer's set, not one pass's: this is what the clip-chain walk
  /// anchors on and what diagnostics read. The per-pass subsets live in
  /// [_GlassPass.scene].
  final GlassScene scene = GlassScene();

  final RetainedClipChain _clipChain = RetainedClipChain();

  /// The ancestor clips most recently retained for re-pushing. Test-only.
  @visibleForTesting
  List<RetainedClip> get debugClipChain => _clipChain.clips;

  /// What every registered shape declared, in registration order.
  final Map<Object, _ShapeRecord> _records = <Object, _ShapeRecord>{};

  /// One pass per distinct material among [_records], in the order each
  /// material's first shape registered.
  final Map<GlassMaterial, _GlassPass> _passes =
      <GlassMaterial, _GlassPass>{};

  /// Whether [_reassignPasses] has work to do.
  ///
  /// Set only when something that decides *which* pass a shape belongs to
  /// moves — a shape appearing or leaving, its declared material, its blend
  /// group, or this layer's own material. A shape re-registering a moved
  /// transform, which happens on every animating frame, deliberately does
  /// not set it: that is the hot path, and its pass is already known.
  bool _assignmentsDirty = false;

  /// Whether [paint] is inside the call that paints this layer's subtree.
  ///
  /// Read by `RenderGlassShape` to tell a repaint it is nested inside — where
  /// the matte is still ahead of it and will pick up whatever it registers —
  /// from one triggered below an intervening repaint boundary, where this
  /// layer is not painting at all and has to be asked for a later frame.
  bool _paintingSubtree = false;

  /// Whether this layer is currently painting its own subtree.
  bool get isPaintingSubtree => _paintingSubtree;

  GeometryProducer _producer;

  GlassMaterial _material;
  GeometryTier _tier;
  double _devicePixelRatio;
  bool _disposed = false;

  /// Bumped once, the moment [_warmUp] settles (successfully or not; see
  /// [_warmUp]'s own doc comment).
  ///
  /// [_refreshMatte] pairs this with the scene revision it last asked
  /// [_producer] about, so it knows when a fresh answer might actually
  /// differ. Without it, a producer not yet ready on an early paint (an
  /// accelerated producer's own shader bundle is still loading) returns
  /// null, `_matte` stays null, and [_refreshMatte]'s "does the cached
  /// matte's revision still match" check -- which requires a non-null
  /// `_matte` to short-circuit at all -- can never skip a re-attempt no
  /// matter how many further paints happen before the scene next actually
  /// changes. This does not gate [paint] itself: an accelerated producer
  /// that is not yet ready still renders unglassed for those first frames,
  /// exactly as it did before Task 18, via `_composition.build` returning
  /// null for a null matte -- gating [paint] directly on this instead was
  /// tried and reverted, because doing so forces at least one microtask's
  /// worth of delay before *any* producer's very first paint can proceed,
  /// including a `RuntimeGeometryProducer` whose warm-up was already
  /// complete (a pre-warmed `ShaderLibrary`) before this layer was even
  /// constructed -- see this file's test suite and the Task 18 fix report
  /// for the regression that caused.
  int _producerGeneration = 0;

  /// The geometry producer currently in use. Test-only.
  ///
  /// Exposed so a regression test can confirm the fallback in [_warmUp]:
  /// a producer selected as available at construction time, but that turns
  /// out not to be once its own warm-up completes (for example an
  /// accelerated shader bundle that failed to build), is swapped out for a
  /// working [RuntimeGeometryProducer] rather than left in place returning
  /// null forever.
  @visibleForTesting
  GeometryProducer get debugProducer => _producer;

  /// Warms up whatever [_producer] needs, plus the shared runtime-effect
  /// [ShaderLibrary] the final composite pass always uses regardless of
  /// which geometry producer is active.
  ///
  /// [GeometryProducer.capabilities] can only answer from information
  /// available synchronously at selection time -- for
  /// `GpuGeometryProducer`, that means "the GPU context works", not "the
  /// shader bundle actually loaded", since loading it is unavoidably
  /// asynchronous. So a producer selected as available can still turn out
  /// not to be, once its warm-up finishes and it has had a chance to try.
  /// When that happens here, [_producer] is replaced with a fresh
  /// [RuntimeGeometryProducer] -- always available, already proven to
  /// render correctly -- so a bundle that failed to build degrades a glass
  /// layer to the runtime-effect path, not to permanently unrefracted
  /// rendering.
  Future<void> _warmUp() async {
    await Future.wait(<Future<void>>[
      ShaderLibrary.instance.warmUp(),
      _producer.warmUp(),
    ]);
    if (_disposed) {
      return;
    }
    if (!_producer.capabilities.available) {
      final failed = _producer;
      _producer = RuntimeGeometryProducer();
      failed.dispose();
    }
    _producerGeneration++;
    if (attached && !_disposed) {
      markNeedsPaint();
    }
  }

  /// Physical pixels per logical pixel.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// How this layer's glass looks by default.
  ///
  /// The material every shape that declared none of its own renders with. A
  /// shape that did declare one is unaffected by changes here, which is why
  /// this only marks the pass assignment dirty rather than invalidating any
  /// matte directly.
  GlassMaterial get material => _material;
  set material(GlassMaterial value) {
    if (_material == value) {
      return;
    }
    _material = value;
    _assignmentsDirty = true;
    markNeedsPaint();
  }

  /// How much geometry work this layer may do.
  ///
  /// Settable, not fixed at construction, because the tier engine downgrades
  /// live: a device that starts accelerated and then overheats, or starts
  /// missing frames, has to be able to drop to the runtime producer and then
  /// to no matte at all without the widget tree being rebuilt around it. A
  /// construction-only tier would mean the only way to act on a thermal or
  /// frame-health signal is to throw away the layer -- and with it the
  /// backdrop capture, the retained clips and every registered shape.
  ///
  /// Swapping producers retires the current matte through the producer that
  /// made it, before that producer is disposed: a generation outlives the
  /// scene it came from, and releasing it afterwards would hand a texture to
  /// an owner that has already let go of it.
  GeometryTier get tier => _tier;
  set tier(GeometryTier value) {
    if (_tier == value) {
      return;
    }
    _tier = value;
    final retiring = _producer;
    for (final pass in _passes.values) {
      final matte = pass.matte;
      if (matte != null) {
        retiring.release(matte);
      }
      pass.matte = null;
    }
    _producer = _selectProducer(value);
    retiring.dispose();
    // The new producer has not warmed up, so _refreshMatte must ask it again
    // rather than trust the (revision, generation, request) triple the old
    // one answered for. Bumping the generation is exactly that signal; the
    // warm-up bumps it a second time when it settles.
    _producerGeneration++;
    unawaited(_warmUp());
    markNeedsPaint();
  }

  /// Registers [key]'s geometry, and what it asked to render with.
  ///
  /// [material] null means "whatever this layer's is"; [group] is the blend
  /// group the shape joined, held only for identity.
  void registerShape(
    Object key,
    ShapeGeometry geometry,
    GlassMaterial? material,
    Object? group,
  ) {
    scene.register(key, geometry);

    final existing = _records[key];
    if (existing == null) {
      _records[key] = _ShapeRecord(
        geometry: geometry,
        declared: material,
        group: group,
      );
      _assignmentsDirty = true;
      return;
    }

    existing.geometry = geometry;
    if (existing.declared != material || !identical(existing.group, group)) {
      existing
        ..declared = material
        ..group = group;
      _assignmentsDirty = true;
      return;
    }

    // The hot path: a shape that only moved. Its pass is already decided, so
    // the new geometry goes straight in -- this runs for every shape on
    // every animating frame, from inside this layer's own subtree paint.
    final assigned = existing.assigned;
    if (assigned != null) {
      _passes[assigned]?.scene.register(key, geometry);
    }
  }

  /// Removes [key] from this layer.
  void unregisterShape(Object key) {
    scene.unregister(key);
    final record = _records.remove(key);
    if (record == null) {
      return;
    }
    final assigned = record.assigned;
    if (assigned != null) {
      _passes[assigned]?.scene.unregister(key);
    }
    // A pass whose last shape just left still holds a matte and a shader.
    _assignmentsDirty = true;
  }

  /// Sorts every registered shape into the pass that will render it.
  ///
  /// A blend group is one continuous surface, and one surface has one
  /// material: the smooth-min in `common/scene.glsl` only reaches shapes
  /// folded into the same matte, so a group split across two passes would
  /// not merge at all -- the members would simply overlap, with a hard seam
  /// where the caller asked for a join. So a group takes the material its
  /// first-registered member asked for and the rest follow it, honouring the
  /// blend (the thing the caller wrote down and can see) over an override
  /// that cannot be honoured alongside it.
  ///
  /// Keeping the group whole is also what keeps each pass's shape array
  /// well-formed. The fold reads a per-shape marker saying "opens a group"
  /// or "continues the one in progress" (see `blend_group_link.dart`), and
  /// a continuation whose opener was sorted into a different pass would
  /// silently merge into whatever unrelated shape happened to precede it
  /// there, at that shape's blend width.
  void _reassignPasses() {
    _assignmentsDirty = false;

    final groupMaterials = <Object, GlassMaterial>{};
    for (final record in _records.values) {
      final group = record.group;
      if (group != null) {
        groupMaterials.putIfAbsent(group, () => record.declared ?? _material);
      }
    }

    for (final entry in _records.entries) {
      final record = entry.value;
      final group = record.group;
      final target = group == null
          ? record.declared ?? _material
          : groupMaterials[group]!;
      assert(() {
        if (record.declared != null && record.declared != target) {
          debugPrint(
            'glass_forge: a Glass inside a GlassBlendGroup asked for its '
            'own material, but the group already renders with the one its '
            'first shape asked for. Shapes that blend into one another are '
            'one surface and take one material; move it out of the group '
            'to give it its own.',
          );
        }
        return true;
      }(), 'debug-only warning; always true');
      final assigned = record.assigned;
      if (assigned != null && assigned != target) {
        _passes[assigned]?.scene.unregister(entry.key);
      }
      record.assigned = target;
      (_passes[target] ??= _GlassPass(target)).scene.register(
        entry.key,
        record.geometry,
      );
    }

    _passes.removeWhere((material, pass) {
      if (pass.scene.shapes.isNotEmpty) {
        return false;
      }
      _retirePass(pass);
      return true;
    });
  }

  void _retirePass(_GlassPass pass) {
    final matte = pass.matte;
    if (matte != null) {
      _producer.release(matte);
    }
    pass.matte = null;
    pass.composition.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!ShaderLibrary.instance.isReady) {
      // Shaders are still loading. Paint the subtree unglassed rather than
      // block the first frame on them — children stay visible immediately,
      // and the constructor's warm-up callback repaints once loading
      // finishes. Upstream instead makes every shape's paint a no-op until
      // its shaders load, so children are invisible until then.
      _paintSubtree(context, offset);
      return;
    }

    if (_assignmentsDirty) {
      _reassignPasses();
    }

    // Everything that decides whether a pass renders at all has to be known
    // *now*, before anything is pushed: a `BackdropFilterLayer` forces a
    // saveLayer and a full backdrop read the moment it exists, so pushing
    // one and then discovering there is nothing to put in it is worse than
    // not pushing it. Which shapes exist, which material each renders with
    // and which blend group each joined are all settled by the time paint
    // begins — registration happens in `attach` and `performLayout` — and
    // none of them can move while the subtree below paints. What *can* move
    // there, and the whole reason the filters are built afterwards, is where
    // each shape is.
    final passes = <_GlassPass>[
      for (final pass in _passes.values)
        if (GlassComposition.willRender(pass.material)) pass,
    ];
    if (passes.isEmpty) {
      // No shapes, or nothing any of their materials would draw. Upstream
      // pushes a full backdrop even when its blur is zero.
      _paintSubtree(context, offset);
      return;
    }

    // Collected fresh every paint: an ancestor's position relative to this
    // layer can change (most commonly by scrolling) without this layer's
    // own scene ever changing, so nothing else would tell us to re-walk.
    //
    // Unlike the scene, this is not stale at this point in the frame and so
    // does not move after the subtree paints. It is read straight off the
    // render tree -- `getTransformTo` and the ancestors' own clip rects --
    // which layout has already settled. The scene lags only because it is a
    // cache that the shapes themselves write into as they paint.
    final firstShape = scene.firstShapeOwner;
    if (firstShape == null) {
      _clipChain.clear();
    } else {
      _clipChain.collect(firstShape, this);
    }

    _pushGlassLayers(context, offset, passes);
  }

  /// Paints the subtree, flagged so a descendant shape can tell that this
  /// layer is the thing painting it.
  void _paintSubtree(PaintingContext context, Offset offset) {
    _paintingSubtree = true;
    try {
      super.paint(context, offset);
    } finally {
      _paintingSubtree = false;
    }
  }

  /// Pushes the backdrop pass wrapped in every retained ancestor clip,
  /// outermost first, with the layer's own local clip innermost.
  ///
  /// Scrolling moves material through a viewport, not the viewport through
  /// the material: each retained clip is re-pushed here, outside this
  /// layer's own offset, so it stays anchored to its own ancestor's bounds
  /// instead of moving with this layer's content.
  ///
  /// Each retained clip's own transform only accounts for its own step in
  /// the chain (see [RetainedClip.transform]), so nesting them still leaves
  /// the canvas transformed by their full composition once the innermost
  /// one is reached -- that composition is undone in one step, right
  /// before the real content paints, since the content already expects
  /// this layer's own frame. Skipping that undo (or reusing each clip's
  /// transform as if it were already relative to the layer) is exactly
  /// what displaced both the backdrop and the widget subtree by however
  /// far a retained clip sat from the layer -- see
  /// `retained_clip_chain_test.dart`'s "a clip offset from the layer does
  /// not displace the content it clips" for the regression this guards.
  ///
  /// [offset] is this layer's own paint offset throughout, and is what the
  /// filters' coordinate mapping is derived from — never the offset an inner
  /// context hands back, which `pushClipRect` and `pushTransform` zero out
  /// whenever they composite rather than clip on the canvas.
  void _pushGlassLayers(
    PaintingContext context,
    Offset offset,
    List<_GlassPass> passes,
  ) {
    void pushBackdrop(PaintingContext innerContext, Offset innerOffset) {
      // The clip is computed in this layer's own local space — the offset
      // is folded in once, by pushClipRect itself, rather than here too;
      // doing it twice would shift the clip by offset a second time.
      final clip = expandToPixelBuckets(Offset.zero & size);
      innerContext.pushClipRect(needsCompositing, innerOffset, clip, (
        clippedContext,
        clippedOffset,
      ) {
        _pushBackdropPasses(clippedContext, clippedOffset, offset, passes);
      });
    }

    final clips = _clipChain.clips;
    if (clips.isEmpty) {
      // The common case, and the only one Task 15 had to handle: skip the
      // transform bookkeeping below entirely rather than pay for an
      // identity pushTransform every frame.
      pushBackdrop(context, offset);
      return;
    }

    var accumulated = Matrix4.identity();
    for (final captured in clips) {
      accumulated = accumulated.multiplied(captured.transform);
    }

    // Composing every clip's own transform, outermost first, reconstructs
    // exactly the transform from the innermost captured clip's local space
    // to this layer's -- the same value `innermostNode.getTransformTo(
    // layer)` would produce, with no ancestor path double-counted. Undoing
    // it here, once, right before the real content, is what keeps that
    // content in this layer's own frame despite everything nested around
    // it above.
    var paint = (PaintingContext innerContext, Offset innerOffset) {
      innerContext.pushTransform(
        needsCompositing,
        innerOffset,
        Matrix4.inverted(accumulated),
        pushBackdrop,
      );
    };

    // Reversed: `clips` is outermost first, but building the closure chain
    // must process the outermost clip *last* so it ends up as the
    // outermost invocation once nesting unwinds -- processing it first
    // would instead leave the innermost clip outermost in the layer tree,
    // composing the chain's transforms in the opposite order to the one
    // `accumulated` above undoes.
    for (final captured in clips.reversed) {
      final next = paint;
      paint = (innerContext, innerOffset) {
        innerContext.pushTransform(
          needsCompositing,
          innerOffset,
          captured.transform,
          (transformedContext, transformedOffset) {
            final rrect = captured.rrect;
            if (rrect != null) {
              transformedContext.pushClipRRect(
                needsCompositing,
                transformedOffset,
                captured.rect,
                rrect,
                next,
                clipBehavior: captured.behavior,
              );
            } else {
              transformedContext.pushClipRect(
                needsCompositing,
                transformedOffset,
                captured.rect,
                next,
                clipBehavior: captured.behavior,
              );
            }
          },
        );
      };
    }

    paint(context, offset);
  }

  /// Pushes one backdrop pass per material as siblings, paints the subtree
  /// inside the last of them, and only then builds each pass's filter.
  ///
  /// The ordering is the point. A shape re-reads its own transform and
  /// re-registers it from inside its `paint` (see
  /// `RenderGlassShape._syncGeometryIfTransformChanged`), which is *this*
  /// layer's `super.paint`. Baking the matte before that call — as this did
  /// until the passes were split out — bakes the scene as the previous
  /// frame's paint left it, so every moving surface refracted one frame
  /// behind its own pixels. Filling the filters in afterwards is legal
  /// because a layer tree is not handed to the compositor until the end of
  /// the frame: `BackdropFilterLayer.filter` is nullable and documented as
  /// needing a value only "before the compositing phase of the pipeline",
  /// and assigning it calls `markNeedsAddToScene` for exactly this.
  ///
  /// Siblings, never nested. Nesting is what flutter#187820 is about (see
  /// [GlassComposition]); siblings are the ordinary arrangement of two
  /// `BackdropFilter`s side by side. A pass writes transparent black outside
  /// its own shapes' coverage and composites srcOver, so what a later pass
  /// reads as backdrop is the untouched original everywhere the earlier
  /// passes did not draw. Where two materials' shapes genuinely overlap the
  /// later one samples the earlier one's glass — glass sampling glass, which
  /// Apple's own guidance says not to do, and which is the reason to put
  /// overlapping surfaces in one material or one blend group.
  void _pushBackdropPasses(
    PaintingContext context,
    Offset offset,
    Offset layerOffset,
    List<_GlassPass> passes,
  ) {
    final pushed = <BackdropFilterLayer>[];
    for (var i = 0; i < passes.length; i++) {
      GlassRenderCounters.instance.recordBackdropPush();
      final backdrop = BackdropFilterLayer();
      pushed.add(backdrop);
      context.pushLayer(
        backdrop,
        // The subtree paints once, above every pass. Putting it in the last
        // one keeps a single-material layer byte-for-byte the arrangement it
        // had before there were passes at all.
        i == passes.length - 1 ? _paintSubtree : _paintNothing,
        offset,
      );
    }

    // The subtree has painted, so every shape has registered the transform
    // it actually painted at. Only now does the scene describe this frame.
    final mapping = _coordinateMapping(layerOffset);
    for (var i = 0; i < passes.length; i++) {
      pushed[i].filter = _buildFilter(passes[i], mapping);
    }
  }

  static void _paintNothing(PaintingContext context, Offset offset) {}

  ui.ImageFilter _buildFilter(_GlassPass pass, Float32List mapping) {
    _refreshMatte(pass);
    final filter = pass.composition.build(
      matte: pass.matte,
      material: pass.material,
      snapshot: FilterSnapshot.of(
        matte: pass.matte,
        devicePixelRatio: _devicePixelRatio,
        materialRevision: pass.material.revision,
        coordinateMapping: mapping,
      ),
      devicePixelRatio: _devicePixelRatio,
    );
    if (filter != null) {
      return filter;
    }
    // Unreachable while `willRender` and `build` agree, and they are written
    // to. But a `BackdropFilterLayer` with no filter asserts in debug and
    // throws in release at compositing time, and the saveLayer was already
    // paid for the moment it was pushed, so the cheapest honest recovery is
    // an identity rather than a crashed frame.
    assert(false, 'willRender() accepted a material build() then refused');
    return ui.ImageFilter.matrix(Matrix4.identity().storage);
  }

  void _refreshMatte(_GlassPass pass) {
    // Two independent reasons a fresh attempt might be worth making: the
    // pass's scene actually changed, or [_producer]'s own readiness changed
    // (its warm-up just settled, or it was just swapped for the runtime
    // fallback in [_warmUp]) since the last time this was asked. Checking
    // only `matte?.sceneRevision`, as before Task 18, conflates "nothing
    // to bake" with "producer was not ready yet" -- both leave `matte`
    // null -- so an accelerated producer not yet ready on an early paint
    // caused a fresh, wasted `produce()` call on every single subsequent
    // paint before its warm-up settled, not just the one that mattered.
    //
    // Per pass, not per layer, so that moving a shape of one material does
    // not re-bake every other material's matte. Each pass's scene is its
    // own registry and bumps its own revision only when its own shapes move.
    final material = pass.material;
    final request = MatteRequest(
      devicePixelRatio: _devicePixelRatio,
      maxDisplacement: material.maxDisplacement * _devicePixelRatio,
      edgeRefraction: material.edgeRefraction * _devicePixelRatio,
      refractionSpread: material.refractionSpread,
      antialiasWidth: 0.5,
      profile: material.profile,
      thickness: material.profile == GlassProfile.dome
          ? material.thickness * _devicePixelRatio
          : 0,
    );
    if (pass.refreshedRevision == pass.scene.revision &&
        pass.refreshedGeneration == _producerGeneration &&
        pass.refreshedRequest == request) {
      return;
    }
    final existing = pass.matte;
    final next = _producer.produce(pass.scene, request);
    GlassRenderCounters.instance.recordMatteProduce();
    if (existing != null) {
      _producer.release(existing);
    }
    pass
      ..matte = next
      ..refreshedRevision = pass.scene.revision
      ..refreshedGeneration = _producerGeneration
      ..refreshedRequest = request;
  }

  Float32List _coordinateMapping(Offset offset) {
    return Float32List.fromList(<double>[
      1,
      0,
      0,
      1,
      -offset.dx * _devicePixelRatio,
      -offset.dy * _devicePixelRatio,
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _passes.values.forEach(_retirePass);
    _passes.clear();
    _records.clear();
    _producer.dispose();
    super.dispose();
  }
}
