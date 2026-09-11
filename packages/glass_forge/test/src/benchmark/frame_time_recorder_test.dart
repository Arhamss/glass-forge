import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';
import 'package:glass_forge/src/benchmark/frame_time_recorder.dart';

/// Builds a real `ui.FrameTiming` from build/raster durations in
/// milliseconds. `ui.FrameTiming`'s constructor exists specifically for
/// tests (see its own doc comment in the engine) -- this is not a stand-in
/// for the real type, it is the real type, fed a known distribution.
ui.FrameTiming _timing({
  required int buildMs,
  required int rasterMs,
  int startMs = 0,
}) {
  final vsync = startMs * 1000;
  final buildStart = vsync;
  final buildFinish = buildStart + buildMs * 1000;
  final rasterStart = buildFinish;
  final rasterFinish = rasterStart + rasterMs * 1000;
  return ui.FrameTiming(
    vsyncStart: vsync,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
  );
}

void main() {
  test('summarize throws when nothing has been recorded', () {
    final recorder = FrameTimeRecorder();
    expect(
      () => recorder.summarize(sceneId: 'empty'),
      throwsA(isA<StateError>()),
    );
  });

  test('recovers the expected percentiles from a known distribution', () {
    final recorder = FrameTimeRecorder()
      ..recordFrameTimings([
        for (var raster = 1; raster <= 10; raster++)
          _timing(buildMs: 2, rasterMs: raster),
      ]);

    final report = recorder.summarize(sceneId: 'scene');

    expect(report.sceneId, 'scene');
    // Same nearest-rank formula as FrameTimeStats's own test: 1..10ms ->
    // p50 at index 4 (5ms), p90 at index 8 (9ms), p99 and worst at 10ms.
    expect(report.raster.p50, const Duration(milliseconds: 5));
    expect(report.raster.p90, const Duration(milliseconds: 9));
    expect(report.raster.p99, const Duration(milliseconds: 10));
    expect(report.raster.worst, const Duration(milliseconds: 10));
    // build was a constant 2ms on every frame, so every percentile agrees.
    expect(report.build.p50, const Duration(milliseconds: 2));
    expect(report.build.worst, const Duration(milliseconds: 2));
    // total = build + raster on this synthetic timeline.
    expect(report.total.worst, const Duration(milliseconds: 12));
  });

  test('the window drops the oldest samples once full', () {
    final recorder = FrameTimeRecorder(windowSize: 3);
    for (final rasterMs in [1, 2, 3, 4, 5]) {
      recorder.recordFrameTimings([_timing(buildMs: 0, rasterMs: rasterMs)]);
    }

    expect(recorder.sampleCount, 3);
    final report = recorder.summarize(sceneId: 'windowed');
    // Only [3, 4, 5]ms should remain. p50 = ceil(0.5*3)=2 -> index 1 = 4ms.
    expect(report.raster.p50, const Duration(milliseconds: 4));
    expect(report.raster.worst, const Duration(milliseconds: 5));
  });

  test('reset clears the window entirely', () {
    final recorder = FrameTimeRecorder()
      ..recordFrameTimings([_timing(buildMs: 1, rasterMs: 1)]);
    expect(recorder.sampleCount, 1);

    recorder.reset();

    expect(recorder.sampleCount, 0);
    expect(
      () => recorder.summarize(sceneId: 'reset'),
      throwsA(isA<StateError>()),
    );
  });

  test('a report carries the mode it was captured in', () {
    final recorder = FrameTimeRecorder()
      ..recordFrameTimings([_timing(buildMs: 1, rasterMs: 1)]);
    final report = recorder.summarize(sceneId: 'mode');

    // flutter_test always runs debug -- see benchmark_run_mode_test.dart for
    // why that is the one thing this suite can pin about current().
    expect(report.runMode, BenchmarkRunMode.debug);
    expect(report.runMode.isTrustworthy, isFalse);
  });
}
