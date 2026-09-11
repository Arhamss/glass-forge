import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/material/demonstration_glass_material.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/material_preset_cell.dart';

/// One-tap access to the material presets: the demonstration preset this
/// screen defaults to, plus the three fitted against real iOS 27 captures,
/// so the values the design bible calls out are never more than a tap
/// away from the raw sliders.
class MaterialPresetRow extends StatelessWidget {
  /// Creates the row.
  const MaterialPresetRow({required this.onPresetSelected, super.key});

  /// Called with the preset's fully-formed material.
  final ValueChanged<GlassMaterial> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MaterialPresetCell(
            label: 'Demonstration',
            onTap: () => onPresetSelected(demonstrationGlassMaterial()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MaterialPresetCell(
            label: 'Regular · Dark',
            onTap: () => onPresetSelected(
              GlassMaterial.regular(brightness: Brightness.dark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MaterialPresetCell(
            label: 'Regular · Light',
            onTap: () => onPresetSelected(
              GlassMaterial.regular(brightness: Brightness.light),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MaterialPresetCell(
            label: 'Clear',
            onTap: () => onPresetSelected(GlassMaterial.clear()),
          ),
        ),
      ],
    );
  }
}
