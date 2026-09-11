import 'package:flutter/cupertino.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/data/models/knob_values.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_stepper.dart';

/// One knob, drawn as the control its kind calls for.
class KnobRow extends StatelessWidget {
  const KnobRow({
    required this.knob,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final StoryKnob knob;
  final KnobValues values;
  final void Function(String id, Object value) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      knob.label,
      style: context.bodyMedium.copyWith(color: AppColors.textSecondary),
    );
    return switch (knob) {
      ToggleKnob(:final id) => Row(
        children: [
          Expanded(child: label),
          CupertinoSwitch(
            value: values.toggle(id),
            activeTrackColor: AppColors.accent,
            onChanged: (on) => onChanged(id, on),
          ),
        ],
      ),
      final SliderKnob slider => InstrumentSlider(
        label: slider.label,
        value: values.slider(slider.id),
        min: slider.min,
        max: slider.max,
        unit: slider.unit,
        fractionDigits: slider.fractionDigits,
        onChanged: (v) => onChanged(slider.id, v),
      ),
      final StepperKnob stepper => Row(
        children: [
          Expanded(child: label),
          SolidStepper(
            value: values.stepper(stepper.id),
            min: stepper.min,
            max: stepper.max,
            decrementLabel: context.l10n.decrease,
            incrementLabel: context.l10n.increase,
            onChanged: (v) => onChanged(stepper.id, v),
          ),
        ],
      ),
      final ChoiceKnob choice => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: AppSpacing.s8),
          InstrumentSegmentedControl<int>(
            values: [for (var i = 0; i < choice.options.length; i++) i],
            labels: choice.options,
            selected: values.choice(choice.id),
            onChanged: (i) => onChanged(choice.id, i),
          ),
        ],
      ),
    };
  }
}
