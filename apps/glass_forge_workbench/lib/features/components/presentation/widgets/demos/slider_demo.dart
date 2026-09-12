import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_slider.dart';

class SliderDemo extends StatefulWidget {
  const SliderDemo({super.key});

  @override
  State<SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<SliderDemo> {
  final ValueNotifier<double> _value = ValueNotifier<double>(0.62);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.demoBrightness;
    return ValueListenableBuilder<double>(
      valueListenable: _value,
      builder: (context, value, _) {
        final percent = '${(value * 100).round()}%';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: context.bodyMedium)),
                Text(percent, style: context.mono),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            GlassSlider(
              value: value,
              semanticLabel: label,
              formatValue: (v) => '${(v * 100).round()}%',
              onChanged: (next) => _value.value = next,
            ),
          ],
        );
      },
    );
  }
}
