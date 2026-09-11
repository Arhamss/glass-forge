import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_circle_button.dart';

/// Minus, a value, plus, on solid chrome.
class SolidStepper extends StatelessWidget {
  const SolidStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.decrementLabel,
    required this.incrementLabel,
    super.key,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String decrementLabel;
  final String incrementLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SolidCircleButton(
          icon: AssetPaths.minus,
          semanticLabel: decrementLabel,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: context.mono,
          ),
        ),
        SolidCircleButton(
          icon: AssetPaths.plus,
          semanticLabel: incrementLabel,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
