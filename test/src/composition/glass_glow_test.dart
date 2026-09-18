import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';

void main() {
  test('none() glows nothing', () {
    expect(const GlassGlow.none().isActive, isFalse);
  });

  test('a zero-strength glow is inactive however large its radius', () {
    expect(
      const GlassGlow(
        centre: Offset(10, 10),
        radius: 200,
        strength: 0,
      ).isActive,
      isFalse,
    );
  });

  test('a zero-radius glow is inactive however strong', () {
    expect(
      const GlassGlow(centre: Offset(10, 10), radius: 0, strength: 1).isActive,
      isFalse,
    );
  });

  group('value equality', () {
    // `const` objects with identical literal fields are canonicalised to
    // one runtime instance at compile time, independent of any custom
    // `operator==` -- so constructing both sides `const` would pass even
    // if `==`/`hashCode` were deleted outright. Deriving a field from a
    // runtime value the compiler cannot fold forces two distinct
    // instances, so `identical` being false is what proves this test is
    // actually exercising `operator==` rather than object identity.
    GlassGlow glowAt(double dx) =>
        GlassGlow(centre: Offset(dx, 2), radius: 3, strength: 4);

    test('two distinct instances with equal fields compare equal', () {
      final a = glowAt(1);
      final b = glowAt(1);

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing centre compares unequal', () {
      final a = glowAt(1);
      final b = glowAt(9);

      expect(identical(a, b), isFalse);
      expect(a, isNot(equals(b)));
    });

    test('differing radius compares unequal', () {
      // Differing field values never canonicalise to one instance, so
      // `const` here does not undermine the `identical` check.
      const a = GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4);
      const b = GlassGlow(centre: Offset(1, 2), radius: 9, strength: 4);

      expect(identical(a, b), isFalse);
      expect(a, isNot(equals(b)));
    });

    test('differing strength compares unequal', () {
      const a = GlassGlow(centre: Offset(1, 2), radius: 3, strength: 4);
      const b = GlassGlow(centre: Offset(1, 2), radius: 3, strength: 9);

      expect(identical(a, b), isFalse);
      expect(a, isNot(equals(b)));
    });
  });
}
