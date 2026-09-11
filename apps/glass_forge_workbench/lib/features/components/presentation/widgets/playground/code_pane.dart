import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_button.dart';

/// The code for exactly what is on the stage.
class CodePane extends StatelessWidget {
  const CodePane({required this.story, super.key});

  final ComponentStory story;

  Future<void> _copy(BuildContext context, String code) async {
    final message = context.l10n.codeCopiedToast;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    showGlassToast(context, message: message, icon: AssetPaths.check);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaygroundCubit, PlaygroundState>(
      buildWhen: (previous, current) => previous.values != current.values,
      builder: (context, state) {
        final code = story.code(state.values);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ground,
                borderRadius: BorderRadius.circular(AppRadius.r16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.all(AppSpacing.s16),
                child: SelectableText(code, style: context.monoSmall),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SolidButton.secondary(
                label: context.l10n.copyCode,
                icon: AssetPaths.copy,
                onPressed: () => _copy(context, code),
              ),
            ),
          ],
        );
      },
    );
  }
}
