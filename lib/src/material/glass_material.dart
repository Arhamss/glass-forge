import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

part 'apple_presets.dart';
part 'dome_preset.dart';

/// How a glass surface looks.
///
/// Parameters are observable quantities in logical pixels, not physical
/// constants. [edgeRefraction] is how far the edge visibly displaces what is
/// behind it — the refractive index is derived from it, because Apple exposes
/// no index and nobody thinks in them.
@immutable
class GlassMaterial {
  /// Creates a material.
  const GlassMaterial({
    this.variant = GlassVariant.regular,
    this.profile = GlassProfile.edgeBand,
    this.thickness = 12.0,
    this.edgeRefraction = 27.42,
    this.refractionSpread = 0.0,
    this.frost = 5.0,
    this.chromaticAberration = 0.0,
    this.tint = const Color(0x00FFFFFF),
    this.tintOpacity = 0.0,
    this.saturation = 1.0,
    this.highlight = 1.0,
    this.lightDirection = const Offset(0, 1),
    this.contour = 0.0,
  });

  /// The fitted regular material. See `apple_presets.dart` for provenance.
  factory GlassMaterial.regular({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    return const GlassMaterial().copyWith(
      thickness: _appleThickness,
      edgeRefraction: _appleEdgeRefraction,
      frost: dark ? _appleRegularFrostDark : _appleRegularFrostLight,
      saturation: dark
          ? _appleRegularSaturationDark
          : _appleRegularSaturationLight,
      tint: dark ? _appleRegularTintDark : _appleRegularTintLight,
      tintOpacity: dark
          ? _appleRegularTintOpacityDark
          : _appleRegularTintOpacityLight,
      highlight: _appleRegularHighlight,
      contour: _appleContour,
    );
  }

  /// The fitted clear material. See `apple_presets.dart` for provenance.
  ///
  /// Apple: clear "does not have adaptive behaviors", so unlike
  /// [GlassMaterial.regular] this takes no `brightness` — the 35% scrim it
  /// applies is computed in-shader from sampled backdrop luminance, not from
  /// platform brightness, so there is nothing here for that parameter to do.
  factory GlassMaterial.clear() {
    return const GlassMaterial(variant: GlassVariant.clear).copyWith(
      thickness: _appleThickness,
      edgeRefraction: _appleEdgeRefraction,
      frost: _appleClearFrost,
      tintOpacity: _appleClearTintOpacity,
      highlight: _appleClearHighlight,
      contour: _appleContour,
    );
  }

  /// The lens a dome of glass makes, as opposed to Apple's flat pane.
  ///
  /// Not fitted data: the Apple presets are, and this is not one of them.
  /// See `dome_preset.dart` for what each value is doing and why.
  factory GlassMaterial.dome() {
    return const GlassMaterial(profile: GlassProfile.dome).copyWith(
      thickness: _domeThickness,
      edgeRefraction: _domeEdgeRefraction,
      frost: _domeFrost,
      chromaticAberration: _domeChromaticAberration,
      tintOpacity: _domeTintOpacity,
      saturation: _domeSaturation,
      highlight: _domeHighlight,
      contour: _domeContour,
      lightDirection: _domeLightDirection,
    );
  }

  /// Regular or clear.
  final GlassVariant variant;

  /// Whether the surface refracts only at its rim, or across its whole
  /// interior as a dome.
  ///
  /// Every other field keeps its meaning under both, with two exceptions.
  /// [edgeRefraction] is still the displacement at the rim; under
  /// [GlassProfile.dome] the interior is displaced too, falling smoothly to
  /// nothing at the centre, which is a magnifying lens -- and the rim never
  /// moves more than 0.35 of the shape's depth, because past that a lens
  /// folds its own image. Under a dome [thickness] barely changes the
  /// displacement and mostly sets the width of the lit edge.
  /// [refractionSpread] shapes only the edge band and has no effect on a
  /// dome, whose extent is the shape.
  final GlassProfile profile;

  /// Apparent depth of the surface, in logical pixels.
  final double thickness;

  /// Peak edge displacement, in logical pixels.
  ///
  /// The observable knob. The refractive index follows from it:
  /// `ratio = edgeRefraction / (8 * thickness); n = sqrt(1 + ratio^2)`.
  final double edgeRefraction;

  /// How far the refraction band reaches inward. 0 is a tight edge band.
  final double refractionSpread;

  /// Blur sigma applied to the backdrop, in logical pixels.
  final double frost;

  /// Dispersion between colour channels. 0 disables the extra taps entirely.
  final double chromaticAberration;

  /// Tint colour.
  final Color tint;

  /// How strongly [tint] is applied.
  final double tintOpacity;

  /// Backdrop saturation multiplier.
  final double saturation;

  /// Rim highlight strength.
  final double highlight;

  /// Direction the rim light comes from.
  ///
  /// Fed from the accelerometer on phones, where Apple's material responds to
  /// device motion; fixed elsewhere, since macOS has no IMU.
  final Offset lightDirection;

  /// Strength of the darkened edge ring.
  final double contour;

  /// Whether this material would put anything on screen.
  ///
  /// When false the layer pushes no backdrop filter at all, so an idle or
  /// fully-hidden glass surface costs nothing.
  ///
  /// Every field with an independently visible effect at its non-neutral
  /// value must be checked here, or a material that only sets that one field
  /// silently vanishes. [saturation] is a multiplier neutral at `1.0`, not
  /// at `0`, so it is compared to its neutral value rather than to zero.
  bool get rendersAnything =>
      frost > 0 ||
      edgeRefraction > 0 ||
      tintOpacity > 0 ||
      highlight > 0 ||
      contour > 0 ||
      saturation != 1.0;

  /// The displacement range the matte codec should cover, in logical pixels.
  double get maxDisplacement => MatteCodec.displacementRangeFor(edgeRefraction);

  /// The derived refractive index.
  double get refractiveIndex {
    final ratio = edgeRefraction / math.max(1e-3, 8 * thickness);
    return math.sqrt(1 + ratio * ratio);
  }

  /// Changes whenever any field changes; used to invalidate cached filters.
  ///
  /// Reusing [hashCode] means two genuinely different materials could in
  /// theory collide and be treated as unchanged, but every field that feeds a
  /// shader uniform also feeds [hashCode] (see the tests), so this is a
  /// well-distributed 64-bit hash over the whole material rather than a
  /// hand-picked subset — the risk is the same one every hashCode-keyed cache
  /// in the platform already accepts.
  int get revision => hashCode;

  /// Returns a copy with the given fields replaced.
  GlassMaterial copyWith({
    GlassVariant? variant,
    GlassProfile? profile,
    double? thickness,
    double? edgeRefraction,
    double? refractionSpread,
    double? frost,
    double? chromaticAberration,
    Color? tint,
    double? tintOpacity,
    double? saturation,
    double? highlight,
    Offset? lightDirection,
    double? contour,
  }) {
    return GlassMaterial(
      variant: variant ?? this.variant,
      profile: profile ?? this.profile,
      thickness: thickness ?? this.thickness,
      edgeRefraction: edgeRefraction ?? this.edgeRefraction,
      refractionSpread: refractionSpread ?? this.refractionSpread,
      frost: frost ?? this.frost,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      tint: tint ?? this.tint,
      tintOpacity: tintOpacity ?? this.tintOpacity,
      saturation: saturation ?? this.saturation,
      highlight: highlight ?? this.highlight,
      lightDirection: lightDirection ?? this.lightDirection,
      contour: contour ?? this.contour,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassMaterial &&
        other.variant == variant &&
        other.profile == profile &&
        other.thickness == thickness &&
        other.edgeRefraction == edgeRefraction &&
        other.refractionSpread == refractionSpread &&
        other.frost == frost &&
        other.chromaticAberration == chromaticAberration &&
        other.tint == tint &&
        other.tintOpacity == tintOpacity &&
        other.saturation == saturation &&
        other.highlight == highlight &&
        other.lightDirection == lightDirection &&
        other.contour == contour;
  }

  @override
  int get hashCode => Object.hash(
    variant,
    profile,
    thickness,
    edgeRefraction,
    refractionSpread,
    frost,
    chromaticAberration,
    tint,
    tintOpacity,
    saturation,
    highlight,
    lightDirection,
    contour,
  );
}
