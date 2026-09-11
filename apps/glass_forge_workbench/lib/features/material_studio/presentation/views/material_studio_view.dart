import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_cubit.dart';
import 'package:glass_forge_workbench/features/house_glass/presentation/cubit/house_glass_state.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_cubit.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_header.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_sheet.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_stage.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_preset_chips.dart';

/// Tunes the house material: the one glass every kit component on every
/// screen wears.
class MaterialStudioView extends StatelessWidget {
  const MaterialStudioView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MaterialStudioCubit(),
      child: Scaffold(
        backgroundColor: AppColors.ground,
        body: Column(
          children: [
            const StudioHeader(),
            const Expanded(flex: 44, child: StudioStage()),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.s12,
              ),
              child: BlocBuilder<HouseGlassCubit, HouseGlassState>(
                buildWhen: (previous, current) =>
                    previous.preset != current.preset,
                builder: (context, state) => Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: MaterialPresetChips(
                    selected: state.preset,
                    onSelected: context.read<HouseGlassCubit>().applyPreset,
                  ),
                ),
              ),
            ),
            const Expanded(flex: 56, child: StudioSheet()),
          ],
        ),
      ),
    );
  }
}
