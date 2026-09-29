import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/design/glass_control_colors.dart';
import 'package:glass_forge/src/design/glass_tint.dart';

/// A named step on the blur scale.
enum GlassBlurStep {
  /// No frost. The fitted value for the clear variant.
  none,

  /// Half the regular step. Glyphs behind the surface stop resolving; the
  /// layout behind it still does.
  thin,

  /// Apple's fitted frost.
  regular,

  /// Twice the regular step.
  thick,

  /// Four times the regular step. Nothing behind the surface is recoverable,
  /// including layout.
  ultra,
}

/// The blur ladder, in logical pixels of Gaussian sigma.
///
/// One number on this scale is measured and the rest are derived from it.
/// [regular] is `_appleRegularFrostLight` from `apple_presets.dart` — fitted
/// against real iOS 27 captures — and every other step is a power of two
/// away from it.
///
/// Powers of two, because the *visible* effect of a blur is roughly
/// logarithmic in sigma. Sigma 7 against sigma 8 is invisible; 7 against 14
/// is obvious. A doubling ladder is therefore the coarsest spacing that
/// never contains two steps a designer cannot tell apart, and five entries
/// span the whole useful range: at [thin] a 17 pt glyph's strokes have
/// smeared into each other but the blocks and colours behind still read, and
/// at [ultra] the blur reaches about seven times that glyph's height, so
/// nothing about the backdrop survives.
///
/// Steps are applied as a **ratio to [regular]**, not as an absolute sigma —
/// see [factorOf]. The fitted frost differs between light and dark (7 and
/// 5), and an absolute sigma would throw that fit away the moment a surface
/// asked for anything other than the regular step.
@immutable
class GlassBlurScale {
  /// Creates a blur scale. Naming one step leaves the rest at their
  /// defaults.
  const GlassBlurScale({
    this.none = 0,
    this.thin = 3.5,
    this.regular = 7,
    this.thick = 14,
    this.ultra = 28,
  });

  /// Sigma at [GlassBlurStep.none].
  final double none;

  /// Sigma at [GlassBlurStep.thin].
  final double thin;

  /// Sigma at [GlassBlurStep.regular].
  final double regular;

  /// Sigma at [GlassBlurStep.thick].
  final double thick;

  /// Sigma at [GlassBlurStep.ultra].
  final double ultra;

  /// The steps in ladder order. Monotonicity is tested on this.
  List<double> get steps => <double>[none, thin, regular, thick, ultra];

  /// The sigma [step] resolves to.
  double sigmaOf(GlassBlurStep step) => switch (step) {
    GlassBlurStep.none => none,
    GlassBlurStep.thin => thin,
    GlassBlurStep.regular => regular,
    GlassBlurStep.thick => thick,
    GlassBlurStep.ultra => ultra,
  };

  /// [step] as a multiplier on a material's own frost.
  ///
  /// Relative to this scale's own [regular], not to the default 7, so a
  /// consumer who widens the anchor widens the whole ladder with it rather
  /// than silently changing every step's ratio to something they did not
  /// choose.
  double factorOf(GlassBlurStep step) =>
      regular <= 0 ? 0 : sigmaOf(step) / regular;

  /// Returns a copy with the given fields replaced.
  GlassBlurScale copyWith({
    double? none,
    double? thin,
    double? regular,
    double? thick,
    double? ultra,
  }) {
    return GlassBlurScale(
      none: none ?? this.none,
      thin: thin ?? this.thin,
      regular: regular ?? this.regular,
      thick: thick ?? this.thick,
      ultra: ultra ?? this.ultra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassBlurScale &&
        other.none == none &&
        other.thin == thin &&
        other.regular == regular &&
        other.thick == thick &&
        other.ultra == ultra;
  }

  @override
  int get hashCode => Object.hash(none, thin, regular, thick, ultra);
}

/// A named step on the corner-radius scale.
enum GlassRadiusStep {
  /// Square corners.
  none,

  /// The anchor eighth.
  small,

  /// The anchor quarter.
  medium,

  /// The anchor half — a minimum-size control becomes a capsule here.
  large,

  /// The anchor itself.
  extraLarge,

  /// As round as the surface allows: half its shorter side.
  capsule,
}

/// The corner-radius ladder, in logical pixels.
///
/// Anchored on 44 — the HIG's minimum touch target, and the one length in
/// iOS chrome that is specified rather than chosen. Every step is that
/// anchor halved again: 44, 22, 11, 5.5. [large] is the interesting one,
/// because a control at the minimum touch target with a 22 pt radius *is* a
/// capsule, which is the shape iOS 26 gives its small glass controls.
///
/// [GlassRadiusStep.capsule] has no stored value on purpose. "As round as it
/// can be" is not a number until there is a size, so [radiusOf] returns
/// [double.infinity] for it and `GlassShape.resolveRadius` clamps that to
/// half the shorter side at paint time — the same clamp that already keeps
/// an over-large radius from producing an invalid distance field.
///
/// Radii are not brightness-dependent and not size-dependent beyond that
/// clamp, so unlike the blur ladder these are absolute.
@immutable
class GlassRadiusScale {
  /// Creates a radius scale. Naming one step leaves the rest at their
  /// defaults.
  const GlassRadiusScale({
    this.none = 0,
    this.small = 5.5,
    this.medium = 11,
    this.large = 22,
    this.extraLarge = 44,
  });

  /// Radius at [GlassRadiusStep.none].
  final double none;

  /// Radius at [GlassRadiusStep.small].
  final double small;

  /// Radius at [GlassRadiusStep.medium].
  final double medium;

  /// Radius at [GlassRadiusStep.large].
  final double large;

  /// Radius at [GlassRadiusStep.extraLarge].
  final double extraLarge;

  /// The steps in ladder order, with the capsule's unbounded radius last.
  List<double> get steps => <double>[
    none,
    small,
    medium,
    large,
    extraLarge,
    double.infinity,
  ];

  /// The radius [step] resolves to, before any size clamp.
  double radiusOf(GlassRadiusStep step) => switch (step) {
    GlassRadiusStep.none => none,
    GlassRadiusStep.small => small,
    GlassRadiusStep.medium => medium,
    GlassRadiusStep.large => large,
    GlassRadiusStep.extraLarge => extraLarge,
    GlassRadiusStep.capsule => double.infinity,
  };

  /// The radius a shape nested inside one of radius [outer], inset by
  /// [padding] on every side, needs in order to stay concentric with it.
  ///
  /// Apple asks for concentric corners, and concentricity is a subtraction,
  /// not a second token: two rounded rectangles share a corner centre only
  /// when the inner radius is the outer radius less the gap between them. A
  /// designer who picks the inner radius off a scale instead will be wrong
  /// by exactly the amount they padded.
  static double concentricInner(double outer, double padding) =>
      outer - padding < 0 ? 0 : outer - padding;

  /// Returns a copy with the given fields replaced.
  GlassRadiusScale copyWith({
    double? none,
    double? small,
    double? medium,
    double? large,
    double? extraLarge,
  }) {
    return GlassRadiusScale(
      none: none ?? this.none,
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      extraLarge: extraLarge ?? this.extraLarge,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassRadiusScale &&
        other.none == none &&
        other.small == small &&
        other.medium == medium &&
        other.large == large &&
        other.extraLarge == extraLarge;
  }

  @override
  int get hashCode => Object.hash(none, small, medium, large, extraLarge);
}

/// A named step on the depth scale.
enum GlassDepthStep {
  /// In the plane. No shadow at all.
  flush,

  /// Just off the plane — chrome that sits on content.
  raised,

  /// Clearly above the plane — chrome that floats over content.
  floating,

  /// A separate layer — a sheet or a modal.
  presented,
}

/// The depth ladder: how far above the content a surface reads, and the
/// shadow that says so.
///
/// Lift is in logical pixels and the ladder is a quadrupling, because a
/// shadow only reads as a *different* shadow when its penumbra changes by a
/// lot; a doubling here produces two steps nobody can tell apart.
///
/// From one lift, two numbers follow by rule rather than by taste:
///
/// * **Blur is twice the lift, offset down by exactly the lift.** That is a
///   key light at 45 degrees, which is the convention every platform shadow
///   already follows.
/// * **Peak opacity falls as the lift grows**, by
///   `referenceOpacity * referenceLift / (referenceLift + lift)`. The same
///   quantity of shadow is spread over a larger penumbra, so the darkest
///   point of it gets lighter. Holding peak opacity constant instead is what
///   makes large elevations look like smudges.
///
/// One thing here is judgement and not derivation, and it is worth naming:
/// [referenceOpacity]. Apple's shadow is content-aware — opacity "increases
/// when it is over text" and "lowers over a solid light background" — and
/// this one cannot be, because nothing in this package samples the backdrop
/// yet. So it is a single value picked to be visible on white without
/// becoming a smear on black, and it is the token most worth overriding for
/// an app with a known background.
@immutable
class GlassDepthScale {
  /// Creates a depth scale. Naming one step leaves the rest at their
  /// defaults.
  const GlassDepthScale({
    this.flush = 0,
    this.raised = 2,
    this.floating = 8,
    this.presented = 32,
    this.shadowColor = const Color(0xFF000000),
    this.referenceOpacity = 0.24,
    this.referenceLift = 8,
  });

  /// Lift at [GlassDepthStep.flush].
  final double flush;

  /// Lift at [GlassDepthStep.raised].
  final double raised;

  /// Lift at [GlassDepthStep.floating].
  final double floating;

  /// Lift at [GlassDepthStep.presented].
  final double presented;

  /// The colour every shadow on this scale is drawn in.
  final Color shadowColor;

  /// Peak shadow opacity at a lift of [referenceLift].
  final double referenceOpacity;

  /// The lift [referenceOpacity] is quoted at.
  final double referenceLift;

  /// The steps in ladder order. Monotonicity is tested on this.
  List<double> get steps => <double>[flush, raised, floating, presented];

  /// The lift [step] resolves to, in logical pixels.
  double liftOf(GlassDepthStep step) => switch (step) {
    GlassDepthStep.flush => flush,
    GlassDepthStep.raised => raised,
    GlassDepthStep.floating => floating,
    GlassDepthStep.presented => presented,
  };

  /// The shadows [step] resolves to.
  ///
  /// Empty at zero lift, and empty is not the same as a transparent shadow:
  /// the surface widget skips its shadow pass entirely on an empty list, so
  /// a flush surface costs no extra path, no mask filter and no save layer.
  List<BoxShadow> shadowsOf(GlassDepthStep step) {
    final lift = liftOf(step);
    if (lift <= 0) {
      return const <BoxShadow>[];
    }
    final opacity = referenceOpacity * referenceLift / (referenceLift + lift);
    return <BoxShadow>[
      BoxShadow(
        color: shadowColor.withValues(alpha: opacity.clamp(0.0, 1.0)),
        offset: Offset(0, lift),
        blurRadius: lift * 2,
      ),
    ];
  }

  /// Returns a copy with the given fields replaced.
  GlassDepthScale copyWith({
    double? flush,
    double? raised,
    double? floating,
    double? presented,
    Color? shadowColor,
    double? referenceOpacity,
    double? referenceLift,
  }) {
    return GlassDepthScale(
      flush: flush ?? this.flush,
      raised: raised ?? this.raised,
      floating: floating ?? this.floating,
      presented: presented ?? this.presented,
      shadowColor: shadowColor ?? this.shadowColor,
      referenceOpacity: referenceOpacity ?? this.referenceOpacity,
      referenceLift: referenceLift ?? this.referenceLift,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassDepthScale &&
        other.flush == flush &&
        other.raised == raised &&
        other.floating == floating &&
        other.presented == presented &&
        other.shadowColor == shadowColor &&
        other.referenceOpacity == referenceOpacity &&
        other.referenceLift == referenceLift;
  }

  @override
  int get hashCode => Object.hash(
    flush,
    raised,
    floating,
    presented,
    shadowColor,
    referenceOpacity,
    referenceLift,
  );
}

/// Every scale the design system resolves against.
///
/// Each field defaults, so overriding one token names one token:
/// `GlassTokens(blur: GlassBlurScale(regular: 9))` keeps the radius, depth
/// and tint ladders exactly as they were.
@immutable
class GlassTokens {
  /// Creates a token set. Naming one scale leaves the rest at their
  /// defaults.
  const GlassTokens({
    this.blur = const GlassBlurScale(),
    this.radius = const GlassRadiusScale(),
    this.depth = const GlassDepthScale(),
    this.tint = const GlassTints(),
    this.controls = const GlassControlPalette(),
    this.flipMaxShortSide = 96,
  });

  /// The blur ladder.
  final GlassBlurScale blur;

  /// The corner-radius ladder.
  final GlassRadiusScale radius;

  /// The depth ladder.
  final GlassDepthScale depth;

  /// The two tint ramps.
  final GlassTints tint;

  /// The controls' own colours — the accent, the painted knob — per
  /// scheme.
  final GlassControlPalette controls;

  /// The shorter side, in logical pixels, at or below which a surface is
  /// small enough to flip its whole scheme.
  ///
  /// Apple's rule is stated in examples rather than numbers — "small
  /// elements like navbars and tabbars… flip from light to dark based on the
  /// background. Larger elements like menus and sidebars adapt based on
  /// context, but they don't flip" — so the threshold has to be inferred,
  /// and the axis matters more than the number. It is the **shorter side**,
  /// not the area: a navigation bar is full-width and 44 tall, a tab bar is
  /// full-width and 49 tall, and both flip, while a menu at 250 by 300 does
  /// not. What those two have in common is not size, it is *thinness* — the
  /// backdrop under a thin element is one strip of one thing, so one
  /// luminance reading describes it, and a single flip decision is right for
  /// all of it. Under a menu it is not.
  ///
  /// 96 is the tallest standard bar iOS ships: a large-title navigation bar,
  /// 52 of title on 44 of bar. Anything thinner than a navigation bar is
  /// chrome; anything thicker is carrying content.
  final double flipMaxShortSide;

  /// Returns a copy with the given fields replaced.
  GlassTokens copyWith({
    GlassBlurScale? blur,
    GlassRadiusScale? radius,
    GlassDepthScale? depth,
    GlassTints? tint,
    GlassControlPalette? controls,
    double? flipMaxShortSide,
  }) {
    return GlassTokens(
      blur: blur ?? this.blur,
      radius: radius ?? this.radius,
      depth: depth ?? this.depth,
      tint: tint ?? this.tint,
      controls: controls ?? this.controls,
      flipMaxShortSide: flipMaxShortSide ?? this.flipMaxShortSide,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassTokens &&
        other.blur == blur &&
        other.radius == radius &&
        other.depth == depth &&
        other.tint == tint &&
        other.controls == controls &&
        other.flipMaxShortSide == flipMaxShortSide;
  }

  @override
  int get hashCode =>
      Object.hash(blur, radius, depth, tint, controls, flipMaxShortSide);
}
