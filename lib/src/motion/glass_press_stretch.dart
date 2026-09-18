import 'package:flutter/foundation.dart';

/// How far a surface elongates toward a held finger.
///
/// Apple's buttons reach toward where they are being touched and pull back
/// when the finger lifts, while barely moving. The reaching is most of the
/// effect; the moving is almost none of it, which is why [travel] is small.
///
/// Derived from the press channel rather than sprung separately, for the
/// same reason `GlassJiggle` is derived from velocity: a second spring has
/// its own phase, and drifts out of step with the press it is supposed to be
/// caused by. Multiplying by the already-sprung press depth makes the
/// deformation causal by construction, needing no extra state and no extra
/// ticker.
///
/// The defaults match what `liquid_glass_widgets` settled on. They are a
/// starting point and are checked against a screen recording of an iOS 27
/// button before they ship.
@immutable
class GlassPressStretch {
  /// Creates a press-stretch.
  const GlassPressStretch({
    this.intensity = 0.5,
    this.squash = 0.3,
    this.travel = 0.15,
  }) : assert(intensity >= 0, 'intensity is a fraction at or above 0'),
       assert(squash >= 0 && squash <= 1, 'squash is a fraction 0 to 1'),
       assert(travel >= 0, 'travel is a fraction at or above 0');

  /// No deformation at all. What Reduce Motion resolves to.
  const GlassPressStretch.none() : intensity = 0, squash = 0, travel = 0;

  /// How far the surface elongates along the finger's offset, as a fraction
  /// of that offset relative to the surface's own size.
  final double intensity;

  /// How much of that elongation is conserved as squash across it.
  ///
  /// 1 keeps area exactly. Lower keeps a label on the surface from
  /// distorting, which is why the default is well below 1: a button's text
  /// is drawn on the surface and deforms with it.
  final double squash;

  /// The fraction of the finger's offset the surface actually translates.
  final double travel;

  /// Whether this deforms or moves anything.
  bool get isActive => intensity > 0 || travel > 0;
}
