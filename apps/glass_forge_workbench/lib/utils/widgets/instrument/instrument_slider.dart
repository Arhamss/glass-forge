import 'package:glass_forge_workbench/exports.dart';

/// One control row inside an `InstrumentPanel`: a label, a right-aligned
/// monospaced value with its unit, and a slider beneath.
///
/// Every number in the workbench is monospaced and carries a unit — this
/// is the one place that rule is enforced, since every material knob in
/// the app is built from this widget.
class InstrumentSlider extends StatelessWidget {
  /// Creates the slider row.
  const InstrumentSlider({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.fractionDigits = 1,
    super.key,
  });

  /// The knob's name, e.g. `'Thickness'`.
  final String label;

  /// The knob's current value.
  final double value;

  /// The value's unit, e.g. `'px'`. Empty for a ratio, which has none.
  final String unit;

  /// Called with the new value as the thumb is dragged.
  final ValueChanged<double> onChanged;

  /// The slider's minimum value.
  final double min;

  /// The slider's maximum value.
  final double max;

  /// How many digits after the decimal point the value is shown with.
  final int fractionDigits;

  String get _reading => unit.isEmpty
      ? value.toStringAsFixed(fractionDigits)
      : '${value.toStringAsFixed(fractionDigits)} $unit';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: context.callout.copyWith(
                color: AppColors.stageForegroundMuted,
              ),
            ),
            const Spacer(),
            Text(
              _reading,
              style: context.mono.copyWith(color: AppColors.stageForeground),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            // Material pads a slider by 24 pt on each side by default, which
            // pushed the track in from the label and value it belongs to.
            padding: EdgeInsets.zero,
            activeTrackColor: AppColors.stageForeground,
            inactiveTrackColor: AppColors.stageDivider,
            thumbColor: AppColors.stageForeground,
            overlayColor: AppColors.stageForeground.withValues(alpha: 0.12),
            thumbSize: WidgetStateProperty.all(const Size(14, 14)),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            // Without this a screen reader reads a percentage of the
            // track, which on a screen made of units is the one number
            // nobody wants.
            semanticFormatterCallback: (_) => '$label, $_reading',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
