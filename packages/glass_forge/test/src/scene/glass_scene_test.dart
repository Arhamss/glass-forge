import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

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
}
