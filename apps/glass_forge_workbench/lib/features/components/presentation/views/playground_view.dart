import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/component_stories.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/playground_sheet.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/playground_stage.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_circle_button.dart';
import 'package:glass_forge_workbench/utils/widgets/tool/tool_top_bar.dart';

/// One component, live over a backdrop, with every knob it has.
class PlaygroundView extends StatelessWidget {
  const PlaygroundView({required this.component, super.key});

  final ComponentId component;

  @override
  Widget build(BuildContext context) {
    final story = storyFor(component);
    return BlocProvider(
      create: (_) => PlaygroundCubit(story.knobs),
      child: Scaffold(
        backgroundColor: AppColors.ground,
        body: Column(
          children: [
            ToolTopBar(
              title: component.title,
              trailing: Builder(
                builder: (context) => SolidCircleButton(
                  icon: AssetPaths.arrowCounterClockwise,
                  semanticLabel: context.l10n.resetToDefaults,
                  onPressed: context.read<PlaygroundCubit>().reset,
                ),
              ),
            ),
            Expanded(flex: 54, child: PlaygroundStage(story: story)),
            Expanded(flex: 46, child: PlaygroundSheet(story: story)),
          ],
        ),
      ),
    );
  }
}
