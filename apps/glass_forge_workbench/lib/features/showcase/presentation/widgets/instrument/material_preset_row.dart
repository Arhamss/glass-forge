import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/material_preset_cell.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';

/// One-tap access to the material presets: the demonstration preset this
/// screen defaults to, the dome, and the three fitted against real iOS 27
/// captures, so the values the design bible calls out are never more than
/// a tap away from the raw sliders.
///
/// The dome sits beside the Apple presets on purpose. It is a different
/// optical model, not a different setting of the same one, and flipping
/// between the two over one backdrop is the quickest way to see what that
/// difference is.
class MaterialPresetRow extends StatelessWidget {
  /// Creates the row.
  const MaterialPresetRow({
    required this.material,
    required this.onPresetSelected,
    super.key,
  });

  /// Called with the preset's fully-formed material.
  final ValueChanged<GlassMaterial> onPresetSelected;

  /// The specimen's current material, used to mark the active preset.
  final GlassMaterial material;

  @override
  Widget build(BuildContext context) {
    final regularDark = GlassMaterial.regular(brightness: Brightness.dark);
    final regularLight = GlassMaterial.regular(brightness: Brightness.light);
    final dome = GlassMaterial.dome();
    final demonstration = demonstrationGlassMaterial();
    final clear = GlassMaterial.clear();

    // Two rows, split by where the numbers came from: the workbench's own
    // materials above, the ones fitted to iOS 27 captures below. Five in one
    // row left each cell too narrow to hold its name.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MaterialPresetCell(
                label: 'Demonstration',
                isSelected: material == demonstration,
                onTap: () => onPresetSelected(demonstration),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MaterialPresetCell(
                label: 'Dome',
                isSelected: material == dome,
                onTap: () => onPresetSelected(dome),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MaterialPresetCell(
                label: 'Regular · Dark',
                isSelected: material == regularDark,
                onTap: () => onPresetSelected(regularDark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MaterialPresetCell(
                label: 'Regular · Light',
                isSelected: material == regularLight,
                onTap: () => onPresetSelected(regularLight),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MaterialPresetCell(
                label: 'Clear',
                isSelected: material == clear,
                onTap: () => onPresetSelected(clear),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
