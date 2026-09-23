import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/composition/retained_clip_chain.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
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

/// What makes two shapes share one backdrop pass.
///
/// The material, by value, as it always was — and the identity of whatever
/// drives their presence. Identity, not value, is the whole point: a
/// presence animating from 0 to 1 over sixty frames has sixty different
/// *values* and one `Animation` object, so keying on the object means the
/// pass, its scene and its matte all survive the animation untouched. The
/// value lives on [_GlassPass.presence] instead, where changing it costs a
/// rebuilt `ImageFilter` and nothing more.
@immutable
class _PassKey {
  const _PassKey(this.material, this.presenceScope);

  /// The material every shape sharing this key renders with.
  final GlassMaterial material;

  /// The identity of whatever drives this key's shapes' presence, or null.
  final Object? presenceScope;

  @override
  bool operator ==(Object other) =>
      other is _PassKey &&
      other.material == material &&
      identical(other.presenceScope, presenceScope);

  @override
  int get hashCode => Object.hash(material, identityHashCode(presenceScope));
}

/// One backdrop pass: every shape in this layer that renders with the same
/// material and presence driver, and the single filter they share.
///
/// Grouping is by material rather than by shape because a backdrop filter is
/// the expensive thing, not a shape. N materials cost N passes; the common
/// case of one material still costs exactly one, which is what the
/// `GlassComposition` invariant is really about.
class _GlassPass {
  _GlassPass(this.key);

  /// What this pass is keyed by.
  final _PassKey key;

  /// The material every shape in [scene] renders with.
  GlassMaterial get material => key.material;

  /// How present this pass's glass is this frame, 0 to 1.
  ///
  /// Mutable and outside the key on purpose. See [_PassKey].
  double presence = 1;

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
    required this.presenceScope,
    required this.presence,
  });

  ShapeGeometry geometry;

  /// The material this shape declared, or null to inherit the layer's.
  GlassMaterial? declared;

  /// The blend group this shape joined, held only for identity.
  Object? group;

  /// The identity of whatever drives this shape's presence, or null.
  Object? presenceScope;

  /// This shape's presence this frame, 0 to 1.
  double presence;

  /// The pass this shape is currently registered into.
  _PassKey? assigned;
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

  /// One pass per distinct material and presence-driver identity among
  /// [_records], in the order each key's first shape registered.
  final Map<_PassKey, _GlassPass> _passes = <_PassKey, _GlassPass>{};

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

  /// Counts the paints of this layer's subtree, so a shape can say which of
  /// them it last read its own transform in.
  ///
  /// See [_resyncShapesThatDidNotPaint] for what that is for.
  int _subtreePaint = 0;

  /// Which paint of this layer's subtree is in progress.
  ///
  /// `RenderGlassShape` stamps this on itself whenever it reads its
  /// transform, which is how the sweep after the subtree paints tells a
  /// shape that took part in it from one that did not.
  int get subtreePaint => _subtreePaint;

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

  /// The touch glow every pass in this layer is lit by.
  ///
  /// One glow per layer, not per shape: a glow that stops at a shape's edge
  /// is the painted version this package rejected. See `GlassGlow`.
  GlassGlow get glow => _glow;
  GlassGlow _glow = const GlassGlow.none();
  set glow(GlassGlow value) {
    if (_glow == value) {
      return;
    }
    _glow = value;
    markNeedsPaint();
  }

  /// The shared glow channel this layer listens to, if any.
  ///
  /// Set from `GlassLayer`, which owns the `ValueNotifier<GlassGlow>` its
  /// `GlassGlowScope` publishes and every `InteractiveGlass` beneath this
  /// layer writes into. Listened to directly here, the same way
  /// `RenderGlassMotion` listens to its `GlassMotionController`: a change
  /// calls [markNeedsPaint] with no widget rebuild in between, which is
  /// what lets the glow follow a spring running every frame.
  ValueListenable<GlassGlow>? get glowListenable => _glowListenable;
  ValueListenable<GlassGlow>? _glowListenable;
  set glowListenable(ValueListenable<GlassGlow>? value) {
    if (identical(_glowListenable, value)) {
      return;
    }
    if (attached) {
      _glowListenable?.removeListener(_onGlowListenableChanged);
    }
    _glowListenable = value;
    if (attached) {
      _glowListenable?.addListener(_onGlowListenableChanged);
    }
    _onGlowListenableChanged();
  }

  void _onGlowListenableChanged() {
    glow = _glowListenable?.value ?? const GlassGlow.none();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _glowListenable?.addListener(_onGlowListenableChanged);
  }

  @override
  void detach() {
    _glowListenable?.removeListener(_onGlowListenableChanged);
    super.detach();
  }

  /// Registers [key]'s geometry, and what it asked to render with.
  ///
  /// [material] null means "whatever this layer's is"; [group] is the blend
  /// group the shape joined, held only for identity. [presenceScope] is the
  /// identity of whatever drives this shape's presence, or null, and
  /// [presence] is its current value, 0 to 1.
  void registerShape(
    Object key,
    ShapeGeometry geometry,
    GlassMaterial? material,
    Object? group,
    Object? presenceScope,
    double presence,
  ) {
    scene.register(key, geometry);

    final existing = _records[key];
    if (existing == null) {
      _records[key] = _ShapeRecord(
        geometry: geometry,
        declared: material,
        group: group,
        presenceScope: presenceScope,
        presence: presence,
      );
      _assignmentsDirty = true;
      return;
    }

    existing.geometry = geometry;
    if (existing.declared != material ||
        !identical(existing.group, group) ||
        !identical(existing.presenceScope, presenceScope)) {
      existing
        ..declared = material
        ..group = group
        ..presenceScope = presenceScope
        ..presence = presence;
      _assignmentsDirty = true;
      return;
    }

    // The hot path: a shape that only moved, or whose presence value ticked.
    // Its pass is already decided, so the new geometry goes straight in --
    // this runs for every shape on every animating frame, from inside this
    // layer's own subtree paint.
    existing.presence = presence;
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

  /// Updates one shape's presence without disturbing its pass.
  ///
  /// Called from `RenderGlassShape`'s presence listener, which ticks in the
  /// animation phase — before paint — so the value read at the top of
  /// [paint] is this frame's.
  void updateShapePresence(Object key, double presence) {
    final record = _records[key];
    if (record == null || record.presence == presence) {
      return;
    }
    record.presence = presence;
    markNeedsPaint();
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
      final material = group == null
          ? record.declared ?? _material
          : groupMaterials[group]!;
      assert(() {
        if (record.declared != null && record.declared != material) {
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
      final target = _PassKey(material, record.presenceScope);
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

    _passes.removeWhere((key, pass) {
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

  /// Warns when two shapes in *different* backdrop passes overlap.
  ///
  /// Two backdrop passes over the same pixels is flutter#187820: the upper
  /// one reads a stale previous-frame backdrop, including its own output,
  /// and white-washes progressively on physical iPhones. It has shipped
  /// broken in this repository by accident more than once, which is why
  /// it is checked rather than only documented.
  ///
  /// A warning, not an assert -- deliberately. Overlap is legitimately
  /// transient: a sheet rising over a tab bar overlaps it for exactly as
  /// long as the handoff takes, and an assert would throw on the very
  /// frame that was in the middle of fixing it. Shapes inside one pass are
  /// fine: they share a matte and fold into one surface via smooth-min,
  /// which is the supported way to overlap.
  ///
  /// Each shape's box comes from [ShapeGeometry.layerBounds], which puts
  /// the shape's own extent through its own basis. Building it from
  /// [ShapeGeometry.origin] and [ShapeGeometry.halfExtent] directly --
  /// which this did until the catalogue index reported fourteen overlaps
  /// between thumbnails a row apart that never touch -- mixes two spaces:
  /// the origin is in the layer's, the half-extent in the shape's own. Any
  /// scale between them is then missing, and a shrinking one over-reports:
  /// the index fits a 200x200 specimen into a 44x44 thumbnail, so every
  /// thumbnail claimed four and a half times its width in each direction
  /// and collided with its neighbours. It is still a bounding box rather
  /// than a silhouette, so two ovals that share a corner of their boxes and
  /// nothing else still report -- an over-estimate a debug diagnostic can
  /// live with, unlike one that scales with the caller's layout.
  ///
  /// Called from two places in [paint], both *after* the subtree has
  /// painted -- never from the top of [paint] itself, where every shape's
  /// registered geometry could still be a fresh mount's `performLayout`-time
  /// value. `RenderGlassShape.performLayout` can register a transform
  /// missing an ancestor's just-assigned offset (see the doc comment on
  /// `RenderGlassShape._syncGeometryIfTransformChanged`), and that is only
  /// corrected once the shape's own `paint` runs. Reading before the
  /// subtree paints caught that one-frame staleness on every fresh mount
  /// of any glass subtree -- a false warning for geometry that never
  /// reached the screen, since the matte and the filter are themselves
  /// built from the corrected, post-paint values. Reading after matches
  /// what actually renders.
  void _debugWarnOnCrossPassOverlap() {
    assert(() {
      final entries = _records.values.toList(growable: false);
      for (var i = 0; i < entries.length; i++) {
        final a = entries[i];
        final assignedA = a.assigned;
        // Unreachable at this point in paint -- every record is assigned
        // by _reassignPasses before the presence fold above runs -- but
        // skipped rather than forced, since this is a diagnostic and
        // should never be what crashes a debug build.
        if (assignedA == null) {
          continue;
        }
        if (!GlassComposition.willRender(assignedA.material, a.presence)) {
          continue;
        }
        final boundsA = a.geometry.layerBounds;
        for (var j = i + 1; j < entries.length; j++) {
          final b = entries[j];
          final assignedB = b.assigned;
          if (assignedB == null || assignedA == assignedB) {
            continue;
          }
          if (!GlassComposition.willRender(assignedB.material, b.presence)) {
            continue;
          }
          final boundsB = b.geometry.layerBounds;
          if (!boundsA.overlaps(boundsB)) {
            continue;
          }
          debugPrint(
            'glass_forge: two glass shapes in different backdrop passes '
            'overlap ($boundsA and $boundsB). The upper pass samples the '
            "lower one's output from the previous frame -- flutter#187820 "
            '-- which white-washes progressively on a physical iPhone. '
            'Give them the same material so they share a pass, join them '
            'with a GlassBlendGroup, or hand one off to the other with '
            'GlassPresence so only one is present at a time.',
          );
          return true;
        }
      }
      return true;
    }(), 'debug-only warning; always true');
  }

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

    // Fold each pass's shapes' presence into the pass. A pass is one
    // surface: the highest presence among its shapes wins rather than an
    // average, so a pass is fully present as soon as any shape in it is,
    // and reaches zero only when every shape has.
    for (final pass in _passes.values) {
      pass.presence = 0;
    }
    for (final record in _records.values) {
      final pass = _passes[record.assigned];
      if (pass != null && record.presence > pass.presence) {
        pass.presence = record.presence;
      }
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
    //
    // `dormant` is every other pass whose material could still draw at full
    // presence -- a presence-driven pass sitting at 0 is capable, it is
    // just not asked to render this frame. Warming these (see [_warmMatte])
    // regardless of whether they are currently visible is what keeps a
    // matte ready for the frame a pass first crosses back above the
    // epsilon. See `GlassPresence`'s own doc comment: animating it "costs a
    // rebuilt image filter per frame and never a rebaked matte," for the
    // driver's whole life, not just once it happens to already be visible.
    final passes = <_GlassPass>[];
    final dormant = <_GlassPass>[];
    for (final pass in _passes.values) {
      if (!GlassComposition.willRender(pass.material, 1)) {
        continue;
      }
      if (GlassComposition.willRender(pass.material, pass.presence)) {
        passes.add(pass);
      } else {
        dormant.add(pass);
      }
    }
    if (passes.isEmpty) {
      // No shapes, nothing any of their materials would draw, or every
      // capable pass is currently at presence 0. Upstream pushes a full
      // backdrop even when its blur is zero.
      _paintSubtree(context, offset);
      // The subtree has now painted, so every shape's registered geometry
      // is this frame's, not layout's -- see the fuller note in
      // _pushBackdropPasses, where the equivalent point sits on the other
      // path through this method.
      _debugWarnOnCrossPassOverlap();
      dormant.forEach(_warmMatte);
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
    // Every shape, not one of them: a retained clip is re-pushed around
    // this layer's whole backdrop pass, and the subtree paints inside the
    // last of those passes, so a clip only one shape sits under would crop
    // every other shape and every painted pixel in the layer to that one
    // shape's box. `collect` keeps only what they all share.
    _clipChain.collect(scene.shapeOwners, this);

    _pushGlassLayers(context, offset, passes, dormant);
  }

  /// Paints the subtree, flagged so a descendant shape can tell that this
  /// layer is the thing painting it.
  void _paintSubtree(PaintingContext context, Offset offset) {
    _paintingSubtree = true;
    _subtreePaint++;
    try {
      super.paint(context, offset);
      _resyncShapesThatDidNotPaint();
    } finally {
      _paintingSubtree = false;
    }
  }

  /// Asks every shape the subtree paint above did not reach where it is now.
  ///
  /// A shape reads its own transform from its own `paint` and nowhere else,
  /// because paint is the only phase where the walk is both permitted and
  /// correct (see `RenderGlassShape._syncGeometry`). That leaves a shape
  /// which moves without repainting holding whatever it registered when it
  /// last painted, and a `ListView` produces exactly that: every row is
  /// wrapped in a `RepaintBoundary`, and scrolling re-lays out nothing, so a
  /// scrolled row neither lays out nor paints while the viewport under it
  /// slides. Measured before this sweep, rows belonging at y = 2.6, 102.6
  /// and 202.6 were still registered at 467.5, 518.8 and 567.5 — where they
  /// were last painted — and the pass refracted that stale backdrop.
  ///
  /// Right after the subtree paint is the moment to ask: layout is over, so
  /// the walk is legal and correct; whichever repaint boundaries skipped
  /// have already skipped, so what did not paint is settled; and the mattes
  /// are still ahead, so what this registers is what they bake from.
  ///
  /// It only asks on frames this layer paints, and a scroll does not make
  /// it paint — `RenderViewportBase.isRepaintBoundary` is true, so a scroll
  /// marks the viewport and stops inside it. `GlassLayer` therefore listens
  /// for scroll notifications and marks this layer itself; see
  /// `_RepaintOnScroll` in `widgets/glass_layer.dart`. Neither half works
  /// without the other, and each has its own failing case in
  /// `test/src/rendering/scrolled_geometry_test.dart`.
  ///
  /// Cost, since this runs on every paint of every glass layer: one integer
  /// comparison per registered shape, and a `getTransformTo` walk only for
  /// the shapes that did not paint. In the ordinary case — everything under
  /// the layer repainted with it — every shape is already stamped with
  /// [_subtreePaint] and nothing walks at all. What it adds where it does
  /// walk is one ancestor walk per silent shape, against the one the clip
  /// chain already makes per shape from `paint` itself.
  void _resyncShapesThatDidNotPaint() {
    // A snapshot: re-registering a shape mutates `_records`' values, and
    // iterating the map's own keys while that happens is only safe as long
    // as nobody adds or removes one. Nothing here does, but a list of the
    // handful of shapes one layer holds is cheap enough not to depend on
    // that staying true.
    final shapes = _records.keys.whereType<RenderGlassShape>().toList(
      growable: false,
    );
    for (final shape in shapes) {
      shape.syncGeometryIfSubtreePaintMissedIt(this);
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
    List<_GlassPass> dormant,
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
        _pushBackdropPasses(
          clippedContext,
          clippedOffset,
          offset,
          passes,
          dormant,
        );
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
  /// Siblings, never nested — but be clear about what that does and does not
  /// buy. An earlier version of this comment claimed nesting is what
  /// flutter#187820 is about. **That is wrong**, and the issue itself says
  /// so: its title is "BackdropFilter(ImageFilter.shader) *stacked above*
  /// another BackdropFilter samples stale previous-frame backdrop including
  /// its own output", and its minimal repro is two ordinary siblings in one
  /// `Stack` — a glass tab bar with a shader filter positioned over it. On a
  /// physical iPhone the upper filter's input is resolved from a stale copy
  /// that includes its own previous output, so it feeds back and converges to
  /// an opaque white wash within a few frames. The simulator composites
  /// correctly and reproduces nothing. The issue is closed, but by a bot for
  /// lack of a reply, not by a fix.
  ///
  /// So the arrangement below is exposed wherever two passes overlap. A pass
  /// writes transparent black outside its own shapes' coverage and composites
  /// srcOver, so where the earlier passes drew nothing the later one reads
  /// the untouched original — but each pass currently covers the whole layer
  /// clip, not its own shapes, so two materials in one layer stack across the
  /// entire layer whether or not their shapes meet.
  ///
  /// Clipping each pass to its own shapes' bounds would remove that for
  /// non-overlapping materials, and make every pass cheaper. It is not as
  /// simple as clipping to the coverage: the shader samples the backdrop up
  /// to the full displacement away from each shape, and a composed frost
  /// blur reaches further again, so the clip has to be inflated by both or
  /// every rim picks up mirrored-edge artefacts. That wants a physical device
  /// to verify, which is also the only way to confirm #187820 here at all.
  ///
  /// Where two materials' shapes genuinely overlap, the later one samples the
  /// earlier one's glass — glass sampling glass, which Apple's own guidance
  /// says not to do, and the reason to put overlapping surfaces in one
  /// material or one blend group.
  void _pushBackdropPasses(
    PaintingContext context,
    Offset offset,
    Offset layerOffset,
    List<_GlassPass> passes,
    List<_GlassPass> dormant,
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

    // Checked here, not earlier in `paint`, for the same reason the filters
    // are built here: before this point every shape's registered geometry
    // could still be a fresh mount's `performLayout`-time value, which
    // `RenderGlassShape.paint`'s own re-sync had not yet corrected (see
    // its doc comment) -- stale in exactly the way that produced a
    // one-frame false warning on every fresh mount, never a shape that
    // actually painted overlapping pixels. Now it reads the same geometry
    // the mattes above were just baked from.
    _debugWarnOnCrossPassOverlap();

    // Dormant passes -- a material rendering alongside a still-faded-out
    // `GlassPresence` pass -- get their matte warmed, off the
    // backdrop-push path entirely. See [_warmMatte].
    dormant.forEach(_warmMatte);
  }

  static void _paintNothing(PaintingContext context, Offset offset) {}

  ui.ImageFilter _buildFilter(_GlassPass pass, Float32List mapping) {
    _refreshMatte(pass);
    final glow = _glow;
    final filter = pass.composition.build(
      matte: pass.matte,
      material: pass.material,
      snapshot: FilterSnapshot.of(
        matte: pass.matte,
        devicePixelRatio: _devicePixelRatio,
        materialRevision: pass.material.revision,
        coordinateMapping: mapping,
        presence: pass.presence,
        glow: glow,
      ),
      devicePixelRatio: _devicePixelRatio,
      presence: pass.presence,
      glow: glow,
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

  /// Bakes [pass]'s matte only if it does not have one yet.
  ///
  /// For a dormant pass -- not pushed this frame, whether because nothing
  /// in this layer is currently visible or because this pass sits
  /// alongside one that is -- this is what keeps a matte ready for the
  /// frame it first becomes visible, without paying for a fresh bake on
  /// every frame it stays invisible in between. That distinction matters:
  /// `RenderGlassShape.paint` re-registers a shape's geometry whenever its
  /// transform changes, unconditionally on presence, so a dormant pass
  /// whose shapes keep moving -- a sheet whose presence hits 0 before it
  /// finishes translating off-screen, or one pre-mounted at presence 0
  /// above content still animating underneath it -- bumps the scene's
  /// revision on every one of those frames regardless. Calling
  /// [_refreshMatte] directly there would rebake on every one of them,
  /// full `PictureRecorder`-to-`toImageSync` cost, indefinitely, for a
  /// pass nobody can see. Motion has always cost a rebake while visible;
  /// going invisible does not make it free. What `GlassPresence` promises
  /// is that its own *value* ticking costs nothing once a matte exists,
  /// which checking for one here, before ever calling [_refreshMatte], is
  /// what actually delivers.
  void _warmMatte(_GlassPass pass) {
    if (pass.matte != null) {
      return;
    }
    _refreshMatte(pass);
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
