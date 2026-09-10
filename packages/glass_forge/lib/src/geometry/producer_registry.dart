import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/null_geometry_producer.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';

/// How much geometry work a tier permits.
enum GeometryTier {
  /// Prefer the fastest available producer.
  accelerated,

  /// Use the portable runtime-effect producer.
  portable,

  /// Do not bake a matte at all.
  none,
}

/// Picks a producer for a tier, skipping any that cannot run here.
///
/// Selection is a runtime decision, not a compile-time one: a device under
/// thermal pressure can drop from accelerated to portable to none between
/// frames without the widget tree noticing.
abstract final class ProducerRegistry {
  static final List<GeometryProducer Function()> _accelerated =
      <GeometryProducer Function()>[];

  /// Registers an accelerated producer factory.
  ///
  /// The Flutter GPU producer registers itself here when it can initialise.
  static void registerAccelerated(GeometryProducer Function() factory) {
    _accelerated.add(factory);
  }

  /// Creates a producer for [tier].
  static GeometryProducer select({required GeometryTier tier}) {
    switch (tier) {
      case GeometryTier.none:
        return NullGeometryProducer();
      case GeometryTier.accelerated:
        for (final factory in _accelerated) {
          final candidate = factory();
          if (candidate.capabilities.available) {
            return candidate;
          }
          candidate.dispose();
        }
        return RuntimeGeometryProducer();
      case GeometryTier.portable:
        return RuntimeGeometryProducer();
    }
  }

  /// Clears registrations. Test-only.
  static void debugReset() => _accelerated.clear();
}
