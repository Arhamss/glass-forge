import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/navigation/presentation/widgets/workbench_rail.dart';

/// Holds the five workbench sections and the rail that switches between
/// them.
///
/// An indexed stack rather than five separate routes: a tier engine that
/// restarted its watchdog, or a spring that snapped home, every time you
/// glanced at another section would make the instrument useless for
/// comparison.
class WorkbenchShell extends StatelessWidget {
  /// Creates the shell.
  const WorkbenchShell({required this.shell, super.key});

  /// The navigation shell holding one branch per section.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stageGround,
      body: shell,
      bottomNavigationBar: WorkbenchRail(
        currentIndex: shell.currentIndex,
        onSelected: (section) => shell.goBranch(
          section.index,
          initialLocation: section.index == shell.currentIndex,
        ),
      ),
    );
  }
}
