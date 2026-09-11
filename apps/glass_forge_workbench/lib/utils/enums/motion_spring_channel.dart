/// Which of `InteractiveGlass`'s three springs the sliders are editing.
///
/// Three separate springs rather than one, because they run at different
/// moments and want different numbers: the one under the finger has to
/// feel attached, the one after it has to feel alive, and the press has to
/// answer before you have finished pressing.
enum MotionSpringChannel {
  /// Runs while a pointer is down.
  follow,

  /// Runs once the pointer has gone.
  settle,

  /// Runs the press response.
  press,
}

/// Labels and copy for [MotionSpringChannel].
extension MotionSpringChannelX on MotionSpringChannel {
  /// The label on the segmented control.
  String get label => switch (this) {
    MotionSpringChannel.follow => 'Follow',
    MotionSpringChannel.settle => 'Settle',
    MotionSpringChannel.press => 'Press',
  };

  /// When this spring runs, and what it is trying to do.
  String get blurb => switch (this) {
    MotionSpringChannel.follow =>
      'Runs under the finger. Short: at 150 ms the surface reads as '
          'attached to the pointer instead of chasing it.',
    MotionSpringChannel.settle =>
      'Runs after you let go. The one you feel most, and the only one '
          'worth any real bounce.',
    MotionSpringChannel.press =>
      'Runs the press response. A press on glass should read as the '
          'surface settling towards the layer, not as a button shrinking.',
  };
}
