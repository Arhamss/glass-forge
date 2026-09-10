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
    // The displacement channel is companded toward the maximum, but the
    // round trip still has to stay under half a physical pixel everywhere,
    // including near zero.
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

  /// The worst round-trip error for displacement magnitude, sampled densely
  /// across [t0, t1] (as a fraction of `maxDisplacement`).
  double worstDisplacementError(double t0, double t1) {
    var worst = 0.0;
    for (var i = 0; i <= 200; i++) {
      final magnitude = 32 * (t0 + (t1 - t0) * i / 200);
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(1, 0),
          signedDistance: 0,
          displacementMagnitude: magnitude,
        ),
      );
      final error = (decoded.displacement - magnitude).abs();
      if (error > worst) worst = error;
    }
    return worst;
  }

  /// The worst round-trip error for signed distance, sampled densely across
  /// [t0, t1] (as a fraction of `maxDisplacement`, on the positive side).
  double worstSignedDistanceError(double t0, double t1) {
    var worst = 0.0;
    for (var i = 0; i <= 200; i++) {
      final distance = 32 * (t0 + (t1 - t0) * i / 200);
      final decoded = codec.decode(
        codec.encode(
          normal: const Offset(0, 1),
          signedDistance: distance,
          displacementMagnitude: 0,
        ),
      );
      final error = (decoded.signedDistance - distance).abs();
      if (error > worst) worst = error;
    }
    return worst;
  }

  test(
    'concentrates displacement-magnitude precision near the maximum, '
    'not zero',
    () {
      // The convex-squircle edge profile is steep near the inner edge of
      // the band and nearly flat near the shape edge (maximum
      // displacement). Banding shows up where the signal is flattest, so
      // the worst-case error there must be the smaller of the two, not the
      // worst-case error near zero.
      final nearZero = worstDisplacementError(0, 0.05);
      final nearMax = worstDisplacementError(0.95, 1);
      expect(nearMax, lessThan(nearZero));
    },
  );

  test(
    'concentrates signed-distance precision near zero, not the maximum',
    () {
      // Coverage, the contour and the bevel are all computed from signed
      // distance near zero — the shape edge — so the worst-case error there
      // must be the smaller of the two, not the worst-case error near the
      // maximum.
      final nearZero = worstSignedDistanceError(0, 0.05);
      final nearMax = worstSignedDistanceError(0.95, 1);
      expect(nearZero, lessThan(nearMax));
    },
  );

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
