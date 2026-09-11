import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/buttons/glass_button.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';

ComponentStory toastStory() => ComponentStory(
  knobs: [
    ToggleKnob(id: 'icon', label: Localization.knobIcon, initialValue: true),
  ],
  builder: (context, values) => GlassButton.secondary(
    label: context.l10n.demoShowToast,
    onPressed: () => showGlassToast(
      context,
      message: context.l10n.demoToastMessage,
      icon: values.toggle('icon') ? AssetPaths.bookmarkSimpleFill : null,
    ),
  ),
  code: (values) =>
      '''
showGlassToast(
  context,
  message: 'Saved to your list',${values.toggle('icon') ? '\n  icon: AssetPaths.bookmarkSimpleFill,' : ''}
);''',
);
