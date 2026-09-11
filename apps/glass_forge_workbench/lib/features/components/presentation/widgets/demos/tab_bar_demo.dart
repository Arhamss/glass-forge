import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_item.dart';

/// A live tab bar that remembers which tab you picked.
class TabBarDemo extends StatefulWidget {
  const TabBarDemo({
    required this.count,
    required this.showLabels,
    required this.badge,
    required this.squash,
    required this.springSeconds,
    super.key,
  });

  final int count;
  final bool showLabels;
  final bool badge;
  final double squash;
  final double springSeconds;

  @override
  State<TabBarDemo> createState() => _TabBarDemoState();
}

class _TabBarDemoState extends State<TabBarDemo> {
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = [
      GlassTabBarItem(
        label: l10n.demoHome,
        icon: AssetPaths.house,
        activeIcon: AssetPaths.houseFill,
      ),
      GlassTabBarItem(
        label: l10n.demoExplore,
        icon: AssetPaths.compass,
        activeIcon: AssetPaths.compassFill,
      ),
      GlassTabBarItem(
        label: l10n.demoSaved,
        icon: AssetPaths.heart,
        activeIcon: AssetPaths.heartFill,
        badge: widget.badge,
      ),
      GlassTabBarItem(
        label: l10n.demoProfile,
        icon: AssetPaths.user,
        activeIcon: AssetPaths.user,
      ),
      GlassTabBarItem(
        label: l10n.demoInbox,
        icon: AssetPaths.bell,
        activeIcon: AssetPaths.bell,
      ),
    ];
    return ValueListenableBuilder<int>(
      valueListenable: _index,
      builder: (context, index, _) => GlassTabBar(
        items: all.take(widget.count).toList(),
        currentIndex: index.clamp(0, widget.count - 1),
        onChanged: (value) => _index.value = value,
        showLabels: widget.showLabels,
        squash: widget.squash,
        selectorDuration: Duration(
          milliseconds: (widget.springSeconds * 1000).round(),
        ),
      ),
    );
  }
}
