import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/material/glass_material.dart';

/// Deliberately **not** tagged `impeller`.
///
/// Every other composition test is, because it constructs
/// `ui.ImageFilter.shader`, which flutter_tester's default backend cannot.
/// These are the opposite case: they exist to cover what happens on a
/// backend *without* shader filter support, and that backend is exactly the
/// one the untagged lane runs on. Tagging this file would skip it in the
/// only environment where it asserts anything.
Float32List _mapping() =>
    Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]);

FilterSnapshot _snapshot({int materialRevision = 0}) => FilterSnapshot.of(
  matte: null,
  devicePixelRatio: 2,
  materialRevision: materialRevision,
  coordinateMapping: _mapping(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('degrades to blur alone where shader filters are unsupported', () {
    // Constructing `ui.ImageFilter.shader` on Skia throws during paint, so
    // before the fallback existed a Skia or web consumer who had not wrapped
    // their app in a `GlassTierScope` got a crash rather than the graceful
    // degradation this package's own headline claim promises. Degrading is
    // what a consumer is entitled to by default, not something to opt into.
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isFalse,
      reason: 'this lane must run on a backend without shader filters, or '
          'the rest of this file asserts nothing',
    );

    final composition = GlassComposition();
    addTearDown(composition.dispose);

    final filter = composition.build(
      matte: null,
      material: const GlassMaterial().copyWith(frost: 8, edgeRefraction: 30),
      snapshot: _snapshot(),
      devicePixelRatio: 2,
    );

    expect(filter, isNotNull);
    expect(filter.toString(), contains('blur'));
  });

  test('pushes no filter at all when the degraded path has no frost', () {
    // An identity backdrop filter is not free: it still forces a saveLayer
    // and a full backdrop read for every glass surface on screen.
    final composition = GlassComposition();
    addTearDown(composition.dispose);

    expect(
      composition.build(
        matte: null,
        material: const GlassMaterial().copyWith(frost: 0, edgeRefraction: 30),
        snapshot: _snapshot(materialRevision: 1),
        devicePixelRatio: 2,
      ),
      isNull,
    );
  });
}
