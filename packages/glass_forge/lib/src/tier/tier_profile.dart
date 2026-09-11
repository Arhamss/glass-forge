import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';

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
    this.dome = true,
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

  /// Whether a [GlassProfile.dome] material may stay a dome.
  ///
  /// False flattens it to [GlassProfile.edgeBand], keeping its tint,
  /// saturation, frost, light, contour and dispersion; this profile's scales
  /// and floors then apply as they would to any edge band. What flattening
  /// takes away is the lens across the interior, the one thing the edge band
  /// cannot draw, and it adds nothing the dome did not show:
  ///
  /// - **The rim refracts no wider than the edge the dome lit.** Under a dome
  ///   `thickness` is the width of the lit edge, so after this profile's
  ///   [refractionScale] the displacement is capped at it. A band mirrors
  ///   the strip just inside itself — `gfEdgeBandFit` keeps its samples off
  ///   the medial axis, but the profile still turns back on itself within
  ///   the band — and the dome preset has no frost to hide that. Rendered
  ///   offscreen over a grid in the Impeller test lane, with the fitted
  ///   band, the preset flattened at half its rim displacement (20 px)
  ///   duplicated and hooked the backdrop all round the rim of a 160 px
  ///   square and folded a disc into a C on a 44 px pill; 14 px did the
  ///   same more narrowly. Capped at its 8 px thickness it read as the same
  ///   clear glass gone flat. On a control that size the dome itself
  ///   displaces its rim about 8 px, since it never moves more than 0.35 of
  ///   a shape's depth, so there the rim barely changes across the swap.
  /// - **Refraction spread goes to zero.** It shapes only the edge band, so
  ///   on a dome it was never visible, and flattening must not switch on a
  ///   setting nobody could see.
  ///
  /// It is an axis of its own because nothing else on the ladder cuts what
  /// a dome costs. Nothing has timed that cost yet. These are counts of
  /// work read off the shaders, per texel or fragment, not durations:
  ///
  /// - **The bake** (`shaders/common/matte_pass.glsl`), paid again whenever
  ///   a shape moves or the material changes. The edge band folds the
  ///   scene 5 times — once for distance, 4 for the normal — and a 6th
  ///   inside the band, for the depth its fit needs. The dome folds it 7
  ///   times everywhere: distance, the steering proxy, the depth at the
  ///   core and 4 for the direction. 5 of those 7 widen every blend to at
  ///   least 3 rim displacements, which keeps the bound check from culling
  ///   any shape that near.
  /// - **The final pass** (`shaders/final_render.frag`), paid every frame.
  ///   The edge band reads the backdrop once a fragment, or 3 times with
  ///   dispersion. The dome reads it bilinearly, 4 taps a read: 4 taps, or
  ///   12 with dispersion.
  ///
  /// So [chromaticAberration] is the largest cut a dome can take and stay a
  /// dome, 12 taps to 4, and [GlassTier.balanced] takes it. After that only
  /// this flag cuts much: [blurScale] saves only what frost costs, and the
  /// dome preset has no frost, while a smaller [refractionScale] moves the
  /// same taps and folds a shorter distance. Flattening takes the reads
  /// from 4 to 1, and the bake from 7 folds a texel to 5, or 6 in the
  /// band.
  final bool dome;

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
  /// A dome is flattened first, when [dome] says so, so that every scale and
  /// floor after it lands on the surface that will actually be drawn. Then
  /// scales come first and floors second, so a floor always wins: the point
  /// of a floor is that the user asked for at least this much obscuring,
  /// and a performance scale must not undo an accessibility requirement.
  GlassMaterial applyTo(
    GlassMaterial material, {
    required Brightness brightness,
  }) {
    // Before the early return below as well, so that a material degraded to
    // nothing does not still claim a profile it will never be drawn with.
    final flattens = !dome && material.profile == GlassProfile.dome;
    final surface = flattens
        ? material.copyWith(profile: GlassProfile.edgeBand, refractionSpread: 0)
        : material;

    if (rendersNothing) {
      // Every field `rendersAnything` checks, driven to its neutral value —
      // including `saturation`, which is neutral at 1 rather than at 0.
      return surface.copyWith(
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

    final scaled = surface.edgeRefraction * refractionScale;
    // See [dome] for why a flattened rim is held to the width of the edge
    // the dome lit. Typed, so a thickness of zero stays a double.
    final double lit = math.max(surface.thickness, 0);
    final refraction = flattens ? math.min(scaled, lit) : scaled;
    return surface.copyWith(
      edgeRefraction: refraction,
      // Spread describes how far inward a band reaches. With no band it is
      // not merely unused, it is meaningless, and leaving it set would make
      // a re-baked matte differ for no visible reason.
      refractionSpread: refraction <= 0 ? 0 : surface.refractionSpread,
      frost: math.max(surface.frost * blurScale, minimumFrost),
      chromaticAberration: chromaticAberration
          ? surface.chromaticAberration
          : 0,
      highlight: surface.highlight * specularScale,
      tintOpacity: math.max(surface.tintOpacity, minimumTintOpacity),
      contour: math.max(surface.contour, minimumContour),
      tint: monochromeTint
          ? (brightness == Brightness.dark
                ? const Color(0xFF000000)
                : const Color(0xFFFFFFFF))
          : surface.tint,
    );
  }

  /// Returns a copy with the given fields replaced.
  TierProfile copyWith({
    GeometryTier? geometry,
    double? refractionScale,
    double? blurScale,
    bool? chromaticAberration,
    bool? dome,
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
      dome: dome ?? this.dome,
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
        other.dome == dome &&
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
    dome,
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
  /// full blur, dispersion, both specular lobes. A dome stays a dome,
  /// dispersion and all.
  full(TierProfile(geometry: GeometryTier.accelerated)),

  /// The runtime-effect geometry pass, still at full optical quality, minus
  /// dispersion.
  ///
  /// Dispersion goes first on the way down because it is the axis with the
  /// worst cost-to-visibility ratio — three taps per fragment for an effect
  /// whose presence in Apple's own material is not even established (see
  /// the architecture spec's open question 5).
  ///
  /// For a dome this is the cheaper dome. Its taps are bilinear, so
  /// dispersion is 8 of its 12 backdrop taps a fragment, and the dome preset
  /// already keeps dispersion low. A strained device keeps its lens here;
  /// see [TierProfile.dome].
  balanced(
    TierProfile(
      geometry: GeometryTier.portable,
      chromaticAberration: false,
    ),
  ),

  /// Half the lensing, less blur, one specular lobe's worth of highlight,
  /// and no domes.
  ///
  /// A dome kept as a dome here would cost exactly what it cost at
  /// [balanced]: dispersion is already gone, the preset has no frost for
  /// the blur scale to save, and half the displacement is the same taps and
  /// folds (see [TierProfile.dome] for the counts). Frame health can take
  /// the ladder two rungs down and no further, so a saturated device whose
  /// second rung saved nothing would stay saturated. Flattening is the only
  /// cut left, so this is where it happens. Getting here takes serious heat
  /// or sustained dropped frames, not a stutter.
  ///
  /// The flattened dome keeps a refracting rim no wider than the edge it
  /// lit as a dome; [TierProfile.dome] has the renders that decided that.
  reduced(
    TierProfile(
      geometry: GeometryTier.portable,
      refractionScale: 0.5,
      blurScale: 0.6,
      chromaticAberration: false,
      dome: false,
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
  ///
  /// No domes either, and not only for cost. A dome with no displacement
  /// still bakes a field of zeros at the dome's 7 folds and reads its
  /// backdrop through bilinear taps with nothing to interpolate. It still
  /// shades as a dome, too: glints, and a Beer-Lambert darkening that
  /// spreads the contour over the lit edge. The border this rung promises,
  /// and the one Increase Contrast and Reduce Transparency ask for by
  /// pinning it, is the edge band's contour ring.
  flat(
    TierProfile(
      geometry: GeometryTier.portable,
      refractionScale: 0,
      blurScale: 0.5,
      chromaticAberration: false,
      dome: false,
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
      dome: false,
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
