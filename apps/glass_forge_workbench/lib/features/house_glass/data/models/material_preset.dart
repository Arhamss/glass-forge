import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';

/// The named starting points for the house material.
enum MaterialPreset { dome, regular, clear, tinted, demonstration }

extension MaterialPresetX on MaterialPreset {
  GlassMaterial get material => switch (this) {
    MaterialPreset.dome => GlassMaterial.dome(),
    MaterialPreset.regular => GlassMaterial.regular(
      brightness: Brightness.dark,
    ),
    MaterialPreset.clear => GlassMaterial.clear(),
    MaterialPreset.tinted => GlassMaterial.dome().copyWith(
      tint: AppColors.accent,
      tintOpacity: 0.16,
    ),
    MaterialPreset.demonstration => demonstrationGlassMaterial(),
  };

  String get label => switch (this) {
    MaterialPreset.dome => Localization.presetDome,
    MaterialPreset.regular => Localization.presetRegular,
    MaterialPreset.clear => Localization.presetClear,
    MaterialPreset.tinted => Localization.presetTinted,
    MaterialPreset.demonstration => Localization.presetDemonstration,
  };
}
