import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/house_glass/data/models/material_preset.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';

void main() {
  group('HouseGlassCubit', () {
    test('starts on the dome preset', () {
      final cubit = HouseGlassCubit();
      expect(cubit.state.preset, MaterialPreset.dome);
      expect(cubit.state.material, GlassMaterial.dome());
    });

    test('applyPreset swaps the material and names the preset', () {
      final cubit = HouseGlassCubit()..applyPreset(MaterialPreset.clear);
      expect(cubit.state.material, GlassMaterial.clear());
      expect(cubit.state.preset, MaterialPreset.clear);
    });

    test('an edited material no longer claims a preset', () {
      final cubit = HouseGlassCubit()
        ..update(GlassMaterial.dome().copyWith(thickness: 31));
      expect(cubit.state.preset, isNull);
      expect(cubit.state.material.thickness, 31);
    });

    test("editing back to a preset's exact material names it again", () {
      final cubit = HouseGlassCubit()
        ..update(GlassMaterial.dome().copyWith(thickness: 31))
        ..update(GlassMaterial.clear());
      expect(cubit.state.preset, MaterialPreset.clear);
    });

    test('every preset is a distinct material', () {
      final materials = {
        for (final preset in MaterialPreset.values) preset.material,
      };
      expect(materials, hasLength(MaterialPreset.values.length));
    });
  });
}
