import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';

ComponentStory buttonStory() => ComponentStory(
  knobs: [
    ChoiceKnob(
      id: 'style',
      label: Localization.knobStyle,
      options: [Localization.optionPrimary, Localization.optionSecondary],
    ),
    ToggleKnob(id: 'icon', label: Localization.knobIcon, initialValue: true),
    ToggleKnob(id: 'loading', label: Localization.knobLoading),
    ToggleKnob(id: 'disabled', label: Localization.knobDisabled),
    ToggleKnob(id: 'expand', label: Localization.knobFullWidth),
  ],
  builder: (context, values) {
    final label = context.l10n.demoContinue;
    final icon = values.toggle('icon') ? AssetPaths.check : null;
    final onPressed = values.toggle('disabled') ? null : () {};
    final button = values.choice('style') == 0
        ? GlassButton.primary(
            label: label,
            icon: icon,
            isLoading: values.toggle('loading'),
            expand: values.toggle('expand'),
            onPressed: onPressed,
          )
        : GlassButton.secondary(
            label: label,
            icon: icon,
            isLoading: values.toggle('loading'),
            expand: values.toggle('expand'),
            onPressed: onPressed,
          );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s32,
      ),
      child: button,
    );
  },
  code: (values) =>
      '''
GlassButton.${values.choice('style') == 0 ? 'primary' : 'secondary'}(
  label: 'Continue',${values.toggle('icon') ? '\n  icon: AssetPaths.check,' : ''}
  isLoading: ${values.toggle('loading')},
  expand: ${values.toggle('expand')},
  onPressed: ${values.toggle('disabled') ? 'null' : 'submit'},
)''',
);
