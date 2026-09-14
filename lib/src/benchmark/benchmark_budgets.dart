import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/benchmark/scene_budget.dart';

/// The full set of committed per-scene budgets, keyed by scene id.
///
/// Loaded from a checked-in JSON file rather than hard-coded, so tightening
/// or relaxing a budget is a reviewable diff to data, not a change buried in
/// the harness's own source -- the whole point of a "regression gate" is
/// that changing what counts as a regression has to go through review too.
@immutable
class BenchmarkBudgets {
  /// Creates a budget set directly. Prefer [BenchmarkBudgets.fromJsonString]
  /// when reading `budgets.json`.
  const BenchmarkBudgets(this._budgets);

  /// Parses the checked-in budgets file.
  ///
  /// The file's shape is `{"scenes": [ {...SceneBudget...}, ... ]}`, plus an
  /// optional `"_provenance"` string field the schema ignores -- present in
  /// the shipped file to record where its numbers came from without every
  /// reader needing a side document to find out.
  factory BenchmarkBudgets.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'budgets.json: expected a JSON object at the top level.',
      );
    }
    final scenes = decoded['scenes'];
    if (scenes is! List) {
      throw const FormatException(
        'budgets.json: expected a "scenes" array.',
      );
    }
    final budgets = <String, SceneBudget>{};
    for (final entry in scenes) {
      if (entry is! Map) {
        throw const FormatException(
          'budgets.json: every entry in "scenes" must be an object.',
        );
      }
      final budget = SceneBudget.fromJson(Map<String, Object?>.from(entry));
      budgets[budget.sceneId] = budget;
    }
    return BenchmarkBudgets(budgets);
  }

  final Map<String, SceneBudget> _budgets;

  /// The budget for [sceneId], or null if none is committed yet.
  ///
  /// A missing budget is not a failure -- it means this scene has no
  /// regression gate yet, which a caller should report loudly rather than
  /// silently treat as a pass. See `BenchmarkGate`.
  SceneBudget? operator [](String sceneId) => _budgets[sceneId];

  /// Every scene id with a committed budget.
  Iterable<String> get sceneIds => _budgets.keys;
}
