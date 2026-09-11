import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Rubber-banding: how far past its rest position a surface may be dragged,
/// and how hard it fights back.
///
/// motor's changelog claims resistance; its source has none — there is no
/// rubber-band, clamp or resistance code anywhere in the package. This is
/// the iOS curve:
///
/// ```text
/// f(x) = limit * (1 - 1 / (x * resistance / limit + 1))
/// ```
///
/// which has the three properties that make overdrag feel right and that
/// nothing simpler has all of: it passes through the origin, it starts out
/// tracking the finger exactly (`f'(0) == resistance`), and it approaches
/// [limit] without ever reaching it, so the surface can never be dragged off
/// its own layer no matter how long the gesture runs.
@immutable
class GlassOverdrag {
  /// Creates a rubber band that asymptotes at [limit] logical pixels.
  const GlassOverdrag({this.limit = 56, this.resistance = 0.55})
    : assert(limit > 0, 'limit must be positive'),
      assert(
        resistance > 0 && resistance <= 1,
        'resistance is the fraction of the drag that gets through at zero '
        'displacement',
      );

  /// No resistance: the surface tracks the pointer one to one, forever.
  const GlassOverdrag.none() : limit = double.infinity, resistance = 1;

  /// The displacement, in logical pixels, this curve approaches but never
  /// reaches.
  final double limit;

  /// The fraction of pointer movement that reaches the surface at rest.
  final double resistance;

  /// Whether this band actually resists anything.
  bool get isActive => limit.isFinite;

  /// Applies the band to a raw pointer displacement.
  double applyToScalar(double raw) {
    if (!isActive || raw == 0) {
      // The curve degenerates at an infinite limit — it flattens to
      // `raw * resistance`, which is a constant *scale*, not the absence of
      // resistance anyone asking for `none()` means.
      return raw;
    }
    final magnitude = raw.abs();
    final banded = limit * (1 - 1 / (magnitude * resistance / limit + 1));
    return banded * raw.sign;
  }

  /// Applies the band radially, so a diagonal drag is resisted the same as
  /// an axial one of the same length.
  ///
  /// Banding each axis on its own would let a 45-degree drag reach
  /// `limit * sqrt(2)` from home while a horizontal one stopped at `limit`,
  /// which reads as a square rubber band around a round surface.
  Offset apply(Offset raw) {
    if (!isActive) {
      return raw;
    }
    final distance = raw.distance;
    if (distance == 0) {
      return Offset.zero;
    }
    return raw * (applyToScalar(distance) / distance);
  }

  /// Inverts [applyToScalar], recovering the raw displacement that produces
  /// [banded].
  ///
  /// Needed when a gesture starts on a surface that is already displaced:
  /// the accumulated pointer travel has to resume from where the band
  /// currently sits, or the surface jumps as soon as the finger moves.
  ///
  /// Capped at [_maxInverseTravel] limits of pointer travel. The band is
  /// asymptotic, so inverting a displacement at or past [limit] — which a
  /// fling reaches, since a fling overshoots the band and springs back —
  /// diverges. The cap is about arithmetic, not feel: a gesture resuming
  /// from a value ten orders of magnitude larger than its own deltas would
  /// be numerically dead for its whole life, unable to carry the surface
  /// further out *or* bring it back. Being stiff that deep in a rubber band
  /// is correct; being unable to move at all is not. The cap is far past
  /// any real gesture, so it never touches an in-band inverse.
  double rawForScalar(double banded) {
    if (!isActive || banded == 0) {
      return banded;
    }
    final ceiling = limit * _maxInverseTravel;
    final magnitude = banded.abs();
    final raw = magnitude >= limit
        ? ceiling
        : limit * magnitude / (resistance * (limit - magnitude));
    return (raw < ceiling ? raw : ceiling) * banded.sign;
  }

  /// How many [limit]s of pointer travel [rawForScalar] will report.
  static const double _maxInverseTravel = 64;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassOverdrag &&
        other.limit == limit &&
        other.resistance == resistance;
  }

  @override
  int get hashCode => Object.hash(limit, resistance);

  @override
  String toString() => 'GlassOverdrag(limit: $limit, $resistance)';
}
