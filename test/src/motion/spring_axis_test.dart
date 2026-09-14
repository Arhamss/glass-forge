import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/spring_axis.dart';

/// Tight enough that nothing snaps to its target part way through a
/// comparison against a simulation that never snaps.
const Tolerance exact = Tolerance(distance: 1e-15, velocity: 1e-15);

void main() {
  group('the closed form is the same physics as SpringSimulation', () {
    // Any integrator — Euler, semi-implicit, Verlet — fails this. The point
    // of solving the oscillator analytically is that a frame of any length
    // lands exactly where the simulation says it should.
    void expectMatchesSimulation(
      SpringDescription spring, {
      required double from,
      required double to,
      required double velocity,
      required double step,
      double until = 1.0,
      double epsilon = 1e-9,
    }) {
      final reference = SpringSimulation(spring, from, to, velocity);
      final axis = SpringAxis(initialPosition: from)
        ..target = to
        ..velocity = velocity;

      var elapsed = 0.0;
      while (elapsed < until) {
        axis.advanceSpring(dt: step, spring: spring, tolerance: exact);
        elapsed += step;
        expect(
          axis.position,
          closeTo(reference.x(elapsed), epsilon),
          reason: 'position at ${elapsed}s',
        );
        expect(
          axis.velocity,
          closeTo(reference.dx(elapsed), epsilon),
          reason: 'velocity at ${elapsed}s',
        );
      }
    }

    test('underdamped, at 120 Hz', () {
      expectMatchesSimulation(
        const GlassMotion(bounce: 0.4).spring,
        from: 0,
        to: 100,
        velocity: 0,
        step: 1 / 120,
      );
    });

    test('underdamped, at wildly uneven frame times', () {
      final spring = const GlassMotion(bounce: 0.4).spring;
      final reference = SpringSimulation(spring, 0, 100, -600);
      final axis = SpringAxis()
        ..target = 100
        ..velocity = -600;
      const steps = <double>[0.004, 0.05, 1 / 120, 0.2, 1 / 60, 0.31];
      var elapsed = 0.0;
      for (final step in steps) {
        axis.advanceSpring(dt: step, spring: spring, tolerance: exact);
        elapsed += step;
        expect(axis.position, closeTo(reference.x(elapsed), 1e-9));
        expect(axis.velocity, closeTo(reference.dx(elapsed), 1e-9));
      }
    });

    test('overdamped', () {
      expectMatchesSimulation(
        const GlassMotion(bounce: -0.6).spring,
        from: 40,
        to: -10,
        velocity: 250,
        step: 1 / 60,
      );
    });

    test('critically damped', () {
      expectMatchesSimulation(
        const GlassMotion.smooth().spring,
        from: 0,
        to: 1,
        velocity: 0,
        step: 1 / 60,
        // Looser than the other regimes on purpose. A spring built from
        // `bounce: 0` lands on a damping ratio that is 1 only to within
        // rounding, so Flutter's own solver and this one can pick different
        // sides of the critical boundary; the two closed forms agree in the
        // limit, not bit for bit.
        epsilon: 1e-6,
      );
    });
  });

  group('retargeting', () {
    test(
      'is C1: the spring after a moved target is the spring that would have '
      'been built from the live position and velocity',
      () {
        final spring = const GlassMotion.interactive().spring;
        final axis = SpringAxis()..target = 100;
        for (var i = 0; i < 7; i++) {
          axis.advanceSpring(dt: 1 / 120, spring: spring, tolerance: exact);
        }

        final positionAtHandoff = axis.position;
        final velocityAtHandoff = axis.velocity;
        expect(velocityAtHandoff, isNot(closeTo(0, 1)));

        axis.target = -40;
        // Nothing about the state may change just because the target did.
        expect(axis.position, positionAtHandoff);
        expect(axis.velocity, velocityAtHandoff);

        final reference = SpringSimulation(
          spring,
          positionAtHandoff,
          -40,
          velocityAtHandoff,
        );
        var elapsed = 0.0;
        for (var i = 0; i < 40; i++) {
          axis.advanceSpring(dt: 1 / 120, spring: spring, tolerance: exact);
          elapsed += 1 / 120;
          expect(axis.position, closeTo(reference.x(elapsed), 1e-9));
          expect(axis.velocity, closeTo(reference.dx(elapsed), 1e-9));
        }
      },
    );

    test('moving the target every frame never discards velocity', () {
      final spring = const GlassMotion.interactive().spring;
      final axis = SpringAxis();
      var target = 0.0;
      for (var i = 0; i < 30; i++) {
        target += 4;
        axis
          ..target = target
          ..advanceSpring(dt: 1 / 120, spring: spring, tolerance: exact);
      }
      // A follow that rebuilt its simulation from rest each frame would
      // creep along at a fraction of this; one that kept velocity tracks a
      // steadily moving target at close to the target's own speed.
      expect(axis.velocity, greaterThan(4 * 120 * 0.5));
      expect(axis.position, greaterThan(target - 30));
    });
  });

  group('settling', () {
    test('a bouncy spring crosses its target, a smooth one never does', () {
      int crossings(GlassMotion motion) {
        final spring = motion.spring;
        final axis = SpringAxis()..target = 100;
        var count = 0;
        var sign = (axis.position - 100).sign;
        for (var i = 0; i < 600; i++) {
          axis.advanceSpring(dt: 1 / 120, spring: spring, tolerance: exact);
          final next = (axis.position - 100).sign;
          if (next != sign && next != 0) {
            count++;
            sign = next;
          }
        }
        return count;
      }

      expect(crossings(const GlassMotion.bouncy()), greaterThanOrEqualTo(1));
      expect(crossings(const GlassMotion.smooth()), 0);
    });

    test('reports done, and lands exactly on the target', () {
      const motion = GlassMotion.snappy();
      final spring = motion.spring;
      final axis = SpringAxis()..target = 100;
      var moving = true;
      var frames = 0;
      while (moving && frames < 2000) {
        moving = axis.advanceSpring(
          dt: 1 / 120,
          spring: spring,
          tolerance: motion.tolerance,
        );
        frames++;
      }
      expect(moving, isFalse, reason: 'never settled');
      expect(axis.position, 100);
      expect(axis.velocity, 0);
    });

    test(
      'a pixel-scale tolerance settles in far fewer frames than the motor '
      'default — the whole reason the tolerance is forwarded',
      () {
        int framesToSettle(GlassMotion motion) {
          final spring = motion.spring;
          final axis = SpringAxis()..target = 100;
          var frames = 0;
          while (axis.advanceSpring(
                dt: 1 / 120,
                spring: spring,
                tolerance: motion.tolerance,
              ) &&
              frames < 5000) {
            frames++;
          }
          return frames;
        }

        final ours = framesToSettle(const GlassMotion.snappy());
        final motorDefault = framesToSettle(
          const GlassMotion.snappy(
            settleDistance: 1e-3,
            settleVelocity: 1e-3,
          ),
        );
        expect(ours, lessThan(motorDefault));
        expect(motorDefault - ours, greaterThan(20));
      },
    );

    test('an axis already at its target never claims to be moving', () {
      final axis = SpringAxis(initialPosition: 12);
      expect(
        axis.advanceSpring(
          dt: 1 / 120,
          spring: const GlassMotion().spring,
          tolerance: const GlassMotion().tolerance,
        ),
        isFalse,
      );
    });
  });

  group('fling', () {
    test('decays under friction and hands over to the spring', () {
      const decay = GlassDecay();
      const motion = GlassMotion.bouncy();
      final spring = motion.spring;
      final axis = SpringAxis()..fling(decay, 2000);
      final resting = decay.restingPoint(start: 0, velocity: 2000);
      axis.target = resting;

      expect(axis.isDecaying, isTrue);
      var frames = 0;
      var velocityBeforeHandoff = 0.0;
      while (axis.isDecaying && frames < 2000) {
        velocityBeforeHandoff = axis.velocity;
        axis.advance(dt: 1 / 120, spring: spring, tolerance: motion.tolerance);
        frames++;
      }

      expect(axis.isDecaying, isFalse, reason: 'friction never gave out');
      expect(frames, greaterThan(10));
      // Friction is asymptotic, so the fling ends a few pixels short of
      // where it was heading, still moving — slowly — in the same
      // direction. The handoff has to inherit that, not restart from rest.
      expect(velocityBeforeHandoff, greaterThan(0));
      expect(velocityBeforeHandoff, lessThan(2000));
      expect(axis.position, lessThan(resting));
      expect(axis.velocity, greaterThan(0));

      // The spring covers the remaining few pixels and stops on the target.
      while (axis.advance(
        dt: 1 / 120,
        spring: spring,
        tolerance: motion.tolerance,
      )) {
        frames++;
        if (frames > 4000) {
          break;
        }
      }
      expect(axis.position, resting);
    });

    test(
      'a fling that overshoots its band is pulled back by the spring '
      'afterwards, rather than being clamped mid-flight',
      () {
        const decay = GlassDecay();
        const motion = GlassMotion.bouncy();
        final axis = SpringAxis()
          ..fling(decay, 3000)
          ..target = 56;
        var maximum = 0.0;
        for (var i = 0; i < 1500; i++) {
          axis.advance(
            dt: 1 / 120,
            spring: motion.spring,
            tolerance: motion.tolerance,
          );
          maximum = math.max(maximum, axis.position);
        }
        expect(maximum, greaterThan(56));
        expect(axis.position, closeTo(56, 1));
      },
    );

    test('endFling keeps position and velocity', () {
      final axis = SpringAxis()
        ..fling(const GlassDecay(), 900)
        ..advance(
          dt: 1 / 60,
          spring: const GlassMotion().spring,
          tolerance: exact,
        );
      final position = axis.position;
      final velocity = axis.velocity;
      axis.endFling();
      expect(axis.isDecaying, isFalse);
      expect(axis.position, position);
      expect(axis.velocity, velocity);
    });
  });

  test('settleInstantly is a jump, not a fast spring', () {
    final axis = SpringAxis()
      ..target = 100
      ..velocity = 500
      ..settleInstantly();
    expect(axis.position, 100);
    expect(axis.velocity, 0);
    expect(axis.isDecaying, isFalse);
  });
}
