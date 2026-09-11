import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_state.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// The blend playground's whole instrument: two numbers and a shape count.
///
/// Collapsed on purpose. Every knob the specimen screen offers would apply
/// here too, and none of them would tell you anything about the fold.
class BlendControlsGroup extends StatelessWidget {
  /// Creates the group.
  const BlendControlsGroup({
    required this.state,
    required this.onBlendChanged,
    required this.onSeparationChanged,
    required this.onArrangementChanged,
    super.key,
  });

  /// The current state of the stage.
  final BlendState state;

  /// Called as the merge width is dragged.
  final ValueChanged<double> onBlendChanged;

  /// Called as the centre distance is dragged.
  final ValueChanged<double> onSeparationChanged;

  /// Called with the newly picked shape count.
  final ValueChanged<BlendArrangement> onArrangementChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Blend',
      cells: [
        InstrumentSlider(
          label: 'Blend width',
          value: state.blend,
          unit: 'px',
          max: BlendState.maxBlend,
          fractionDigits: 0,
          onChanged: onBlendChanged,
        ),
        InstrumentSlider(
          label: 'Separation',
          value: state.separation,
          unit: 'px',
          min: BlendState.minSeparation,
          max: BlendState.maxSeparation,
          fractionDigits: 0,
          onChanged: onSeparationChanged,
        ),
        InstrumentSegmentedControl<BlendArrangement>(
          values: BlendArrangement.values,
          labels: [for (final value in BlendArrangement.values) value.label],
          selected: state.arrangement,
          onChanged: onArrangementChanged,
        ),
        const InstrumentNote(
          text: 'Bring the gap under the blend width and the shapes should '
              'grow a neck between them before their edges ever meet. Two '
              'circles that only join at the moment they intersect are not '
              'folding. They are overlapping.',
        ),
      ],
    );
  }
}
