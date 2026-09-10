import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

void main() {
  group('minimumSingularValue', () {
    test('is 1 for an identity basis', () {
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(1, 0),
        const Offset(0, 1),
      );
      expect(s, closeTo(1, 1e-9));
    });

    test('is the smaller scale under non-uniform scaling', () {
      // A basis scaled 3x horizontally and 2x vertically. The smallest amount
      // any direction is stretched by is 2, so a local distance of 1 is worth
      // at least 2 screen pixels — never 3, or the SDF stops being a lower
      // bound and culling starts dropping shapes that are actually visible.
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(3, 0),
        const Offset(0, 2),
      );
      expect(s, closeTo(2, 1e-9));
    });

    test('is rotation invariant', () {
      const angle = math.pi / 5;
      final axisX = Offset(math.cos(angle), math.sin(angle)) * 3;
      final axisY = Offset(-math.sin(angle), math.cos(angle)) * 2;
      final s = ShapeGeometry.minimumSingularValue(axisX, axisY);
      expect(s, closeTo(2, 1e-9));
    });

    test('is zero for a degenerate basis', () {
      final s = ShapeGeometry.minimumSingularValue(
        const Offset(1, 0),
        const Offset(2, 0),
      );
      expect(s, closeTo(0, 1e-9));
    });
  });

  group('resolve', () {
    test('inverts a rotated basis so local space is recoverable', () {
      final toLayer = Matrix4.rotationZ(math.pi / 2);
      final geometry = ShapeGeometry.resolve(
        shape: const GlassOval(),
        size: const Size(10, 10),
        toLayer: toLayer,
        devicePixelRatio: 1,
      );

      // Mapping a point through the basis and back must be the identity.
      const point = Offset(3, 7);
      final local = geometry.toLocal(point);
      final back = geometry.toLayerSpace(local);
      expect(back.dx, closeTo(point.dx, 1e-6));
      expect(back.dy, closeTo(point.dy, 1e-6));
    });

    test('scales geometry by device pixel ratio', () {
      final geometry = ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(8)),
        ),
        size: const Size(100, 40),
        toLayer: Matrix4.identity(),
        devicePixelRatio: 3,
      );

      // Every geometric quantity is in physical pixels. Upstream forgot this
      // for thickness alone, so its refraction rim renders a third as wide on
      // a 3x phone as it does on the 1x machine its goldens were taken on.
      expect(geometry.radius, closeTo(24, 1e-9));
      expect(geometry.halfExtent.width, closeTo(150, 1e-9));
      expect(geometry.halfExtent.height, closeTo(60, 1e-9));
    });
  });
}
