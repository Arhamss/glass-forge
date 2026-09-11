import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/house_glass/data/models/material_preset.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_state.dart';

/// Owns the house material: one app-wide glass look, edited on the Material
/// tab and read by every kit component through `HouseGlass`.
class HouseGlassCubit extends Cubit<HouseGlassState> {
  HouseGlassCubit()
    : super(
        HouseGlassState(
          material: MaterialPreset.dome.material,
          preset: MaterialPreset.dome,
        ),
      );

  void applyPreset(MaterialPreset preset) =>
      emit(HouseGlassState(material: preset.material, preset: preset));

  void update(GlassMaterial material) =>
      emit(HouseGlassState(material: material, preset: _presetOf(material)));

  MaterialPreset? _presetOf(GlassMaterial material) {
    for (final preset in MaterialPreset.values) {
      if (preset.material == material) return preset;
    }
    return null;
  }
}
