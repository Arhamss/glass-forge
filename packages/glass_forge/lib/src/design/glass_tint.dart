import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/design/glass_legibility.dart';

/// A named point on a tint ramp.
///
/// The names are legibility promises, not sizes. Each one is the *smallest*
/// tint opacity that keeps its promise over the worst backdrop the scheme
/// can face, so asking for a stronger step never buys more transparency than
/// the promise needs — which is what Apple means by "letting as much of the
/// content through as possible".
enum GlassTintStep {
  /// Clears 3:1 — WCAG 2.2's floor for large text and for UI components.
  legible,

  /// Apple's own fitted value. Sits between [legible] and [readable].
  regular,

  /// Clears 4.5:1 — WCAG 2.2's floor for body text.
  readable,

  /// Clears 7:1 — WCAG 2.2 AAA, and the treatment Increase Contrast asks
  /// for.
  opaque,
}

/// One brightness scheme's tint colour and the opacities it is used at.
///
/// Two things are fixed per scheme and one varies. The **colour** is fixed:
/// it comes from the fitted Apple captures in `apple_presets.dart` and is
/// not ours to retune. The **label colour** is fixed: a scheme exists so
/// that one of white or black is the readable one. The **opacity** is the
/// ramp, and every step on it is derived rather than chosen — see
/// [GlassTintStep].
///
/// The worst case each step is derived against is the backdrop that hurts
/// that scheme most: pure white under the dark scheme, pure black under the
/// light scheme. Anything else in between is strictly better, so a step that
/// clears its threshold at the worst case clears it everywhere.
@immutable
class GlassTintRamp {
  /// Creates a ramp.
  const GlassTintRamp({
    required this.color,
    required this.label,
    required this.legible,
    required this.regular,
    required this.readable,
    required this.opaque,
  });

  /// The light scheme, fitted to iOS 27.
  ///
  /// [color] is `_appleRegularTintLight` and [regular] is
  /// `_appleRegularTintOpacityLight`, both from `apple_presets.dart`. The
  /// other three are solved from that colour against a black backdrop: 0.353
  /// reaches 3:1, 0.461 reaches 4.5:1, 0.591 reaches 7:1. Apple's fitted
  /// 0.407 lands between the first two — its own material is legible for
  /// large text and short of the body-text threshold, which is the
  /// compromise, not a bug in the fit.
  static const GlassTintRamp appleLight = GlassTintRamp(
    color: Color(0xFFFDFCFD),
    label: Color(0xFF000000),
    legible: 0.353,
    regular: 0.407,
    readable: 0.461,
    opaque: 0.591,
  );

  /// The dark scheme, fitted to iOS 27.
  ///
  /// [color] is `_appleRegularTintDark` and [regular] is
  /// `_appleRegularTintOpacityDark`. Note that it is `0xFF3A3A3A` and not
  /// black: Apple's dark tint is a lifted grey, so the surface reads as
  /// glass with light behind it rather than as a hole cut in the screen.
  /// Solved against a white backdrop, 0.539 reaches 3:1, 0.693 reaches 4.5:1
  /// and 0.843 reaches 7:1 — so the fitted 0.56 clears the first by a
  /// hair's breadth and nothing more.
  static const GlassTintRamp appleDark = GlassTintRamp(
    color: Color(0xFF3A3A3A),
    label: Color(0xFFFFFFFF),
    legible: 0.539,
    regular: 0.56,
    readable: 0.693,
    opaque: 0.843,
  );

  /// The tint colour.
  final Color color;

  /// The colour labels on this scheme's glass are drawn in.
  final Color label;

  /// Opacity at [GlassTintStep.legible].
  final double legible;

  /// Opacity at [GlassTintStep.regular].
  final double regular;

  /// Opacity at [GlassTintStep.readable].
  final double readable;

  /// Opacity at [GlassTintStep.opaque].
  final double opaque;

  /// The steps in ramp order. The scale's monotonicity is tested on this.
  List<double> get steps => <double>[legible, regular, readable, opaque];

  /// The opacity [step] resolves to.
  double opacityFor(GlassTintStep step) => switch (step) {
    GlassTintStep.legible => legible,
    GlassTintStep.regular => regular,
    GlassTintStep.readable => readable,
    GlassTintStep.opaque => opaque,
  };

  /// The composited colour this ramp produces over [backdrop].
  Color surfaceOver(
    Color backdrop, {
    GlassTintStep step = GlassTintStep.regular,
  }) {
    return GlassLegibility.surfaceOver(
      tint: color,
      opacity: opacityFor(step),
      backdrop: backdrop,
    );
  }

  /// The contrast [label] gets on this ramp's glass over [backdrop].
  double labelContrastOver(
    Color backdrop, {
    GlassTintStep step = GlassTintStep.regular,
  }) {
    return GlassLegibility.contrastRatio(surfaceOver(backdrop, step: step),
        label);
  }

  /// Returns a copy with the given fields replaced.
  GlassTintRamp copyWith({
    Color? color,
    Color? label,
    double? legible,
    double? regular,
    double? readable,
    double? opaque,
  }) {
    return GlassTintRamp(
      color: color ?? this.color,
      label: label ?? this.label,
      legible: legible ?? this.legible,
      regular: regular ?? this.regular,
      readable: readable ?? this.readable,
      opaque: opaque ?? this.opaque,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassTintRamp &&
        other.color == color &&
        other.label == label &&
        other.legible == legible &&
        other.regular == regular &&
        other.readable == readable &&
        other.opaque == opaque;
  }

  @override
  int get hashCode =>
      Object.hash(color, label, legible, regular, readable, opaque);
}

/// Both tint ramps, and the rule for choosing between them.
@immutable
class GlassTints {
  /// Creates a pair of ramps. Naming one leaves the other fitted.
  const GlassTints({
    this.light = GlassTintRamp.appleLight,
    this.dark = GlassTintRamp.appleDark,
  });

  /// The light scheme's ramp.
  final GlassTintRamp light;

  /// The dark scheme's ramp.
  final GlassTintRamp dark;

  /// The ramp for [brightness].
  GlassTintRamp of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The scheme whose labels stay more legible over [backdrop].
  ///
  /// This is the decision behind Apple's "small elements… flip from light to
  /// dark based on the background", and it is computed rather than
  /// thresholded. The obvious shortcut is to flip at the backdrop luminance
  /// where black and white text are equally legible — 0.179, the L solving
  /// `(L + 0.05) / 0.05 == 1.05 / (L + 0.05)`. That is the right pivot for
  /// text drawn *directly* on the backdrop, and the wrong one for text drawn
  /// on glass: the tint drags the composite toward itself, and for the
  /// fitted ramps the real crossover is at luminance 0.135. Thresholding at
  /// 0.179 would pick the worse scheme for every backdrop in between.
  ///
  /// Comparing the two composites has no such gap by construction, and it
  /// keeps being right if a consumer replaces either tint.
  Brightness schemeFor(
    Color backdrop, {
    GlassTintStep step = GlassTintStep.regular,
  }) {
    final onDark = dark.labelContrastOver(backdrop, step: step);
    final onLight = light.labelContrastOver(backdrop, step: step);
    return onDark > onLight ? Brightness.dark : Brightness.light;
  }

  /// Returns a copy with the given fields replaced.
  GlassTints copyWith({GlassTintRamp? light, GlassTintRamp? dark}) =>
      GlassTints(light: light ?? this.light, dark: dark ?? this.dark);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassTints && other.light == light && other.dark == dark;
  }

  @override
  int get hashCode => Object.hash(light, dark);
}
