import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
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

    GlassRenderCounters.instance.recordBackdropPush();
    // The clip is computed in this layer's own local space — [offset] is
    // folded in once, by pushClipRect itself, rather than here too; doing it
    // twice would shift the clip by offset a second time.
    final clip = expandToPixelBuckets(Offset.zero & size);
    context.pushClipRect(needsCompositing, offset, clip, (
      innerContext,
      innerOffset,
    ) {
      innerContext.pushLayer(
        BackdropFilterLayer()..filter = filter,
        super.paint,
        innerOffset,
      );
    });
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
