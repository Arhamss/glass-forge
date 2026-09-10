import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';

Float32List _mapping([double tx = 0]) =>
    Float32List.fromList(<double>[1, 0, 0, 1, tx, 0]);

void main() {
  test('equal inputs compare equal so the filter can be reused', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
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
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(12),
    );
    expect(a, isNot(b));
  });

  test('a changed material revision invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 2,
      coordinateMapping: _mapping(),
    );
    expect(a, isNot(b));
  });

  test('a changed device pixel ratio invalidates the filter', () {
    final a = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 2,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    final b = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 1,
      coordinateMapping: _mapping(),
    );
    expect(a, isNot(b));
  });
}
