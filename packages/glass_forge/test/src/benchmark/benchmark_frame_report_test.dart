import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/benchmark_frame_report.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';
import 'package:glass_forge/src/benchmark/frame_time_stats.dart';

void main() {
  final stats = FrameTimeStats.of(const [Duration(milliseconds: 4)]);

  test('a trustworthy report prints no warning banner', () {
    final report = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.profile,
      build: stats,
      raster: stats,
      total: stats,
    );

    expect(report.toHumanReadable(), isNot(contains('DEBUG BUILD')));
  });

  test('a debug report always prints the warning, even with no caller '
      'checking runMode first', () {
    // This is the property that matters: the banner is inside the string
    // the caller prints, not a separate thing the caller has to remember to
    // check and prepend.
    final report = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.debug,
      build: stats,
      raster: stats,
      total: stats,
    );

    expect(report.toHumanReadable(), contains('DEBUG BUILD'));
  });

  test('toJson carries trustworthy as an explicit boolean', () {
    final trustworthy = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.release,
      build: stats,
      raster: stats,
      total: stats,
    );
    final untrustworthy = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.debug,
      build: stats,
      raster: stats,
      total: stats,
    );

    expect(trustworthy.toJson()['trustworthy'], isTrue);
    expect(untrustworthy.toJson()['trustworthy'], isFalse);
  });

  test('notes are carried through when present, omitted when not', () {
    final withNotes = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.profile,
      build: stats,
      raster: stats,
      total: stats,
      notes: 'why this scene exists',
    );
    final withoutNotes = BenchmarkFrameReport(
      sceneId: 'scene',
      runMode: BenchmarkRunMode.profile,
      build: stats,
      raster: stats,
      total: stats,
    );

    expect(withNotes.toJson()['notes'], 'why this scene exists');
    expect(withoutNotes.toJson().containsKey('notes'), isFalse);
  });
}
