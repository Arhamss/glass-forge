import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// Bakes nothing.
///
/// The cheapest tiers do not refract at all — they render a translucent fill
/// with a border. This is also the correct producer when the user has asked
/// to reduce transparency.
class NullGeometryProducer implements GeometryProducer {
  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'none');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}
