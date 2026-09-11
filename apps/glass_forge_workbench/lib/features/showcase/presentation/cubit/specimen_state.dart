import 'package:equatable/equatable.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/showcase_shape.dart';

/// State for the specimen screen's cubit.
class SpecimenState extends Equatable {
  /// Creates a state.
  const SpecimenState({
    this.shape = ShowcaseShape.roundedRectangle,
    this.material = const GlassMaterial(),
    this.backdrop = GlassBackdrop.photographic,
  });

  /// The specimen's silhouette.
  final ShowcaseShape shape;

  /// The specimen's current material.
  final GlassMaterial material;

  /// The backdrop currently shown on the stage.
  final GlassBackdrop backdrop;

  /// Returns a copy with the given fields replaced.
  SpecimenState copyWith({
    ShowcaseShape? shape,
    GlassMaterial? material,
    GlassBackdrop? backdrop,
  }) {
    return SpecimenState(
      shape: shape ?? this.shape,
      material: material ?? this.material,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  List<Object?> get props => [shape, material, backdrop];
}
