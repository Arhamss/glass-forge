import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/components/data/models/knob_values.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';

void main() {
  const knobs = <StoryKnob>[
    ToggleKnob(id: 'labels', label: 'Labels', initialValue: true),
    SliderKnob(
      id: 'squash',
      label: 'Squash',
      min: 0,
      max: 1,
      initialValue: 0.8,
    ),
    StepperKnob(id: 'tabs', label: 'Tabs', min: 2, max: 5, initialValue: 4),
    ChoiceKnob(
      id: 'style',
      label: 'Style',
      options: ['A', 'B'],
      initialIndex: 1,
    ),
  ];

  test('starts every knob at its initial value', () {
    final values = KnobValues.initial(knobs);
    expect(values.toggle('labels'), isTrue);
    expect(values.slider('squash'), 0.8);
    expect(values.stepper('tabs'), 4);
    expect(values.choice('style'), 1);
  });

  test('set returns a new value set and leaves the old one alone', () {
    final before = KnobValues.initial(knobs);
    final after = before.set('tabs', 3);
    expect(after.stepper('tabs'), 3);
    expect(before.stepper('tabs'), 4);
    expect(after, isNot(before));
    expect(after.set('tabs', 4), before);
  });

  test('a slider formats its value with its unit', () {
    const knob = SliderKnob(
      id: 'r',
      label: 'Refraction',
      min: 0,
      max: 60,
      initialValue: 27.42,
      unit: 'px',
    );
    expect(knob.format(27.42), '27.4 px');
  });
}
