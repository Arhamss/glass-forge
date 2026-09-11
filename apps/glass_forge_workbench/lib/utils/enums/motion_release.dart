/// What happens to the specimen when you let go of it.
enum MotionRelease {
  /// The spring carries it back to where it was laid out.
  springsHome,

  /// Friction carries it until it stops, and it stays there.
  fliesFree,
}

/// Labels and copy for [MotionRelease].
extension MotionReleaseX on MotionRelease {
  /// The label on the segmented control.
  String get label => switch (this) {
    MotionRelease.springsHome => 'Springs home',
    MotionRelease.fliesFree => 'Flies free',
  };

  /// What to expect after the throw.
  String get blurb => switch (this) {
    MotionRelease.springsHome =>
      'The release spring takes the fling velocity as its own, so a hard '
          'throw overshoots home and comes back.',
    MotionRelease.fliesFree =>
      'Nothing to come back to. Friction ends the throw wherever it ends '
          'it, which is the one thing motor cannot do: its controller '
          'assumes everything is heading somewhere.',
  };
}
