import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The arithmetic every legibility promise in this layer is stated in.
///
/// Glass is translucent, so a label's contrast is never against the tint —
/// it is against the tint *composited over whatever is behind it*, which
/// changes as the user scrolls. Every number in `GlassTintRamp` and every
/// `minimumContrast` on a `GlassSurfaceSpec` is a claim about that
/// composite, and this is the function that evaluates the claim. The tests
/// re-derive the ramp's constants from here, so a change to a tint colour
/// that quietly stops clearing its stated threshold fails the build rather
/// than shipping.
///
/// The ratios are WCAG 2.2's, because that is the only contrast model with
/// published thresholds a design system can be held to. Apple publishes no
/// contrast figure for Liquid Glass; measured against WCAG its own fitted
/// material clears 3:1 over the worst case and not 4.5:1, which is the
/// compromise recorded on `GlassTintRamp.regular`.
abstract final class GlassLegibility {
  /// The WCAG 2.2 contrast ratio between two opaque colours, from 1 to 21.
  ///
  /// Both arguments must be opaque. A translucent colour's `computeLuminance`
  /// ignores its alpha, so passing one silently measures a surface nobody
  /// will see — composite it with [surfaceOver] first.
  static double contrastRatio(Color a, Color b) {
    assert(a.a == 1, 'contrastRatio needs an opaque colour, not $a');
    assert(b.a == 1, 'contrastRatio needs an opaque colour, not $b');
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    final lighter = math.max(first, second);
    final darker = math.min(first, second);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The colour a viewer actually sees where [tint] covers [backdrop].
  ///
  /// Source-over in sRGB, which is what the compositor does — deliberately
  /// not a linear-light blend. Blending in linear light would give a
  /// different (and more physically correct) result, but it would no longer
  /// predict what the screen shows.
  static Color surfaceOver({
    required Color tint,
    required double opacity,
    required Color backdrop,
  }) {
    return Color.alphaBlend(
      tint.withValues(alpha: opacity.clamp(0.0, 1.0)),
      backdrop.withValues(alpha: 1),
    );
  }

  /// The contrast [label] gets on a surface of [tint] over [backdrop].
  static double labelContrast({
    required Color tint,
    required double opacity,
    required Color backdrop,
    required Color label,
  }) {
    return contrastRatio(
      surfaceOver(tint: tint, opacity: opacity, backdrop: backdrop),
      label,
    );
  }

  /// The smallest opacity in `[floor, ceiling]` whose label contrast reaches
  /// [target].
  ///
  /// This is what "the amount of tint shifts to always ensure buttons remain
  /// legible" means in practice: the baseline step a surface asks for is a
  /// *floor*, and a backdrop that would undercut the target pushes the tint
  /// up until it does not. It never pushes the tint *down* — a surface that
  /// is already more legible than it promised is not a defect.
  ///
  /// Solved by bisection rather than inverted analytically. Composite
  /// luminance is monotone in opacity (each channel is a linear
  /// interpolation between backdrop and tint, and luminance is monotone in
  /// every channel), so bisection converges, but the sRGB transfer curve
  /// makes the inverse a piecewise root that is not worth writing out. Twelve
  /// halvings resolve to 1/4096 of the range, far finer than an 8-bit alpha
  /// can express. This runs once per style resolution and only when a
  /// backdrop is known — never per frame.
  static double opacityForContrast({
    required Color tint,
    required Color backdrop,
    required Color label,
    required double target,
    required double floor,
    required double ceiling,
  }) {
    double contrastAt(double opacity) => labelContrast(
      tint: tint,
      opacity: opacity,
      backdrop: backdrop,
      label: label,
    );

    if (ceiling <= floor || contrastAt(floor) >= target) {
      return floor;
    }
    if (contrastAt(ceiling) < target) {
      // Out of reach at both ends. Because contrast is monotone in opacity,
      // one of the two endpoints is the best available, and which one
      // depends on the direction: more tint helps over a backdrop the tint
      // is darker than, and hurts over one it is lighter than.
      return contrastAt(ceiling) >= contrastAt(floor) ? ceiling : floor;
    }

    var low = floor;
    var high = ceiling;
    for (var i = 0; i < 12; i++) {
      final middle = (low + high) / 2;
      if (contrastAt(middle) >= target) {
        high = middle;
      } else {
        low = middle;
      }
    }
    return high;
  }
}
