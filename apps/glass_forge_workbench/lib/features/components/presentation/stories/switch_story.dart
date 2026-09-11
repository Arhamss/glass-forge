import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/switch_demo.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

ComponentStory switchStory() => ComponentStory(
  knobs: [ToggleKnob(id: 'disabled', label: Localization.knobDisabled)],
  builder: (context, values) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.s32),
    child: SwitchDemo(disabled: values.toggle('disabled')),
  ),
  code: (values) =>
      '''
GlassSwitch(
  value: wifi,
  semanticLabel: 'Wi-Fi',
  onChanged: ${values.toggle('disabled') ? 'null' : '(on) => setState(() => wifi = on)'},
)''',
);
