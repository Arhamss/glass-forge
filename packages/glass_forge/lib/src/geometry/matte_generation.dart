import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';

/// An immutable baked matte.
///
/// Generations are never overwritten in place. A frame that has been submitted
/// to the compositor may still sample the texture it was built with, so a
/// geometry change allocates a new generation and the old one is released only
/// once nothing can reference it. Upstream mutates instead, and an expanding
/// shape visibly corrupts its stationary neighbours.
@immutable
class MatteGeneration {
  /// Creates a generation.
  const MatteGeneration({
    required this.texture,
    required this.bounds,
    required this.sceneRevision,
    required this.codec,
  });

  /// The baked matte.
  final ui.Image texture;

  /// The region [texture] covers, in **layer-local physical pixels**.
  ///
  /// Layer-local, never screen space: baking an ancestor transform in here
  /// would apply its scale once in the matte and again during compositing.
  final Rect bounds;

  /// The scene revision this was baked from.
  final int sceneRevision;

  /// How to read the channels back.
  final MatteCodec codec;

  /// A copy shifted by [delta], reusing the same texture.
  ///
  /// Used when every shape moved by the same amount: the pixels are still
  /// correct, only their placement changed.
  MatteGeneration translated(Offset delta) => MatteGeneration(
        texture: texture,
        bounds: bounds.shift(delta),
        sceneRevision: sceneRevision,
        codec: codec,
      );
}
