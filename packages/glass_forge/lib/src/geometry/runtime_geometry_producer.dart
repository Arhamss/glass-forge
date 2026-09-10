import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
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

    final shader = ShaderLibrary.instance.acquire(GlassShaderId.geometry);
    try {
      _setUniforms(shader, scene, request, allocation);

      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..translate(-allocation.left, -allocation.top)
        ..drawRect(allocation, Paint()..shader = shader);
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
      ShaderLibrary.instance.release(shader);
    }
  }

  void _setUniforms(
    ui.FragmentShader shader,
    GlassScene scene,
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

    final shapes = scene.shapes;
    for (var s = 0; s < kMaxShapes; s++) {
      if (s < shapes.length) {
        final g = shapes[s];
        shader
          ..setFloat(i++, g.origin.dx - allocation.left)
          ..setFloat(i++, g.origin.dy - allocation.top)
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
    shader.setFloat(
      i++,
      shapes.length.clamp(0, kMaxShapes).toDouble(),
    );
  }

  @override
  void release(MatteGeneration generation) {
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
