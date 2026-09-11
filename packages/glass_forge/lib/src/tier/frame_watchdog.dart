import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// How saturated the frame pipeline looks.
///
/// Deliberately not a millisecond figure. `rasterDuration` ends at
/// `DrawToSurfaceUnsafe`, which is command-buffer encode and submit — not GPU
/// execution — so GPU cost never appears as a duration at all. It appears as
/// backpressure: the next frame's drawable acquisition stalls and `totalSpan`
/// creeps past budget. Flutter's own tracking issue (#136493) says the same
/// thing: the GPU cannot be measured here except indirectly. So this is a
/// saturation verdict, and anything that reads it as "the GPU took N ms" is
/// reading it wrong.
enum FrameHealth {
  /// Frames are landing inside budget.
  healthy,

  /// Frames are missing budget often enough to notice.
  strained,

  /// The pipeline is not keeping up.
  saturated,
}

/// Watches real frame timings and reports whether the app is keeping up.
///
/// Two properties matter more than the thresholds:
///
/// **It must not oscillate.** A tier that drops on a stutter and climbs back
/// on the next quiet second produces visible popping, which is worse than
/// either tier. So degradation is immediate and recovery is slow and banded:
/// the ratio has to fall well below the level that triggered the degrade
/// ([recoveryRatio], a fraction of [strainedRatio]) and stay there for
/// [recoveryFrames] frames, and recovery then climbs one step at a time.
///
/// **It must not itself cost anything per frame.** The window is a
/// preallocated [Uint8List] ring and the miss count is maintained
/// incrementally, so recording a frame is a compare, two array writes and an
/// integer add — no allocation, no sorting, no growth. That matters because
/// a p90 computed the obvious way (sort the window) would be `O(n log n)` on
/// every frame, and a watchdog whose own cost shows up in the timings it
/// watches is a feedback loop, not a measurement.
///
/// The "ratio of frames over budget" test *is* the p90 test, which is why it
/// can be `O(1)`: p90 of the window exceeds budget exactly when more than 10%
/// of the window exceeds budget. [strainedRatio] is that same 10%, expressed
/// in the form that can be maintained incrementally.
class FrameWatchdog extends ChangeNotifier
    implements ValueListenable<FrameHealth> {
  /// Creates a watchdog.
  ///
  /// [frameBudget] defaults to the display's own refresh period, read once at
  /// first use. Every other parameter exists so a test can drive the
  /// thresholds directly rather than by generating thousands of frames.
  FrameWatchdog({
    Duration? frameBudget,
    this.windowFrames = 90,
    this.strainedRatio = 0.10,
    this.saturatedRatio = 0.30,
    this.recoveryRatio = 0.03,
    this.recoveryFrames = 240,
  }) : assert(windowFrames > 0, 'the window needs at least one frame'),
       assert(
         recoveryRatio < strainedRatio,
         'recovery must be stricter than degradation, or the two thresholds '
         'meet and the health flips on a single frame',
       ),
       assert(
         strainedRatio < saturatedRatio,
         'saturated must be a harder verdict than strained',
       ),
       _budgetMicroseconds = frameBudget?.inMicroseconds,
       _window = Uint8List(windowFrames);

  /// How many recent frames the verdict is drawn from.
  final int windowFrames;

  /// The fraction of over-budget frames that counts as [FrameHealth.strained].
  final double strainedRatio;

  /// The fraction that counts as [FrameHealth.saturated].
  final double saturatedRatio;

  /// The fraction the window must fall back below before recovery can begin.
  ///
  /// Strictly below [strainedRatio]: the gap between them is the hysteresis
  /// band, and a window sitting inside it neither degrades nor recovers.
  final double recoveryRatio;

  /// How many consecutive frames must sit below [recoveryRatio] before the
  /// health climbs one step.
  final int recoveryFrames;

  final Uint8List _window;
  int _cursor = 0;
  int _filled = 0;
  int _missCount = 0;
  int _cleanRun = 0;
  int? _budgetMicroseconds;
  FrameHealth _health = FrameHealth.healthy;
  bool _attached = false;

  @override
  FrameHealth get value => _health;

  /// The fraction of the current window that missed budget.
  ///
  /// Exposed for diagnostics, not for decisions — the decision is [value],
  /// which carries the hysteresis this number does not.
  double get missRatio => _filled == 0 ? 0 : _missCount / _filled;

  /// Whether enough frames have been seen to judge.
  ///
  /// A third of the window. Judging from two frames would let app startup —
  /// which always misses — pin the tier for the whole session.
  bool get hasVerdict => _filled >= (windowFrames / 3).ceil();

  /// Starts observing real frames.
  void start() {
    if (_attached) {
      return;
    }
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(recordTimings);
  }

  /// Stops observing.
  void stop() {
    if (!_attached) {
      return;
    }
    _attached = false;
    SchedulerBinding.instance.removeTimingsCallback(recordTimings);
  }

  /// Records a batch of timings.
  ///
  /// Public because this is the whole testable surface: a test feeds
  /// synthetic timings and asserts the thresholds and the hysteresis, rather
  /// than trying to make a real device miss frames on cue.
  ///
  /// The engine batches these — roughly once a second in release, ~100 ms in
  /// debug — so this runs a handful of times a second over a short list, not
  /// inside the frame it is measuring.
  void recordTimings(List<ui.FrameTiming> timings) {
    if (timings.isEmpty) {
      return;
    }
    final budget = _budgetMicroseconds ??= _displayBudgetMicroseconds();
    var changed = false;
    for (final timing in timings) {
      // `rasterDuration`, not `totalSpan`, and the difference is the whole
      // decision this watchdog exists to make. Glass is a raster-thread and
      // GPU cost; a frame that blew its budget inside `build` is a slow
      // widget tree, and degrading the tier would make the app uglier
      // without making it faster. GPU backpressure does land here — the
      // stalled drawable acquisition happens *inside* the next frame's
      // raster span — so the one signal that responds to glass is also the
      // one that responds to the GPU.
      //
      // `totalSpan` is deliberately not OR-ed in. It could not fire on its
      // own anyway (`rasterStart >= vsyncStart`, so `rasterDuration` is
      // always the shorter of the two), and reading it as a second
      // condition would only add UI-thread cost to a raster-thread verdict.
      changed |= _record(
        missed: timing.rasterDuration.inMicroseconds > budget,
      );
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Folds one frame into the window and re-judges. Returns whether the
  /// verdict moved.
  bool _record({required bool missed}) {
    // Evict the frame this one replaces before counting it, so `_missCount`
    // always describes exactly the frames currently in the window.
    if (_filled == windowFrames) {
      _missCount -= _window[_cursor];
    } else {
      _filled++;
    }
    final bit = missed ? 1 : 0;
    _window[_cursor] = bit;
    _missCount += bit;
    _cursor = (_cursor + 1) % windowFrames;

    if (!hasVerdict) {
      return false;
    }

    final ratio = _missCount / _filled;
    final observed = ratio >= saturatedRatio
        ? FrameHealth.saturated
        : ratio >= strainedRatio
        ? FrameHealth.strained
        : FrameHealth.healthy;

    if (observed.index > _health.index) {
      // Degrade readily, and all the way to what was observed rather than
      // one step at a time: a device that is dropping a third of its frames
      // should not spend another window's worth of them at an intermediate
      // tier on the way down.
      _health = observed;
      _cleanRun = 0;
      return true;
    }

    if (ratio > recoveryRatio) {
      // Inside the hysteresis band, or still bad. Either way the clean run
      // is broken, and the health stays where it is.
      _cleanRun = 0;
      return false;
    }

    _cleanRun++;
    if (_cleanRun < recoveryFrames || _health == FrameHealth.healthy) {
      return false;
    }
    // One step at a time, and the counter restarts: climbing from saturated
    // to healthy costs two full clean runs, because the first step puts more
    // work back on the GPU and the second must be earned under that new load.
    _health = FrameHealth.values[_health.index - 1];
    _cleanRun = 0;
    return true;
  }

  /// The display's frame period, or 60 Hz when it cannot be read.
  int _displayBudgetMicroseconds() {
    const fallback = 16667;
    final view = ui.PlatformDispatcher.instance.implicitView;
    final rate = view?.display.refreshRate ?? 0;
    if (rate <= 0 || !rate.isFinite) {
      return fallback;
    }
    return (1000000 / rate).round();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
