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
/// [intensity] then scales that fraction into the elongation. The
/// defaults are measured off screenshots of the iOS 27 Clock app's Edit
/// and + buttons pulled down on a physical iPhone, 2026-09-30: each grows
/// about 1.5x along the pull, glass and label alike, keeps its width apart
/// from the press growth — no squash — and moves about 10 pt after the
/// finger. With the press growth's 1.10, an [intensity] of 0.35 lands at
/// that 1.5. The earlier 0.05 — `liquid_glass_widgets`'
/// `AnchorStretchSettings.nativeTremor` — read as no stretch at all.
///
/// Letting go bounces: the stretch springs back through rest into a
/// brief squash, scaled by [rebound], before it settles.
///
/// A stretched surface also lights up: [sheen] adds a white lift to the
/// touch glow in proportion to how far the surface has given, the "hue"
/// native glass takes on while it is pulled.
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
    this.intensity = 0.35,
    this.squash = 0,
    this.travel = 0.15,
    this.sheen = 0.2,
    this.rebound = 0.75,
  }) : assert(intensity >= 0, 'intensity is a fraction at or above 0'),
       assert(squash >= 0 && squash <= 1, 'squash is a fraction 0 to 1'),
       assert(travel >= 0, 'travel is a fraction at or above 0'),
       assert(sheen >= 0 && sheen <= 1, 'sheen is a fraction 0 to 1'),
       assert(rebound >= 0, 'rebound is a gain at or above 0');

  /// No deformation at all. What Reduce Motion resolves to.
  const GlassPressStretch.none()
    : intensity = 0,
      squash = 0,
      travel = 0,
      sheen = 0,
      rebound = 0;

  /// How much movement, in logical pixels, is ignored before the glass
  /// starts to give.
  static const double slop = 3;

  /// The most the surface ever [travel]s, in logical pixels.
  static const double maxTravel = 10;

  /// How far the surface elongates along the drag at full reach, as a
  /// fraction of its size: 0.35 is at most 35 % longer.
  final double intensity;

  /// How much of that elongation is conserved as squash across it.
  ///
  /// 1 keeps area exactly. 0, the default, leaves the width alone, which is
  /// what a native button does: pulled down, it gets taller and its label
  /// with it, and no narrower.
  final double squash;

  /// The fraction of the drag, past [slop], that the surface actually
  /// translates along with the finger, never more than [maxTravel].
  final double travel;

  /// How much white light a fully stretched surface gains, 0 to 1.
  ///
  /// Added to the touch glow's strength in proportion to the stretch's
  /// reach, and the glow widens with it so the lift covers the whole
  /// surface rather than pooling under the finger. It reaches the shader
  /// through the same glow channel, so a surface with its glow turned off
  /// takes on no sheen either. 0.2 adds about 50 of 255 at full reach.
  final double sheen;

  /// How hard the surface bounces back through rest when the finger lifts.
  ///
  /// The release spring undershoots rest once, by about a quarter, and
  /// the stretch follows it through: briefly shorter along the pull and
  /// wider across it, and back past home, before it settles. This
  /// multiplies that rebound, and only the rebound. At 1 the stretch
  /// follows the spring as it is; the default 0.75 softens that to a
  /// squash of about 7 % back through rest, the settle of a native button
  /// let go. Higher bounces harder; at 0 it just eases out.
  final double rebound;

  /// Whether this deforms or moves anything.
  bool get isActive => intensity > 0 || travel > 0;
}
