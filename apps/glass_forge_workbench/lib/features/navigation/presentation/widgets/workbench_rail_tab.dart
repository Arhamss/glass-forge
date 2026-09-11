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
        // Deliberately no `alignment:` on this Container. A Container with
        // an alignment and bounded parent constraints expands to fill the
        // parent — and this one's parent is a `bottomNavigationBar`, whose
        // maximum height is the whole screen. The tab grew to full height,
        // took the rail with it, and left the body no room at all: the app
        // launched showing nothing but a full-height selection pill.
        // Padding sizes the box to its text instead, `minHeight` keeps the
        // 44pt touch target, and `textAlign` does the centring alignment
        // was there for.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stageForeground.withValues(alpha: 0.12)
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            section.label,
            maxLines: 1,
            textAlign: TextAlign.center,
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
