import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_tint.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

/// The backdrop that hurts a scheme most: the one furthest from its tint.
Color _worstBackdropFor(Brightness brightness) =>
    brightness == Brightness.dark ? _white : _black;

Color _grey(int value) => Color(0xFF000000 | value << 16 | value << 8 | value);

void main() {
  group('every step is the smallest one that keeps its promise', () {
    // The whole claim of the ramp is that each step is *derived* — the least
    // tint that clears a published WCAG threshold over the worst backdrop
    // the scheme can face — rather than picked. Two assertions per step make
    // that claim falsifiable: the step must clear its threshold, and one
    // thousandth less must not. Change the tint colour and both halves move,
    // so a swapped colour that no longer delivers its stated contrast fails
    // here rather than shipping.
    const targets = <GlassTintStep, double>{
      GlassTintStep.legible: 3,
      GlassTintStep.readable: 4.5,
      GlassTintStep.opaque: 7,
    };

    for (final brightness in Brightness.values) {
      final ramp = const GlassTints().of(brightness);
      final backdrop = _worstBackdropFor(brightness);
      for (final entry in targets.entries) {
        test('${brightness.name} ${entry.key.name} is minimal', () {
          final opacity = ramp.opacityFor(entry.key);
          expect(
            ramp.labelContrastOver(backdrop, step: entry.key),
            greaterThanOrEqualTo(entry.value),
          );
          final shaved = ramp.copyWith(
            legible: entry.key == GlassTintStep.legible
                ? opacity - 0.001
                : null,
            readable: entry.key == GlassTintStep.readable
                ? opacity - 0.001
                : null,
            opaque: entry.key == GlassTintStep.opaque
                ? opacity - 0.001
                : null,
          );
          expect(
            shaved.labelContrastOver(backdrop, step: entry.key),
            lessThan(entry.value),
            reason: '${entry.key.name} is higher than it needs to be',
          );
        });
      }
    }
  });

  test("Apple's own fitted tint clears 3:1 and misses 4.5:1", () {
    // Not a defect in the fit — it is the compromise Apple made, and it is
    // the reason `readable` exists as a separate step rather than the
    // regular one being good enough for body text. Recording it as a test
    // means nobody can quietly assume the fitted material is AA for text.
    for (final brightness in Brightness.values) {
      final ramp = const GlassTints().of(brightness);
      final contrast = ramp.labelContrastOver(
        _worstBackdropFor(brightness),
      );
      expect(contrast, greaterThanOrEqualTo(3));
      expect(contrast, lessThan(4.5));
      expect(ramp.regular, greaterThan(ramp.legible));
      expect(ramp.regular, lessThan(ramp.readable));
    }
  });

  test('the ramp only ever goes up', () {
    for (final brightness in Brightness.values) {
      final steps = const GlassTints().of(brightness).steps;
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]));
      }
    }
  });

  group('choosing a scheme from the backdrop', () {
    test('the extremes go the obvious way', () {
      expect(const GlassTints().schemeFor(_black), Brightness.dark);
      expect(const GlassTints().schemeFor(_white), Brightness.light);
    });

    test('the decision changes exactly once across the grey range', () {
      // A flip rule that oscillated would make a navigation bar strobe as
      // content scrolled under it. One transition is what makes "flip" a
      // decision rather than a flicker, and it is a property of comparing
      // two composites that a naive luminance threshold also has — but that
      // a hand-tuned pair of thresholds would lose.
      var transitions = 0;
      var previous = const GlassTints().schemeFor(_grey(0));
      for (var value = 1; value <= 255; value++) {
        final next = const GlassTints().schemeFor(_grey(value));
        if (next != previous) {
          transitions++;
          previous = next;
        }
      }
      expect(transitions, 1);
    });

    test('flipping is worth doing: it beats either fixed scheme outright', () {
      // This is the payoff for implementing Apple's size gate at all. A
      // surface that may choose its scheme has a far better worst case than
      // one pinned to either, because each fixed scheme is terrible at one
      // end of the range.
      const tints = GlassTints();
      var flipWorst = double.infinity;
      var darkWorst = double.infinity;
      var lightWorst = double.infinity;
      for (var value = 0; value <= 255; value++) {
        final backdrop = _grey(value);
        final onDark = tints.dark.labelContrastOver(backdrop);
        final onLight = tints.light.labelContrastOver(backdrop);
        final chosen = tints.schemeFor(backdrop) == Brightness.dark
            ? onDark
            : onLight;
        flipWorst = flipWorst < chosen ? flipWorst : chosen;
        darkWorst = darkWorst < onDark ? darkWorst : onDark;
        lightWorst = lightWorst < onLight ? lightWorst : onLight;
      }
      expect(darkWorst, lessThan(4.5));
      expect(lightWorst, lessThan(4.5));
      expect(flipWorst, greaterThan(2 * darkWorst));
      expect(flipWorst, greaterThan(2 * lightWorst));
    });

    test('the decision follows the ramps, not a hard-coded luminance', () {
      // Swap which ramp each scheme uses and the answers swap with them.
      // The tempting shortcut — `luminance < 0.179 ? dark : light` — passes
      // every other test in this group and fails this one, which is the
      // point: the crossover belongs to the tints in force, and for the
      // fitted pair it sits at 0.135 rather than at the textbook 0.179.
      const swapped = GlassTints(
        light: GlassTintRamp.appleDark,
        dark: GlassTintRamp.appleLight,
      );
      expect(swapped.schemeFor(_black), Brightness.light);
      expect(swapped.schemeFor(_white), Brightness.dark);
    });
  });

  test('naming one step leaves the rest of the ramp alone', () {
    final overridden = GlassTintRamp.appleDark.copyWith(readable: 0.8);
    expect(overridden.readable, 0.8);
    expect(overridden.legible, GlassTintRamp.appleDark.legible);
    expect(overridden.regular, GlassTintRamp.appleDark.regular);
    expect(overridden.opaque, GlassTintRamp.appleDark.opaque);
    expect(overridden.color, GlassTintRamp.appleDark.color);
    expect(const GlassTints(light: GlassTintRamp.appleDark).dark,
        GlassTintRamp.appleDark);
  });
}
