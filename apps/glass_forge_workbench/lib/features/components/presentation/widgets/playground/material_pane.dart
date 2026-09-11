import 'package:flutter/cupertino.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/features/house_glass/data/models/material_preset.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_knob_panels.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_preset_chips.dart';

/// Lets one playground wear its own material without touching the house
/// material every other screen uses.
class MaterialPane extends StatelessWidget {
  const MaterialPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PlaygroundCubit>();
    final house = HouseGlass.of(context);
    return BlocBuilder<PlaygroundCubit, PlaygroundState>(
      buildWhen: (previous, current) =>
          previous.materialOverride != current.materialOverride,
      builder: (context, state) {
        final override = state.materialOverride;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.useHouseMaterial, style: context.bodyMedium),
                ),
                CupertinoSwitch(
                  value: override == null,
                  activeTrackColor: AppColors.accent,
                  onChanged: (useHouse) =>
                      cubit.setMaterialOverride(useHouse ? null : house),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.useHouseMaterialNote,
              style: context.caption.copyWith(color: AppColors.textTertiary),
            ),
            if (override != null) ...[
              const SizedBox(height: AppSpacing.s20),
              MaterialPresetChips(
                selected: MaterialPreset.values
                    .where((preset) => preset.material == override)
                    .firstOrNull,
                onSelected: (preset) =>
                    cubit.setMaterialOverride(preset.material),
              ),
              const SizedBox(height: AppSpacing.s16),
              MaterialKnobPanels(
                material: override,
                groups: const [MaterialGroup.shape, MaterialGroup.optics],
                onChanged: cubit.setMaterialOverride,
              ),
            ],
          ],
        );
      },
    );
  }
}
