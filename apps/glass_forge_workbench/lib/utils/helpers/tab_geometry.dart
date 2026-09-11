import 'dart:ui';

/// The arithmetic behind a sliding selector: where it rests for a tab, which
/// tab a finger is over, and how much it stretches in flight.
///
/// Alignments are logical (start = -1, end = 1) and meant for
/// `AlignmentDirectional`, so RTL mirrors without a second code path.
abstract class TabGeometry {
  static double alignFor(int index, int count) =>
      count <= 1 ? 0 : index / (count - 1) * 2 - 1;

  /// The logical index of the tab under [localX] on a bar [width] wide.
  static int indexAt(
    double localX,
    double width,
    int count, {
    required bool rtl,
  }) {
    if (count <= 1 || width <= 0) return 0;
    final slot = (localX / (width / count)).floor().clamp(0, count - 1);
    return rtl ? count - 1 - slot : slot;
  }

  /// The alignment that keeps a selector centred under [localX], clamped to
  /// the first and last slot centres.
  static double alignAt(
    double localX,
    double width,
    int count, {
    required bool rtl,
  }) {
    if (count <= 1 || width <= 0) return 0;
    final slot = (localX / (width / count) - 0.5).clamp(0.0, count - 1.0);
    final logical = rtl ? count - 1 - slot : slot;
    return logical / (count - 1) * 2 - 1;
  }

  /// Scale for a selector moving at [velocity] alignment units per second.
  ///
  /// Stretches along its travel and thins across it, the way a drop of
  /// liquid does, then settles back to round as it slows. [squash] scales
  /// the effect: 0 is rigid.
  static Offset squashScale(double velocity, {required double squash}) {
    final t = (velocity.abs() / 10).clamp(0.0, 1.0) * squash;
    if (t == 0) return const Offset(1, 1);
    return Offset(1 + t * 0.35, 1 - t * 0.2);
  }
}
