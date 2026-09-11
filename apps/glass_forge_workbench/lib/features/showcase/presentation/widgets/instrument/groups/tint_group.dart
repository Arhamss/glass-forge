import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/tint_swatch_row.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument_panel.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument_slider.dart';

/// The instrument's "Tint" group: how strongly a colour is mixed into the
/// glass, and which colour.
class TintGroup extends StatelessWidget {
  /// Creates the group.
  const TintGroup({
    required this.tintOpacity,
    required this.tint,
    required this.onTintOpacityChanged,
    required this.onTintChanged,
    super.key,
  });

  /// The material's current tint strength, from 0 to 1.
  final double tintOpacity;

  /// The material's current tint colour.
  final Color tint;

  /// Called with the newly dragged tint opacity, from 0 to 1.
  final ValueChanged<double> onTintOpacityChanged;

  /// Called with the newly picked tint colour.
  final ValueChanged<Color> onTintChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Tint',
      cells: [
        InstrumentSlider(
          label: 'Tint opacity',
          value: tintOpacity * 100,
          unit: '%',
          onChanged: (double value) => onTintOpacityChanged(value / 100),
        ),
        TintSwatchRow(selected: tint, onChanged: onTintChanged),
      ],
    );
  }
}
