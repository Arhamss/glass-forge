import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/benchmark/benchmark_frame_report.dart';
import 'package:glass_forge/src/benchmark/scene_budget.dart';

/// One metric that exceeded its committed budget.
@immutable
class BudgetViolation {
  /// Creates a violation record.
  const BudgetViolation({
    required this.metric,
    required this.actualMs,
    required this.budgetMs,
  });

  /// Which percentile, e.g. `"raster p90"`.
  final String metric;

  /// What was measured, in milliseconds.
  final double actualMs;

  /// What the committed budget allows, in milliseconds.
  final double budgetMs;

  /// How far over budget this metric landed, in milliseconds.
  double get overshootMs => actualMs - budgetMs;

  @override
  String toString() =>
      '$metric: ${actualMs.toStringAsFixed(2)}ms exceeds budget '
      '${budgetMs.toStringAsFixed(2)}ms '
      '(+${overshootMs.toStringAsFixed(2)}ms)';
}

/// The verdict for one scene against its budget.
@immutable
class BenchmarkGateResult {
  /// Creates a result.
  const BenchmarkGateResult({
    required this.sceneId,
    required this.violations,
    required this.skippedUntrustworthy,
  });

  /// The scene this verdict is for.
  final String sceneId;

  /// Every budget line this scene exceeded. Empty means no violations were
  /// found -- see [passed] for what that means combined with
  /// [skippedUntrustworthy].
  final List<BudgetViolation> violations;

  /// True when the underlying report's `BenchmarkRunMode` was not
  /// trustworthy (debug), so no real comparison was performed.
  ///
  /// [violations] is always empty in this case -- there is nothing to
  /// report a violation *of* -- which is exactly why this flag exists as a
  /// separate field instead of being folded into [passed]. A caller that
  /// only checks `violations.isEmpty` would read a skipped, unevaluated
  /// scene as a clean pass; a debug-mode number must never be presentable
  /// as evidence of anything, passing included.
  final bool skippedUntrustworthy;

  /// Whether this scene may be reported as passing.
  ///
  /// False whenever [skippedUntrustworthy] is true, regardless of
  /// [violations] -- an untrustworthy report has produced no verdict at
  /// all, and "no verdict" is not the same thing as "passed".
  bool get passed => !skippedUntrustworthy && violations.isEmpty;
}

/// Compares a captured report against its committed budget.
abstract final class BenchmarkGate {
  /// Evaluates [report] against [budget].
  ///
  /// `report.sceneId` and `budget.sceneId` must match -- callers look a
  /// budget up by the report's own scene id (see `BenchmarkBudgets`), so a
  /// mismatch here means the caller wired the wrong pair together, which is
  /// a bug worth an assertion rather than a silently wrong comparison.
  static BenchmarkGateResult evaluate(
    BenchmarkFrameReport report,
    SceneBudget budget,
  ) {
    assert(
      report.sceneId == budget.sceneId,
      'evaluate() was given a report for "${report.sceneId}" and a budget '
      'for "${budget.sceneId}" -- these must be the same scene.',
    );

    if (!report.runMode.isTrustworthy) {
      return BenchmarkGateResult(
        sceneId: report.sceneId,
        violations: const <BudgetViolation>[],
        skippedUntrustworthy: true,
      );
    }

    final violations = <BudgetViolation>[];
    void check(String metric, double actualMs, double budgetMs) {
      if (actualMs > budgetMs) {
        violations.add(
          BudgetViolation(
            metric: metric,
            actualMs: actualMs,
            budgetMs: budgetMs,
          ),
        );
      }
    }

    check(
      'raster p90',
      report.raster.p90.inMicroseconds / 1000,
      budget.rasterP90Ms,
    );
    check(
      'raster p99',
      report.raster.p99.inMicroseconds / 1000,
      budget.rasterP99Ms,
    );
    check(
      'build p90',
      report.build.p90.inMicroseconds / 1000,
      budget.buildP90Ms,
    );

    return BenchmarkGateResult(
      sceneId: report.sceneId,
      violations: violations,
      skippedUntrustworthy: false,
    );
  }
}
