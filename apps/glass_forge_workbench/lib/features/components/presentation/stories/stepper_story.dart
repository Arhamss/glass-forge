import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/stepper_demo.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

ComponentStory stepperStory() => ComponentStory(
  knobs: [
    StepperKnob(
      id: 'max',
      label: Localization.knobMax,
      min: 3,
      max: 12,
      initialValue: 8,
    ),
  ],
  builder: (context, values) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.s32),
    child: StepperDemo(max: values.stepper('max')),
  ),
  code: (values) =>
      '''
GlassStepper(
  value: guests,
  min: 1,
  max: ${values.stepper('max')},
  decrementLabel: 'Fewer guests',
  incrementLabel: 'More guests',
  onChanged: (value) => setState(() => guests = value),
)''',
);
