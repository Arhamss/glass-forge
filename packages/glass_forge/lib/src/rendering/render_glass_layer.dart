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
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Owns one backdrop capture and the scene it is shaped by.
///
/// Always built as soon as a `GlassLayer` widget is, regardless of whether
/// its shaders have finished loading — unlike upstream, which withholds its
/// whole layer (and therefore every descendant's registration point) until
/// then. [paint] simply skips the backdrop pass while
/// [ShaderLibrary.isReady] is false, painting the subtree unglassed; the
/// warm-up callback started in the constructor repaints once shaders land.
class RenderGlassLayer extends RenderProxyBox {
  /// Creates a glass layer.
  RenderGlassLayer({
    required this._material,
    required GeometryTier tier,
    required this._devicePixelRatio,
  }) : _producer = ProducerRegistry.select(tier: tier) {
    unawaited(
      ShaderLibrary.instance.warmUp().then((_) {
        if (attached && !_disposed) {
          markNeedsPaint();
        }
      }),
    );
  }

  /// The shapes belonging to this layer.
  final GlassScene scene = GlassScene();

  final RetainedClipChain _clipChain = RetainedClipChain();

  /// The ancestor clips most recently retained for re-pushing. Test-only.
  @visibleForTesting
  List<RetainedClip> get debugClipChain => _clipChain.clips;

  final GlassComposition _composition = GlassComposition();
  final GeometryProducer _producer;
  MatteGeneration? _matte;
  GlassMaterial _material;
  double _devicePixelRatio;
  bool _disposed = false;

  /// Physical pixels per logical pixel.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// How this layer's glass looks.
  GlassMaterial get material => _material;
  set material(GlassMaterial value) {
    if (_material == value) {
      return;
    }
    _material = value;
    markNeedsPaint();
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
      super.paint(context, offset);
      return;
    }

    _refreshMatte();

    final filter = _composition.build(
      matte: _matte,
      material: _material,
      snapshot: FilterSnapshot.of(
        matte: _matte,
        devicePixelRatio: _devicePixelRatio,
        materialRevision: _material.revision,
        coordinateMapping: _coordinateMapping(offset),
      ),
      devicePixelRatio: _devicePixelRatio,
    );

    if (filter == null) {
      // Nothing to render, so no backdrop pass at all. Upstream pushes a
      // full backdrop even when its blur is zero.
      super.paint(context, offset);
      return;
    }

    // Collected fresh every paint: an ancestor's position relative to this
    // layer can change (most commonly by scrolling) without this layer's
    // own scene ever changing, so nothing else would tell us to re-walk.
    final firstShape = scene.firstShapeOwner;
    if (firstShape == null) {
      _clipChain.clear();
    } else {
      _clipChain.collect(firstShape, this);
    }

    _pushGlassLayers(context, offset, filter);
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
  void _pushGlassLayers(
    PaintingContext context,
    Offset offset,
    ui.ImageFilter filter,
  ) {
    GlassRenderCounters.instance.recordBackdropPush();

    void pushBackdrop(PaintingContext innerContext, Offset innerOffset) {
      // The clip is computed in this layer's own local space — the offset
      // is folded in once, by pushClipRect itself, rather than here too;
      // doing it twice would shift the clip by offset a second time.
      final clip = expandToPixelBuckets(Offset.zero & size);
      innerContext.pushClipRect(needsCompositing, innerOffset, clip, (
        clippedContext,
        clippedOffset,
      ) {
        clippedContext.pushLayer(
          BackdropFilterLayer()..filter = filter,
          super.paint,
          clippedOffset,
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

  void _refreshMatte() {
    final existing = _matte;
    if (existing != null && existing.sceneRevision == scene.revision) {
      return;
    }
    final next = _producer.produce(
      scene,
      MatteRequest(
        devicePixelRatio: _devicePixelRatio,
        maxDisplacement: _material.maxDisplacement * _devicePixelRatio,
        edgeRefraction: _material.edgeRefraction * _devicePixelRatio,
        refractionSpread: _material.refractionSpread,
        antialiasWidth: 0.5,
      ),
    );
    GlassRenderCounters.instance.recordMatteProduce();
    if (existing != null) {
      _producer.release(existing);
    }
    _matte = next;
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
    final matte = _matte;
    if (matte != null) {
      _producer.release(matte);
    }
    _matte = null;
    _producer.dispose();
    _composition.dispose();
    super.dispose();
  }
}
