import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/benchmark/scenes/benchmark_backdrop.dart';
import 'package:glass_forge/src/benchmark/scenes/benchmark_scene.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// The fixed backdrop size every scene renders against.
///
/// Held constant on purpose: `BenchmarkAxis.matteArea` is the one family
/// that deliberately varies content size (the glass shape's own size, not
/// this), so keeping every other family's backdrop identical is what makes
/// their comparisons single-axis.
const Size _kSceneSize = Size(390, 700);

/// One shared starting point every axis changes exactly one field of.
const GlassMaterial _kBaselineMaterial = GlassMaterial(
  frost: 8,
  edgeRefraction: 20,
);

const BorderRadius _kCornerRadius = BorderRadius.all(Radius.circular(16));

Widget _shapeGrid(int count, {Size shapeSize = const Size(72, 72)}) {
  return Center(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Glass(
            shape: const GlassRoundedRectangle(radius: _kCornerRadius),
            child: SizedBox.fromSize(size: shapeSize),
          ),
      ],
    ),
  );
}

Widget _sceneWith({
  required GeometryTier tier,
  required GlassMaterial material,
  required Widget child,
}) {
  return AnimatedBenchmarkBackdrop(
    size: _kSceneSize,
    child: GlassLayer(material: material, tier: tier, child: child),
  );
}

BenchmarkScene _shapeCountScene(int count) {
  const tier = GeometryTier.portable;
  return BenchmarkScene(
    id: 'shape_count_$count',
    axis: BenchmarkAxis.shapeCount,
    description:
        '$count registered shapes in one layer, baseline material, '
        'runtime-effect producer.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial,
      child: _shapeGrid(count),
    ),
  );
}

BenchmarkScene _blendGroupScene(int size) {
  const tier = GeometryTier.portable;
  return BenchmarkScene(
    id: 'blend_group_$size',
    axis: BenchmarkAxis.blendGroupSize,
    description: '$size shapes merged into one GlassBlendGroup.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial,
      child: GlassBlendGroup(blend: 24, child: _shapeGrid(size)),
    ),
  );
}

BenchmarkScene _matteAreaScene(String label, Size shapeSize) {
  const tier = GeometryTier.portable;
  return BenchmarkScene(
    id: 'matte_area_$label',
    axis: BenchmarkAxis.matteArea,
    description:
        'One shape at ${shapeSize.width.round()}x'
        '${shapeSize.height.round()} logical px.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial,
      child: Center(
        child: Glass(
          shape: const GlassRoundedRectangle(radius: _kCornerRadius),
          child: SizedBox.fromSize(size: shapeSize),
        ),
      ),
    ),
  );
}

BenchmarkScene _frostSigmaScene(String label, double frost) {
  const tier = GeometryTier.portable;
  return BenchmarkScene(
    id: 'frost_sigma_$label',
    axis: BenchmarkAxis.frostSigma,
    description: 'One mid-sized shape, frost sigma $frost.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial.copyWith(frost: frost),
      child: const Center(
        child: Glass(
          shape: GlassRoundedRectangle(radius: _kCornerRadius),
          child: SizedBox.square(dimension: 160),
        ),
      ),
    ),
  );
}

BenchmarkScene _chromaticAberrationScene({required bool on}) {
  const tier = GeometryTier.portable;
  final label = on ? 'on' : 'off';
  return BenchmarkScene(
    id: 'chromatic_aberration_$label',
    axis: BenchmarkAxis.chromaticAberration,
    description: 'One mid-sized shape, chromatic aberration $label.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial.copyWith(
        chromaticAberration: on ? 4 : 0,
      ),
      child: const Center(
        child: Glass(
          shape: GlassRoundedRectangle(radius: _kCornerRadius),
          child: SizedBox.square(dimension: 160),
        ),
      ),
    ),
  );
}

BenchmarkScene _geometryProducerScene(GeometryTier tier) {
  return BenchmarkScene(
    id: 'geometry_producer_${tier.name}',
    axis: BenchmarkAxis.geometryProducer,
    description:
        '4 shapes baked by the ${tier.name} geometry producer -- on a '
        'device without Flutter GPU, "accelerated" falls back to the '
        'runtime-effect producer, so compare the raw numbers against the '
        'device that produced them, not against this scene in isolation.',
    tier: tier,
    build: (context) => _sceneWith(
      tier: tier,
      material: _kBaselineMaterial,
      child: _shapeGrid(4),
    ),
  );
}

/// Every benchmark scene this package ships, grouped by axis.
///
/// Each scene changes exactly one field relative to its family's shared
/// baseline -- see the private builders above -- so a budget regression on
/// one scene id points at one cause, which is the entire reason this
/// harness exists rather than one big "does glass_forge feel fast" number.
List<BenchmarkScene> get glassBenchmarkScenes {
  return List.unmodifiable(
    <BenchmarkScene>[
      for (final count in const <int>[1, 4, kMaxShapes])
        _shapeCountScene(count),
      for (final size in const <int>[2, 4, kMaxShapes]) _blendGroupScene(size),
      _matteAreaScene('small', const Size(48, 48)),
      _matteAreaScene('medium', const Size(160, 160)),
      _matteAreaScene('large', const Size(320, 600)),
      _frostSigmaScene('off', 0),
      _frostSigmaScene('default', 8),
      _frostSigmaScene('heavy', 24),
      _chromaticAberrationScene(on: false),
      _chromaticAberrationScene(on: true),
      _geometryProducerScene(GeometryTier.accelerated),
      _geometryProducerScene(GeometryTier.portable),
    ],
  );
}
