import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_segmented_control.dart';

class SegmentedDemo extends StatefulWidget {
  const SegmentedDemo({required this.count, super.key});

  final int count;

  @override
  State<SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<SegmentedDemo> {
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.demoDay,
      l10n.demoWeek,
      l10n.demoMonth,
      l10n.demoYear,
    ].take(widget.count).toList();
    return ValueListenableBuilder<int>(
      valueListenable: _index,
      builder: (context, index, _) => GlassSegmentedControl<int>(
        values: [for (var i = 0; i < labels.length; i++) i],
        labelOf: (i) => labels[i],
        selected: index.clamp(0, labels.length - 1),
        onChanged: (value) => _index.value = value,
      ),
    );
  }
}
