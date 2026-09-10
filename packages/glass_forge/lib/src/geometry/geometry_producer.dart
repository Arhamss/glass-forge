import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

/// What a producer can do on this device.
@immutable
class GeometryCapabilities {
  /// Creates a capability report.
  const GeometryCapabilities({required this.available, required this.name});

  /// Whether this producer can run here at all.
  ///
  /// False is a normal answer, not an error: Flutter GPU is unavailable on
  /// Skia, on older Flutter, and when its shader bundle did not build. The
  /// registry falls through to the next producer and the caller never knows.
  final bool available;

  /// A short name for diagnostics.
  final String name;
}

/// Everything a producer needs that is not the scene itself.
@immutable
class MatteRequest {
  /// Creates a request.
  const MatteRequest({
    required this.devicePixelRatio,
    required this.maxDisplacement,
    required this.edgeRefraction,
    required this.refractionSpread,
    required this.antialiasWidth,
  });

  /// Physical pixels per logical pixel.
  final double devicePixelRatio;

  /// The displacement range the codec covers, in physical pixels.
  final double maxDisplacement;

  /// Peak edge displacement, in physical pixels.
  final double edgeRefraction;

  /// How far the band reaches inward. 0 is a tight edge band.
  final double refractionSpread;

  /// Half-width of the coverage ramp, in physical pixels.
  ///
  /// Computed from the transform basis rather than `fwidth`, which is
  /// unavailable in runtime effects even on Impeller.
  final double antialiasWidth;
}

/// Bakes a scene into a matte.
abstract interface class GeometryProducer {
  /// What this producer can do here.
  GeometryCapabilities get capabilities;

  /// Loads whatever this producer needs before its first [produce].
  Future<void> warmUp();

  /// Bakes [scene]. Returns null when there is nothing to bake.
  MatteGeneration? produce(GlassScene scene, MatteRequest request);

  /// Releases a generation this producer created.
  void release(MatteGeneration generation);

  /// Releases everything.
  void dispose();
}
