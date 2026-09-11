import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/benchmark/benchmark_frame_report.dart';
import 'package:glass_forge/src/benchmark/benchmark_gate.dart';
import 'package:glass_forge/src/benchmark/benchmark_run_mode.dart';
import 'package:glass_forge/src/benchmark/frame_time_stats.dart';
import 'package:glass_forge/src/benchmark/scene_budget.dart';

/// A report where build and raster each read exactly one fixed value at
/// every percentile -- `FrameTimeStats.of` over one sample reports that
/// sample as every percentile, which is the simplest way to pin an exact,
/// known value for the gate to compare against a budget.
BenchmarkFrameReport _report({
  required int buildMs,
  required int rasterMs,
  BenchmarkRunMode mode = BenchmarkRunMode.profile,
}) {
  final build = FrameTimeStats.of([Duration(milliseconds: buildMs)]);
  final raster = FrameTimeStats.of([Duration(milliseconds: rasterMs)]);
  return BenchmarkFrameReport(
    sceneId: 'scene',
    runMode: mode,
    build: build,
    raster: raster,
    total: raster,
  );
}

const _budget = SceneBudget(
  sceneId: 'scene',
  rasterP90Ms: 16,
  rasterP99Ms: 20,
  buildP90Ms: 8,
);

void main() {
  test('a report comfortably under budget passes clean', () {
    final result = BenchmarkGate.evaluate(
      _report(buildMs: 3, rasterMs: 5),
      _budget,
    );

    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
    expect(result.skippedUntrustworthy, isFalse);
  });

  test('exceeding raster p90 alone reports exactly that one violation', () {
    // build (5ms, budget 8) and raster p99 (17ms, budget 20) both still
    // pass; only raster p90 (17ms, budget 16) is over.
    final result = BenchmarkGate.evaluate(
      _report(buildMs: 5, rasterMs: 17),
      _budget,
    );

    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    final violation = result.violations.single;
    expect(violation.metric, 'raster p90');
    expect(violation.actualMs, 17);
    expect(violation.budgetMs, 16);
    expect(violation.overshootMs, closeTo(1, 1e-9));
  });

  test('exceeding every budget line reports all three', () {
    final result = BenchmarkGate.evaluate(
      _report(buildMs: 100, rasterMs: 100),
      _budget,
    );

    expect(result.passed, isFalse);
    expect(
      result.violations.map((v) => v.metric),
      containsAll(<String>['raster p90', 'raster p99', 'build p90']),
    );
  });

  test('a debug-mode report is skipped, not silently passed', () {
    // The premise this test protects: skippedUntrustworthy must be checked
    // independently of violations, because a caller that only looked at
    // `violations.isEmpty` would read this as a clean pass.
    final result = BenchmarkGate.evaluate(
      _report(buildMs: 1000, rasterMs: 1000, mode: BenchmarkRunMode.debug),
      _budget,
    );

    expect(result.skippedUntrustworthy, isTrue);
    expect(result.violations, isEmpty);
    expect(result.passed, isFalse);
  });

  test('a mismatched scene id between report and budget asserts', () {
    final mismatched = SceneBudget(
      sceneId: 'a_different_scene',
      rasterP90Ms: _budget.rasterP90Ms,
      rasterP99Ms: _budget.rasterP99Ms,
      buildP90Ms: _budget.buildP90Ms,
    );

    expect(
      () => BenchmarkGate.evaluate(
        _report(buildMs: 1, rasterMs: 1),
        mismatched,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
