import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_panel.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';

/// The instrument's "Geometry" group: thickness, edge refraction, and how
/// far the refraction band reaches inward.
class GeometryGroup extends StatelessWidget {
  /// Creates the group.
  const GeometryGroup({
    required this.thickness,
    required this.edgeRefraction,
    required this.refractionSpread,
    required this.onThicknessChanged,
    required this.onEdgeRefractionChanged,
    required this.onRefractionSpreadChanged,
    this.showRefractionSpread = true,
    super.key,
  });

  /// The material's current thickness.
  final double thickness;

  /// The material's current peak edge displacement.
  final double edgeRefraction;

  /// The material's current refraction spread.
  final double refractionSpread;

  /// Called with the newly dragged thickness.
  final ValueChanged<double> onThicknessChanged;

  /// Called with the newly dragged edge refraction.
  final ValueChanged<double> onEdgeRefractionChanged;

  /// Called with the newly dragged refraction spread.
  final ValueChanged<double> onRefractionSpreadChanged;

  /// A dome bends across its whole face, so spread does nothing to it and
  /// its slider would be a control with no effect.
  final bool showRefractionSpread;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: context.l10n.groupGeometry,
      cells: [
        InstrumentSlider(
          label: context.l10n.knobThickness,
          value: thickness,
          unit: 'px',
          max: 40,
          onChanged: onThicknessChanged,
        ),
        InstrumentSlider(
          label: context.l10n.knobEdgeRefraction,
          value: edgeRefraction,
          unit: 'px',
          max: 80,
          onChanged: onEdgeRefractionChanged,
        ),
        if (showRefractionSpread)
          InstrumentSlider(
            label: context.l10n.knobRefractionSpread,
            value: refractionSpread,
            unit: 'px',
            max: 40,
            onChanged: onRefractionSpreadChanged,
          ),
      ],
    );
  }
}
