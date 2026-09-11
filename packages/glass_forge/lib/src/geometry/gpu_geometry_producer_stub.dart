import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// Web substitute for the real `GpuGeometryProducer`.
///
/// `package:flutter_gpu`'s `external` members are not valid for dart2js —
/// `flutter build web` fails outright the moment anything in the dependency
/// graph imports that package, which is exactly what happened the first time
/// an app actually used `GlassLayer` (nothing had before). Web has no
/// `dart.library.io`, so `gpu_geometry_producer.dart`'s conditional export
/// resolves to this file instead of `gpu_geometry_producer_io.dart` there,
/// and `package:flutter_gpu` is never imported transitively on that
/// platform at all.
///
/// Always reports itself unavailable. `ProducerRegistry` and
/// `RenderGlassLayer` already treat "accelerated producer unavailable" as a
/// normal fall-through to the runtime-effect producer — the same path a
/// Skia (non-Impeller) consumer takes today — so a web consumer degrades
/// exactly the same way, and this producer is never actually selected there.
class GpuGeometryProducer implements GeometryProducer {
  /// Creates a producer.
  ///
  /// Takes no `debugBundleAssetKeys` — unlike the native implementation,
  /// there is no bundle to point at here. Nothing on web ever constructs
  /// this with one; only `register()`'s no-argument tear-off is used at
  /// runtime, and this file's tests never run on web.
  GpuGeometryProducer();

  /// Registers this producer as an accelerated option.
  ///
  /// Called from the same call site as the native implementation's
  /// `register()`, so a web build still calls it — it just never becomes
  /// [capabilities]-available.
  static void register() {
    ProducerRegistry.registerAccelerated(GpuGeometryProducer.new);
  }

  @override
  GeometryCapabilities get capabilities => const GeometryCapabilities(
    available: false,
    name: 'flutter-gpu (unsupported on web)',
  );

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}
