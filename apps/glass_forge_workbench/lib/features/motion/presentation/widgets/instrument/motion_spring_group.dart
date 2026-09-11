import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/enums/motion_spring_channel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_note.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// The three springs, one at a time.
///
/// Duration and bounce, never stiffness and damping: a spring described
/// the way the physics is written is a spring nobody can tune by feel.
class MotionSpringGroup extends StatelessWidget {
  /// Creates the group.
  const MotionSpringGroup({
    required this.channel,
    required this.spring,
    required this.onChannelChanged,
    required this.onDurationChanged,
    required this.onBounceChanged,
    super.key,
  });

  /// Which spring the sliders are editing.
  final MotionSpringChannel channel;

  /// That spring's current values.
  final GlassMotion spring;

  /// Called with the newly picked spring.
  final ValueChanged<MotionSpringChannel> onChannelChanged;

  /// Called as the period is dragged, in milliseconds.
  final ValueChanged<double> onDurationChanged;

  /// Called as the overshoot is dragged.
  final ValueChanged<double> onBounceChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Spring',
      cells: [
        InstrumentSegmentedControl<MotionSpringChannel>(
          values: MotionSpringChannel.values,
          labels: [
            for (final value in MotionSpringChannel.values) value.label,
          ],
          selected: channel,
          onChanged: onChannelChanged,
        ),
        InstrumentSlider(
          label: 'Duration',
          value: spring.duration.inMilliseconds.toDouble(),
          unit: 'ms',
          min: MotionState.minDurationMs,
          max: MotionState.maxDurationMs,
          fractionDigits: 0,
          onChanged: onDurationChanged,
        ),
        InstrumentSlider(
          label: 'Bounce',
          value: spring.bounce,
          unit: '',
          min: -1,
          max: 1,
          fractionDigits: 2,
          onChanged: onBounceChanged,
        ),
        InstrumentNote(text: channel.blurb),
        const InstrumentNote(
          text: 'Duration is the spring period, not how long it takes to '
              'stop. Bounce runs from -1, heavily overdamped, through 0, '
              'no overshoot, to 1. Retuning a spring re-seats the surface, '
              'so tune it first and throw it after.',
        ),
      ],
    );
  }
}
