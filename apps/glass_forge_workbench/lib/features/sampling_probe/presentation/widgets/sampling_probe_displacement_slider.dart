import 'package:glass_forge_workbench/exports.dart';

/// Controls the glass material's peak edge displacement.
///
/// Displacement is what the shipped shader multiplies by devicePixelRatio
/// before it ever reaches a texture lookup — so this is the knob that
/// decides whether a given DPR crosses into visible texel snapping.
class SamplingProbeDisplacementSlider extends StatelessWidget {
  /// Creates the slider.
  const SamplingProbeDisplacementSlider({
    required this.edgeRefraction,
    required this.onChanged,
    super.key,
  });

  /// The current peak edge displacement, in logical pixels.
  final double edgeRefraction;

  /// Called with the new displacement value.
  final ValueChanged<double> onChanged;

  static const _maxDisplacement = 60.0;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final physicalDisplacement = edgeRefraction * devicePixelRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Edge displacement: ${edgeRefraction.toStringAsFixed(1)} lpx '
          '(${physicalDisplacement.toStringAsFixed(1)} px at '
          '${devicePixelRatio.toStringAsFixed(1)}x)',
          style: context.callout.copyWith(color: AppColors.textSecondary),
        ),
        SliderTheme(
          data: SliderThemeData(
            thumbSize: WidgetStateProperty.all(const Size(13, 13)),
            activeTrackColor: AppColors.textPrimary,
            trackHeight: 4,
            inactiveTrackColor: AppColors.hairlineStrong,
            thumbColor: AppColors.textPrimary,
            overlayColor: AppColors.accentSoft,
          ),
          child: Slider(
            value: edgeRefraction,
            max: _maxDisplacement,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
