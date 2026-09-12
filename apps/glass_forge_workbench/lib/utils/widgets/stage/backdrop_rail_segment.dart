import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// One option in the `BackdropRail`.
class BackdropRailSegment extends StatelessWidget {
  const BackdropRailSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// The drawn height. The rail's own padding lifts the touch target to the
  /// 44 pt floor.
  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: label,
      pressedScale: 0.94,
      // A fixed height, not a minimum: a Container with an alignment and
      // loose constraints — which an Align at the foot of a stage hands it —
      // grows to the full height available, and the rail swallowed the stage.
      child: AnimatedContainer(
        duration: AppMotion.select,
        curve: AppMotion.selectCurve,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectedFill : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.rPill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.captionMedium.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
