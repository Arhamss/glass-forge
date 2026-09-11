import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/knob_row.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

class VariantsPane extends StatelessWidget {
  const VariantsPane({required this.knobs, super.key});

  final List<StoryKnob> knobs;

  @override
  Widget build(BuildContext context) {
    if (knobs.isEmpty) {
      return Text(
        context.l10n.noKnobs,
        style: context.body.copyWith(color: AppColors.textSecondary),
      );
    }
    return BlocBuilder<PlaygroundCubit, PlaygroundState>(
      buildWhen: (previous, current) => previous.values != current.values,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final knob in knobs) ...[
            if (knob != knobs.first)
              const Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.s12,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.hairline,
                ),
              ),
            KnobRow(
              knob: knob,
              values: state.values,
              onChanged: context.read<PlaygroundCubit>().setKnob,
            ),
          ],
        ],
      ),
    );
  }
}
