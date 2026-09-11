import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:motor/motor.dart';

/// A fling: velocity in, friction, no target.
///
/// motor ships spring, curve, none and trimmed motions and **no decay**. Its
/// [Motion] base class is abstract with the right hook,
/// [createSimulation], but the controller wrapped around it is target-based
/// (`_getStatusWhenDone` asks whether the *target* equals the initial value,
/// `_redirectSimulation` re-runs `animateTo` against the stored target), so a
/// targetless simulation handed to a `MotionController` reports nonsense
/// statuses and is silently re-pointed at a target it never had.
///
/// So: this is a real [Motion] — anything that only calls [createSimulation]
/// can use it — but it is consumed by `GlassMotionController`, which runs
/// simulations itself and has no notion of a target while one is running.
/// **Do not hand it to `MotionController.animateTo`.** The `end` argument is
/// ignored, because a fling has no end until friction says so.
@immutable
class GlassDecay extends Motion {
  /// Creates a decay with iOS's scroll friction.
  const GlassDecay({
    this.drag = 0.135,
    this.settleVelocity = 8,
  }) : assert(drag > 0 && drag < 1, 'drag is a per-second retention factor');

  /// The fluid drag coefficient: velocity retained per second.
  ///
  /// 0.135 is the value iOS scrolling uses, and the one Flutter's own
  /// `BouncingScrollSimulation` picked to match it.
  final double drag;

  /// The speed, in logical pixels per second, at which the fling is over.
  ///
  /// The default friction simulation stops at `Tolerance.defaultTolerance`
  /// — a thousandth of a pixel per second — which on a shader-driving
  /// controller is several hundred frames of invisible creep.
  final double settleVelocity;

  @override
  Tolerance get tolerance => Tolerance(velocity: settleVelocity);

  /// A fling never has to be settled *at* anything; friction ends it.
  @override
  bool get needsSettle => false;

  /// Friction always terminates, bounds or no bounds.
  @override
  bool get unboundedWillSettle => true;

  /// Builds the friction simulation. [end] is ignored — see the class doc.
  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) => FrictionSimulation(drag, start, velocity, tolerance: tolerance);

  /// Where a fling from [start] at [velocity] comes to rest.
  ///
  /// Closed form, so a caller can decide whether a fling is worth starting —
  /// or clamp where it will land — without stepping the simulation.
  double restingPoint({required double start, required double velocity}) =>
      FrictionSimulation(drag, start, velocity, tolerance: tolerance).finalX;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassDecay &&
        other.drag == drag &&
        other.settleVelocity == settleVelocity;
  }

  @override
  int get hashCode => Object.hash(drag, settleVelocity);

  @override
  String toString() => 'GlassDecay(drag: $drag)';
}
