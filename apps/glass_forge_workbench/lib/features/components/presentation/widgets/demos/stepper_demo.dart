import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_stepper.dart';

class StepperDemo extends StatefulWidget {
  const StepperDemo({required this.max, super.key});

  final int max;

  @override
  State<StepperDemo> createState() => _StepperDemoState();
}

class _StepperDemoState extends State<StepperDemo> {
  final ValueNotifier<int> _value = ValueNotifier<int>(2);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<int>(
      valueListenable: _value,
      builder: (context, value, _) => Row(
        children: [
          Expanded(child: Text(l10n.demoGuests, style: context.bodyMedium)),
          GlassStepper(
            value: value.clamp(1, widget.max),
            min: 1,
            max: widget.max,
            decrementLabel: l10n.decrease,
            incrementLabel: l10n.increase,
            onChanged: (next) => _value.value = next,
          ),
        ],
      ),
    );
  }
}
