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
  ///
  /// [isOwner] defaults to `true`: a generation returned by a producer's
  /// `produce()` owns its [texture] and is the one that may dispose it.
  const MatteGeneration({
    required this.texture,
    required this.bounds,
    required this.sceneRevision,
    required this.codec,
    this.isOwner = true,
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

  /// Whether this generation owns [texture] and may dispose it.
  ///
  /// `false` for a [translated] view: it aliases another generation's
  /// texture rather than owning it, so releasing it must be a no-op. Without
  /// this flag, `release()` cannot tell a derived view from the original it
  /// borrows from — both carry the same [texture], and disposing one
  /// disposes the other, since they are the same object. A producer must
  /// check this before disposing on release.
  final bool isOwner;

  /// A copy shifted by [delta], reusing the same texture.
  ///
  /// Used when every shape moved by the same amount: the pixels are still
  /// correct, only their placement changed. The result does not own the
  /// texture — see [isOwner] — because the original generation is still the
  /// one responsible for disposing it.
  MatteGeneration translated(Offset delta) => MatteGeneration(
    texture: texture,
    bounds: bounds.shift(delta),
    sceneRevision: sceneRevision,
    codec: codec,
    isOwner: false,
  );
}
