import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// A trivial render object, standing in for a `RenderGlassShape` --
/// `GlassScene` does not depend on that type, only on the key being a
/// `RenderObject`.
class _FakeShape extends RenderConstrainedBox {
  _FakeShape() : super(additionalConstraints: const BoxConstraints());
}

ShapeGeometry _geometry({Offset origin = Offset.zero, double radius = 8}) {
  return ShapeGeometry.resolve(
    shape: GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(radius)),
    ),
    size: const Size(100, 40),
    toLayer: Matrix4.translationValues(origin.dx, origin.dy, 0),
    devicePixelRatio: 1,
  );
}

void main() {
  test('registering a shape bumps the revision', () {
    final scene = GlassScene();
    final before = scene.revision;
    scene.register('a', _geometry());
    expect(scene.revision, greaterThan(before));
  });

  test('re-registering identical geometry does NOT bump the revision', () {
    // This is the whole point. A scroll frame re-runs layout and re-registers
    // every shape with the same numbers; if that bumps the revision the matte
    // is rebuilt every frame for nothing.
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.register('a', _geometry());
    expect(scene.revision, after);
  });

  test('changing geometry bumps the revision', () {
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.register('a', _geometry(radius: 16));
    expect(scene.revision, greaterThan(after));
  });

  test('unregistering bumps the revision', () {
    // Upstream's unregister forgets to dirty, so a removed group's matte
    // survives in the composite until something unrelated forces a rebuild.
    final scene = GlassScene()..register('a', _geometry());
    final after = scene.revision;
    scene.unregister('a');
    expect(scene.revision, greaterThan(after));
    expect(scene.shapes, isEmpty);
  });

  test('detects a uniform translation of every shape', () {
    final before = GlassScene()
      ..register('a', _geometry())
      ..register('b', _geometry(origin: const Offset(50, 0)));
    final after = GlassScene()
      ..register('a', _geometry(origin: const Offset(10, 5)))
      ..register('b', _geometry(origin: const Offset(60, 5)));

    // Everything moved by the same delta and nothing else changed, so the
    // matte can be reused with shifted bounds instead of re-rendered.
    expect(after.uniformTranslationSince(before), const Offset(10, 5));
  });

  test('reports no uniform translation when shapes move differently', () {
    final before = GlassScene()
      ..register('a', _geometry())
      ..register('b', _geometry(origin: const Offset(50, 0)));
    final after = GlassScene()
      ..register('a', _geometry(origin: const Offset(10, 0)))
      ..register('b', _geometry(origin: const Offset(90, 0)));

    expect(after.uniformTranslationSince(before), isNull);
  });

  test('bounds pad for antialiasing', () {
    final scene = GlassScene()..register('a', _geometry());
    final padded = scene.bounds(padding: 0.5);
    final tight = scene.bounds(padding: 0);
    expect(padded.width, closeTo(tight.width + 1, 1e-9));
  });

  test(
    'uniformTranslationSince refuses a translation when the shape count '
    'differs, even though every shape in common agrees on the delta',
    () {
      final before = GlassScene()
        ..register('a', _geometry())
        ..register('b', _geometry(origin: const Offset(50, 0)));
      final after = GlassScene()
        ..register('a', _geometry(origin: const Offset(10, 5)))
        ..register('b', _geometry(origin: const Offset(60, 5)))
        ..register('c', _geometry(origin: const Offset(70, 5)));

      expect(after.uniformTranslationSince(before), isNull);
    },
  );

  test(
    'uniformTranslationSince refuses a translation when a shape key from '
    'one scene has no counterpart in the other',
    () {
      final before = GlassScene()
        ..register('a', _geometry())
        ..register('b', _geometry(origin: const Offset(50, 0)));
      final after = GlassScene()
        ..register('a', _geometry(origin: const Offset(10, 5)))
        ..register('c', _geometry(origin: const Offset(60, 5)));

      expect(after.uniformTranslationSince(before), isNull);
    },
  );

  test(
    'uniformTranslationSince refuses a translation when a shape also '
    'changed, so a shifted matte is never reused over pixels that no '
    'longer match',
    () {
      final before = GlassScene()
        ..register('a', _geometry())
        ..register('b', _geometry(origin: const Offset(50, 0)));
      final after = GlassScene()
        ..register('a', _geometry(origin: const Offset(10, 5)))
        ..register(
          'b',
          _geometry(origin: const Offset(60, 5), radius: 16),
        );

      expect(after.uniformTranslationSince(before), isNull);
    },
  );

  test(
    'unregistering a key that was never registered leaves the revision '
    'unchanged',
    () {
      final scene = GlassScene()..register('a', _geometry());
      final after = scene.revision;
      scene.unregister('does-not-exist');
      expect(scene.revision, after);
    },
  );

  test('shapeOwners is empty for an empty scene', () {
    expect(GlassScene().shapeOwners, isEmpty);
  });

  test(
    'shapeOwners skips shapes registered under a key that is not a render '
    'object',
    () {
      // Production code always registers under the RenderGlassShape that
      // resolved the geometry; only this file's own helper tests register
      // under plain strings, for brevity. shapeOwners exists to hand real
      // starting points to the ancestor-clip walk, so it must drop a key
      // it cannot walk from rather than hand back something unusable.
      final scene = GlassScene()..register('a', _geometry());
      expect(scene.shapeOwners, isEmpty);
    },
  );

  test(
    'shapeOwners returns every render object that registered a shape, in '
    'registration order',
    () {
      final first = _FakeShape();
      final second = _FakeShape();
      final scene = GlassScene()
        ..register(first, _geometry())
        ..register(second, _geometry(origin: const Offset(50, 0)));

      // Order matters to the clip walk: the first entry is the one whose
      // clips every later entry narrows, so a scene that shuffled them
      // would make the retained chain depend on registration order.
      expect(scene.shapeOwners.toList(), <Object>[first, second]);
    },
  );

  test(
    'shapeOwners is empty again once the last shape unregisters',
    () {
      final shape = _FakeShape();
      final scene = GlassScene()
        ..register(shape, _geometry())
        ..unregister(shape);
      expect(scene.shapeOwners, isEmpty);
    },
  );

  test(
    "bounds encloses a rotated shape's corners, wider than its unrotated "
    'footprint',
    () {
      const size = Size(40, 100);
      const shape = GlassRoundedRectangle(
        radius: BorderRadius.all(Radius.circular(8)),
      );
      final straightScene = GlassScene()
        ..register(
          'a',
          ShapeGeometry.resolve(
            shape: shape,
            size: size,
            toLayer: Matrix4.identity(),
            devicePixelRatio: 1,
          ),
        );
      final rotatedScene = GlassScene()
        ..register(
          'a',
          ShapeGeometry.resolve(
            shape: shape,
            size: size,
            toLayer: Matrix4.rotationZ(math.pi / 4),
            devicePixelRatio: 1,
          ),
        );

      final straightBounds = straightScene.bounds(padding: 0);
      final rotatedBounds = rotatedScene.bounds(padding: 0);

      // A 40x100 rectangle rotated 45 degrees has an axis-aligned bounding
      // box that is a square of side (20 + 50) * sqrt(2) — wider than the
      // unrotated shape's 40-pixel width.
      // The basis is stored as Float32List, so allow for float32 rounding.
      const expectedSide = (20 + 50) * math.sqrt2;
      expect(rotatedBounds.width, closeTo(expectedSide, 1e-3));
      expect(rotatedBounds.height, closeTo(expectedSide, 1e-3));
      expect(rotatedBounds.width, greaterThan(straightBounds.width));
    },
  );
}
