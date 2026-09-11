import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/controls/glass_switch.dart';

class SwitchDemo extends StatefulWidget {
  const SwitchDemo({required this.disabled, super.key});

  final bool disabled;

  @override
  State<SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<SwitchDemo> {
  final ValueNotifier<(bool, bool)> _values = ValueNotifier((true, false));

  @override
  void dispose() {
    _values.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<(bool, bool)>(
      valueListenable: _values,
      builder: (context, values, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, label) in [
            l10n.demoWifi,
            l10n.demoAirplane,
          ].indexed)
            Row(
              children: [
                Expanded(child: Text(label, style: context.bodyMedium)),
                GlassSwitch(
                  value: index == 0 ? values.$1 : values.$2,
                  semanticLabel: label,
                  onChanged: widget.disabled
                      ? null
                      : (on) => _values.value = index == 0
                            ? (on, values.$2)
                            : (values.$1, on),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
