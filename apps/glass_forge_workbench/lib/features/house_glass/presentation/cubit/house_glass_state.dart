import 'package:equatable/equatable.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/house_glass/data/models/material_preset.dart';

class HouseGlassState extends Equatable {
  const HouseGlassState({required this.material, this.preset});

  /// The material every kit component renders with unless told otherwise.
  final GlassMaterial material;

  /// The preset [material] exactly matches, or null once it has been edited
  /// away from all of them.
  final MaterialPreset? preset;

  @override
  List<Object?> get props => [material, preset];
}
