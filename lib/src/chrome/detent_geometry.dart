import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';

/// The sheet's shape at one height: how far it is inset, and how round it is.
///
/// Both are functions of [height] and nothing else — not of which detent is
/// current, and not of which detent is being travelled to. That is the
/// difference between a morph that tracks a finger and one that plays an
/// animation when a detent is reached: only the *snap* is discrete.
@immutable
class GlassDetentSheetMetrics {
  /// Creates metrics directly. [GlassDetentSheetMetrics.at] is the usual way.
  const GlassDetentSheetMetrics({
    required this.height,
    required this.gap,
    required this.bottomGap,
    required this.radius,
    required this.progress,
  });

  /// The metrics for a sheet [height] logical pixels tall.
  ///
  /// [lowest] and [top] are the resolved first and last detents, which is
  /// what the morph is measured between: a sheet whose detents are 0.1 and
  /// 1.0 floats fully at a tenth of the screen, not at zero.
  factory GlassDetentSheetMetrics.at({
    required double height,
    required double lowest,
    required double top,
    double gap = 12,
    double? bottomGap,
    double floatingRadius = 44,
    double flushRadius = 55,
  }) {
    final span = top - lowest;
    // A degenerate span means one detent. Flush is the right answer for it:
    // a sheet that cannot be dragged anywhere is not floating between
    // anything, and the alternative is NaN in a shader uniform.
    final progress = span > 0
        ? clampDouble((height - lowest) / span, 0, 1)
        : 1.0;
    return GlassDetentSheetMetrics(
      height: height,
      gap: lerpDouble(gap, 0, progress)!,
      bottomGap: lerpDouble(bottomGap ?? gap, 0, progress)!,
      radius: lerpDouble(floatingRadius, flushRadius, progress)!,
      progress: progress,
    );
  }

  /// How tall the sheet is, in logical pixels.
  final double height;

  /// How far the sheet is inset from the screen's **side** edges.
  final double gap;

  /// How far the sheet is inset from the screen's **bottom** edge.
  ///
  /// Separate from [gap] because the two are asked for by different things.
  /// The side inset is taste — how much of the backdrop shows past the
  /// sheet. The bottom one is a clearance: where the sheet floats over other
  /// glass chrome, it has to clear that chrome's whole height before their
  /// two backdrop passes would overlap, and a bar is usually taller than any
  /// side inset anyone wants. Driving both from one number means paying for
  /// that clearance twice in width — a 52pt bar needs 64pt of bottom gap and
  /// takes 128pt off the sheet's width to get it.
  final double bottomGap;

  /// The corner radius, on all four corners.
  final double radius;

  /// How far between the lowest detent (0) and the top one (1) this is.
  final double progress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GlassDetentSheetMetrics &&
        other.height == height &&
        other.gap == gap &&
        other.bottomGap == bottomGap &&
        other.radius == radius &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(height, gap, bottomGap, radius, progress);

  @override
  String toString() =>
      'GlassDetentSheetMetrics(height: $height, gap: $gap, '
      'bottomGap: $bottomGap, radius: $radius)';
}

/// Which of [heights] a sheet released at [height] with [velocity] belongs at.
///
/// The velocity is projected forward through [decay] first, so a flick lands
/// where the fling would have come to rest and then snaps from *there*. That
/// is why a hard flick carries past the nearest detent without any threshold
/// to tune: friction already encodes how far a given speed travels, and iOS
/// uses the same 0.135 retention factor for exactly this judgement.
///
/// [heights] must be ascending and non-empty — `resolveGlassDetents` returns
/// it that way. [height] is in logical pixels, increasing upward — a drag
/// upward raises it, a fling upward is positive velocity in pixels per
/// second.
int nearestDetentIndex(
  List<double> heights,
  double height, {
  double velocity = 0,
  GlassDecay decay = const GlassDecay(),
}) {
  assert(heights.isNotEmpty, 'a sheet with no detents has nowhere to go');
  final projected = velocity == 0
      ? height
      : decay.restingPoint(start: height, velocity: velocity);
  var best = 0;
  var bestDistance = (heights[0] - projected).abs();
  for (var i = 1; i < heights.length; i++) {
    final distance = (heights[i] - projected).abs();
    if (distance < bestDistance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}
