import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';

/// Everything the engine copies into a native `ImageFilter` when it first
/// converts one.
///
/// A shader's uniforms are copied at conversion time, not read live, so a
/// cached filter is only valid while these values are unchanged. Compare
/// snapshots before rebuilding: upstream rebuilds the filter every paint,
/// which is both wasteful and the reason it cannot carry ancestor translation
/// in uniforms without tripping flutter#138627.
@immutable
class FilterSnapshot {
  /// Creates a snapshot.
  ///
  /// Prefer [FilterSnapshot.of] to ensure [coordinateMapping] is defensively
  /// copied. This constructor stores the list as-is, so callers must not
  /// mutate it afterwards.
  FilterSnapshot({
    required this.texture,
    required this.matteBounds,
    required this.devicePixelRatio,
    required this.materialRevision,
    required Float32List coordinateMapping,
    required this.presence,
  }) : coordinateMapping = Float32List.fromList(coordinateMapping);

  /// Captures the current state.
  factory FilterSnapshot.of({
    required MatteGeneration? matte,
    required double devicePixelRatio,
    required int materialRevision,
    required Float32List coordinateMapping,
    required double presence,
  }) {
    return FilterSnapshot(
      texture: matte?.texture,
      matteBounds: matte?.bounds,
      devicePixelRatio: devicePixelRatio,
      materialRevision: materialRevision,
      coordinateMapping: Float32List.fromList(coordinateMapping),
      presence: presence,
    );
  }

  /// The matte texture bound as a sampler, if any.
  final ui.Image? texture;

  /// Where that matte sits, in layer-local physical pixels.
  final Rect? matteBounds;

  /// Physical pixels per logical pixel.
  final double devicePixelRatio;

  /// Bumped whenever the material's uniforms change.
  final int materialRevision;

  /// The affine that maps `FlutterFragCoord` into matte space:
  /// `[a,b,c,d,tx,ty]`.
  final Float32List coordinateMapping;

  /// How present this pass's glass is, 0 to 1. See `GlassPresence`.
  final double presence;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FilterSnapshot &&
        identical(other.texture, texture) &&
        other.matteBounds == matteBounds &&
        other.devicePixelRatio == devicePixelRatio &&
        other.materialRevision == materialRevision &&
        other.presence == presence &&
        _sameMapping(other.coordinateMapping, coordinateMapping);
  }

  @override
  int get hashCode => Object.hash(
        texture,
        matteBounds,
        devicePixelRatio,
        materialRevision,
        presence,
        Object.hashAll(coordinateMapping),
      );

  static bool _sameMapping(Float32List a, Float32List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
