import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_backdrop_style.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_segmented_control.dart';

/// Switches the probe between the worst-case stress backdrop and a smooth,
/// photographic-style stand-in.
class SamplingProbeBackdropStyleToggle extends StatelessWidget {
  /// Creates the toggle.
  const SamplingProbeBackdropStyleToggle({
    required this.style,
    required this.onChanged,
    super.key,
  });

  /// The currently selected backdrop style.
  final SamplingProbeBackdropStyle style;

  /// Called with the newly selected style.
  final ValueChanged<SamplingProbeBackdropStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentSegmentedControl<SamplingProbeBackdropStyle>(
      values: SamplingProbeBackdropStyle.values,
      labels: [
        for (final value in SamplingProbeBackdropStyle.values) value.label,
      ],
      selected: style,
      onChanged: onChanged,
    );
  }
}
