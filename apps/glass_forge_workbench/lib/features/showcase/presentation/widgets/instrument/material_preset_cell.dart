import 'package:glass_forge_workbench/exports.dart';

/// One tappable cell in a `MaterialPresetRow`.
class MaterialPresetCell extends StatelessWidget {
  /// Creates the cell.
  const MaterialPresetCell({
    required this.label,
    required this.onTap,
    super.key,
  });

  /// The preset's name, e.g. `'Regular · Dark'`.
  final String label;

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
          color: AppColors.stageGround,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stageBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.captionMedium.copyWith(
            color: AppColors.stageForegroundMuted,
          ),
        ),
      ),
    );
  }
}
