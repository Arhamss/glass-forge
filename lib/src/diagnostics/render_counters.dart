import 'package:flutter/foundation.dart';

/// Counts the operations whose frequency is the point of this renderer.
///
/// These are assertions, not telemetry. "Does not re-rasterise while
/// scrolling" and "captures the backdrop once per layer" are behavioural
/// claims, and a golden image cannot check either — a frame that rebuilt its
/// matte forty times looks identical to one that rebuilt it never.
class GlassRenderCounters {
  GlassRenderCounters._();

  /// The shared instance.
  static final GlassRenderCounters instance = GlassRenderCounters._();

  int _matteProduceCount = 0;
  int _backdropPushCount = 0;
  int _passAssignmentCount = 0;

  /// How many mattes have been baked.
  int get matteProduceCount => _matteProduceCount;

  /// How many backdrop filters have been pushed.
  int get backdropPushCount => _backdropPushCount;

  /// How many times a layer has re-sorted its shapes into backdrop passes.
  ///
  /// Every run allocates and re-keys, and a pass that moves to a new key is
  /// at best carried over and at worst rebuilt with a fresh matte. Moving a
  /// shape, or animating what its pass renders with through a scope such as
  /// `GlassPresence`, is meant to cost none.
  int get passAssignmentCount => _passAssignmentCount;

  /// Records a matte bake.
  void recordMatteProduce() {
    if (kDebugMode) {
      _matteProduceCount++;
    }
  }

  /// Records a backdrop push.
  void recordBackdropPush() {
    if (kDebugMode) {
      _backdropPushCount++;
    }
  }

  /// Records one run of a layer's pass assignment.
  void recordPassAssignment() {
    if (kDebugMode) {
      _passAssignmentCount++;
    }
  }

  /// Resets every counter.
  void reset() {
    _matteProduceCount = 0;
    _backdropPushCount = 0;
    _passAssignmentCount = 0;
  }
}
