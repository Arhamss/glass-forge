import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/helpers/glass_material_code.dart';

void main() {
  test('the default material is one constructor call', () {
    expect(
      GlassMaterialCode.of(const GlassMaterial()),
      'const GlassMaterial()',
    );
  });

  test('only fields that differ from the defaults are written', () {
    final code = GlassMaterialCode.of(
      const GlassMaterial().copyWith(thickness: 20, frost: 2.5),
    );
    expect(
      code,
      'const GlassMaterial(\n'
      '  thickness: 20.0,\n'
      '  frost: 2.5,\n'
      ')',
    );
  });

  test('enums, colours and offsets are written as Dart', () {
    final code = GlassMaterialCode.of(
      const GlassMaterial(
        variant: GlassVariant.clear,
        profile: GlassProfile.dome,
      ).copyWith(
        tint: const Color(0xFFD4F25A),
        tintOpacity: 0.16,
        lightDirection: const Offset(-0.5, 0.866),
      ),
    );
    expect(code, contains('variant: GlassVariant.clear,'));
    expect(code, contains('profile: GlassProfile.dome,'));
    expect(code, contains('tint: Color(0xFFD4F25A),'));
    expect(code, contains('tintOpacity: 0.16,'));
    expect(code, contains('lightDirection: Offset(-0.5, 0.866),'));
  });

  test('the dome preset round-trips to its own fields', () {
    final code = GlassMaterialCode.of(GlassMaterial.dome());
    expect(code, startsWith('const GlassMaterial(\n'));
    expect(code, contains('profile: GlassProfile.dome,'));
  });
}
