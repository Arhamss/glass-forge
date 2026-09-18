import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/motion/glass_motion_state.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';

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
/// `translate(state.translation) · about-centre(press-stretch · velocity-
/// stretch)`, so the surface both moves and deforms about its own middle —
/// which is also where `ShapeGeometry.resolve` reads its basis from, so the
/// matte deforms with the shape rather than sliding relative to it.
///
/// Two deformations are folded into that single "about-centre" 2x2:
///
///  * A squash-and-stretch along the live *velocity* vector (see
///    [GlassJiggle]).
///  * An elongation along the *press anchor* — the finger's offset from the
///    surface's centre (see [GlassPressStretch]) — scaled to a fraction of
///    the surface's own half-extent so a finger at the edge of a small
///    button reaches as far proportionally as one at the edge of a large
///    one.
///
/// Each is written out as a similarity transform on a 2x2 rather than built
/// from three [Matrix4]s: `R(theta) · diag(a, b) · R(-theta)` with `cos` and
/// `sin` read straight off the normalised vector, which costs no
/// trigonometry at all. Each of those 2x2s is symmetric on its own — a
/// similarity transform of a diagonal by a rotation always is — but their
/// *product* is not, in general: two symmetric matrices commute (and so
/// their product stays symmetric) only when they share eigenvectors, which
/// here would mean the velocity and the press anchor pointing the same way.
/// A fling and a held finger point in unrelated directions in general, so
/// the product below carries all four entries rather than mirroring one
/// into the other. The two 2x2s are multiplied by hand, entry by entry,
/// rather than as two allocated [Matrix4]s, because this runs per frame per
/// surface.
Matrix4 glassSurfaceTransform({
  required Size size,
  required GlassMotionState state,
  required GlassJiggle jiggle,
  required GlassPressStretch pressStretch,
  required double pressScale,
}) {
  final press = lerpDouble(1, pressScale, state.press) ?? 1;
  final speed = state.velocity.distance;
  final stretch = jiggle.stretchFor(speed);

  final double v00;
  final double v01;
  final double v11;
  if (stretch == 1 || speed == 0) {
    v00 = press;
    v01 = 0;
    v11 = press;
  } else {
    final cos = state.velocity.dx / speed;
    final sin = state.velocity.dy / speed;
    final along = press * stretch;
    final across = press / stretch;
    v00 = along * cos * cos + across * sin * sin;
    v01 = (along - across) * cos * sin;
    v11 = along * sin * sin + across * cos * cos;
  }

  // The press anchor, as a fraction of the surface's own half-extent, so a
  // finger at the edge of a small button reaches as far proportionally as
  // one at the edge of a large one.
  final anchor = state.pressAnchor * state.press;
  final reach = pressStretch.isActive && anchor != Offset.zero
      ? Offset(anchor.dx / (size.width / 2), anchor.dy / (size.height / 2))
      : Offset.zero;
  final reachDistance = reach.distance;

  final double m00;
  final double m01;
  final double m10;
  final double m11;
  if (reachDistance == 0) {
    // No anchor deformation: the anchor 2x2 is the identity, so the
    // product is just the velocity matrix, still symmetric.
    m00 = v00;
    m01 = v01;
    m10 = v01;
    m11 = v11;
  } else {
    final pressAlong = 1 + pressStretch.intensity * reachDistance;
    final pressAcross =
        1 / (1 + pressStretch.intensity * reachDistance * pressStretch.squash);
    final cos = reach.dx / reachDistance;
    final sin = reach.dy / reachDistance;
    final a00 = pressAlong * cos * cos + pressAcross * sin * sin;
    final a01 = (pressAlong - pressAcross) * cos * sin;
    final a11 = pressAlong * sin * sin + pressAcross * cos * cos;
    // Not symmetric in general — see the doc comment above — so all four
    // entries are carried separately instead of mirroring m01 into m10.
    m00 = v00 * a00 + v01 * a01;
    m01 = v00 * a01 + v01 * a11;
    m10 = v01 * a00 + v11 * a01;
    m11 = v01 * a01 + v11 * a11;
  }

  final centreX = size.width / 2;
  final centreY = size.height / 2;
  return Matrix4.identity()
    ..translateByDouble(
      state.translation.dx + anchor.dx * pressStretch.travel + centreX,
      state.translation.dy + anchor.dy * pressStretch.travel + centreY,
      0,
      1,
    )
    ..multiply(
      Matrix4.identity()
        ..setEntry(0, 0, m00)
        ..setEntry(0, 1, m01)
        ..setEntry(1, 0, m10)
        ..setEntry(1, 1, m11),
    )
    ..translateByDouble(-centreX, -centreY, 0, 1);
}
