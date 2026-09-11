import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/backdrop_thumbnail.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/playground_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';

/// The component, live, over the backdrop the user picked.
class PlaygroundStage extends StatelessWidget {
  const PlaygroundStage({required this.story, super.key});

  final ComponentStory story;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundCubit, PlaygroundState>(
      buildWhen: (previous, current) =>
          previous.values != current.values ||
          previous.backdrop != current.backdrop ||
          previous.materialOverride != current.materialOverride,
      builder: (context, state) {
        final override = state.materialOverride;
        final component = story.builder(context, state.values);
        return Stack(
          fit: StackFit.expand,
          children: [
            PlaygroundBackdropSurface(backdrop: state.backdrop),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      vertical: AppSpacing.s16,
                    ),
                    // Scales a component down rather than letting a tall one
                    // run under the backdrop picker. A transform, so the
                    // glass inside is unaffected.
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width,
                          child: Center(
                            child: override == null
                                ? component
                                : HouseGlass(
                                    material: override,
                                    child: component,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.s12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final backdrop in PlaygroundBackdrop.values)
                        BackdropThumbnail(
                          backdrop: backdrop,
                          isSelected: backdrop == state.backdrop,
                          onTap: () => context
                              .read<PlaygroundCubit>()
                              .setBackdrop(backdrop),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
