import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
import 'package:glass_forge/src/material/glass_material.dart';

void main() {
  const material = GlassMaterial();

  test('presence 0 renders nothing, whatever the material would do', () {
    expect(GlassComposition.willRender(material, 1), isTrue);
    expect(GlassComposition.willRender(material, 0), isFalse);
  });

  test('a presence below the epsilon is treated as zero', () {
    expect(GlassComposition.willRender(material, 0.0001), isFalse);
  });

  test('a snapshot differing only in presence is not equal', () {
    final mapping = Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]);
    final full = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 7,
      coordinateMapping: mapping,
      presence: 1,
      glow: const GlassGlow.none(),
    );
    final half = FilterSnapshot.of(
      matte: null,
      devicePixelRatio: 3,
      materialRevision: 7,
      coordinateMapping: mapping,
      presence: 0.5,
      glow: const GlassGlow.none(),
    );
    expect(full, isNot(equals(half)));
    expect(full.presence, 1);
  });
}
