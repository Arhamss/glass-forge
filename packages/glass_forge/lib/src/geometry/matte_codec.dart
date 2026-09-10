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
/// - **B** — signed edge distance, sqrt-companded on both sides.
/// - **A** — displacement magnitude, sqrt-companded.
///
/// Storing a normal plus a magnitude rather than a displacement vector is what
/// makes 8 bits enough. Companding then spends the code points near zero,
/// where the narrow contour and highlight ramps live and where banding shows.
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
    out[3] = _encodeCompanded(
      (displacementMagnitude / maxDisplacement).clamp(0.0, 1.0),
    );
    return out;
  }

  /// Decodes one texel produced by [encode].
  ({Offset normal, double signedDistance, double displacement}) decode(
    Float32List rgba,
  ) {
    return (
      normal: Offset(_decodeSigned(rgba[0]), _decodeSigned(rgba[1])),
      signedDistance: _decodeCompandedSigned(rgba[2]) * maxDisplacement,
      displacement: _decodeCompanded(rgba[3]) * maxDisplacement,
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

  static double _encodeCompanded(double linear) {
    final normalized = 1 - math.sqrt(1 - linear.clamp(0.0, 1.0));
    return (normalized * 255).roundToDouble() / 255;
  }

  static double _decodeCompanded(double encoded) {
    final inverse = 1 - encoded;
    return 1 - inverse * inverse;
  }

  static double _encodeCompandedSigned(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    final magnitude = _encodeCompanded(clamped.abs());
    return clamped.isNegative ? 0.5 - magnitude * 0.5 : 0.5 + magnitude * 0.5;
  }

  static double _decodeCompandedSigned(double encoded) {
    final centered = (encoded - 0.5) * 2;
    final magnitude = _decodeCompanded(centered.abs());
    return centered.isNegative ? -magnitude : magnitude;
  }
}
