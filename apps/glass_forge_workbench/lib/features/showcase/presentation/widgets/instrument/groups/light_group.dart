import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument/light_direction_dial.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument_panel.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/instrument_slider.dart';

/// The instrument's "Light" group: rim highlight strength, edge contour,
/// and the direction the rim light comes from.
class LightGroup extends StatelessWidget {
  /// Creates the group.
  const LightGroup({
    required this.highlight,
    required this.contour,
    required this.lightDirection,
    required this.onHighlightChanged,
    required this.onContourChanged,
    required this.onLightDirectionChanged,
    super.key,
  });

  /// The material's current rim highlight strength.
  final double highlight;

  /// The material's current edge contour strength, from 0 to 1.
  final double contour;

  /// The material's current light direction.
  final Offset lightDirection;

  /// Called with the newly dragged highlight.
  final ValueChanged<double> onHighlightChanged;

  /// Called with the newly dragged contour, from 0 to 1.
  final ValueChanged<double> onContourChanged;

  /// Called with the newly picked light direction.
  final ValueChanged<Offset> onLightDirectionChanged;

  @override
  Widget build(BuildContext context) {
    return InstrumentPanel(
      title: 'Light',
      cells: [
        InstrumentSlider(
          label: 'Highlight',
          value: highlight,
          unit: '×',
          max: 3,
          fractionDigits: 2,
          onChanged: onHighlightChanged,
        ),
        InstrumentSlider(
          label: 'Contour',
          value: contour * 100,
          unit: '%',
          onChanged: (double value) => onContourChanged(value / 100),
        ),
        Row(
          children: [
            Text(
              'Direction',
              style: context.p2Medium.copyWith(
                color: AppColors.stageForegroundMuted,
              ),
            ),
            const Spacer(),
            LightDirectionDial(
              direction: lightDirection,
              onChanged: onLightDirectionChanged,
            ),
          ],
        ),
      ],
    );
  }
}
