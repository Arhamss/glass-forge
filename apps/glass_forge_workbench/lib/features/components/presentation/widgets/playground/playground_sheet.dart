import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/code_pane.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/material_pane.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/variants_pane.dart';
import 'package:glass_forge_workbench/utils/enums/playground_pane.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';

/// The solid tinker sheet under the stage. Never glass: the controls must
/// stay legible whatever the stage is doing.
class PlaygroundSheet extends StatelessWidget {
  const PlaygroundSheet({required this.story, super.key});

  final ComponentStory story;

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
      child: BlocBuilder<PlaygroundCubit, PlaygroundState>(
        buildWhen: (previous, current) => previous.pane != current.pane,
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.s16,
                AppSpacing.gutter,
                AppSpacing.s8,
              ),
              child: InstrumentSegmentedControl<PlaygroundPane>(
                values: PlaygroundPane.values,
                labels: [for (final pane in PlaygroundPane.values) pane.label],
                selected: state.pane,
                onChanged: context.read<PlaygroundCubit>().setPane,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.s12,
                  AppSpacing.gutter,
                  AppSpacing.s24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: switch (state.pane) {
                  PlaygroundPane.variants => VariantsPane(knobs: story.knobs),
                  PlaygroundPane.material => const MaterialPane(),
                  PlaygroundPane.code => CodePane(story: story),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
