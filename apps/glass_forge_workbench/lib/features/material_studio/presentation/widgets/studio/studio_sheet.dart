import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_state.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_cubit.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_state.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/layout/shell_insets.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group_label.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_knob_panels.dart';

/// The house material's knobs, one group at a time so each fits on screen.
class StudioSheet extends StatelessWidget {
  const StudioSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadiusDirectional.vertical(
          top: Radius.circular(AppRadius.r24),
        ),
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: BlocBuilder<MaterialStudioCubit, MaterialStudioState>(
        buildWhen: (previous, current) => previous.group != current.group,
        builder: (context, studio) => Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.s16,
                AppSpacing.gutter,
                AppSpacing.s8,
              ),
              child: InstrumentSegmentedControl<MaterialGroup>(
                values: MaterialGroup.values,
                labels: [for (final group in MaterialGroup.values) group.label],
                selected: studio.group,
                onChanged: context.read<MaterialStudioCubit>().setGroup,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.s8,
                  AppSpacing.gutter,
                  ShellInsets.bottomClearance(context),
                ),
                child: BlocBuilder<HouseGlassCubit, HouseGlassState>(
                  buildWhen: (previous, current) =>
                      previous.material != current.material,
                  builder: (context, house) => MaterialKnobPanels(
                    material: house.material,
                    groups: [studio.group],
                    onChanged: context.read<HouseGlassCubit>().update,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
