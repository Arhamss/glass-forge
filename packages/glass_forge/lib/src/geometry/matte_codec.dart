import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Packs a shape's surface into an RGBA8 matte, and reads it back.
///
/// The channels are:
///
/// - **R, G** — the unit surface normal, in an asymmetric 0..254 code so that
///   -1, 0 and +1 are all exactly representable. A symmetric code cannot hit
///   all three, and a flat surface then acquires a permanent sub-pixel tilt.
/// - **B** — signed edge distance, companded toward **zero**.
/// - **A** — displacement magnitude, companded toward the **maximum**.
///
/// Storing a normal plus a magnitude rather than a displacement vector is
/// what makes 8 bits enough. The two channels are companded in opposite
/// directions, deliberately, because they need precision in opposite places:
///
/// - Displacement magnitude follows the convex-squircle edge profile, which
///   is steep near the inner edge of the band and goes nearly flat as it
///   approaches the shape edge — where the magnitude is largest. Banding
///   shows up where the signal is flattest, since many screen pixels then
///   land on the same few code points, so this channel spends its precision
///   near the maximum via `1 - sqrt(1 - x)`.
/// - Signed edge distance is what coverage, the contour and the bevel key
///   off of, and all three are computed near distance zero — the shape edge
///   itself. This channel spends its precision near zero via `sqrt(x)`.
///
/// Do not "unify" these back into one compander: `1 - sqrt(1 - x)` is steepest
/// (its derivative is largest) as `x` approaches 1, so it concentrates code
/// points near the *maximum*, not zero. `sqrt(x)` is steepest near `x = 0`
/// and concentrates code points there instead. Each channel uses the one that
/// matches where its own precision needs to live.
///
/// This class is the Dart mirror of `shaders/common/codec.glsl`. The two are
/// tested against each other; if they drift, the matte decodes to nonsense.
@immutable
class MatteCodec {
  /// Creates a codec covering displacements up to [maxDisplacement] physical
  /// pixels.
  const MatteCodec({required this.maxDisplacement});

  /// The largest displacement magnitude this codec can represent.
  final double maxDisplacement;

  /// The displacement range worth encoding for a given edge refraction.
  ///
  /// Sized just above what the profile can actually produce. Upstream uses
  /// `thickness * 10`, which spends most of the range on values the profile
  /// never reaches.
  static double displacementRangeFor(double edgeRefraction) {
    return math.max(1e-3, 1.05 * edgeRefraction);
  }

  /// Encodes one texel. Returns RGBA in 0..1.
  Float32List encode({
    required Offset normal,
    required double signedDistance,
    required double displacementMagnitude,
  }) {
    final length = normal.distance;
    final unit = length < 1e-9 ? Offset.zero : normal / length;

    final out = Float32List(4);
    out[0] = _encodeSigned(unit.dx);
    out[1] = _encodeSigned(unit.dy);
    out[2] = _encodeCompandedSigned(signedDistance / maxDisplacement);
    out[3] = _encodeTowardMax(
      (displacementMagnitude / maxDisplacement).clamp(0.0, 1.0),
    );
    return out;
  }

  /// Decodes just the signed edge distance from a texel's blue channel.
  ///
  /// The Dart mirror of `gfDecodeMatteDistance`. The final pass derives
  /// coverage, the contour and the rim falloff from this and never from the
  /// displacement magnitude in the alpha channel — the edge-band profile
  /// drives that magnitude to exactly zero across the whole interior on
  /// purpose, so keying coverage off it leaves every shape hollow.
  double decodeSignedDistance(double blue) {
    return _decodeCompandedSigned(blue) * maxDisplacement;
  }

  /// Decodes one texel produced by [encode].
  ({Offset normal, double signedDistance, double displacement}) decode(
    Float32List rgba,
  ) {
    return (
      normal: Offset(_decodeSigned(rgba[0]), _decodeSigned(rgba[1])),
      signedDistance: _decodeCompandedSigned(rgba[2]) * maxDisplacement,
      displacement: _decodeTowardMax(rgba[3]) * maxDisplacement,
    );
  }

  // 0..254 of the 0..255 range, so 127 is exactly the midpoint and -1/0/+1
  // all land on integers.
  static double _encodeSigned(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    return ((clamped * 0.5 + 0.5) * 254).roundToDouble() / 255;
  }

  static double _decodeSigned(double encoded) {
    return (encoded * 255 / 254) * 2 - 1;
  }

  // Concentrates precision near the maximum of the 0..1 range: this is
  // steepest (its derivative is largest) as `linear` approaches 1. Used for
  // displacement magnitude, whose edge profile goes flat near the shape
  // edge — the maximum — which is where banding needs to be fought.
  static double _encodeTowardMax(double linear) {
    final normalized = 1 - math.sqrt(1 - linear.clamp(0.0, 1.0));
    return (normalized * 255).roundToDouble() / 255;
  }

  static double _decodeTowardMax(double encoded) {
    final inverse = 1 - encoded;
    return 1 - inverse * inverse;
  }

  // Concentrates precision near zero: this is steepest as `linear`
  // approaches 0. Used for signed edge distance, since coverage, the
  // contour and the bevel are all computed near distance zero.
  static double _encodeTowardZero(double linear) {
    final normalized = math.sqrt(linear.clamp(0.0, 1.0));
    return (normalized * 255).roundToDouble() / 255;
  }

  static double _decodeTowardZero(double encoded) {
    return encoded * encoded;
  }

  static double _encodeCompandedSigned(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final magnitude = _encodeTowardZero(clamped.abs());
    return clamped.isNegative ? 0.5 - magnitude * 0.5 : 0.5 + magnitude * 0.5;
  }

  static double _decodeCompandedSigned(double encoded) {
    final centered = (encoded - 0.5) * 2;
    final magnitude = _decodeTowardZero(centered.abs());
    return centered.isNegative ? -magnitude : magnitude;
  }
}
