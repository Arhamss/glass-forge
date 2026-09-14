import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:motor/motor.dart';

/// How a glass surface moves.
///
/// Apple specifies motion as a **duration and a bounce**, never as stiffness
/// and damping, and this keeps that vocabulary end to end: [duration] is the
/// spring's perceptual oscillation period (not its settle time) and [bounce]
/// runs from `-1` (heavily overdamped) through `0` (no overshoot) to `1`
/// (undamped). The conversion is motor's, via [CupertinoMotion], so the
/// presets here are the same numbers SwiftUI's `.bouncy`, `.snappy`,
/// `.smooth` and `.interactiveSpring` resolve to rather than a second
/// hand-tuned set that drifts from them.
///
/// Two things motor does not do are added here:
///
/// * **Tolerance is forwarded.** `SpringMotion` builds every simulation with
///   `Tolerance.defaultTolerance` (1e-3 for both distance and velocity) and
///   never passes its own `tolerance` field through. On a controller whose
///   output feeds a shader that means tens of frames spent travelling a
///   thousandth of a pixel. [settleDistance] and [settleVelocity] are in
///   logical pixels and pixels per second, so "settled" means "settled to
///   the eye".
/// * **Reduce Motion resolves to an instant settle**, never to a shorter
///   spring — see `GlassReduceMotion`. A faster spring is still motion; the
///   accessibility setting asks for none.
@immutable
class GlassMotion {
  /// Creates a spring described by a duration and a bounce.
  const GlassMotion({
    this.duration = const Duration(milliseconds: 500),
    this.bounce = 0,
    this.settleDistance = 0.5,
    this.settleVelocity = 8,
  });

  /// A spring with a pronounced overshoot. SwiftUI's `.bouncy`.
  const GlassMotion.bouncy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0,
    double settleDistance = 0.5,
    double settleVelocity = 8,
  }) : this(
         duration: duration,
         bounce: 0.3 + extraBounce,
         settleDistance: settleDistance,
         settleVelocity: settleVelocity,
       );

  /// A spring with a small overshoot. SwiftUI's `.snappy`.
  const GlassMotion.snappy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0,
    double settleDistance = 0.5,
    double settleVelocity = 8,
  }) : this(
         duration: duration,
         bounce: 0.15 + extraBounce,
         settleDistance: settleDistance,
         settleVelocity: settleVelocity,
       );

  /// A spring that does not overshoot at all. SwiftUI's `.smooth`.
  const GlassMotion.smooth({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0,
    double settleDistance = 0.5,
    double settleVelocity = 8,
  }) : this(
         duration: duration,
         bounce: extraBounce,
         settleDistance: settleDistance,
         settleVelocity: settleVelocity,
       );

  /// The short spring meant to run *under the finger*, not after it.
  ///
  /// SwiftUI's `.interactiveSpring`. This is the default everywhere a
  /// gesture is in progress: at 150 ms the surface reads as attached to the
  /// pointer rather than chasing it.
  const GlassMotion.interactive({
    Duration duration = const Duration(milliseconds: 150),
    double extraBounce = 0,
    double settleDistance = 0.5,
    double settleVelocity = 8,
  }) : this(
         duration: duration,
         bounce: 0.14 + extraBounce,
         settleDistance: settleDistance,
         settleVelocity: settleVelocity,
       );

  /// The spring's perceptual period — **not** how long it takes to settle.
  final Duration duration;

  /// Overshoot, from `-1` (overdamped) through `0` (none) to `1`.
  final double bounce;

  /// The amplitude, in logical pixels, below which the spring is at rest.
  ///
  /// Half a logical pixel: on a 3x display that is 1.5 physical pixels of
  /// residual travel, which is under the antialiasing band the matte already
  /// paints over the shape's own edge.
  final double settleDistance;

  /// The speed, in logical pixels per second, below which the spring is at
  /// rest.
  ///
  /// Eight pixels per second is a sixteenth of a pixel per frame at 120 Hz.
  final double settleVelocity;

  /// This configuration as motor's own [Motion], with [tolerance] actually
  /// forwarded to the simulations it builds.
  ///
  /// Construct it once and keep it: [CupertinoMotion.description] recomputes
  /// a `sqrt` and a `pow` and allocates a [SpringDescription] on **every**
  /// access, and `SpringMotion.==` reads it six times.
  CupertinoMotion get motion => _TolerantCupertinoMotion(
    duration: duration,
    bounce: bounce,
    tolerance: tolerance,
  );

  /// The damped-harmonic-oscillator parameters this resolves to.
  ///
  /// Allocates; see [motion]. Callers cache this per gesture, never per
  /// frame.
  SpringDescription get spring => motion.description;

  /// When this spring counts as settled, in the units named on
  /// [settleDistance] and [settleVelocity].
  Tolerance get tolerance =>
      Tolerance(distance: settleDistance, velocity: settleVelocity);

  /// This motion with its settle thresholds divided by [pixelsPerUnit].
  ///
  /// A channel that is not measured in pixels — press depth runs 0 to 1 —
  /// still has to settle at a *visual* threshold, so it converts: a press
  /// that moves a 200 px box by 4 px across its whole range settles when the
  /// remaining travel is under half of one of those pixels, not when the
  /// unitless value is within half of 1.0, which would be the entire range.
  GlassMotion scaledTo(double pixelsPerUnit) {
    assert(pixelsPerUnit > 0, 'pixelsPerUnit must be positive');
    return GlassMotion(
      duration: duration,
      bounce: bounce,
      settleDistance: settleDistance / pixelsPerUnit,
      settleVelocity: settleVelocity / pixelsPerUnit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassMotion &&
        other.duration == duration &&
        other.bounce == bounce &&
        other.settleDistance == settleDistance &&
        other.settleVelocity == settleVelocity;
  }

  // Deliberately hashes the inputs, not `spring`: SpringMotion's own
  // equality reads `description` six times per comparison, and that getter
  // is three transcendental calls and an allocation deep.
  @override
  int get hashCode =>
      Object.hash(duration, bounce, settleDistance, settleVelocity);

  @override
  String toString() =>
      'GlassMotion(${duration.inMilliseconds}ms, bounce: $bounce)';
}

/// A [CupertinoMotion] that forwards the tolerance it was given.
///
/// `Motion.tolerance` is a plain field the base constructor fills with
/// `Tolerance.defaultTolerance`, and no spring subclass in motor offers a way
/// to set it. Overriding the getter is the same route motor's own
/// `TrimmedMotion` takes.
class _TolerantCupertinoMotion extends CupertinoMotion {
  /// The field has to be private — `tolerance` itself is the inherited
  /// field this shadows — so the initializing formal is private too.
  const _TolerantCupertinoMotion({
    required super.duration,
    required super.bounce,
    required this._tolerance,
  });

  final Tolerance _tolerance;

  @override
  Tolerance get tolerance => _tolerance;
}
