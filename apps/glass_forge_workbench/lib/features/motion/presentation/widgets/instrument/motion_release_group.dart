import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/enums/motion_release.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// What happens after the finger leaves.
///
/// The friction slider appears only for a free fling, because that is the
/// only time it does anything — a control that sits there doing nothing
/// teaches the wrong thing about the API.
class MotionReleaseGroup extends StatelessWidget {
  /// Creates the group.
  const MotionReleaseGroup({
    required this.release,
    required this.decayDrag,
    required this.onReleaseChanged,
    required this.onDecayDragChanged,
    super.key,
  });

  /// What letting go currently does.
  final MotionRelease release;

  /// The velocity a free fling retains per second.
  final double decayDrag;

  /// Called with the newly picked release behaviour.
  final ValueChanged<MotionRelease> onReleaseChanged;

  /// Called as the friction is dragged.
  final ValueChanged<double> onDecayDragChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Letting go',
      cells: [
        InstrumentSegmentedControl<MotionRelease>(
          values: MotionRelease.values,
          labels: [for (final value in MotionRelease.values) value.label],
          selected: release,
          onChanged: onReleaseChanged,
        ),
        if (release == MotionRelease.fliesFree)
          InstrumentSlider(
            label: 'Friction',
            value: decayDrag,
            unit: '',
            min: MotionState.minDecayDrag,
            max: MotionState.maxDecayDrag,
            fractionDigits: 3,
            onChanged: onDecayDragChanged,
          ),
        InstrumentNote(text: release.blurb),
      ],
    );
  }
}
