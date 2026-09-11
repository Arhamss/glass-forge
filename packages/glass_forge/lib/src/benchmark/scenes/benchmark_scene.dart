import 'package:flutter/widgets.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';

/// Which variable a `BenchmarkScene` isolates.
///
/// Grouping scenes by axis is what makes a regression legible: two scenes
/// that differ in exactly one of these values can be compared directly, and
/// a failing gate names the scene id, which names its axis, instead of
/// leaving "something got slower" to be diagnosed from scratch.
enum BenchmarkAxis {
  /// Number of shapes registered into one layer's scene.
  shapeCount,

  /// How many shapes are merged into one `GlassBlendGroup`.
  blendGroupSize,

  /// The area, in logical pixels, the baked matte has to cover.
  matteArea,

  /// Backdrop blur sigma (`GlassMaterial.frost`).
  frostSigma,

  /// Chromatic aberration on versus off.
  chromaticAberration,

  /// Which `GeometryProducer` bakes the matte.
  geometryProducer,
}

/// A single, repeatable rendering scene used to isolate one performance
/// variable.
///
/// [build] must be a pure function of the scene's own fields: no
/// randomness, no wall-clock reads, nothing that would make two runs of the
/// same scene produce different widget trees. That is what "repeatable"
/// means here -- a regression has to be attributable to a code change, not
/// to noise the scene itself introduced.
@immutable
class BenchmarkScene {
  /// Creates a scene.
  const BenchmarkScene({
    required this.id,
    required this.axis,
    required this.description,
    required this.tier,
    required this.build,
  });

  /// Stable identifier.
  ///
  /// Also the key `budgets.json` looks scenes up by, so renaming a scene is
  /// a `budgets.json` diff a reviewer sees, not a gate that silently stops
  /// applying to anything.
  final String id;

  /// Which variable this scene isolates.
  final BenchmarkAxis axis;

  /// One line, human-readable, printed alongside every report so a report
  /// is legible without cross-referencing the scene catalog.
  final String description;

  /// Which geometry producer [build] pins the layer to.
  ///
  /// Purely informational here -- [build] is what actually sets it on the
  /// `GlassLayer` it constructs. Every scene builder in
  /// `glass_benchmark_scenes.dart` reads this same value from one local
  /// `const` when constructing both fields, specifically so the two can
  /// never drift apart.
  final GeometryTier tier;

  /// Builds the widget tree this scene measures.
  final WidgetBuilder build;
}
