import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/shape_clusters.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// Bakes the matte with a runtime-effect fragment shader.
///
/// Works on every backend that supports `FragmentProgram`, which is all of
/// them. Slower than the Flutter GPU path because the result round-trips
/// through `toImageSync`, whose display list is retained until the image is
/// disposed (flutter#138627) — hence the release discipline below.
class RuntimeGeometryProducer implements GeometryProducer {
  final List<ui.Image> _live = <ui.Image>[];

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'runtime-effect');

  @override
  Future<void> warmUp() => ShaderLibrary.instance.warmUp();

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    if (scene.shapes.isEmpty) {
      return null;
    }

    final padded = scene.bounds(padding: request.antialiasWidth);
    if (padded.isEmpty || !padded.isFinite) {
      // Zero-size or non-finite bounds crash toImageSync. Upstream #149 and
      // #131 are both this crash, reported from production.
      return null;
    }

    final allocation = expandToPixelBuckets(padded);
    final width = allocation.width.round();
    final height = allocation.height.round();
    if (width <= 0 || height <= 0) {
      return null;
    }

    final clusters = clusterShapes(
      scene.shapes,
      padding: clusterPadding(request),
    );
    final shaders = <ui.FragmentShader>[];
    ui.FragmentShader shaderFor(List<ShapeGeometry> shapes) {
      // One shader per draw, never one re-written between draws: whether a
      // draw snapshots its uniforms when it is recorded or reads them when
      // the picture is rasterised is the engine's business, and the pool
      // makes separate shaders free.
      final shader = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
      shaders.add(shader);
      _setUniforms(shader, shapes, request, allocation);
      return shader;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(-allocation.left, -allocation.top);
      if (clusters.length == 1) {
        // The common case, and exactly the single draw this always was.
        canvas.drawRect(
          allocation,
          Paint()..shader = shaderFor(clusters.single.shapes),
        );
      } else {
        // Clear to "outside" first: a texel no cluster draws would otherwise
        // stay zeroed, and a zeroed texel decodes as the deep interior --
        // solid glass everywhere between clusters. A draw with no shapes
        // bakes exactly the encoding the shader writes far from any shape,
        // which a Paint colour could not: its alpha is 0, and a colour with
        // alpha 0 premultiplies to black.
        //
        // BlendMode.src throughout, because the matte is data, not colour:
        // srcOver would mix a texel whose magnitude (alpha) is 0 with the
        // clear beneath it. No antialiasing, because a partially covered
        // edge texel would be a blend of two encodings -- and the clip is
        // whole pixels anyway (ShapeCluster.bounds).
        Paint matte(List<ShapeGeometry> shapes) => Paint()
          ..shader = shaderFor(shapes)
          ..blendMode = BlendMode.src
          ..isAntiAlias = false;
        canvas.drawRect(allocation, matte(const <ShapeGeometry>[]));
        for (final cluster in clusters) {
          final clip = cluster.bounds.intersect(allocation);
          if (clip.isEmpty) {
            continue;
          }
          canvas.drawRect(clip, matte(cluster.shapes));
        }
      }
      final picture = recorder.endRecording();
      try {
        final texture = picture.toImageSync(width, height);
        _live.add(texture);
        return MatteGeneration(
          texture: texture,
          bounds: allocation,
          sceneRevision: scene.revision,
          codec: MatteCodec(maxDisplacement: request.maxDisplacement),
        );
      } finally {
        picture.dispose();
      }
    } finally {
      shaders.forEach(ShaderLibrary.instance.release);
    }
  }

  /// Writes one draw's uniforms: the first `kMaxShapes` of [shapes].
  ///
  /// A cluster larger than that is the one case left that drops shapes;
  /// the layer's debug warning names it (see `RenderGlassLayer`).
  void _setUniforms(
    ui.FragmentShader shader,
    List<ShapeGeometry> shapes,
    MatteRequest request,
    Rect allocation,
  ) {
    var i = 0;
    // uSize is index 0-1, written by the engine for filter shaders. For a
    // Paint.shader we set it ourselves.
    shader
      ..setFloat(i++, allocation.width)
      ..setFloat(i++, allocation.height)
      ..setFloat(i++, request.maxDisplacement)
      ..setFloat(i++, request.edgeRefraction)
      ..setFloat(i++, request.refractionSpread)
      ..setFloat(i++, request.antialiasWidth);

    for (var s = 0; s < kMaxShapes; s++) {
      if (s < shapes.length) {
        final g = shapes[s];
        // Layer-local, not allocation-relative. FlutterFragCoord reports the
        // pre-translation space the translated Canvas draws into, which is
        // already layer-local; subtracting the allocation origin here as
        // well applied that offset twice. Invisible for a shape at its
        // layer's top-left, where the allocation starts at about zero, and
        // fatal everywhere else — the SDF is evaluated entirely off the
        // shape and the whole matte encodes "outside".
        shader
          ..setFloat(i++, g.origin.dx)
          ..setFloat(i++, g.origin.dy)
          ..setFloat(i++, g.halfExtent.width)
          ..setFloat(i++, g.halfExtent.height)
          ..setFloat(i++, g.inverseBasis[0])
          ..setFloat(i++, g.inverseBasis[1])
          ..setFloat(i++, g.inverseBasis[2])
          ..setFloat(i++, g.inverseBasis[3])
          ..setFloat(i++, g.type.sdfCode.toDouble())
          ..setFloat(i++, g.radius)
          ..setFloat(i++, g.distanceScale)
          ..setFloat(i++, g.blendMarker);
      } else {
        // Unused slots must still be written: an unwritten uniform is
        // undefined, and Impeller has rejected draws over default-valued
        // uniforms before (upstream #39).
        for (var pad = 0; pad < 12; pad++) {
          shader.setFloat(i++, 0);
        }
      }
    }
    shader
      ..setFloat(i++, shapes.length.clamp(0, kMaxShapes).toDouble())
      // uProfile, after the shape block so every earlier index is where it
      // always was.
      ..setFloat(i++, request.profileCode)
      ..setFloat(i++, request.thickness)
      ..setFloat(i++, 0)
      ..setFloat(i++, 0);
  }

  @override
  void release(MatteGeneration generation) {
    if (!generation.isOwner) {
      // A translated() view aliases its origin's texture rather than owning
      // it. Both carry the same ui.Image, so disposing here would dispose
      // the original out from under it. Releasing a view is a no-op; only
      // the owner can retire the texture.
      return;
    }
    if (_live.remove(generation.texture)) {
      generation.texture.dispose();
    }
  }

  @override
  void dispose() {
    for (final texture in _live) {
      texture.dispose();
    }
    _live.clear();
  }
}
