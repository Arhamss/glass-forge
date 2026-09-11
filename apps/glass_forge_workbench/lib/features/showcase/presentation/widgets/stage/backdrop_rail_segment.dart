import 'package:glass_forge_workbench/exports.dart';

/// One label in the `BackdropRail` segmented control.
class BackdropRailSegment extends StatelessWidget {
  /// Creates the segment.
  const BackdropRailSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The backdrop's display name.
  final String label;

  /// Whether this segment is the currently picked backdrop.
  final bool isSelected;

  /// Called when the segment is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        // The hit area meets the 44pt touch-target floor even though the
        // visual pill below it stays thin — Center expands to fill this
        // box without stretching the pill it wraps.
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.stageForeground.withValues(alpha: 0.12)
                  : AppColors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: context.captionMedium.copyWith(
                color: isSelected
                    ? AppColors.stageForeground
                    : AppColors.stageForegroundMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
