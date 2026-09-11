import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';

/// Every axis a tier can move, and how far it has moved each one.
///
/// The spec models tiering as a capability vector rather than a single
/// slider, because the axes have genuinely different costs and genuinely
/// different reasons to be turned down: chromatic aberration is two extra
/// texture taps per fragment, the geometry producer is a whole render pass,
/// and blur sigma is the one that scales with surface area. A device can be
/// short of any one of those without being short of the others.
///
/// [GlassTier] names the useful points in that space. This type is the space
/// itself, so an accessibility setting can land somewhere none of the named
/// presets sits — Increase Contrast is not a performance tier, but it moves
/// four of these axes at once.
@immutable
class TierProfile {
  /// Creates a profile.
  const TierProfile({
    required this.geometry,
    this.refractionScale = 1.0,
    this.blurScale = 1.0,
    this.chromaticAberration = true,
    this.specularScale = 1.0,
    this.elasticMotion = true,
    this.minimumFrost = 0.0,
    this.minimumTintOpacity = 0.0,
    this.minimumContour = 0.0,
    this.monochromeTint = false,
    this.rendersNothing = false,
  });

  /// Which geometry producer may bake the matte.
  final GeometryTier geometry;

  /// Multiplier on `edgeRefraction`. Zero removes lensing entirely.
  final double refractionScale;

  /// Multiplier on `frost`.
  final double blurScale;

  /// Whether the 3-tap dispersion may run at all.
  final bool chromaticAberration;

  /// Multiplier on the rim highlight.
  final double specularScale;

  /// Whether the material may have elastic properties.
  ///
  /// Consumed by the motion subsystem, not by the renderer: Apple's Reduce
  /// Motion contract is "decreases the intensity of some effects and
  /// disables any elastic properties for the material", which is a statement
  /// about springs, not about pixels. It lives here because Reduce Motion is
  /// a tier input like any other, and motion should read one resolved answer
  /// rather than re-derive the setting itself.
  final bool elasticMotion;

  /// A floor under `frost`, in logical pixels.
  ///
  /// A floor and not a target: Reduce Transparency has to make the material
  /// *frostier* than it was, and a material that was already frostier than
  /// this must not be thinned out to meet it.
  final double minimumFrost;

  /// A floor under `tintOpacity`.
  final double minimumTintOpacity;

  /// A floor under `contour` — the darkened edge ring that reads as a
  /// border.
  final double minimumContour;

  /// Whether the tint is forced to black or white.
  ///
  /// Apple's Increase Contrast contract: elements become "predominantly
  /// black or white and [are highlighted] with a contrasting border". Which
  /// of the two follows the platform brightness, which is why [applyTo]
  /// takes one.
  final bool monochromeTint;

  /// Whether glass renders at all.
  ///
  /// Reserved for the case where the renderer genuinely cannot: Skia, where
  /// `ui.ImageFilter.shader` throws rather than runs. [applyTo] then returns
  /// a material whose `rendersAnything` is false, so the layer pushes no
  /// backdrop pass and never constructs the filter that would have thrown.
  /// This is not the bottom of the performance ladder — that is
  /// [GlassTier.flat], which still draws a real surface.
  final bool rendersNothing;

  /// Applies this profile's limits to [material].
  ///
  /// Scales come first and floors come second, so a floor always wins: the
  /// point of a floor is that the user asked for at least this much
  /// obscuring, and a performance scale must not undo an accessibility
  /// requirement.
  GlassMaterial applyTo(
    GlassMaterial material, {
    required Brightness brightness,
  }) {
    if (rendersNothing) {
      // Every field `rendersAnything` checks, driven to its neutral value —
      // including `saturation`, which is neutral at 1 rather than at 0.
      return material.copyWith(
        edgeRefraction: 0,
        refractionSpread: 0,
        frost: 0,
        chromaticAberration: 0,
        tintOpacity: 0,
        saturation: 1,
        highlight: 0,
        contour: 0,
      );
    }

    final refraction = material.edgeRefraction * refractionScale;
    return material.copyWith(
      edgeRefraction: refraction,
      // Spread describes how far inward a band reaches. With no band it is
      // not merely unused, it is meaningless, and leaving it set would make
      // a re-baked matte differ for no visible reason.
      refractionSpread: refraction <= 0 ? 0 : material.refractionSpread,
      frost: math.max(material.frost * blurScale, minimumFrost),
      chromaticAberration: chromaticAberration
          ? material.chromaticAberration
          : 0,
      highlight: material.highlight * specularScale,
      tintOpacity: math.max(material.tintOpacity, minimumTintOpacity),
      contour: math.max(material.contour, minimumContour),
      tint: monochromeTint
          ? (brightness == Brightness.dark
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF))
          : material.tint,
    );
  }

  /// Returns a copy with the given fields replaced.
  TierProfile copyWith({
    GeometryTier? geometry,
    double? refractionScale,
    double? blurScale,
    bool? chromaticAberration,
    double? specularScale,
    bool? elasticMotion,
    double? minimumFrost,
    double? minimumTintOpacity,
    double? minimumContour,
    bool? monochromeTint,
    bool? rendersNothing,
  }) {
    return TierProfile(
      geometry: geometry ?? this.geometry,
      refractionScale: refractionScale ?? this.refractionScale,
      blurScale: blurScale ?? this.blurScale,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      specularScale: specularScale ?? this.specularScale,
      elasticMotion: elasticMotion ?? this.elasticMotion,
      minimumFrost: minimumFrost ?? this.minimumFrost,
      minimumTintOpacity: minimumTintOpacity ?? this.minimumTintOpacity,
      minimumContour: minimumContour ?? this.minimumContour,
      monochromeTint: monochromeTint ?? this.monochromeTint,
      rendersNothing: rendersNothing ?? this.rendersNothing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TierProfile &&
        other.geometry == geometry &&
        other.refractionScale == refractionScale &&
        other.blurScale == blurScale &&
        other.chromaticAberration == chromaticAberration &&
        other.specularScale == specularScale &&
        other.elasticMotion == elasticMotion &&
        other.minimumFrost == minimumFrost &&
        other.minimumTintOpacity == minimumTintOpacity &&
        other.minimumContour == minimumContour &&
        other.monochromeTint == monochromeTint &&
        other.rendersNothing == rendersNothing;
  }

  @override
  int get hashCode => Object.hash(
    geometry,
    refractionScale,
    blurScale,
    chromaticAberration,
    specularScale,
    elasticMotion,
    minimumFrost,
    minimumTintOpacity,
    minimumContour,
    monochromeTint,
    rendersNothing,
  );
}

/// The named points on the tier ladder, richest first.
///
/// Declaration order is the ladder, and [index] is load-bearing: the
/// resolver clamps and steps by it. Adding a rung means putting it in the
/// right place, not appending it.
enum GlassTier {
  /// Everything on: the Flutter GPU geometry pass, full edge refraction,
  /// full blur, dispersion, both specular lobes.
  full(TierProfile(geometry: GeometryTier.accelerated)),

  /// The runtime-effect geometry pass, still at full optical quality, minus
  /// dispersion.
  ///
  /// Dispersion goes first on the way down because it is the axis with the
  /// worst cost-to-visibility ratio — three taps per fragment for an effect
  /// whose presence in Apple's own material is not even established (see
  /// the architecture spec's open question 5).
  balanced(
    TierProfile(
      geometry: GeometryTier.portable,
      chromaticAberration: false,
    ),
  ),

  /// Half the lensing, less blur, one specular lobe's worth of highlight.
  reduced(
    TierProfile(
      geometry: GeometryTier.portable,
      refractionScale: 0.5,
      blurScale: 0.6,
      chromaticAberration: false,
      specularScale: 0.5,
    ),
  ),

  /// No lensing at all: a tinted, lightly blurred, bordered surface.
  ///
  /// Still bakes a matte, which is not a contradiction — the matte is what
  /// gives the surface its *shape*. Without one the composite pass has no
  /// coverage to work with and degrades to blurring the layer's whole
  /// rectangle, which is both wrong-looking and not cheaper. What this tier
  /// drops is the optical work, not the silhouette.
  flat(
    TierProfile(
      geometry: GeometryTier.portable,
      refractionScale: 0,
      blurScale: 0.5,
      chromaticAberration: false,
      specularScale: 0.25,
      minimumTintOpacity: 0.55,
      minimumContour: 0.3,
    ),
  ),

  /// Glass renders nothing.
  ///
  /// Not a performance rung — [lowered] will never step here — but the
  /// honest answer on a backend where `ui.ImageFilter.shader` throws.
  /// Children still paint normally; only the glass is gone.
  off(
    TierProfile(
      geometry: GeometryTier.none,
      refractionScale: 0,
      blurScale: 0,
      chromaticAberration: false,
      specularScale: 0,
      rendersNothing: true,
    ),
  );

  const GlassTier(this.profile);

  /// What this tier permits on each axis.
  final TierProfile profile;

  /// The poorer of this tier and [ceiling].
  ///
  /// "Poorer" is a higher [index]. Clamping rather than assigning is what
  /// lets four independent signals each impose a ceiling without any of them
  /// needing to know about the others.
  GlassTier clampedTo(GlassTier ceiling) =>
      index >= ceiling.index ? this : ceiling;

  /// This tier, [steps] rungs poorer, stopping at [flat].
  ///
  /// Never reaches [off]: no amount of heat or dropped frames means the
  /// renderer *cannot* draw glass, and a device that quietly stopped drawing
  /// it would look broken rather than degraded.
  GlassTier lowered(int steps) {
    if (steps <= 0) {
      return this;
    }
    final target = math.min(index + steps, GlassTier.flat.index);
    return GlassTier.values[math.max(target, index)];
  }
}
