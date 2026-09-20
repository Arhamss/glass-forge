import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';

/// One scalar channel of a glass surface's motion.
///
/// The whole reason this exists instead of a `SingleMotionController` per
/// axis: motor's only way to move a target is `animateTo`, which allocates a
/// fresh [Simulation] per dimension, throws away the old ones and restarts
/// the ticker. Tracking a finger calls that sixty to a hundred and twenty
/// times a second. Here [target] is a field.
///
/// [advanceSpring] is the closed-form solution of the damped harmonic
/// oscillator, re-seeded from the live ([position], [velocity]) pair on every
/// step. That is what makes a moving target free *and* what makes a retarget
/// C1-continuous for nothing: the state carried across the change is
/// position and velocity, so there is no discontinuity to smooth over. It is
/// also exact rather than integrated, so a long frame is no less accurate
/// than a short one.
class SpringAxis {
  /// Creates an axis at rest at [initialPosition].
  SpringAxis({double initialPosition = 0})
    : position = initialPosition,
      target = initialPosition;

  /// Where the channel is now.
  double position;

  /// How fast it is moving, in units per second.
  double velocity = 0;

  /// Where it is heading. Assign freely; this is the follow primitive.
  double target;

  Simulation? _simulation;
  double _simulationTime = 0;

  /// Whether a fling is in flight on this axis.
  bool get isDecaying => _simulation != null;

  /// Starts a fling from the current [position] at [velocity].
  ///
  /// The simulation is allocated once, here, not per pointer event: a fling
  /// is a single event.
  void fling(GlassDecay decay, double initialVelocity) {
    velocity = initialVelocity;
    _simulation = decay.createSimulation(
      start: position,
      velocity: initialVelocity,
    );
    _simulationTime = 0;
  }

  /// Abandons any fling, keeping position and velocity.
  ///
  /// The handoff back to the spring is continuous because both quantities
  /// survive it — which is the entire point of not re-deriving velocity from
  /// a finite difference of positions.
  void endFling() {
    _simulation = null;
    _simulationTime = 0;
  }

  /// Snaps to [target] with no motion at all.
  ///
  /// What Reduce Motion resolves to. Not a faster spring: a faster spring is
  /// still motion.
  void settleInstantly() {
    endFling();
    position = target;
    velocity = 0;
  }

  /// Advances by [dt] seconds. Returns whether the channel is still moving.
  ///
  /// A fling runs until friction ends it and then hands over to the spring
  /// in the same step, so the frame a fling finishes on is not a frame where
  /// nothing happens.
  bool advance({
    required double dt,
    required SpringDescription spring,
    required Tolerance tolerance,
  }) {
    final simulation = _simulation;
    if (simulation != null) {
      _simulationTime += dt;
      position = simulation.x(_simulationTime);
      velocity = simulation.dx(_simulationTime);
      if (!simulation.isDone(_simulationTime)) {
        return true;
      }
      endFling();
    }
    return advanceSpring(dt: dt, spring: spring, tolerance: tolerance);
  }

  /// One analytic spring step toward [target].
  ///
  /// Exposed for tests that want the physics without the fling branch.
  bool advanceSpring({
    required double dt,
    required SpringDescription spring,
    required Tolerance tolerance,
  }) {
    if (_isAtRest(tolerance)) {
      position = target;
      velocity = 0;
      return false;
    }

    final omega = math.sqrt(spring.stiffness / spring.mass);
    final zeta =
        spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
    final displacement = position - target;
    final v = velocity;

    if (zeta < 1 - _criticalBand) {
      final damped = omega * math.sqrt(1 - zeta * zeta);
      final decay = math.exp(-zeta * omega * dt);
      final a = displacement;
      final b = (v + zeta * omega * displacement) / damped;
      final cos = math.cos(damped * dt);
      final sin = math.sin(damped * dt);
      final oscillation = a * cos + b * sin;
      position = target + decay * oscillation;
      velocity =
          decay * (damped * (b * cos - a * sin) - zeta * omega * oscillation);
    } else if (zeta > 1 + _criticalBand) {
      final rate = omega * math.sqrt(zeta * zeta - 1);
      final fast = -zeta * omega - rate;
      final slow = -zeta * omega + rate;
      final second = (v - slow * displacement) / (fast - slow);
      final first = displacement - second;
      final slowTerm = first * math.exp(slow * dt);
      final fastTerm = second * math.exp(fast * dt);
      position = target + slowTerm + fastTerm;
      velocity = slow * slowTerm + fast * fastTerm;
    } else {
      // Critically damped. The underdamped branch divides by the damped
      // frequency and the overdamped branch divides by the difference of
      // the two roots; both go to zero here, so this case is not an
      // optimisation, it is the only finite form. The band around zeta == 1
      // exists because a spring built from a duration and a bounce of
      // exactly zero lands there up to floating-point noise.
      final decay = math.exp(-omega * dt);
      final a = displacement;
      final b = v + omega * displacement;
      final drift = a + b * dt;
      position = target + decay * drift;
      velocity = decay * (b - omega * drift);
    }

    if (_isAtRest(tolerance)) {
      position = target;
      velocity = 0;
      return false;
    }
    return true;
  }

  bool _isAtRest(Tolerance tolerance) =>
      (position - target).abs() < tolerance.distance &&
      velocity.abs() < tolerance.velocity;

  /// How far from critical damping still counts as critical.
  ///
  /// `SpringDescription.withDurationAndBounce` computes the damping from a
  /// square root, so `bounce: 0` produces a ratio that is 1 only to within
  /// rounding; without a band, that lands in whichever of the two singular
  /// branches the last bit happened to choose.
  static const double _criticalBand = 1e-9;
}
