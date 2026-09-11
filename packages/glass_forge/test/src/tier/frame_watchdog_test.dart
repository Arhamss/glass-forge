import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/tier/frame_watchdog.dart';

const _budget = Duration(microseconds: 16667);

/// A frame that spent [rasterMicros] on the raster thread and [buildMicros]
/// on the UI thread.
///
/// `totalSpan` is the sum, which is what makes the "a slow build is not a
/// glass problem" test below meaningful: a frame can miss its budget overall
/// while its raster span is comfortably inside it.
ui.FrameTiming _frame({required int rasterMicros, int buildMicros = 1000}) {
  return ui.FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: buildMicros,
    rasterStart: buildMicros,
    rasterFinish: buildMicros + rasterMicros,
    rasterFinishWallTime: buildMicros + rasterMicros,
  );
}

ui.FrameTiming get _good => _frame(rasterMicros: 4000);
ui.FrameTiming get _bad => _frame(rasterMicros: 40000);

void _feed(FrameWatchdog watchdog, ui.FrameTiming frame, int count) {
  for (var i = 0; i < count; i++) {
    watchdog.recordTimings(<ui.FrameTiming>[frame]);
  }
}

/// A watchdog with round numbers, so every threshold below is arithmetic
/// rather than an approximation: a 100-frame window makes a miss count and a
/// miss ratio the same number. The degrade thresholds are the shipped
/// defaults — a tenth of the window for strained, three tenths for
/// saturated — because those are what the tests are about.
FrameWatchdog _watchdog({double recoveryRatio = 0.03}) {
  return FrameWatchdog(
    frameBudget: _budget,
    windowFrames: 100,
    recoveryRatio: recoveryRatio,
    recoveryFrames: 20,
  );
}

void main() {
  test('a window of frames inside budget is healthy', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);

    _feed(watchdog, _good, 100);

    expect(watchdog.value, FrameHealth.healthy);
    expect(watchdog.missRatio, 0);
  });

  test('withholds a verdict until it has seen enough frames', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);

    // Every frame so far has missed, but a handful of frames is what app
    // startup looks like on every device. Judging from them would pin a
    // perfectly capable phone to a low tier for the whole session.
    _feed(watchdog, _bad, 10);

    expect(watchdog.hasVerdict, isFalse);
    expect(watchdog.value, FrameHealth.healthy);

    _feed(watchdog, _bad, 30);

    expect(watchdog.hasVerdict, isTrue);
    expect(watchdog.value, FrameHealth.saturated);
  });

  test('degrades the moment a tenth of the window has missed, not before', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);

    _feed(watchdog, _good, 91);
    _feed(watchdog, _bad, 9);

    // 9 misses in 100 frames. Below the threshold, so nothing moves.
    expect(watchdog.value, FrameHealth.healthy);

    _feed(watchdog, _bad, 1);

    // The 100-frame window now holds 90 good and 10 bad: exactly a tenth,
    // which is the p90-over-budget condition expressed as a count.
    expect(watchdog.value, FrameHealth.strained);
  });

  test('a brief stutter inside a healthy window does not degrade anything', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);

    _feed(watchdog, _good, 100);
    _feed(watchdog, _bad, 5);

    expect(watchdog.missRatio, closeTo(0.05, 1e-9));
    expect(watchdog.value, FrameHealth.healthy);
  });

  test('drops straight to saturated rather than stepping through strained', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);

    _feed(watchdog, _good, 60);
    _feed(watchdog, _bad, 40);

    expect(watchdog.value, FrameHealth.saturated);
  });

  test(
    'a slow build with a fast raster is not counted as a missed frame',
    () {
      final watchdog = _watchdog();
      addTearDown(watchdog.dispose);

      // Well over budget in total, entirely on the UI thread. Degrading the
      // glass tier cannot speed up a slow build method, so treating this as
      // evidence against glass would make the app uglier for nothing.
      final slowBuild = _frame(rasterMicros: 3000, buildMicros: 60000);
      expect(slowBuild.totalSpan, greaterThan(_budget));

      _feed(watchdog, slowBuild, 100);

      expect(watchdog.value, FrameHealth.healthy);
    },
  );

  test(
    'recovery waits for a sustained clean run, not merely a clean window',
    () {
      // recoveryRatio 0 makes the clean run start exactly when the window
      // holds no missed frame at all, so the boundary below is arithmetic
      // rather than a guess.
      final watchdog = _watchdog(recoveryRatio: 0);
      addTearDown(watchdog.dispose);

      _feed(watchdog, _good, 90);
      _feed(watchdog, _bad, 10);
      expect(watchdog.value, FrameHealth.strained);

      // The ten bad frames are the newest in the ring, so they are the last
      // to be evicted: the window is not fully clean until 100 good frames
      // have gone through it. The clean run therefore reaches 1 on good
      // frame 100 and 20 on good frame 119.
      _feed(watchdog, _good, 99);
      expect(
        watchdog.value,
        FrameHealth.strained,
        reason: 'the window still holds a missed frame',
      );

      _feed(watchdog, _good, 19);
      expect(
        watchdog.value,
        FrameHealth.strained,
        reason: 'a fully clean window is not yet a sustained clean run',
      );

      _feed(watchdog, _good, 1);
      expect(watchdog.value, FrameHealth.healthy);
    },
  );

  test('climbs back one rung at a time', () {
    final watchdog = _watchdog(recoveryRatio: 0);
    addTearDown(watchdog.dispose);

    _feed(watchdog, _good, 60);
    _feed(watchdog, _bad, 40);
    expect(watchdog.value, FrameHealth.saturated);

    // 100 frames to flush the window, then 20 for the first clean run.
    _feed(watchdog, _good, 119);
    expect(watchdog.value, FrameHealth.strained);

    // The second rung has to be earned all over again, under the load the
    // first one just put back.
    _feed(watchdog, _good, 19);
    expect(watchdog.value, FrameHealth.strained);
    _feed(watchdog, _good, 1);
    expect(watchdog.value, FrameHealth.healthy);
  });

  test(
    'does not oscillate while the miss rate sits in the hysteresis band',
    () {
      final watchdog = _watchdog();
      addTearDown(watchdog.dispose);
      var notifications = 0;
      watchdog.addListener(() => notifications++);

      _feed(watchdog, _good, 90);
      _feed(watchdog, _bad, 10);
      expect(watchdog.value, FrameHealth.strained);
      expect(notifications, 1);

      // One miss in every twenty frames: a 5% miss rate, which is below the
      // 10% that degrades and above the 3% that starts a recovery run. A
      // watchdog without a band would flap between the two verdicts here
      // for as long as the pattern lasts.
      for (var i = 0; i < 500; i++) {
        final frame = i % 20 == 0 ? _bad : _good;
        watchdog.recordTimings(<ui.FrameTiming>[frame]);
      }

      expect(watchdog.value, FrameHealth.strained);
      expect(
        notifications,
        1,
        reason: 'the only notification should still be the original degrade',
      );
    },
  );

  test('notifies once per verdict change, not once per frame', () {
    final watchdog = _watchdog();
    addTearDown(watchdog.dispose);
    var notifications = 0;
    watchdog.addListener(() => notifications++);

    _feed(watchdog, _good, 100);
    expect(notifications, 0);

    // A whole window of misses passes through in one batch. The verdict
    // moves once (healthy -> saturated), even though 100 frames were folded
    // in and the intermediate arithmetic passed through `strained`.
    watchdog.recordTimings(List<ui.FrameTiming>.filled(100, _bad));

    expect(watchdog.value, FrameHealth.saturated);
    expect(notifications, 1);
  });

  test('rejects thresholds that leave no hysteresis band', () {
    expect(
      () => FrameWatchdog(recoveryRatio: 0.2),
      throwsA(isA<AssertionError>()),
    );
  });
}
