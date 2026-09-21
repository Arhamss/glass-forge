import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/glass_detent.dart';

void main() {
  group('resolving one detent', () {
    test('a fraction is a fraction of the available height', () {
      expect(
        const GlassDetent.fraction(0.1)
            .resolve(available: 800, contentHeight: 0),
        80,
      );
    });

    test('a height is itself, clamped to what there is', () {
      expect(
        const GlassDetent.height(200).resolve(available: 800, contentHeight: 0),
        200,
      );
      expect(
        const GlassDetent.height(2000)
            .resolve(available: 800, contentHeight: 0),
        800,
      );
    });

    test('content measures the child, clamped to what there is', () {
      expect(
        const GlassDetent.content().resolve(available: 800, contentHeight: 260),
        260,
      );
      expect(
        const GlassDetent.content().resolve(available: 800, contentHeight: 900),
        800,
      );
    });

    // An unbounded child — a ListView with no height — has an infinite
    // intrinsic. Resolving that to infinity would put the sheet's top edge at
    // negative infinity and take the whole layout with it, so it saturates at
    // the available height instead, which is the answer a caller who wrote
    // `content()` around a scrollable actually wanted.
    test('an unmeasurable child falls back to the available height', () {
      expect(
        const GlassDetent.content().resolve(
          available: 800,
          contentHeight: double.infinity,
        ),
        800,
      );
    });
  });

  group('resolving a list', () {
    test('returns heights in ascending order', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[
            GlassDetent.fraction(0.1),
            GlassDetent.fraction(0.5),
            GlassDetent.fraction(1),
          ],
          available: 800,
          contentHeight: 0,
        ),
        <double>[80, 400, 800],
      );
    });

    // Two detents that resolve to the same pixel height are one detent with a
    // dead zone between them: a drag released anywhere near either snaps to
    // whichever the nearest-search happened to reach first, and a caller
    // watching `onDetentChanged` sees an index that never changes. Collapsing
    // them is the only reading that keeps the index meaningful.
    test('collapses detents that resolve to the same height', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[
            GlassDetent.height(400),
            GlassDetent.fraction(0.5),
            GlassDetent.fraction(1),
          ],
          available: 800,
          contentHeight: 0,
        ),
        <double>[400, 800],
      );
    });

    test('a zero available height resolves everything to zero', () {
      expect(
        resolveGlassDetents(
          const <GlassDetent>[
            GlassDetent.fraction(0.1),
            GlassDetent.fraction(1),
          ],
          available: 0,
          contentHeight: 0,
        ),
        <double>[0],
      );
    });
  });

  group('what is rejected', () {
    test('a fraction outside (0, 1]', () {
      expect(() => GlassDetent.fraction(0), throwsAssertionError);
      expect(() => GlassDetent.fraction(1.5), throwsAssertionError);
    });

    test('a non-positive height', () {
      expect(() => GlassDetent.height(0), throwsAssertionError);
    });
  });
}
