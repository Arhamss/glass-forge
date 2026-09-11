import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_mode.dart';

/// Switches the probe between the shipped shader and the bilinear
/// reconstruction candidate.
class SamplingProbeModeToggle extends StatelessWidget {
  /// Creates the toggle.
  const SamplingProbeModeToggle({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  /// The currently selected mode.
  final SamplingProbeMode mode;

  /// Called with the newly selected mode.
  final ValueChanged<SamplingProbeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SlidingTab(
      initialIndex: SamplingProbeMode.values.indexOf(mode),
      labels: [for (final value in SamplingProbeMode.values) value.label],
      onTapCallbacks: [
        for (final value in SamplingProbeMode.values) () => onChanged(value),
      ],
    );
  }
}
