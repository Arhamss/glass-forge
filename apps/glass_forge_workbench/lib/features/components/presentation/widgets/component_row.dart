import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

class ComponentRow extends StatelessWidget {
  const ComponentRow({required this.component, this.onTap, super.key});

  final ComponentId component;

  /// Null shows the row without a destination.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(color: AppColors.hairline),
            ),
            alignment: Alignment.center,
            child: AppSvgIcon(component.glyph, size: 20),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(component.title, style: context.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  component.summary,
                  style: context.calloutRegular.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s8),
            const AppSvgIcon(
              AssetPaths.caretRight,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(
        label: '${component.title}. ${component.summary}',
        excludeSemantics: true,
        child: row,
      );
    }
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: '${component.title}. ${component.summary}',
      child: row,
    );
  }
}
