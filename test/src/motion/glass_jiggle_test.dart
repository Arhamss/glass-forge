import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';

const Size _size = Size(120, 80);

/// How [transform]'s linear part maps [direction].
Offset _mapDirection(Matrix4 transform, Offset direction) {
  const anchor = Offset(60, 40);
  return MatrixUtils.transformPoint(transform, anchor + direction) -
      MatrixUtils.transformPoint(transform, anchor);
}

double _determinant(Matrix4 transform) {
  final x = _mapDirection(transform, const Offset(1, 0));
  final y = _mapDirection(transform, const Offset(0, 1));
  return x.dx * y.dy - x.dy * y.dx;
}

Matrix4 _transformFor(
  Offset velocity, {
  double press = 0,
  double pressScale = 0.96,
  GlassJiggle jiggle = const GlassJiggle(),
}) => glassSurfaceTransform(
  size: _size,
  state: GlassMotionState(
    translation: Offset.zero,
    velocity: velocity,
    press: press,
  ),
  jiggle: jiggle,
  pressScale: pressScale,
);

void main() {
  group('squash and stretch', () {
    test('conserves area exactly, at any speed and any direction', () {
      const velocities = <Offset>[
        Offset(900, 0),
        Offset(0, -1400),
        Offset(700, 700),
        Offset(-300, 120),
        Offset(12000, -5000),
      ];
      for (final velocity in velocities) {
        expect(
          _determinant(_transformFor(velocity)),
          closeTo(1, 1e-12),
          reason: 'area changed for $velocity',
        );
      }
    });

    test('stretches along the velocity and compresses across it', () {
      const velocity = Offset(1500, 0);
      final transform = _transformFor(velocity);
      final stretch = const GlassJiggle().stretchFor(velocity.distance);
      expect(stretch, greaterThan(1));

      final along = _mapDirection(transform, const Offset(1, 0));
      final across = _mapDirection(transform, const Offset(0, 1));
      expect(along.distance, closeTo(stretch, 1e-12));
      expect(across.distance, closeTo(1 / stretch, 1e-12));
    });

    test('follows the velocity when it is diagonal', () {
      final velocity = const Offset(1, 1) * 1200;
      final transform = _transformFor(velocity);
      final stretch = const GlassJiggle().stretchFor(velocity.distance);
      final unit = velocity / velocity.distance;
      final perpendicular = Offset(-unit.dy, unit.dx);

      expect(_mapDirection(transform, unit).distance, closeTo(stretch, 1e-12));
      expect(
        _mapDirection(transform, perpendicular).distance,
        closeTo(1 / stretch, 1e-12),
      );
      // ...and the stretched direction is still the velocity's direction,
      // not merely the same length.
      final mapped = _mapDirection(transform, unit);
      expect(
        math.atan2(mapped.dy, mapped.dx),
        closeTo(math.atan2(unit.dy, unit.dx), 1e-12),
      );
    });

    test('saturates rather than growing without bound', () {
      const jiggle = GlassJiggle(maxStretch: 1.2, halfSpeed: 1000);
      expect(jiggle.stretchFor(1000), closeTo(1.1, 1e-12));
      expect(jiggle.stretchFor(1000000000), lessThan(1.2));
      expect(jiggle.stretchFor(1000000000), greaterThan(1.19));
      // Monotone in speed, so faster always reads as more deformed.
      var previous = 1.0;
      for (var speed = 0.0; speed < 8000; speed += 25) {
        final next = jiggle.stretchFor(speed);
        expect(next, greaterThanOrEqualTo(previous));
        previous = next;
      }
    });

    test('a surface at rest is not deformed at all', () {
      final transform = _transformFor(Offset.zero);
      expect(MatrixUtils.getAsTranslation(transform), isNotNull);
    });

    test(
      'GlassJiggle.none leaves a fast-moving surface exactly undeformed, '
      'which is what Reduce Motion resolves to',
      () {
        final transform = _transformFor(
          const Offset(5000, 2000),
          jiggle: const GlassJiggle.none(),
        );
        expect(MatrixUtils.getAsTranslation(transform), isNotNull);
      },
    );
  });

  group('press', () {
    test('scales uniformly and shrinks area by the square of the scale', () {
      final transform = _transformFor(Offset.zero, press: 1, pressScale: 0.9);
      expect(_determinant(transform), closeTo(0.81, 1e-12));
      expect(
        _mapDirection(transform, const Offset(1, 0)).distance,
        closeTo(0.9, 1e-12),
      );
      expect(
        _mapDirection(transform, const Offset(0, 1)).distance,
        closeTo(0.9, 1e-12),
      );
    });

    test('interpolates, so a half-settled press is half the scale', () {
      final transform = _transformFor(
        Offset.zero,
        press: 0.5,
        pressScale: 0.9,
      );
      expect(
        _mapDirection(transform, const Offset(1, 0)).distance,
        closeTo(0.95, 1e-12),
      );
    });

    test('composes with stretch without disturbing its direction', () {
      const velocity = Offset(0, 1500);
      final transform = _transformFor(
        velocity,
        press: 1,
        pressScale: 0.9,
      );
      final stretch = const GlassJiggle().stretchFor(velocity.distance);
      expect(
        _mapDirection(transform, const Offset(0, 1)).distance,
        closeTo(0.9 * stretch, 1e-12),
      );
      expect(_determinant(transform), closeTo(0.81, 1e-12));
    });
  });

  group('about the centre', () {
    test('the surface deforms about its own middle, not its corner', () {
      final transform = _transformFor(const Offset(4000, 0));
      final centre = MatrixUtils.transformPoint(
        transform,
        const Offset(60, 40),
      );
      expect(centre.dx, closeTo(60, 1e-9));
      expect(centre.dy, closeTo(40, 1e-9));
    });

    test('translation moves the whole surface, centre included', () {
      final transform = glassSurfaceTransform(
        size: _size,
        state: const GlassMotionState(
          translation: Offset(17, -23),
          velocity: Offset.zero,
          press: 0,
        ),
        jiggle: const GlassJiggle(),
        pressScale: 0.96,
      );
      expect(MatrixUtils.getAsTranslation(transform), const Offset(17, -23));
    });
  });
}
