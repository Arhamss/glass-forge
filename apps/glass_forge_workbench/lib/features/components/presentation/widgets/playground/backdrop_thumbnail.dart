import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/components/presentation/widgets/playground/playground_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

class BackdropThumbnail extends StatelessWidget {
  const BackdropThumbnail({
    required this.backdrop,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final PlaygroundBackdrop backdrop;
  final bool isSelected;
  final VoidCallback onTap;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      isSelected: isSelected,
      semanticLabel: backdrop.label,
      pressedScale: 0.94,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppMotion.select,
            width: size,
            height: size,
            padding: const EdgeInsetsDirectional.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.r12 + 2),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.hairlineStrong,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r12 - 1),
              child: PlaygroundBackdropSurface(backdrop: backdrop),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            backdrop.label,
            style: context.caption.copyWith(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
