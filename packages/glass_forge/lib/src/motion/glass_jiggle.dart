import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';

/// Squash and stretch, derived from live velocity.
///
/// This is the difference between glass and a moving rectangle, and it is
/// deliberately **not** a channel of its own. Animating deformation
/// separately means a second spring with its own phase, which drifts out of
/// step with the translation it is supposed to be caused by — the surface
/// keeps wobbling after it has stopped, or starts wobbling before it has
/// moved. Reading it straight off the translation spring's velocity makes it
/// causal by construction: it is largest exactly when the surface is moving
/// fastest, it is zero the instant the surface stops, and it needs no extra
/// state, no extra spring and no extra ticker.
///
/// The deformation stretches **along** the velocity vector and compresses
/// perpendicular to it by the reciprocal, so the determinant is exactly one:
/// area is conserved, which is what stops a fast-moving surface from looking
/// like it is also growing.
@immutable
class GlassJiggle {
  /// Creates a jiggle.
  const GlassJiggle({this.maxStretch = 1.18, this.halfSpeed = 1600})
    : assert(maxStretch >= 1, 'maxStretch is a ratio at or above 1'),
      assert(halfSpeed > 0, 'halfSpeed must be positive');

  /// No deformation at all. What Reduce Motion resolves to.
  const GlassJiggle.none() : maxStretch = 1, halfSpeed = 1;

  /// The stretch ratio approached at infinite speed.
  ///
  /// 1.18 is about as far as a surface can deform before it stops reading as
  /// the same object.
  final double maxStretch;

  /// The speed, in logical pixels per second, at which half the available
  /// stretch is reached.
  ///
  /// A saturating curve rather than a linear one: a fling can carry several
  /// thousand pixels per second, and anything linear either does nothing at
  /// gesture speed or tears the surface apart at fling speed.
  final double halfSpeed;

  /// Whether this deforms anything.
  bool get isActive => maxStretch > 1;

  /// The stretch ratio for a surface moving at [speed].
  double stretchFor(double speed) {
    if (!isActive || speed <= 0) {
      return 1;
    }
    return 1 + (maxStretch - 1) * (speed / (speed + halfSpeed));
  }
}

/// The transform a glass surface of [size] paints under, given [state].
///
/// Composed in parent space as
/// `translate(state.translation) · about-centre(press · stretch)`, so the
/// surface both moves and deforms about its own middle — which is also where
/// `ShapeGeometry.resolve` reads its basis from, so the matte deforms with
/// the shape rather than sliding relative to it.
///
/// The rotation into and out of the velocity frame is written out as a
/// similarity transform on a 2x2 rather than built from three [Matrix4]s:
/// `R(theta) · diag(a, b) · R(-theta)` with `cos` and `sin` read straight off
/// the normalised velocity, which costs no trigonometry at all.
Matrix4 glassSurfaceTransform({
  required Size size,
  required GlassMotionState state,
  required GlassJiggle jiggle,
  required double pressScale,
}) {
  final press = lerpDouble(1, pressScale, state.press) ?? 1;
  final speed = state.velocity.distance;
  final stretch = jiggle.stretchFor(speed);

  final double m00;
  final double m01;
  final double m11;
  if (stretch == 1 || speed == 0) {
    m00 = press;
    m01 = 0;
    m11 = press;
  } else {
    final cos = state.velocity.dx / speed;
    final sin = state.velocity.dy / speed;
    final along = press * stretch;
    final across = press / stretch;
    m00 = along * cos * cos + across * sin * sin;
    m01 = (along - across) * cos * sin;
    m11 = along * sin * sin + across * cos * cos;
  }

  final centreX = size.width / 2;
  final centreY = size.height / 2;
  // The 2x2 is symmetric — a similarity transform of a diagonal by a
  // rotation always is — so m10 is m01.
  return Matrix4.identity()
    ..translateByDouble(
      state.translation.dx + centreX,
      state.translation.dy + centreY,
      0,
      1,
    )
    ..multiply(
      Matrix4.identity()
        ..setEntry(0, 0, m00)
        ..setEntry(0, 1, m01)
        ..setEntry(1, 0, m01)
        ..setEntry(1, 1, m11),
    )
    ..translateByDouble(-centreX, -centreY, 0, 1);
}
