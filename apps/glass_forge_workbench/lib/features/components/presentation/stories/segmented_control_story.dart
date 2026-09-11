import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/demos/segmented_demo.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

ComponentStory segmentedControlStory() => ComponentStory(
  knobs: [
    StepperKnob(
      id: 'options',
      label: Localization.knobOptions,
      min: 2,
      max: 4,
      initialValue: 3,
    ),
  ],
  builder: (context, values) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.s32),
    child: SegmentedDemo(count: values.stepper('options')),
  ),
  code: (values) =>
      '''
GlassSegmentedControl<Range>(
  values: Range.values, // ${values.stepper('options')} options
  labelOf: (range) => range.label,
  selected: range,
  onChanged: (value) => setState(() => range = value),
)''',
);
