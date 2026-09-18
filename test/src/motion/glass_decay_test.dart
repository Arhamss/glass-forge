import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';

void main() {
  test('builds a friction simulation, which motor has none of', () {
    final simulation = const GlassDecay().createSimulation(velocity: 1000);
    expect(simulation, isA<FrictionSimulation>());
    expect(simulation.dx(0), closeTo(1000, 1e-9));
    // Friction only ever slows it down.
    var previous = simulation.dx(0);
    for (var t = 0.0; t < 3; t += 0.01) {
      final speed = simulation.dx(t);
      expect(speed, lessThanOrEqualTo(previous + 1e-9));
      previous = speed;
    }
  });

  test('ignores end, because a fling has no target', () {
    const decay = GlassDecay();
    final a = decay.createSimulation(velocity: 800);
    final b = decay.createSimulation(end: 999999, velocity: 800);
    for (var t = 0.0; t < 2; t += 0.05) {
      expect(a.x(t), b.x(t));
    }
  });

  test(
    'forwards its settle velocity, so a fling ends at a visible speed '
    'rather than at a thousandth of a pixel per second',
    () {
      const ours = GlassDecay();
      final simulation = ours.createSimulation(velocity: 1200);
      expect(simulation.tolerance.velocity, ours.settleVelocity);

      double endTime(Simulation s) {
        var t = 0.0;
        while (!s.isDone(t) && t < 60) {
          t += 1 / 240;
        }
        return t;
      }

      final tight = const GlassDecay(
        settleVelocity: 1e-3,
      ).createSimulation(velocity: 1200);
      expect(endTime(simulation), lessThan(endTime(tight)));
    },
  );

  test('restingPoint agrees with where the simulation actually stops', () {
    const decay = GlassDecay();
    final simulation = decay.createSimulation(start: 25, velocity: -1500);
    expect(
      decay.restingPoint(start: 25, velocity: -1500),
      closeTo(simulation.x(1000000), 1e-6),
    );
  });

  test('a heavier drag stops sooner', () {
    expect(
      const GlassDecay(drag: 0.01).restingPoint(start: 0, velocity: 1000),
      lessThan(
        const GlassDecay(drag: 0.5).restingPoint(start: 0, velocity: 1000),
      ),
    );
  });

  group('value semantics', () {
    // `const` objects with identical literal fields are canonicalised to
    // one runtime instance at compile time, independent of any custom
    // `operator==` -- so comparing two `const GlassDecay()` literals would
    // pass even if `==`/`hashCode` were deleted outright. Plain (non-const)
    // constructor calls always allocate distinct instances, so `identical`
    // being false here is what proves this test actually exercises
    // `operator==` rather than object identity.
    GlassDecay decayWith({
      double drag = 0.135,
      double settleVelocity = 8,
    }) => GlassDecay(drag: drag, settleVelocity: settleVelocity);

    test('two distinct instances with equal fields compare equal', () {
      final a = decayWith();
      final b = decayWith();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing drag compares unequal', () {
      final a = decayWith();
      final b = decayWith(drag: 0.2);

      expect(identical(a, b), isFalse);
      expect(a, isNot(equals(b)));
    });

    test('differing settleVelocity compares unequal', () {
      final a = decayWith();
      final b = decayWith(settleVelocity: 1);

      expect(identical(a, b), isFalse);
      expect(a, isNot(equals(b)));
    });
  });
}
