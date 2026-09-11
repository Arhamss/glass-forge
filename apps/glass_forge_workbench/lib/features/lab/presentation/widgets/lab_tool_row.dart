import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/lab_tool.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

class LabToolRow extends StatelessWidget {
  const LabToolRow({required this.tool, required this.onTap, super.key});

  final LabTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: '${tool.title}. ${tool.summary}',
      child: Padding(
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
              child: AppSvgIcon(tool.icon, size: 20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.title, style: context.headline),
                  const SizedBox(height: 2),
                  Text(
                    tool.summary,
                    style: context.calloutRegular.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            const AppSvgIcon(
              AssetPaths.caretRight,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
