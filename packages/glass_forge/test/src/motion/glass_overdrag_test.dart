import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';

void main() {
  group('the rubber band', () {
    const band = GlassOverdrag(limit: 48, resistance: 0.4);

    test('passes through the origin', () {
      expect(band.applyToScalar(0), 0);
      expect(band.apply(Offset.zero), Offset.zero);
    });

    test('tracks the pointer exactly at rest', () {
      // f'(0) == resistance. A band that started anywhere else makes the
      // first pixel of every drag feel either sticky or slippery.
      const h = 1e-6;
      expect(band.applyToScalar(h) / h, closeTo(band.resistance, 1e-4));
    });

    test('never reaches the limit, however hard it is pulled', () {
      for (final raw in <double>[100, 1000, 100000, 1000000000000]) {
        expect(band.applyToScalar(raw), lessThan(48));
        expect(band.applyToScalar(raw), greaterThan(0));
      }
    });

    test('is monotone, so a drag never reverses under the finger', () {
      var previous = 0.0;
      for (var raw = 0.0; raw < 500; raw += 0.5) {
        final banded = band.applyToScalar(raw);
        expect(banded, greaterThanOrEqualTo(previous));
        previous = banded;
      }
    });

    test('is odd, so both directions resist identically', () {
      for (final raw in <double>[3, 30, 300]) {
        expect(band.applyToScalar(-raw), -band.applyToScalar(raw));
      }
    });

    test('resists a diagonal drag the same as an axial one', () {
      // Banding each axis independently would let a 45-degree drag reach
      // limit * sqrt(2) from home.
      final diagonal = band.apply(const Offset(200, 200));
      final axial = band.apply(const Offset(282.842712474619, 0));
      expect(diagonal.distance, closeTo(axial.distance, 1e-9));
      expect(diagonal.dx, closeTo(diagonal.dy, 1e-9));
    });

    test('inverts, so a second gesture resumes where the first left off', () {
      for (final raw in <double>[0.5, 5, 50, 500, -70]) {
        expect(band.rawForScalar(band.applyToScalar(raw)), closeTo(raw, 1e-6));
      }
    });

    test(
      'stays finite past the asymptote, so a gesture that grabs a surface '
      'a fling pushed out of the band is still a live gesture',
      () {
        // Without a cap the inverse diverges and every later pointer delta
        // is lost in the noise: the surface can neither be pulled further
        // out nor dragged back, for the rest of the gesture.
        for (final beyond in <double>[48, 60, 400]) {
          final resumed = band.rawForScalar(beyond);
          expect(resumed.isFinite, isTrue);
          expect(band.applyToScalar(resumed), lessThan(48));

          // Stiff this deep in a band is correct; unable to move at all is
          // not. Both directions must still change the surface's position.
          final here = band.applyToScalar(resumed);
          expect(band.applyToScalar(resumed + 200), greaterThan(here));
          expect(band.applyToScalar(resumed - 200), lessThan(here));
        }
      },
    );
  });

  group('GlassOverdrag.none', () {
    test('is the identity, not a constant scale', () {
      // The curve degenerates to `raw * resistance` at an infinite limit,
      // which would silently halve every drag in the package's default
      // configuration.
      const none = GlassOverdrag.none();
      expect(none.applyToScalar(1234.5), 1234.5);
      expect(none.apply(const Offset(-90, 12)), const Offset(-90, 12));
      expect(none.rawForScalar(77), 77);
      expect(none.isActive, isFalse);
    });
  });

  test('a tighter limit resists sooner', () {
    const tight = GlassOverdrag(limit: 20);
    const loose = GlassOverdrag(limit: 200);
    expect(tight.applyToScalar(100), lessThan(loose.applyToScalar(100)));
  });

  test('value semantics', () {
    expect(const GlassOverdrag(), const GlassOverdrag());
    expect(const GlassOverdrag().hashCode, const GlassOverdrag().hashCode);
    expect(const GlassOverdrag(limit: 10), isNot(const GlassOverdrag()));
  });
}
