import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The light under a fingertip, spreading across a whole backdrop pass.
///
/// Apple: "Starting right under your fingertips, the glow spreads throughout
/// the element and onto any Liquid Glass elements nearby." A glow that
/// spills onto its neighbours cannot belong to one shape, so this belongs to
/// the pass -- every shape sharing that pass is lit by it, and the gaps
/// between them are not, because the shader masks it by coverage for free.
@immutable
class GlassGlow {
  /// Creates a glow.
  const GlassGlow({
    required this.centre,
    required this.radius,
    required this.strength,
  });

  /// No glow.
  const GlassGlow.none() : centre = Offset.zero, radius = 0, strength = 0;

  /// Where the finger is, in layer-local logical pixels.
  final Offset centre;

  /// How far the light reaches, in logical pixels.
  final double radius;

  /// How much it brightens at the centre, 0 to 1.
  final double strength;

  /// Whether this puts any light on screen.
  ///
  /// `GlassComposition._writeUniforms` is the only place a [GlassGlow]
  /// reaches the shader, and it forces the uniform's strength to 0
  /// whenever this is false -- so a `radius: 0` glow, even with nonzero
  /// [strength], cannot disagree with what gets drawn. That choke point is
  /// deliberately in Dart rather than in `final_render.frag`'s own
  /// `uGlow.w > 0.0` gate: the shader gate only ever sees what
  /// `_writeUniforms` sends it, so fixing it there covers every future
  /// caller for free, without a per-fragment radius check duplicated
  /// across both `.frag` files.
  bool get isActive => radius > 0 && strength > 0;

  @override
  bool operator ==(Object other) =>
      other is GlassGlow &&
      other.centre == centre &&
      other.radius == radius &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(centre, radius, strength);
}
