import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/helpers/glass_material_tween.dart';

void main() {
  final from = GlassMaterial.dome();
  final to = GlassMaterial.clear().copyWith(tint: const Color(0xFFD4F25A));
  final tween = GlassMaterialTween(begin: from, end: to);

  test('the ends are the materials themselves', () {
    expect(tween.lerp(0), from);
    expect(tween.lerp(1), to);
  });

  test('numbers pass through their midpoint', () {
    final mid = tween.lerp(0.5);
    expect(mid.thickness, closeTo((from.thickness + to.thickness) / 2, 1e-9));
    expect(mid.frost, closeTo((from.frost + to.frost) / 2, 1e-9));
  });

  test('the optical model switches halfway, never blends', () {
    expect(tween.lerp(0.49).profile, from.profile);
    expect(tween.lerp(0.5).profile, to.profile);
    expect(tween.lerp(0.49).variant, from.variant);
    expect(tween.lerp(0.5).variant, to.variant);
  });
}
