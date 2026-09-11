import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/debug.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Builds the single image filter a glass layer paints through.
///
/// Exactly one `BackdropFilter` per layer. Blur and the glass shader compose
/// into one filter rather than stacking: a shader filter above another
/// backdrop filter reads a stale previous-frame backdrop — including its own
/// output — on physical iPhones (flutter#187820), which is a progressive
/// white-wash. Upstream stacks two, so it is exposed to exactly this.
class GlassComposition {
  ui.ImageFilter? _filter;
  ui.FragmentShader? _shader;
  FilterSnapshot? _snapshot;
  ui.Image? _emptyMatte;
  int _buildCount = 0;

  /// How many native filters have been built. Test-only.
  @visibleForTesting
  int get debugFilterBuildCount => _buildCount;

  /// Returns the filter for this frame, or null if nothing should be painted.
  ui.ImageFilter? build({
    required MatteGeneration? matte,
    required GlassMaterial material,
    required FilterSnapshot snapshot,
    required double devicePixelRatio,
  }) {
    if (!material.rendersAnything) {
      return null;
    }
    if (_filter != null && _snapshot == snapshot) {
      return _filter;
    }

    final shaderId = debugBilinearBackdropSampling
        ? GlassShaderId.finalRenderBilinearProbe
        : GlassShaderId.finalRender;
    final shader = _shader ??= ShaderLibrary.instance.acquire(shaderId);
    _writeUniforms(shader, matte, material, snapshot, devicePixelRatio);

    final glass = ui.ImageFilter.shader(shader);
    final frost = material.frost * devicePixelRatio;
    _filter = frost <= 0
        ? glass
        : ui.ImageFilter.compose(
            inner: ui.ImageFilter.blur(
              sigmaX: frost,
              sigmaY: frost,
              tileMode: TileMode.mirror,
            ),
            outer: glass,
          );
    _snapshot = snapshot;
    _buildCount++;
    return _filter;
  }

  void _writeUniforms(
    ui.FragmentShader shader,
    MatteGeneration? matte,
    GlassMaterial material,
    FilterSnapshot snapshot,
    double devicePixelRatio,
  ) {
    final bounds = matte?.bounds ?? Rect.zero;
    final tint = material.tint;
    var i = 2; // 0 and 1 are uSize, written by the engine.
    shader
      ..setFloat(i++, bounds.left)
      ..setFloat(i++, bounds.top)
      ..setFloat(i++, bounds.width)
      ..setFloat(i++, bounds.height)
      ..setFloat(i++, material.maxDisplacement * devicePixelRatio)
      ..setFloat(i++, material.chromaticAberration)
      ..setFloat(i++, material.tintOpacity)
      ..setFloat(i++, material.saturation)
      ..setFloat(i++, tint.r)
      ..setFloat(i++, tint.g)
      ..setFloat(i++, tint.b)
      ..setFloat(i++, material.variant == GlassVariant.clear ? 1 : 0)
      ..setFloat(i++, material.highlight)
      ..setFloat(i++, material.lightDirection.dx)
      ..setFloat(i++, material.lightDirection.dy)
      ..setFloat(i++, material.contour)
      ..setFloat(i++, snapshot.coordinateMapping[0])
      ..setFloat(i++, snapshot.coordinateMapping[1])
      ..setFloat(i++, snapshot.coordinateMapping[2])
      ..setFloat(i++, snapshot.coordinateMapping[3])
      ..setFloat(i++, snapshot.coordinateMapping[4])
      ..setFloat(i++, snapshot.coordinateMapping[5])
      // uMatte (sampler index 1) is required: `ImageFilter.shader` demands
      // every declared sampler past index 0 be bound before construction,
      // even one the shader itself will not sample from. With no matte,
      // bind a 1x1 fully transparent placeholder instead — its alpha
      // decodes to zero coverage, so the shader's own early-out takes it
      // straight to a plain backdrop pass-through.
      ..setImageSampler(1, matte?.texture ?? _ensureEmptyMatte());
  }

  ui.Image _ensureEmptyMatte() {
    final cached = _emptyMatte;
    if (cached != null) {
      return cached;
    }
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final image = recorder.endRecording().toImageSync(1, 1);
    _emptyMatte = image;
    return image;
  }

  /// Releases the shader and drops the cached filter.
  void dispose() {
    final shader = _shader;
    if (shader != null) {
      ShaderLibrary.instance.release(shader);
    }
    _shader = null;
    _filter = null;
    _snapshot = null;
    _emptyMatte?.dispose();
    _emptyMatte = null;
  }
}
