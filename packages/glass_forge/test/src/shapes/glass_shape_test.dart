import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

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
}
