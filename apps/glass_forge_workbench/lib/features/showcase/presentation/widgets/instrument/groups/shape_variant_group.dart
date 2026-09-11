import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/material_preset_row.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/enums/showcase_shape.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_variant_extensions.dart';

/// The instrument's "Specimen" group: shape, variant, and the material
/// presets fitted against real iOS 27 captures.
class ShapeVariantGroup extends StatelessWidget {
  /// Creates the group.
  const ShapeVariantGroup({
    required this.shape,
    required this.variant,
    required this.onShapeChanged,
    required this.onVariantChanged,
    required this.onPresetSelected,
    super.key,
  });

  /// The specimen's current silhouette.
  final ShowcaseShape shape;

  /// The material's current variant.
  final GlassVariant variant;

  /// Called with the newly picked shape.
  final ValueChanged<ShowcaseShape> onShapeChanged;

  /// Called with the newly picked variant.
  final ValueChanged<GlassVariant> onVariantChanged;

  /// Called with a preset's fully-formed material.
  final ValueChanged<GlassMaterial> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Specimen',
      cells: [
        InstrumentSegmentedControl<ShowcaseShape>(
          values: ShowcaseShape.values,
          labels: [for (final value in ShowcaseShape.values) value.label],
          selected: shape,
          onChanged: onShapeChanged,
        ),
        InstrumentSegmentedControl<GlassVariant>(
          values: GlassVariant.values,
          labels: [for (final value in GlassVariant.values) value.label],
          selected: variant,
          onChanged: onVariantChanged,
        ),
        MaterialPresetRow(onPresetSelected: onPresetSelected),
      ],
    );
  }
}
