import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_stat_card.dart';

ComponentStory statCardStory() => ComponentStory(
  knobs: [
    ChoiceKnob(
      id: 'delta',
      label: Localization.knobDelta,
      options: [
        Localization.optionNone,
        Localization.optionUp,
        Localization.optionDown,
      ],
      initialIndex: 1,
    ),
  ],
  builder: (context, values) {
    final l10n = context.l10n;
    return SizedBox(
      width: 200,
      child: GlassStatCard(
        label: l10n.demoSteps,
        value: '8,412',
        unit: l10n.demoStepsUnit,
        delta: switch (values.choice('delta')) {
          1 => '+12%',
          2 => '−4%',
          _ => null,
        },
        deltaIsPositive: values.choice('delta') != 2,
      ),
    );
  },
  code: (values) =>
      '''
GlassStatCard(
  label: 'Steps',
  value: '8,412',
  unit: 'today',${values.choice('delta') == 0 ? '' : "\n  delta: '${values.choice('delta') == 1 ? '+12%' : '−4%'}',\n  deltaIsPositive: ${values.choice('delta') == 1},"}
)''',
);
