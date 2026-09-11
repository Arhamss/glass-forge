import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/gpu_geometry_producer.dart';
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

  static bool _registered = false;

  /// Registers an accelerated producer factory.
  ///
  /// The Flutter GPU producer registers itself here when it can initialise.
  static void registerAccelerated(GeometryProducer Function() factory) {
    _accelerated.add(factory);
  }

  /// Registers the accelerated producers this package ships, exactly once
  /// per process.
  ///
  /// This is the one place that names [GpuGeometryProducer]; neither
  /// `GlassLayer` nor anything else a consumer can see mentions it, so the
  /// accelerated path arrives without anyone asking for it. `register()`
  /// only appends a factory to a list — it constructs and probes nothing —
  /// so this cannot throw. The `try`/`catch` is defensive redundancy, not a
  /// load-bearing guard: registration itself must never be able to break a
  /// consumer's first frame.
  ///
  /// Both entry points that need the list populated call this — producer
  /// selection and the tier engine's capability probe — because the tier
  /// engine can run before any `GlassLayer` exists, and a probe that
  /// reported "no accelerated producer" purely because nothing had built a
  /// layer yet would pin the device to a lower tier for the rest of the
  /// session.
  static void ensureAcceleratedRegistered() {
    if (_registered) {
      return;
    }
    _registered = true;
    try {
      GpuGeometryProducer.register();
    } on Object catch (error) {
      debugPrint(
        'glass_forge: registering the Flutter GPU geometry producer failed '
        '($error). The runtime-effect producer remains available.',
      );
    }
  }

  /// The name of the first accelerated producer that can run here, or null
  /// when none can.
  ///
  /// Answers the tier engine's "is real acceleration available?" from the
  /// same capability reports [select] uses, rather than re-probing the GPU
  /// context alongside them. `GpuGeometryProducer` caches its context probe
  /// process-wide, so asking here and asking again at selection costs one
  /// probe between them.
  ///
  /// Constructs each candidate because [GeometryCapabilities] is an instance
  /// getter, and disposes it again immediately: a candidate built only to be
  /// asked a question owns no textures yet, so this is a construction and a
  /// field read, not GPU work.
  static String? probeAccelerated() {
    ensureAcceleratedRegistered();
    for (final factory in _accelerated) {
      final candidate = factory();
      final capabilities = candidate.capabilities;
      candidate.dispose();
      if (capabilities.available) {
        return capabilities.name;
      }
    }
    return null;
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
  static void debugReset() {
    _accelerated.clear();
    _registered = false;
  }

  /// How many accelerated producer factories are currently registered.
  /// Test-only.
  @visibleForTesting
  static int get debugAcceleratedCount => _accelerated.length;
}
