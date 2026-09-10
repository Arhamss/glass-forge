import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// The allocation granularity for backdrop clip bounds and matte textures.
///
/// Backdrop image filters allocate an offscreen Impeller render target sized
/// to their clip bounds. Without bucketing, a slow animated transform yields a
/// differently sized target on nearly every frame, so the target is
/// reallocated every frame for no visual benefit.
const int kDefaultBucket = 64;

/// Snaps a logical coordinate to a whole device pixel.
///
/// Uses `floor(x + 0.5)` rather than `round()` on purpose: `round()` rounds
/// halves away from zero, so a matte that straddles the origin changes size by
/// one pixel as it crosses it.
double snapToPixel(double logical, double devicePixelRatio) {
  return (logical * devicePixelRatio + 0.5).floorToDouble();
}

/// Rounds [value] up to the next multiple of [bucket].
int bucketDimension(int value, {int bucket = kDefaultBucket}) {
  if (value <= 0) {
    return 0;
  }
  return ((value + bucket - 1) ~/ bucket) * bucket;
}

/// Expands [rect] so its size falls on bucket boundaries.
///
/// The origin is floored and the size is grown; the result always contains the
/// input, so nothing is clipped by the rounding.
Rect expandToPixelBuckets(Rect rect, {int bucket = kDefaultBucket}) {
  if (rect.isEmpty) {
    return Rect.zero;
  }
  final left = rect.left.floorToDouble();
  final top = rect.top.floorToDouble();
  final width = bucketDimension(
    math.max(1, (rect.right - left).ceil()),
    bucket: bucket,
  );
  final height = bucketDimension(
    math.max(1, (rect.bottom - top).ceil()),
    bucket: bucket,
  );
  return Rect.fromLTWH(left, top, width.toDouble(), height.toDouble());
}
