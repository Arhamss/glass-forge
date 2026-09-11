import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/data/models/material_preset.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// The material presets as a row of chips. None is selected once the
/// material has been edited away from all of them.
class MaterialPresetChips extends StatelessWidget {
  const MaterialPresetChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MaterialPreset? selected;
  final ValueChanged<MaterialPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in MaterialPreset.values) ...[
            if (preset != MaterialPreset.values.first)
              const SizedBox(width: AppSpacing.s8),
            PressableScale(
              onTap: () => onSelected(preset),
              isSelected: preset == selected,
              semanticLabel: preset.label,
              pressedScale: 0.95,
              child: AnimatedContainer(
                duration: AppMotion.select,
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.s20,
                ),
                decoration: BoxDecoration(
                  color: preset == selected
                      ? AppColors.accentSoft
                      : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                  border: Border.all(
                    color: preset == selected
                        ? AppColors.accent
                        : AppColors.hairline,
                  ),
                ),
                child: Text(
                  preset.label,
                  style: context.callout.copyWith(
                    color: preset == selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
