import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/shell/presentation/widgets/scroll_edge_fade.dart';
import 'package:glass_forge_workbench/features/shell/presentation/widgets/shell_fade_through.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_tab.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_item.dart';
import 'package:glass_forge_workbench/utils/widgets/layout/shell_insets.dart';

/// The four tabs, and the floating glass tab bar that switches them.
///
/// An indexed stack, so a tab keeps its scroll position and its state while
/// another is on screen.
class WorkbenchShell extends StatelessWidget {
  const WorkbenchShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: ShellFadeThrough(index: shell.currentIndex, child: shell),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade.top(
              extent: MediaQuery.paddingOf(context).top + AppSpacing.s16,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScrollEdgeFade.bottom(
              extent: ShellInsets.bottomClearance(context) + AppSpacing.s16,
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.gutter,
            end: AppSpacing.gutter,
            bottom: ShellInsets.tabBarBottom(context),
            child: GlassTabBar(
              currentIndex: shell.currentIndex,
              onChanged: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              items: [
                for (final tab in WorkbenchTab.values)
                  GlassTabBarItem(
                    label: tab.label,
                    icon: tab.icon,
                    activeIcon: tab.activeIcon,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
