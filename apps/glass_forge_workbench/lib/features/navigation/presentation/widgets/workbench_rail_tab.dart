import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/workbench_section.dart';

/// One tab in the `WorkbenchRail`.
///
/// Labelled rather than iconographic, and selected by fill rather than by
/// colour alone — the same selection vocabulary the backdrop rail and the
/// instrument's segmented controls already use.
class WorkbenchRailTab extends StatelessWidget {
  /// Creates the tab.
  const WorkbenchRailTab({
    required this.section,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The section this tab switches to.
  final WorkbenchSection section;

  /// Whether this section is the one on screen.
  final bool isSelected;

  /// Called when the tab is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: section.label,
      hint: section.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stageForeground.withValues(alpha: 0.12)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            section.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.captionMedium.copyWith(
              color: isSelected
                  ? AppColors.stageForeground
                  : AppColors.stageForegroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}
