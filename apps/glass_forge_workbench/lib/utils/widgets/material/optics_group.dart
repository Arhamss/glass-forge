import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// The instrument's "Optics" group: how the backdrop is filtered before it
/// reaches the eye — blur, dispersion, and saturation.
class OpticsGroup extends StatelessWidget {
  /// Creates the group.
  const OpticsGroup({
    required this.frost,
    required this.chromaticAberration,
    required this.saturation,
    required this.onFrostChanged,
    required this.onChromaticAberrationChanged,
    required this.onSaturationChanged,
    super.key,
  });

  /// The material's current blur sigma.
  final double frost;

  /// The material's current channel dispersion.
  final double chromaticAberration;

  /// The material's current saturation multiplier.
  final double saturation;

  /// Called with the newly dragged frost.
  final ValueChanged<double> onFrostChanged;

  /// Called with the newly dragged chromatic aberration.
  final ValueChanged<double> onChromaticAberrationChanged;

  /// Called with the newly dragged saturation.
  final ValueChanged<double> onSaturationChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: context.l10n.groupOptics,
      cells: [
        InstrumentSlider(
          label: context.l10n.knobFrost,
          value: frost,
          unit: 'px',
          max: 30,
          onChanged: onFrostChanged,
        ),
        InstrumentSlider(
          label: context.l10n.knobChromatic,
          value: chromaticAberration,
          unit: 'px',
          max: 5,
          fractionDigits: 2,
          onChanged: onChromaticAberrationChanged,
        ),
        InstrumentSlider(
          label: context.l10n.knobSaturation,
          value: saturation,
          unit: '×',
          max: 3,
          fractionDigits: 2,
          onChanged: onSaturationChanged,
        ),
      ],
    );
  }
}
