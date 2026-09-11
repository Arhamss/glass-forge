import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:motor/motor.dart';

void main() {
  group('preset parity with CupertinoMotion', () {
    void expectSameSpring(SpringDescription actual, SpringDescription want) {
      expect(actual.mass, closeTo(want.mass, 1e-12));
      expect(actual.stiffness, closeTo(want.stiffness, 1e-9));
      expect(actual.damping, closeTo(want.damping, 1e-9));
    }

    // These are the numbers SwiftUI's .bouncy, .snappy, .smooth and
    // .interactiveSpring resolve to. Hand-tuning our own would drift from
    // Apple silently; deriving them through CupertinoMotion cannot.
    test('bouncy', () {
      expectSameSpring(
        const GlassMotion.bouncy().spring,
        const CupertinoMotion.bouncy().description,
      );
    });

    test('snappy', () {
      expectSameSpring(
        const GlassMotion.snappy().spring,
        const CupertinoMotion.snappy().description,
      );
    });

    test('smooth', () {
      expectSameSpring(
        const GlassMotion.smooth().spring,
        const CupertinoMotion.smooth().description,
      );
    });

    test('interactive', () {
      expectSameSpring(
        const GlassMotion.interactive().spring,
        const CupertinoMotion.interactive().description,
      );
    });

    test('extraBounce reaches the spring', () {
      final plain = const GlassMotion.snappy().spring;
      final extra = const GlassMotion.snappy(extraBounce: 0.2).spring;
      expect(extra.damping, lessThan(plain.damping));
    });
  });

  group('duration and bounce are Apple vocabulary, not stiffness', () {
    double dampingRatio(SpringDescription spring) =>
        spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));

    test('bounce 0 is critical damping', () {
      expect(
        dampingRatio(const GlassMotion.smooth().spring),
        closeTo(1, 1e-9),
      );
    });

    test('positive bounce is underdamped by exactly 1 - bounce', () {
      expect(
        dampingRatio(const GlassMotion(bounce: 0.3).spring),
        closeTo(0.7, 1e-9),
      );
    });

    test('negative bounce is overdamped by 1 / (1 + bounce)', () {
      expect(
        dampingRatio(const GlassMotion(bounce: -0.5).spring),
        closeTo(2, 1e-9),
      );
    });

    test('duration is the oscillation period, so it sets stiffness', () {
      final fast = const GlassMotion(
        duration: Duration(milliseconds: 250),
      ).spring;
      final slow = const GlassMotion(
        duration: Duration(milliseconds: 1000),
      ).spring;
      // k = 4*pi^2/T^2, so quartering the period multiplies k by sixteen.
      expect(fast.stiffness / slow.stiffness, closeTo(16, 1e-6));
    });
  });

  group('tolerance', () {
    test(
      'is forwarded into the simulations the motion builds — motor never '
      'does this, which is what makes a pixel-scale spring tick at a '
      'thousandth of a pixel',
      () {
        final ours = const GlassMotion(
          settleDistance: 0.25,
          settleVelocity: 6,
        ).motion.createSimulation();
        expect(ours.tolerance.distance, 0.25);
        expect(ours.tolerance.velocity, 6);

        // The defect, reproduced: motor's own CupertinoMotion drops it.
        final theirs = const CupertinoMotion().createSimulation();
        expect(theirs.tolerance.distance, Tolerance.defaultTolerance.distance);
        expect(theirs.tolerance.velocity, Tolerance.defaultTolerance.velocity);
      },
    );

    test("scaledTo converts pixel thresholds into a channel's own units", () {
      final scaled = const GlassMotion(
        settleDistance: 0.25,
        settleVelocity: 6,
      ).scaledTo(8);
      expect(scaled.tolerance.distance, closeTo(0.03125, 1e-12));
      expect(scaled.tolerance.velocity, closeTo(0.75, 1e-12));
      // Scaling must not disturb the physics.
      expect(scaled.spring.stiffness, const GlassMotion().spring.stiffness);
      expect(scaled.spring.damping, const GlassMotion().spring.damping);
    });
  });

  group('value semantics', () {
    test('equal configurations compare and hash equal', () {
      const a = GlassMotion.snappy();
      const b = GlassMotion.snappy();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different settle threshold is a different motion', () {
      expect(
        const GlassMotion.snappy(settleDistance: 0.25),
        isNot(const GlassMotion.snappy(settleDistance: 0.1)),
      );
    });
  });
}
