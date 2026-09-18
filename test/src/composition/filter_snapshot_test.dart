import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';

Float32List _mapping([double tx = 0]) =>
    Float32List.fromList(<double>[1, 0, 0, 1, tx, 0]);

ui.Image _testImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder, const Rect.fromLTWH(0, 0, 10, 10))
      .drawRect(const Rect.fromLTWH(0, 0, 10, 10), ui.Paint());
  return recorder.endRecording().toImageSync(10, 10);
}

void main() {
  test('equal inputs compare equal so the filter can be reused', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a changed coordinate mapping invalidates the filter', () {
    // This is the whole reason the snapshot exists: the mapping lives in
    // uniforms the engine already copied, so reusing the filter after it
    // changes renders the previous frame's geometry.
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(12),
      presence: 1,
    );
    expect(a, isNot(b));
  });

  test('a changed material revision invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 2,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, isNot(b));
  });

  test('a changed device pixel ratio invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 2,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, isNot(b));
  });

  test('matte texture reuse prevents stale render', () {
    final image = _testImage();
    const codec = MatteCodec(maxDisplacement: 10);
    final matte = MatteGeneration(
      texture: image,
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      sceneRevision: 1,
      codec: codec,
    );
    final a = FilterSnapshot.of(
      matte: matte,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: matte,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    image.dispose();
  });

  test('different textures prevent stale render', () {
    final image1 = _testImage();
    final image2 = _testImage();
    const codec = MatteCodec(maxDisplacement: 10);
    final matte1 = MatteGeneration(
      texture: image1,
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      sceneRevision: 1,
      codec: codec,
    );
    final matte2 = MatteGeneration(
      texture: image2,
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      sceneRevision: 1,
      codec: codec,
    );
    final a = FilterSnapshot.of(
      matte: matte1,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: matte2,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, isNot(b));
    image1.dispose();
    image2.dispose();
  });

  test('shifted bounds prevent stale render', () {
    final image = _testImage();
    const codec = MatteCodec(maxDisplacement: 10);
    final matte1 = MatteGeneration(
      texture: image,
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      sceneRevision: 1,
      codec: codec,
    );
    final matte2 = matte1.translated(const Offset(5, 5));
    final a = FilterSnapshot.of(
      matte: matte1,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final b = FilterSnapshot.of(
      matte: matte2,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(a, isNot(b));
    image.dispose();
  });

  test('matte presence prevents stale render', () {
    final image = _testImage();
    const codec = MatteCodec(maxDisplacement: 10);
    final matte = MatteGeneration(
      texture: image,
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      sceneRevision: 1,
      codec: codec,
    );
    final withMatte = FilterSnapshot.of(
      matte: matte,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    final withoutMatte = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
      presence: 1,
    );
    expect(withMatte, isNot(withoutMatte));
    expect(withoutMatte, isNot(withMatte));
    image.dispose();
  });
}
