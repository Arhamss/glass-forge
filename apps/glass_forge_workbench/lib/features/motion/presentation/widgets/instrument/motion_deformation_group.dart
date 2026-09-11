import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// Squash and stretch, read straight off the translation spring's
/// velocity.
///
/// Not a spring of its own, which is why it never keeps wobbling after the
/// surface has stopped: it is largest exactly when the surface is fastest
/// and zero the instant it is still.
class MotionDeformationGroup extends StatelessWidget {
  /// Creates the group.
  const MotionDeformationGroup({
    required this.maxStretch,
    required this.halfSpeed,
    required this.onMaxStretchChanged,
    required this.onHalfSpeedChanged,
    super.key,
  });

  /// The stretch ratio approached at infinite speed.
  final double maxStretch;

  /// The speed at which half of it is reached.
  final double halfSpeed;

  /// Called as the stretch ceiling is dragged.
  final ValueChanged<double> onMaxStretchChanged;

  /// Called as the half-speed is dragged.
  final ValueChanged<double> onHalfSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Squash and stretch',
      cells: [
        InstrumentSlider(
          label: 'Most stretch',
          value: maxStretch,
          unit: 'x',
          min: 1,
          max: MotionState.maxStretchCeiling,
          fractionDigits: 2,
          onChanged: onMaxStretchChanged,
        ),
        InstrumentSlider(
          label: 'Half at',
          value: halfSpeed,
          unit: 'px/s',
          min: MotionState.minHalfSpeed,
          max: MotionState.maxHalfSpeed,
          fractionDigits: 0,
          onChanged: onHalfSpeedChanged,
        ),
        const InstrumentNote(
          text: 'The surface stretches along the direction it is moving '
              'and squashes across it by the reciprocal, so its area never '
              'changes. That is what stops a fast one from also looking '
              'like it grew. Take Most stretch to 1.00 and the deformation '
              'is gone, which is where Reduce Motion puts it.',
        ),
      ],
    );
  }
}
