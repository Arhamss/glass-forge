import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';

/// What a spring is *for*, rather than what it is made of.
///
/// Surfaces name a role here instead of carrying their own [GlassMotion], so
/// that retuning one spring in a theme retunes every surface that uses it.
/// A designer who decides sheets are too slow changes
/// [GlassMotionDefaults.present] once.
enum GlassMotionRole {
  /// Runs under a finger that is still down.
  follow,

  /// Runs after the finger has gone.
  settle,

  /// Runs the press response.
  press,

  /// Runs a surface on and off screen.
  present,
}

/// The springs a theme hands out, one per [GlassMotionRole].
///
/// Every default here is the same value the motion layer already uses in its
/// own constructors — `InteractiveGlass` and `GlassMotionController` — and
/// that is not a coincidence to be maintained by hand: a test asserts the
/// two agree, so a theme that silently disagreed with the widget it themes
/// would fail the build.
///
/// Reduce Motion is deliberately **not** applied here. `GlassReduceMotion`
/// resolves it at the point a spring is actually driven, because the
/// accessibility contract is "no elastic properties", which is a statement
/// about simulations, not about configuration. A theme that pre-flattened
/// its springs would also silently discard the user's real motion
/// preferences the moment they turned the setting back off.
@immutable
class GlassMotionDefaults {
  /// Creates a set of springs. Naming one leaves the rest at the values the
  /// motion layer uses.
  const GlassMotionDefaults({
    this.follow = const GlassMotion.interactive(),
    this.settle = const GlassMotion.bouncy(),
    this.press = const GlassMotion.snappy(
      duration: Duration(milliseconds: 250),
      extraBounce: 0.1,
    ),
    this.present = const GlassMotion.smooth(
      duration: Duration(milliseconds: 400),
    ),
  });

  /// The spring for [GlassMotionRole.follow].
  final GlassMotion follow;

  /// The spring for [GlassMotionRole.settle].
  final GlassMotion settle;

  /// The spring for [GlassMotionRole.press].
  ///
  /// The spring into a press. The way back out is
  /// `InteractiveGlass.pressReleaseMotion`, which has no role of its own.
  final GlassMotion press;

  /// The spring for [GlassMotionRole.present].
  ///
  /// The one default with no counterpart in the motion layer, because
  /// nothing there presents anything yet. It does not overshoot: a sheet
  /// that springs past its detent and comes back reads as a mistake rather
  /// than as liveliness, and 400 ms is long enough for the eye to follow a
  /// screen-height travel.
  final GlassMotion present;

  /// The spring [role] resolves to.
  GlassMotion of(GlassMotionRole role) => switch (role) {
    GlassMotionRole.follow => follow,
    GlassMotionRole.settle => settle,
    GlassMotionRole.press => press,
    GlassMotionRole.present => present,
  };

  /// Returns a copy with the given fields replaced.
  GlassMotionDefaults copyWith({
    GlassMotion? follow,
    GlassMotion? settle,
    GlassMotion? press,
    GlassMotion? present,
  }) {
    return GlassMotionDefaults(
      follow: follow ?? this.follow,
      settle: settle ?? this.settle,
      press: press ?? this.press,
      present: present ?? this.present,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassMotionDefaults &&
        other.follow == follow &&
        other.settle == settle &&
        other.press == press &&
        other.present == present;
  }

  @override
  int get hashCode => Object.hash(follow, settle, press, present);
}
