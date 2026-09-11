import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/navigation/presentation/widgets/workbench_rail_tab.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_section.dart';

/// The workbench's section switcher: five labelled tabs on a solid
/// chassis at the foot of every screen.
///
/// Solid on purpose. A glass tab bar over a glass specimen would be the
/// one thing Apple's guidance rules out outright, and it would re-tint
/// every time the stage above it changed.
class WorkbenchRail extends StatelessWidget {
  /// Creates the rail.
  const WorkbenchRail({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// The index of the section currently on screen.
  final int currentIndex;

  /// Called with the newly picked section.
  final ValueChanged<WorkbenchSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stageRaised,
        border: BorderDirectional(
          top: BorderSide(color: AppColors.stageBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
          child: Row(
            children: [
              for (final section in WorkbenchSection.values)
                Expanded(
                  child: WorkbenchRailTab(
                    section: section,
                    isSelected: section.index == currentIndex,
                    onTap: () => onSelected(section),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
