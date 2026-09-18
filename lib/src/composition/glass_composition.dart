import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/debug.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/material/glass_variant.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

/// Builds the single image filter one backdrop pass paints through.
///
/// Blur and the glass shader compose into one filter rather than stacking: a
/// shader filter above another backdrop filter reads a stale previous-frame
/// backdrop — including its own output — on physical iPhones
/// (flutter#187820), which is a progressive white-wash. Upstream stacks two,
/// so it is exposed to exactly this.
///
/// A layer owns one of these per *distinct material* among its shapes, and
/// pushes those passes as siblings under one clip — never nested, which is
/// the arrangement flutter#187820 is about. One material, which is the
/// common case, is still exactly one `BackdropFilter`. See
/// `RenderGlassLayer`.
class GlassComposition {
  ui.ImageFilter? _filter;
  ui.FragmentShader? _shader;
  FilterSnapshot? _snapshot;
  ui.Image? _emptyMatte;
  int _buildCount = 0;

  /// How many native filters have been built. Test-only.
  @visibleForTesting
  int get debugFilterBuildCount => _buildCount;

  /// Below this, a pass is not worth a backdrop read and is dropped entirely.
  ///
  /// Not exactly zero: a spring settling toward 0 lands on values like 1e-9,
  /// and a pass that costs a saveLayer and a full backdrop read to draw a
  /// billionth of a refraction is a pass that should not be pushed.
  static const double _presenceEpsilon = 0.001;

  /// Whether [material] can put anything on screen on this backend.
  ///
  /// Answerable without a matte, and that is the whole point: a
  /// `BackdropFilterLayer` is pushed *before* the subtree paints (so the
  /// matte can be baked from the transforms that paint registers rather than
  /// from last frame's), and a pushed backdrop filter costs a saveLayer and
  /// a full backdrop read whether or not a filter ever lands on it. So the
  /// "push nothing at all" decision has to be made from what is known
  /// beforehand. Every input here — the material, and the backend — is.
  ///
  /// A null matte is deliberately *not* one of those inputs. It does not
  /// mean "nothing to draw": the shader binds a transparent placeholder and
  /// early-outs per fragment, which still leaves the frost, and on the
  /// degraded path the frost is all there ever was. What a null matte costs
  /// is the refraction, not the pass.
  ///
  /// Kept in step with [build] by construction: this returns false for
  /// exactly the three cases [build] returns null for.
  static bool willRender(GlassMaterial material, double presence) {
    if (presence < _presenceEpsilon) {
      return false;
    }
    if (!material.rendersAnything) {
      return false;
    }
    if (!ui.ImageFilter.isShaderFilterSupported) {
      return material.frost * presence > 0;
    }
    return true;
  }

  /// Returns the filter for this frame, or null if nothing should be painted.
  ui.ImageFilter? build({
    required MatteGeneration? matte,
    required GlassMaterial material,
    required FilterSnapshot snapshot,
    required double devicePixelRatio,
    required double presence,
  }) {
    if (presence < _presenceEpsilon) {
      return null;
    }
    if (!material.rendersAnything) {
      return null;
    }
    if (_filter != null && _snapshot == snapshot) {
      return _filter;
    }

    if (!ui.ImageFilter.isShaderFilterSupported) {
      // Skia, and therefore the web canvaskit/html backends. Constructing
      // `ui.ImageFilter.shader` there throws during paint, which turns the
      // package's own headline claim -- real refraction where the GPU allows,
      // graceful degradation everywhere else -- into a crash for anyone who
      // has not wrapped their app in a `GlassTierScope`. Degrading is the
      // behaviour a consumer is entitled to by default, not something they
      // have to opt into, so the frost survives on its own and the
      // refraction, rim and contour simply do not happen.
      //
      // Cached against `snapshot` like the shader path, so a surface whose
      // frost never changes is not rebuilding a blur every frame.
      _filter = _blurOnly(material, devicePixelRatio, presence);
      _snapshot = snapshot;
      _buildCount++;
      return _filter;
    }

    final shaderId = debugBilinearBackdropSampling
        ? GlassShaderId.finalRenderBilinearProbe
        : GlassShaderId.finalRender;
    final shader = _shader ??= ShaderLibrary.instance.acquire(shaderId);
    _writeUniforms(
      shader,
      matte,
      material,
      snapshot,
      devicePixelRatio,
      presence,
    );

    final glass = ui.ImageFilter.shader(shader);
    final frost = material.frost * presence * devicePixelRatio;
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

  /// The degraded filter: the frost, and nothing else.
  ///
  /// Returns null rather than an identity filter when there is no blur to
  /// apply — pushing a `BackdropFilter` that does nothing still forces a
  /// saveLayer and a full backdrop read for every glass surface on screen.
  static ui.ImageFilter? _blurOnly(
    GlassMaterial material,
    double devicePixelRatio,
    double presence,
  ) {
    final frost = material.frost * presence * devicePixelRatio;
    if (frost <= 0) {
      return null;
    }
    return ui.ImageFilter.blur(
      sigmaX: frost,
      sigmaY: frost,
      tileMode: TileMode.mirror,
    );
  }

  void _writeUniforms(
    ui.FragmentShader shader,
    MatteGeneration? matte,
    GlassMaterial material,
    FilterSnapshot snapshot,
    double devicePixelRatio,
    double presence,
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
      ..setFloat(i++, material.chromaticAberration * presence)
      ..setFloat(i++, material.tintOpacity * presence)
      ..setFloat(i++, 1 + (material.saturation - 1) * presence)
      ..setFloat(i++, tint.r)
      ..setFloat(i++, tint.g)
      ..setFloat(i++, tint.b)
      ..setFloat(i++, material.variant == GlassVariant.clear ? 1 : 0)
      ..setFloat(i++, material.highlight * presence)
      ..setFloat(i++, material.lightDirection.dx)
      ..setFloat(i++, material.lightDirection.dy)
      ..setFloat(i++, material.contour * presence)
      ..setFloat(i++, snapshot.coordinateMapping[0])
      ..setFloat(i++, snapshot.coordinateMapping[1])
      ..setFloat(i++, snapshot.coordinateMapping[2])
      ..setFloat(i++, snapshot.coordinateMapping[3])
      ..setFloat(i++, snapshot.coordinateMapping[4])
      ..setFloat(i++, snapshot.coordinateMapping[5])
      // uSurface: which profile shades this pass, and the slab thickness in
      // matte pixels, which sizes the dome's lit edge.
      ..setFloat(i++, material.profile == GlassProfile.dome ? 1 : 0)
      ..setFloat(i++, material.thickness * devicePixelRatio)
      // uSurface.z is presence: the shader scales the decoded displacement
      // magnitude by it and leaves the signed distance alone, so the
      // refraction fades without the edge moving. Written as a constant 0
      // before A1, which is why the shader edit and this one have to land
      // together.
      ..setFloat(i++, presence)
      ..setFloat(i++, 0)
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
