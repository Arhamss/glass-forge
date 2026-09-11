import 'package:glass_forge_workbench/exports.dart';

/// One tappable cell in a `MaterialPresetRow`.
class MaterialPresetCell extends StatelessWidget {
  /// Creates the cell.
  const MaterialPresetCell({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// The preset's name, e.g. `'Regular · Dark'`.
  final String label;

  /// Whether the specimen's material currently equals this preset.
  ///
  /// Without this a preset row reads as dead: tapping a cell that is already
  /// active, or whose effect is subtle, gives no acknowledgement at all.
  final bool isSelected;

  /// Called when the cell is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stageForeground.withValues(alpha: 0.12)
              : AppColors.stageGround,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stageBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.captionMedium.copyWith(
            color: isSelected
                ? AppColors.stageForeground
                : AppColors.stageForegroundMuted,
          ),
        ),
      ),
    );
  }
}
