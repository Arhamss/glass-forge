// This suite constructs `ui.ImageFilter.shader`, which throws
// `UnsupportedError` outside Impeller. `flutter_tester`'s default software
// backend does not enable Impeller, so this file is excluded from a bare
// `flutter test` run (see dart_test.yaml) and only runs via the separate
// `flutter test --tags impeller --run-skipped --enable-impeller` CI step.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

Float32List _mapping([double tx = 0]) =>
    Float32List.fromList(<double>[1, 0, 0, 1, tx, 0]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('builds a single composed filter, never a stack', () {
    final composition = GlassComposition();
    final filter = composition.build(
      matte: null,
      material: const GlassMaterial(),
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(),
        presence: 1,
        glow: const GlassGlow.none(),
      ),
      devicePixelRatio: 1,
      presence: 1,
      glow: const GlassGlow.none(),
    );
    expect(filter, isNotNull);
    expect(composition.debugFilterBuildCount, 1);
    composition.dispose();
  });

  test('reuses the filter when the snapshot is unchanged', () {
    final composition = GlassComposition();
    const material = GlassMaterial();
    FilterSnapshot snapshot() => FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 1,
      materialRevision: 0,
      coordinateMapping: _mapping(),
      presence: 1,
      glow: const GlassGlow.none(),
    );

    composition
      ..build(
        matte: null,
        material: material,
        snapshot: snapshot(),
        devicePixelRatio: 1,
        presence: 1,
        glow: const GlassGlow.none(),
      )
      ..build(
        matte: null,
        material: material,
        snapshot: snapshot(),
        devicePixelRatio: 1,
        presence: 1,
        glow: const GlassGlow.none(),
      );

    expect(composition.debugFilterBuildCount, 1);
    composition.dispose();
  });

  test('rebuilds when the coordinate mapping changes', () {
    final composition = GlassComposition();
    const material = GlassMaterial();

    composition
      ..build(
        matte: null,
        material: material,
        snapshot: FilterSnapshot.of(
          matte: null,
          devicePixelRatio: 1,
          materialRevision: 0,
          coordinateMapping: _mapping(),
          presence: 1,
          glow: const GlassGlow.none(),
        ),
        devicePixelRatio: 1,
        presence: 1,
        glow: const GlassGlow.none(),
      )
      ..build(
        matte: null,
        material: material,
        snapshot: FilterSnapshot.of(
          matte: null,
          devicePixelRatio: 1,
          materialRevision: 0,
          coordinateMapping: _mapping(9),
          presence: 1,
          glow: const GlassGlow.none(),
        ),
        devicePixelRatio: 1,
        presence: 1,
        glow: const GlassGlow.none(),
      );

    expect(composition.debugFilterBuildCount, 2);
    composition.dispose();
  });

  test('returns null when the material renders nothing', () {
    // No filter pushed at all, so an idle layer costs no backdrop pass.
    // Upstream pushes a full backdrop even at blur 0.
    final composition = GlassComposition();
    final filter = composition.build(
      matte: null,
      material: const GlassMaterial(
        frost: 0,
        edgeRefraction: 0,
        highlight: 0,
      ),
      snapshot: FilterSnapshot.of(
        matte: null,
        devicePixelRatio: 1,
        materialRevision: 0,
        coordinateMapping: _mapping(),
        presence: 1,
        glow: const GlassGlow.none(),
      ),
      devicePixelRatio: 1,
      presence: 1,
      glow: const GlassGlow.none(),
    );
    expect(filter, isNull);
    composition.dispose();
  });
}
