import 'package:flutter/foundation.dart';

/// The frame-time ceilings one benchmark scene must stay under.
///
/// Values are milliseconds, matching `FrameTimeStats.toJson`'s units, so a
/// budget and a report line up field-for-field without a unit conversion in
/// between -- one more place a regression could otherwise hide.
@immutable
class SceneBudget {
  /// Creates a budget.
  const SceneBudget({
    required this.sceneId,
    required this.rasterP90Ms,
    required this.rasterP99Ms,
    required this.buildP90Ms,
  });

  /// Reads a budget from a decoded JSON object.
  ///
  /// Throws [FormatException] rather than a bare cast failure when a field
  /// is missing or the wrong type, so a malformed `budgets.json` names the
  /// scene and the field it failed on instead of an opaque `type '_Map' is
  /// not a subtype`.
  factory SceneBudget.fromJson(Map<String, Object?> json) {
    final sceneId = json['sceneId'];
    if (sceneId is! String) {
      throw const FormatException(
        'SceneBudget.fromJson: "sceneId" must be a string.',
      );
    }
    double field(String name) {
      final value = json[name];
      if (value is num) {
        return value.toDouble();
      }
      throw FormatException(
        'SceneBudget.fromJson("$sceneId"): "$name" must be a number.',
      );
    }

    return SceneBudget(
      sceneId: sceneId,
      rasterP90Ms: field('rasterP90Ms'),
      rasterP99Ms: field('rasterP99Ms'),
      buildP90Ms: field('buildP90Ms'),
    );
  }

  /// The `BenchmarkScene.id` this budget applies to.
  final String sceneId;

  /// Ceiling for raster-thread p90, in milliseconds.
  final double rasterP90Ms;

  /// Ceiling for raster-thread p99, in milliseconds.
  final double rasterP99Ms;

  /// Ceiling for UI-thread build p90, in milliseconds.
  final double buildP90Ms;

  /// This budget as a JSON-encodable map.
  Map<String, Object?> toJson() => <String, Object?>{
    'sceneId': sceneId,
    'rasterP90Ms': rasterP90Ms,
    'rasterP99Ms': rasterP99Ms,
    'buildP90Ms': buildP90Ms,
  };
}
