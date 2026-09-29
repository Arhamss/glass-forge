import 'package:flutter/foundation.dart';

/// How far a surface gives when a finger drags across it while pressing.
///
/// Driven by how far the finger has moved since it went down, not by where
/// it sits on the surface. A finger held still — a plain tap, or a press at
/// the very edge — leaves the glass undeformed; only movement flexes it.
/// Apple's own description is of glass that "moves in tandem with your
/// interaction" (WWDC25, *Meet Liquid Glass*), and its sessions name
/// scaling and bouncing for a tap, never a reach toward the finger.
///
/// The movement goes through three stages before it deforms anything:
///
///  * a [slop] of 3 pt is ignored, so the tremor of a finger at rest never
///    registers;
///  * the rest is rubber-banded, `d / (1 + d / 100)` then halved, so it
///    saturates near 50 pt however far the finger goes;
///  * that is taken as a fraction of the surface's own half-extent in the
///    drag's direction, capped at 1, so a small button and a large card
///    give about the same number of points rather than the same ratio.
///
/// [intensity] then scales that fraction into the elongation. At the
/// default 0.05 no surface stretches past 5 %, which is the ceiling
/// `liquid_glass_widgets` measured on a native iOS 26 button at 120 fps and
/// ships as `AnchorStretchSettings.nativeTremor` (intensity, squash and
/// translation damping all 0.1, on a halved, resisted drag). Its
/// `GlassButton` has used that since its #267; the looser 0.5 / 0.3 / 0.15
/// that this class used to default to are only that package's generic
/// constructor defaults, which only its `GlassChip` still uses.
///
/// Derived from the press channel rather than sprung separately, for the
/// same reason `GlassJiggle` is derived from velocity: a second spring has
/// its own phase, and drifts out of step with the press it is supposed to be
/// caused by. Multiplying by the already-sprung press depth makes the
/// deformation causal by construction, and it rides the release spring back
/// to nothing rather than snapping away when the finger lifts.
@immutable
class GlassPressStretch {
  /// Creates a press-stretch.
  const GlassPressStretch({
    this.intensity = 0.05,
    this.squash = 1,
    this.travel = 0.05,
  }) : assert(intensity >= 0, 'intensity is a fraction at or above 0'),
       assert(squash >= 0 && squash <= 1, 'squash is a fraction 0 to 1'),
       assert(travel >= 0, 'travel is a fraction at or above 0');

  /// No deformation at all. What Reduce Motion resolves to.
  const GlassPressStretch.none() : intensity = 0, squash = 0, travel = 0;

  /// How much movement, in logical pixels, is ignored before the glass
  /// starts to give.
  static const double slop = 3;

  /// The most the surface ever [travel]s, in logical pixels.
  static const double maxTravel = 4;

  /// How far the surface elongates along the drag at full reach, as a
  /// fraction of its size: 0.05 is at most 5 % longer.
  final double intensity;

  /// How much of that elongation is conserved as squash across it.
  ///
  /// 1, the default, keeps area exactly — the "matching squash" of a native
  /// button. At a few percent a label on the surface does not visibly
  /// distort, so there is no reason to break the conservation.
  final double squash;

  /// The fraction of the drag, past [slop], that the surface actually
  /// translates along with the finger, never more than [maxTravel].
  final double travel;

  /// Whether this deforms or moves anything.
  bool get isActive => intensity > 0 || travel > 0;
}
