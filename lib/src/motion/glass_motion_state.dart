import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One frame of a glass surface's live deformation.
///
/// [velocity] is a first-class part of the state rather than something a
/// consumer differentiates out of successive [translation]s. Squash and
/// stretch is derived from it (see `GlassJiggle`), and a finite difference of
/// positions would lag the real velocity by half a frame, go to zero at the
/// exact moment the surface is moving fastest through its rest point, and
/// quantise badly at 120 Hz.
@immutable
class GlassMotionState {
  /// Creates a state.
  const GlassMotionState({
    required this.translation,
    required this.velocity,
    required this.press,
    this.pressAnchor = Offset.zero,
  });

  /// A surface at rest, unpressed, at its origin.
  static const GlassMotionState rest = GlassMotionState(
    translation: Offset.zero,
    velocity: Offset.zero,
    press: 0,
  );

  /// Displacement from the surface's laid-out position, in logical pixels.
  final Offset translation;

  /// Current speed, in logical pixels per second.
  final Offset velocity;

  /// Press depth: `0` released, `1` fully pressed.
  final double press;

  /// Where the finger is, relative to the surface's centre, in logical
  /// pixels.
  ///
  /// [Offset.zero] when nothing is touching it. Scaled by [press] wherever
  /// it is used, so it ramps in and out on the press spring rather than
  /// snapping.
  final Offset pressAnchor;

  /// Whether this is the resting state, exactly.
  bool get isAtRest =>
      translation == Offset.zero &&
      velocity == Offset.zero &&
      press == 0 &&
      pressAnchor == Offset.zero;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassMotionState &&
        other.translation == translation &&
        other.velocity == velocity &&
        other.press == press &&
        other.pressAnchor == pressAnchor;
  }

  @override
  int get hashCode => Object.hash(translation, velocity, press, pressAnchor);

  @override
  String toString() =>
      'GlassMotionState($translation, v: $velocity, press: $press, '
      'anchor: $pressAnchor)';
}
