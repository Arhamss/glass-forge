import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_cubit.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';

void main() {
  const knobs = <StoryKnob>[
    StepperKnob(id: 'tabs', label: 'Tabs', min: 2, max: 5, initialValue: 4),
    ToggleKnob(id: 'labels', label: 'Labels', initialValue: true),
  ];

  test('starts on the knobs initial values with no override', () {
    final cubit = PlaygroundCubit(knobs);
    expect(cubit.state.values.stepper('tabs'), 4);
    expect(cubit.state.materialOverride, isNull);
  });

  test('knobs, backdrop and override change independently', () {
    final cubit = PlaygroundCubit(knobs)
      ..setKnob('tabs', 3)
      ..setBackdrop(PlaygroundBackdrop.checker)
      ..setMaterialOverride(GlassMaterial.clear());
    expect(cubit.state.values.stepper('tabs'), 3);
    expect(cubit.state.values.toggle('labels'), isTrue);
    expect(cubit.state.backdrop, PlaygroundBackdrop.checker);
    expect(cubit.state.materialOverride, GlassMaterial.clear());
  });

  test('reset restores the knobs and drops the override, keeps the view', () {
    final cubit = PlaygroundCubit(knobs)
      ..setKnob('tabs', 2)
      ..setBackdrop(PlaygroundBackdrop.black)
      ..setMaterialOverride(GlassMaterial.clear())
      ..reset();
    expect(cubit.state.values.stepper('tabs'), 4);
    expect(cubit.state.materialOverride, isNull);
    expect(cubit.state.backdrop, PlaygroundBackdrop.black);
  });
}
