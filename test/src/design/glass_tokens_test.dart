import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_tokens.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';

void _expectStrictlyIncreasing(List<double> values, String what) {
  for (var i = 1; i < values.length; i++) {
    expect(
      values[i],
      greaterThan(values[i - 1]),
      reason: '$what is not a ladder: step $i is not above step ${i - 1}',
    );
  }
}

void main() {
  group('blur', () {
    test('the ladder only ever goes up', () {
      _expectStrictlyIncreasing(const GlassBlurScale().steps, 'the blur scale');
    });

    test('the anchor is the fitted frost, not a number of our own', () {
      // The scale claims `regular` is Apple's measured light-mode frost. If
      // apple_presets.dart is ever refitted against a new capture, this
      // fails rather than letting the design system quietly drift off the
      // material it says it is built on.
      expect(
        const GlassBlurScale().regular,
        GlassMaterial.regular(brightness: Brightness.light).frost,
      );
    });

    test('steps are ratios to the anchor, so the regular step is identity', () {
      const scale = GlassBlurScale();
      expect(scale.factorOf(GlassBlurStep.regular), 1);
      expect(scale.factorOf(GlassBlurStep.none), 0);
      expect(
        scale.factorOf(GlassBlurStep.thick),
        scale.thick / scale.regular,
      );
    });

    test('moving the anchor moves the whole ladder with it', () {
      // A consumer who widens `regular` is widening the scale, not silently
      // re-proportioning every other step against a hidden default.
      const widened = GlassBlurScale(regular: 14);
      expect(
        widened.factorOf(GlassBlurStep.thick),
        lessThan(const GlassBlurScale().factorOf(GlassBlurStep.thick)),
      );
    });
  });

  group('radius', () {
    test('the ladder only ever goes up, capsule included', () {
      _expectStrictlyIncreasing(
        const GlassRadiusScale().steps,
        'the radius scale',
      );
    });

    test('the ladder is one anchor halved, not five opinions', () {
      // 44 is the HIG minimum touch target. Every other step is derived from
      // it, so a consumer who moves the anchor gets a scale that is still a
      // scale.
      const scale = GlassRadiusScale();
      expect(scale.large, scale.extraLarge / 2);
      expect(scale.medium, scale.extraLarge / 4);
      expect(scale.small, scale.extraLarge / 8);
    });

    test('a capsule resolves to half the shorter side at any size', () {
      // The capsule step carries no number — it is an unbounded radius that
      // GlassShape's own clamp turns into a capsule at paint time. That
      // hand-off is the only reason the step works, so it is worth pinning.
      final shape = GlassSuperellipse(
        radius: BorderRadius.circular(
          const GlassRadiusScale().radiusOf(GlassRadiusStep.capsule),
        ),
      );
      expect(shape.resolveRadius(const Size(200, 44)), 22);
      expect(shape.resolveRadius(const Size(44, 200)), 22);
      expect(shape.resolveRadius(const Size(60, 60)), 30);
      expect(shape.resolveRadius(const Size(200, 44)).isFinite, isTrue);
    });

    test('a fixed step does not move with the size', () {
      final shape = GlassSuperellipse(
        radius: BorderRadius.circular(
          const GlassRadiusScale().radiusOf(GlassRadiusStep.medium),
        ),
      );
      expect(shape.resolveRadius(const Size(400, 400)), 11);
      expect(shape.resolveRadius(const Size(300, 90)), 11);
    });

    test('concentric corners share a centre, which is what makes them '
        'concentric', () {
      // The inner corner's centre sits `padding + innerRadius` from the outer
      // rectangle's corner, and the outer corner's centre sits `outerRadius`
      // from it. Concentric means those are the same point.
      for (final padding in <double>[0, 4, 12, 22]) {
        expect(
          padding + GlassRadiusScale.concentricInner(22, padding),
          22,
          reason: 'inset by $padding is not concentric',
        );
      }
      // Past the outer radius there is no concentric answer; square is the
      // honest one, and a negative radius would be an invalid distance field.
      expect(GlassRadiusScale.concentricInner(12, 30), 0);
    });
  });

  group('depth', () {
    test('the lift ladder only ever goes up', () {
      _expectStrictlyIncreasing(
        const GlassDepthScale().steps,
        'the depth scale',
      );
    });

    test('flush costs nothing, not a transparent shadow', () {
      // The surface widget skips its whole shadow pass on an empty list. A
      // zero-opacity BoxShadow would look identical and still cost a path, a
      // mask filter and a save layer on every paint.
      expect(
        const GlassDepthScale().shadowsOf(GlassDepthStep.flush),
        isEmpty,
      );
    });

    test('a shadow spreads as it lifts, and its darkest point fades', () {
      // The rule the scale is built on: the same quantity of shadow over a
      // larger penumbra has a lighter peak. Holding peak opacity constant
      // instead is what makes big elevations read as smudges, so this is the
      // assertion that would fail if someone "simplified" the law away.
      const scale = GlassDepthScale();
      final lifted = <GlassDepthStep>[
        GlassDepthStep.raised,
        GlassDepthStep.floating,
        GlassDepthStep.presented,
      ];
      final blurs = <double>[];
      final opacities = <double>[];
      for (final step in lifted) {
        final shadow = scale.shadowsOf(step).single;
        blurs.add(shadow.blurRadius);
        opacities.add(shadow.color.a);
        expect(shadow.offset.dy, scale.liftOf(step));
        expect(shadow.color.a, lessThanOrEqualTo(scale.referenceOpacity));
      }
      _expectStrictlyIncreasing(blurs, 'shadow blur');
      _expectStrictlyIncreasing(
        opacities.reversed.toList(),
        'shadow opacity, read from the top of the ladder down',
      );
    });
  });

  test('naming one scale leaves the others alone', () {
    const overridden = GlassTokens(blur: GlassBlurScale(thick: 18));
    const base = GlassTokens();
    expect(overridden.blur.thick, 18);
    expect(overridden.blur.regular, base.blur.regular);
    expect(overridden.radius, base.radius);
    expect(overridden.depth, base.depth);
    expect(overridden.tint, base.tint);
    expect(overridden.flipMaxShortSide, base.flipMaxShortSide);
  });
}
