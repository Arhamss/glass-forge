import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/design/glass_legibility.dart';
import 'package:glass_forge/src/design/glass_motion_defaults.dart';
import 'package:glass_forge/src/design/glass_tint.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

/// How far a surface is allowed to go to stay legible over its backdrop.
///
/// Apple splits this three ways and the split is gated on size, not on
/// component type: "small elements like navbars and tabbars… flip from light
/// to dark based on the background. Larger elements like menus and sidebars
/// adapt based on context, but they don't flip." Clear glass does neither —
/// it "does not have adaptive behaviors" at all.
///
/// The gate lives here rather than in the renderer because it is a *design*
/// decision about what a role means, and because the renderer has no idea
/// how big anything is until long after the material has been chosen.
enum GlassAdaptation {
  /// Chooses the light or dark scheme outright, from what is behind.
  ///
  /// Strictly better legibility than [adapt] — a flipping surface can always
  /// pick the more readable of two schemes, where an adapting one is stuck
  /// with the ambient one and can only thicken its tint. That is the whole
  /// reason the rule is worth implementing.
  flip,

  /// Keeps the ambient scheme, and raises its tint until labels clear the
  /// role's contrast target.
  adapt,

  /// Neither. The material is whatever the scheme says and nothing moves it.
  none,
}

/// The recurring roles a consumer actually reaches for.
///
/// Deliberately short. Apple's guidance is that glass belongs to "the
/// navigation layer that floats above the content" — a longer list would be
/// a list of places not to use it.
enum GlassSurfaceRole {
  /// A navigation bar, tab bar or toolbar.
  navigationBar,

  /// A sheet, popover or sidebar.
  sheet,

  /// A card in the content layer.
  card,

  /// A button, toggle, slider or segmented control.
  control,

  /// The dimming layer under a modal.
  scrim,
}

/// What a role is made of, before it meets a size and a backdrop.
///
/// Everything here is a token *name*, never a number, which is the point of
/// the layer: a role says "thick blur, readable tint, presented depth" and a
/// theme decides what those are worth.
@immutable
class GlassSurfaceSpec {
  /// Creates a spec.
  const GlassSurfaceSpec({
    required this.blur,
    required this.tint,
    required this.radius,
    required this.depth,
    required this.adaptation,
    required this.motion,
    required this.minimumContrast,
    this.variant = GlassVariant.regular,
  });

  /// A navigation bar, tab bar or toolbar.
  ///
  /// Flips, because Apple names navigation bars and tab bars as the
  /// canonical flipping elements. Takes the regular tint and a 3:1 target:
  /// a bar carries a title and controls, which is WCAG's large-text and
  /// UI-component case, and it is also where Apple's own fitted value
  /// lands. An app whose bar carries small text raises [tint] to
  /// [GlassTintStep.readable] and [minimumContrast] to 4.5.
  static const GlassSurfaceSpec navigationBar = GlassSurfaceSpec(
    blur: GlassBlurStep.regular,
    tint: GlassTintStep.regular,
    radius: GlassRadiusStep.large,
    depth: GlassDepthStep.floating,
    adaptation: GlassAdaptation.flip,
    motion: GlassMotionRole.settle,
    minimumContrast: 3,
  );

  /// A sheet, popover or sidebar.
  ///
  /// Adapts but never flips — Apple's second half of the same sentence. It
  /// covers a screenful of different things, so one luminance reading does
  /// not describe what is behind it and a single flip decision would be
  /// wrong for most of its area. Blurs thick and tints to 4.5:1 because a
  /// sheet carries body text.
  static const GlassSurfaceSpec sheet = GlassSurfaceSpec(
    blur: GlassBlurStep.thick,
    tint: GlassTintStep.readable,
    radius: GlassRadiusStep.extraLarge,
    depth: GlassDepthStep.presented,
    adaptation: GlassAdaptation.adapt,
    motion: GlassMotionRole.present,
    minimumContrast: 4.5,
  );

  /// A card in the content layer.
  ///
  /// Adapts rather than flips: a card is usually well over the flip
  /// threshold anyway, and a content-layer element that inverted its own
  /// scheme as the page scrolled would be the "appear, disappear and change
  /// colour with seemingly little relevance" failure Apple is criticised
  /// for. Body text, so 4.5:1.
  static const GlassSurfaceSpec card = GlassSurfaceSpec(
    blur: GlassBlurStep.regular,
    tint: GlassTintStep.readable,
    radius: GlassRadiusStep.medium,
    depth: GlassDepthStep.raised,
    adaptation: GlassAdaptation.adapt,
    motion: GlassMotionRole.settle,
    minimumContrast: 4.5,
  );

  /// A button, toggle, slider or segmented control.
  ///
  /// The one role that is reliably small, so the one that reliably flips.
  /// Blurs thin: it covers about a word of backdrop, and Apple asks for blur
  /// to scale with element size. Capsule, which is what a 44 pt control
  /// resolves to on the radius ladder anyway, stated explicitly so it stays
  /// a capsule at other heights.
  static const GlassSurfaceSpec control = GlassSurfaceSpec(
    blur: GlassBlurStep.thin,
    tint: GlassTintStep.regular,
    radius: GlassRadiusStep.capsule,
    depth: GlassDepthStep.raised,
    adaptation: GlassAdaptation.flip,
    motion: GlassMotionRole.press,
    minimumContrast: 3,
  );

  /// The dimming layer under a modal.
  ///
  /// The only role that does not adapt at all, because a scrim's whole job
  /// is to be the *same* amount of separation over everything — a scrim that
  /// thinned out over easy backdrops would let the content behind compete
  /// with the modal exactly where it is most distracting. Square, flush, and
  /// blurred as hard as the ladder goes.
  static const GlassSurfaceSpec scrim = GlassSurfaceSpec(
    blur: GlassBlurStep.ultra,
    tint: GlassTintStep.readable,
    radius: GlassRadiusStep.none,
    depth: GlassDepthStep.flush,
    adaptation: GlassAdaptation.none,
    motion: GlassMotionRole.present,
    minimumContrast: 4.5,
  );

  /// Regular or clear.
  final GlassVariant variant;

  /// Which blur step this role takes.
  final GlassBlurStep blur;

  /// Which tint step this role takes when no backdrop is known.
  final GlassTintStep tint;

  /// Which corner radius this role takes.
  final GlassRadiusStep radius;

  /// Which depth step this role takes.
  final GlassDepthStep depth;

  /// The most adaptation this role is allowed.
  ///
  /// A ceiling, not a guarantee: [adaptationFor] can demote
  /// [GlassAdaptation.flip] to [GlassAdaptation.adapt] on a surface that
  /// turned out to be large, and never promotes in the other direction.
  final GlassAdaptation adaptation;

  /// Which spring this role moves on.
  final GlassMotionRole motion;

  /// The label contrast this role promises over a known backdrop.
  ///
  /// 3 for chrome, 4.5 where body text sits. Only meaningful when a backdrop
  /// is supplied to [resolve] — with nothing to measure against, the
  /// baseline [tint] step is all there is, and that step already carries the
  /// same promise against the worst case.
  final double minimumContrast;

  /// How much adaptation a surface of [size] actually gets.
  ///
  /// The gate only ever removes adaptation. Promoting
  /// [GlassAdaptation.adapt] to [GlassAdaptation.flip] because something
  /// happened to be small would let a sidebar invert itself on a phone,
  /// which is the behaviour Apple explicitly excludes.
  GlassAdaptation adaptationFor(Size size, {required double maxShortSide}) {
    if (variant == GlassVariant.clear) {
      // Apple: clear "does not have adaptive behaviors". Not a size
      // question at all.
      return GlassAdaptation.none;
    }
    if (adaptation != GlassAdaptation.flip) {
      return adaptation;
    }
    final shortSide = math.min(size.width, size.height);
    return shortSide <= maxShortSide
        ? GlassAdaptation.flip
        : GlassAdaptation.adapt;
  }

  /// Resolves this role against a real size, scheme and backdrop.
  ///
  /// [backdrop] is what is actually behind the surface. Supply it when the
  /// app knows — a fixed page background, a known artwork colour — and
  /// leave it null otherwise: nothing in this package samples the backdrop
  /// yet, so a guess here would be worse than the honest baseline. Without
  /// it the role's own [tint] step is used unchanged, and that step is
  /// already the smallest one that keeps its promise against the worst
  /// case.
  GlassSurfaceStyle resolve({
    required Size size,
    required Brightness platformBrightness,
    GlassTokens tokens = const GlassTokens(),
    GlassMotionDefaults motionDefaults = const GlassMotionDefaults(),
    Color? backdrop,
  }) {
    final resolvedAdaptation = adaptationFor(
      size,
      maxShortSide: tokens.flipMaxShortSide,
    );

    final brightness =
        resolvedAdaptation == GlassAdaptation.flip && backdrop != null
        ? tokens.tint.schemeFor(backdrop, step: tint)
        : platformBrightness;

    final ramp = tokens.tint.of(brightness);
    final isClear = variant == GlassVariant.clear;
    final base = isClear
        ? GlassMaterial.clear()
        : GlassMaterial.regular(brightness: brightness);

    var opacity = isClear ? base.tintOpacity : ramp.opacityFor(tint);
    if (!isClear &&
        backdrop != null &&
        resolvedAdaptation != GlassAdaptation.none) {
      opacity = GlassLegibility.opacityForContrast(
        tint: ramp.color,
        backdrop: backdrop,
        label: ramp.label,
        target: minimumContrast,
        floor: opacity,
        ceiling: ramp.opaque,
      );
    }

    final material = base.copyWith(
      // A ratio, not an absolute sigma, so the fitted frost's own
      // light/dark difference survives every step but `regular`.
      frost: base.frost * tokens.blur.factorOf(blur),
      tint: isClear ? base.tint : ramp.color,
      tintOpacity: opacity,
    );

    return GlassSurfaceStyle(
      material: material,
      shape: GlassSuperellipse(
        // Superellipse for every role: Apple's corners are continuous, and
        // this is the one shape whose SDF matches Flutter's own
        // RoundedSuperellipse clip exactly, so refraction and clip agree at
        // the corners.
        radius: BorderRadius.circular(tokens.radius.radiusOf(radius)),
      ),
      motion: motionDefaults.of(motion),
      shadows: tokens.depth.shadowsOf(depth),
      labelColor: ramp.label,
      brightness: brightness,
      adaptation: resolvedAdaptation,
      labelContrast: backdrop == null
          ? null
          : GlassLegibility.labelContrast(
              tint: isClear ? base.tint : ramp.color,
              opacity: opacity,
              backdrop: backdrop,
              label: ramp.label,
            ),
    );
  }

  /// Returns a copy with the given fields replaced.
  GlassSurfaceSpec copyWith({
    GlassVariant? variant,
    GlassBlurStep? blur,
    GlassTintStep? tint,
    GlassRadiusStep? radius,
    GlassDepthStep? depth,
    GlassAdaptation? adaptation,
    GlassMotionRole? motion,
    double? minimumContrast,
  }) {
    return GlassSurfaceSpec(
      variant: variant ?? this.variant,
      blur: blur ?? this.blur,
      tint: tint ?? this.tint,
      radius: radius ?? this.radius,
      depth: depth ?? this.depth,
      adaptation: adaptation ?? this.adaptation,
      motion: motion ?? this.motion,
      minimumContrast: minimumContrast ?? this.minimumContrast,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassSurfaceSpec &&
        other.variant == variant &&
        other.blur == blur &&
        other.tint == tint &&
        other.radius == radius &&
        other.depth == depth &&
        other.adaptation == adaptation &&
        other.motion == motion &&
        other.minimumContrast == minimumContrast;
  }

  @override
  int get hashCode => Object.hash(
    variant,
    blur,
    tint,
    radius,
    depth,
    adaptation,
    motion,
    minimumContrast,
  );
}

/// A role, resolved against a size, a scheme and a backdrop.
///
/// Everything a consumer needs to draw one surface, and nothing that still
/// needs deciding.
@immutable
class GlassSurfaceStyle {
  /// Creates a resolved style.
  const GlassSurfaceStyle({
    required this.material,
    required this.shape,
    required this.motion,
    required this.shadows,
    required this.labelColor,
    required this.brightness,
    required this.adaptation,
    required this.labelContrast,
  });

  /// The material to render.
  final GlassMaterial material;

  /// The silhouette.
  final GlassShape shape;

  /// The spring this surface moves on.
  final GlassMotion motion;

  /// The shadow that says how far above the content this sits.
  final List<BoxShadow> shadows;

  /// The colour labels on this surface must be drawn in.
  ///
  /// Apple's rule is that labels go vibrant rather than hard-coded, and this
  /// is the closest honest approximation: the scheme that won picks the one
  /// of black or white it exists to make readable.
  final Color labelColor;

  /// The scheme that won — the platform's, or the flipped one.
  final Brightness brightness;

  /// How much adaptation this surface actually got, after size gating.
  final GlassAdaptation adaptation;

  /// The contrast [labelColor] gets on this surface, or null when no
  /// backdrop was supplied to measure against.
  ///
  /// Exposed because a promise nobody can read is not a promise. A debug
  /// overlay, a test, or an app with an unusual background can all check
  /// what they are actually getting.
  final double? labelContrast;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassSurfaceStyle &&
        other.material == material &&
        other.shape == shape &&
        other.motion == motion &&
        listEquals(other.shadows, shadows) &&
        other.labelColor == labelColor &&
        other.brightness == brightness &&
        other.adaptation == adaptation &&
        other.labelContrast == labelContrast;
  }

  @override
  int get hashCode => Object.hash(
    material,
    shape,
    motion,
    Object.hashAll(shadows),
    labelColor,
    brightness,
    adaptation,
    labelContrast,
  );
}

/// The five roles, and what each one is made of.
///
/// Each field defaults to its fitted spec, so overriding one role names one
/// role: `GlassSurfaces(card: GlassSurfaceSpec.card.copyWith(blur: thick))`
/// leaves the other four exactly as they were.
@immutable
class GlassSurfaces {
  /// Creates a set of surfaces. Naming one leaves the rest fitted.
  const GlassSurfaces({
    this.navigationBar = GlassSurfaceSpec.navigationBar,
    this.sheet = GlassSurfaceSpec.sheet,
    this.card = GlassSurfaceSpec.card,
    this.control = GlassSurfaceSpec.control,
    this.scrim = GlassSurfaceSpec.scrim,
  });

  /// The spec for [GlassSurfaceRole.navigationBar].
  final GlassSurfaceSpec navigationBar;

  /// The spec for [GlassSurfaceRole.sheet].
  final GlassSurfaceSpec sheet;

  /// The spec for [GlassSurfaceRole.card].
  final GlassSurfaceSpec card;

  /// The spec for [GlassSurfaceRole.control].
  final GlassSurfaceSpec control;

  /// The spec for [GlassSurfaceRole.scrim].
  final GlassSurfaceSpec scrim;

  /// The spec [role] resolves to.
  GlassSurfaceSpec of(GlassSurfaceRole role) => switch (role) {
    GlassSurfaceRole.navigationBar => navigationBar,
    GlassSurfaceRole.sheet => sheet,
    GlassSurfaceRole.card => card,
    GlassSurfaceRole.control => control,
    GlassSurfaceRole.scrim => scrim,
  };

  /// Returns a copy with the given fields replaced.
  GlassSurfaces copyWith({
    GlassSurfaceSpec? navigationBar,
    GlassSurfaceSpec? sheet,
    GlassSurfaceSpec? card,
    GlassSurfaceSpec? control,
    GlassSurfaceSpec? scrim,
  }) {
    return GlassSurfaces(
      navigationBar: navigationBar ?? this.navigationBar,
      sheet: sheet ?? this.sheet,
      card: card ?? this.card,
      control: control ?? this.control,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassSurfaces &&
        other.navigationBar == navigationBar &&
        other.sheet == sheet &&
        other.card == card &&
        other.control == control &&
        other.scrim == scrim;
  }

  @override
  int get hashCode => Object.hash(navigationBar, sheet, card, control, scrim);
}
