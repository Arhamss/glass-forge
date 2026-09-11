import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// What the surface does while a finger is on it: how far it presses, and
/// how hard the rubber band fights being dragged away from rest.
class MotionTouchGroup extends StatelessWidget {
  /// Creates the group.
  const MotionTouchGroup({
    required this.pressScale,
    required this.overdragLimit,
    required this.overdragResistance,
    required this.onPressScaleChanged,
    required this.onOverdragLimitChanged,
    required this.onOverdragResistanceChanged,
    super.key,
  });

  /// What a fully pressed surface scales to.
  final double pressScale;

  /// The displacement the band approaches but never reaches.
  final double overdragLimit;

  /// The fraction of pointer movement that gets through at rest.
  final double overdragResistance;

  /// Called as the press depth is dragged.
  final ValueChanged<double> onPressScaleChanged;

  /// Called as the band's limit is dragged.
  final ValueChanged<double> onOverdragLimitChanged;

  /// Called as the band's resistance is dragged.
  final ValueChanged<double> onOverdragResistanceChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Under the finger',
      cells: [
        InstrumentSlider(
          label: 'Press depth',
          value: pressScale,
          unit: 'x',
          min: 0.8,
          max: 1,
          fractionDigits: 2,
          onChanged: onPressScaleChanged,
        ),
        InstrumentSlider(
          label: 'Band limit',
          value: overdragLimit,
          unit: 'px',
          min: MotionState.minOverdragLimit,
          max: MotionState.maxOverdragLimit,
          fractionDigits: 0,
          onChanged: onOverdragLimitChanged,
        ),
        InstrumentSlider(
          label: 'Band resistance',
          value: overdragResistance,
          unit: '',
          min: 0.05,
          max: 1,
          fractionDigits: 2,
          onChanged: onOverdragResistanceChanged,
        ),
        const InstrumentNote(
          text:
              'The band tracks the finger exactly at rest and approaches '
              'its limit without ever reaching it, so you can drag hard and '
              'the surface still never leaves its own layer. Push '
              'resistance to 1 and it follows one to one until the limit '
              'takes over.',
        ),
      ],
    );
  }
}
