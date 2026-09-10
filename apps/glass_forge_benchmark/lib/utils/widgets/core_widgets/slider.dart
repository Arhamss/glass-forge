import 'package:glass_forge_benchmark/exports.dart';

class FeesSlider extends StatefulWidget {
  const FeesSlider({super.key, this.initialValue = 1, this.onChanged});

  final double initialValue;
  final ValueChanged<double>? onChanged;

  @override
  State<FeesSlider> createState() => _FeesSliderState();
}

class _FeesSliderState extends State<FeesSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fees',
              style: context.p1Medium.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              'Amount: \$ ${_value.toInt()}',
              style: context.p1Medium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: SliderTheme(
            data: SliderThemeData(
              thumbSize: WidgetStateProperty.all(const Size(13, 13)),
              activeTrackColor: AppColors.primary,
              trackHeight: 4,
              inactiveTrackColor: AppColors.primary,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: _value,
              min: 1,
              max: 500,
              onChanged: (value) {
                setState(() => _value = value);
                widget.onChanged?.call(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}
