import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:glass_forge/glass_forge.dart';

/// Morphs one material into another: every number glides, and the two
/// choices that pick an optical model — profile and variant — switch at the
/// halfway point, since there is no such thing as half a dome.
class GlassMaterialTween extends Tween<GlassMaterial> {
  GlassMaterialTween({super.begin, super.end});

  @override
  GlassMaterial lerp(double t) {
    final a = begin ?? end!;
    final b = end ?? begin!;
    if (t <= 0) return a;
    if (t >= 1) return b;
    final model = t < 0.5 ? a : b;
    double mix(double x, double y) => lerpDouble(x, y, t)!;
    return GlassMaterial(
      variant: model.variant,
      profile: model.profile,
    ).copyWith(
      thickness: mix(a.thickness, b.thickness),
      edgeRefraction: mix(a.edgeRefraction, b.edgeRefraction),
      refractionSpread: mix(a.refractionSpread, b.refractionSpread),
      frost: mix(a.frost, b.frost),
      chromaticAberration: mix(a.chromaticAberration, b.chromaticAberration),
      tint: Color.lerp(a.tint, b.tint, t),
      tintOpacity: mix(a.tintOpacity, b.tintOpacity),
      saturation: mix(a.saturation, b.saturation),
      highlight: mix(a.highlight, b.highlight),
      lightDirection: Offset.lerp(a.lightDirection, b.lightDirection, t),
      contour: mix(a.contour, b.contour),
    );
  }
}
