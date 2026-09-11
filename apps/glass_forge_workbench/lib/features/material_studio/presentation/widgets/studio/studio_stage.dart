import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/material_studio/data/models/studio_stage_mode.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_cubit.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_state.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_composition.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/widgets/studio/studio_specimen.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_segmented_control.dart';

/// The house material over a busy photograph, in context or on its own.
class StudioStage extends StatelessWidget {
  const StudioStage({super.key});

  static const double _toggleWidth = 240;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaterialStudioCubit, MaterialStudioState>(
      buildWhen: (previous, current) => previous.mode != current.mode,
      builder: (context, state) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Image.asset(
              AssetPaths.photoFlowerMarket,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: GlassSegmentedControl.height + AppSpacing.s24,
              bottom: AppSpacing.s16,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: switch (state.mode) {
                  StudioStageMode.inContext => const StudioComposition(),
                  StudioStageMode.shape => const StudioSpecimen(),
                },
              ),
            ),
          ),
          PositionedDirectional(
            top: AppSpacing.s12,
            start: 0,
            end: 0,
            child: Center(
              child: SizedBox(
                width: _toggleWidth,
                child: GlassSegmentedControl<StudioStageMode>(
                  values: StudioStageMode.values,
                  labelOf: (mode) => mode.label,
                  selected: state.mode,
                  onChanged: context.read<MaterialStudioCubit>().setMode,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
