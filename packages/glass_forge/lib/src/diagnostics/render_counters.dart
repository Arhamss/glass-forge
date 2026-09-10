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

  /// How many mattes have been baked.
  int get matteProduceCount => _matteProduceCount;

  /// How many backdrop filters have been pushed.
  int get backdropPushCount => _backdropPushCount;

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

  /// Resets both counters.
  void reset() {
    _matteProduceCount = 0;
    _backdropPushCount = 0;
  }
}
