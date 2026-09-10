import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';

void main() {
  const codec = MatteCodec(maxDisplacement: 32);

  test('encodes the cardinal normals exactly', () {
    // -1, 0 and +1 must all be exactly representable, or a flat surface
    // acquires a permanent sub-pixel tilt from its own encoding.
    for (final n in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1)]) {
      final decoded = codec.decode(
        codec.encode(normal: n, signedDistance: 0, displacementMagnitude: 0),
      );
      expect(decoded.normal.dx, closeTo(n.dx, 1e-6));
      expect(decoded.normal.dy, closeTo(n.dy, 1e-6));
    }
  });

  test('round-trips displacement within the 8-bit error bound', () {
    // sqrt companding spends code points where the eye is: near zero
    // displacement, where the contour and highlight ramps live.
    for (var i = 0; i <= 32; i++) {
      final magnitude = 32 * i / 32;
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(1, 0),
          signedDistance: 0,
          displacementMagnitude: magnitude,
        ),
      );
      expect((decoded.displacement - magnitude).abs(), lessThan(0.5));
    }
  });

  test('resolves small displacements more finely than large ones', () {
    double errorNear(double magnitude) {
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(1, 0),
          signedDistance: 0,
          displacementMagnitude: magnitude,
        ),
      );
      return (decoded.displacement - magnitude).abs();
    }

    expect(errorNear(1), lessThan(errorNear(30)));
  });

  test('round-trips signed distance on both sides of the edge', () {
    for (final d in const [-24.0, -1.0, 0.0, 1.0, 24.0]) {
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(0, 1),
          signedDistance: d,
          displacementMagnitude: 0,
        ),
      );
      expect((decoded.signedDistance - d).abs(), lessThan(0.5));
    }
  });

  test('sizes the range to what is reachable', () {
    // Upstream uses thickness * 10, so most code points address displacements
    // the profile can never produce.
    expect(MatteCodec.displacementRangeFor(27.42), closeTo(28.79, 0.01));
  });

  test('clamps rather than wrapping when asked for the impossible', () {
    final decoded = codec.decode(
      codec.encode(
        normal: const Offset(1, 0),
        signedDistance: 0,
        displacementMagnitude: 1000,
      ),
    );
    expect(decoded.displacement, closeTo(32, 0.5));
  });
}
