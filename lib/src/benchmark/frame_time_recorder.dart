import 'dart:ui' as ui;

import 'package:glass_forge/src/benchmark/benchmark_frame_report.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';
import 'package:glass_forge/src/benchmark/frame_time_stats.dart';

/// Reduces a stream of engine frame timings to rolling build/raster/total
/// percentiles.
///
/// Deliberately does not call `SchedulerBinding.instance.addTimingsCallback`
/// itself, and does not import `package:flutter/scheduler.dart` at all --
/// the caller (a benchmark runner driving a real device, or a test feeding
/// hand-built timings) owns that subscription and its lifetime. This class
/// only owns the arithmetic, which is what makes it testable with synthetic
/// data: `ui.FrameTiming` has a public constructor that exists specifically
/// for tests (see its own doc comment), so [recordFrameTimings] can be fed a
/// known distribution and the percentiles that come back can be asserted
/// exactly -- no widget pumped, no device involved, no raster thread ever
/// runs.
class FrameTimeRecorder {
  /// Creates a recorder.
  ///
  /// [windowSize] caps how many of the most recent frames are kept; once
  /// full, the oldest sample is dropped as a new one arrives. A benchmark
  /// scene runs for a fixed wall-clock window, not a fixed frame count, so
  /// this exists to bound memory on a very high refresh-rate display rather
  /// than to implement the windowing itself.
  FrameTimeRecorder({this.windowSize = 1000})
    : assert(windowSize > 0, 'windowSize must be positive');

  /// The maximum number of recent frames retained per metric.
  final int windowSize;

  final List<Duration> _build = <Duration>[];
  final List<Duration> _raster = <Duration>[];
  final List<Duration> _total = <Duration>[];

  /// Feeds a batch of engine-reported timings, in the same shape
  /// `SchedulerBinding.addTimingsCallback` delivers them.
  void recordFrameTimings(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      _push(_build, timing.buildDuration);
      _push(_raster, timing.rasterDuration);
      _push(_total, timing.totalSpan);
    }
  }

  void _push(List<Duration> window, Duration value) {
    window.add(value);
    if (window.length > windowSize) {
      window.removeAt(0);
    }
  }

  /// How many frames are currently held in the window.
  ///
  /// The same for every metric: one `ui.FrameTiming` always contributes to
  /// build, raster and total together, and [windowSize] is one shared cap
  /// applied identically to all three lists.
  int get sampleCount => _total.length;

  /// Reduces the current window to a report.
  ///
  /// Throws [StateError] if nothing has been recorded yet -- see
  /// `FrameTimeStats.of`'s own reasoning for why an empty window must never
  /// silently become a zero-cost report.
  BenchmarkFrameReport summarize({required String sceneId, String? notes}) {
    if (_total.isEmpty) {
      throw StateError(
        'FrameTimeRecorder.summarize() was called for "$sceneId" with zero '
        'frames recorded. A report built from no samples is not a '
        'measurement of "nothing costs anything" -- it is silence dressed '
        'up as a result. Make sure the scene actually produced frames '
        'while this recorder was listening.',
      );
    }
    return BenchmarkFrameReport(
      sceneId: sceneId,
      runMode: BenchmarkRunMode.current(),
      build: FrameTimeStats.of(_build),
      raster: FrameTimeStats.of(_raster),
      total: FrameTimeStats.of(_total),
      notes: notes,
    );
  }

  /// Clears every recorded sample.
  ///
  /// Used between scenes so one scene's tail frames cannot bleed into the
  /// next scene's percentiles when a single process measures several scenes
  /// in sequence.
  void reset() {
    _build.clear();
    _raster.clear();
    _total.clear();
  }
}
