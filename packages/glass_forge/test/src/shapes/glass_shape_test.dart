import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';
import 'package:glass_forge/src/widgets/glass.dart';

/// A non-const rounded rectangle, so two calls with the same [value] return
/// genuinely distinct instances rather than one canonicalized const object.
GlassRoundedRectangle _roundedRectOf(double value) =>
    GlassRoundedRectangle(radius: BorderRadius.circular(value));

void main() {
  test('sdf codes are stable and distinct', () {
    // These integers cross into the shader. Reordering them silently changes
    // which SDF every shape resolves to, so they are pinned here.
    expect(ShapeType.none.sdfCode, 0);
    expect(ShapeType.roundedRectangle.sdfCode, 1);
    expect(ShapeType.ellipse.sdfCode, 2);
    expect(ShapeType.superellipse.sdfCode, 3);
  });

  test('rounded rectangle reports its own type', () {
    const shape = GlassRoundedRectangle(radius: BorderRadius.zero);
    expect(shape.type, ShapeType.roundedRectangle);
  });

  test('a superellipse is not silently a rounded rectangle', () {
    // Upstream's "squircle" SDF is term-for-term identical to its rounded
    // rectangle while its clip uses a real superellipse, so the refraction
    // dome and the child clip disagree at every corner. Keep them distinct.
    const rect = GlassRoundedRectangle(radius: BorderRadius.zero);
    const squircle = GlassSuperellipse(radius: BorderRadius.zero);
    expect(rect.type, isNot(squircle.type));
  });

  test('radius clamps to half the shorter side', () {
    const shape = GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(9000)),
    );
    expect(shape.resolveRadius(const Size(100, 40)), 20);
  });

  test('an oval has no corner radius', () {
    const shape = GlassOval();
    expect(shape.resolveRadius(const Size(100, 40)), 0);
  });

  test('refraction silhouette and clip silhouette agree for rounded rect', () {
    const shape = GlassRoundedRectangle(radius: BorderRadius.zero);
    const size = Size(100, 100);
    expect(shape.toBorder(size), isA<RoundedRectangleBorder>());
  });

  test('refraction silhouette and clip silhouette agree for oval', () {
    const shape = GlassOval();
    const size = Size(100, 100);
    expect(shape.toBorder(size), isA<OvalBorder>());
  });

  test(
    'refraction silhouette and clip silhouette agree for superellipse, not '
    'silently a rounded rectangle',
    () {
      const shape = GlassSuperellipse(radius: BorderRadius.zero);
      const size = Size(100, 100);
      final border = shape.toBorder(size);
      expect(border, isA<RoundedSuperellipseBorder>());
      expect(border, isNot(isA<RoundedRectangleBorder>()));
    },
  );

  test('clip uses clamped radius, not requested radius', () {
    const shape = GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(9000)),
    );
    const size = Size(100, 40);
    final border = shape.toBorder(size) as RoundedRectangleBorder;
    // The requested radius is 9000, but the limit is half the shorter side
    // (20). The border should be built from 20, not 9000.
    expect(border.borderRadius, BorderRadius.circular(20));
  });

  test(
    'two independently constructed but equal shapes compare equal',
    () {
      // Not `const`: a real caller rebuilds a shape like this every frame
      // (a radius bound to theme, state, or an animation), so the two
      // instances here must be genuinely distinct objects, not one
      // canonicalized const value, for this to test anything.
      final a = _roundedRectOf(12);
      final b = _roundedRectOf(12);
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      // GlassOval carries no fields, so every instance of it is const and
      // therefore already canonicalized to one object; its == is still
      // exercised here, just without an independent-instance claim that a
      // fieldless type cannot make.
      const ovalA = GlassOval();
      const ovalB = GlassOval();
      expect(ovalA, equals(ovalB));
      expect(ovalA.hashCode, equals(ovalB.hashCode));

      final superA = GlassSuperellipse(radius: BorderRadius.circular(12));
      final superB = GlassSuperellipse(radius: BorderRadius.circular(12));
      expect(identical(superA, superB), isFalse);
      expect(superA, equals(superB));
      expect(superA.hashCode, equals(superB.hashCode));
    },
  );

  test('shapes of different radii or types are not equal', () {
    expect(_roundedRectOf(12), isNot(equals(_roundedRectOf(20))));
    expect(_roundedRectOf(12), isNot(equals(const GlassOval())));
    expect(
      _roundedRectOf(12),
      isNot(equals(GlassSuperellipse(radius: BorderRadius.circular(12)))),
    );
  });

  test(
    'GlassShapeClipper skips a reclip for an equal but rebuilt shape '
    '(regression: shouldReclip reclipping every frame)',
    () {
      final previous = GlassShapeClipper(_roundedRectOf(12));
      final rebuilt = GlassShapeClipper(_roundedRectOf(12));
      expect(rebuilt.shouldReclip(previous), isFalse);

      final changed = GlassShapeClipper(_roundedRectOf(20));
      expect(changed.shouldReclip(previous), isTrue);
    },
  );
}
