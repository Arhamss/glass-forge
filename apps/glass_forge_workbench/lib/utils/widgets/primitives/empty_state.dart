import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/solid_button.dart';

/// What a list says when it has nothing to show, and the one thing to do
/// about it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.s32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(color: AppColors.hairline),
            ),
            alignment: Alignment.center,
            child: AppSvgIcon(icon, size: 26, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(title, textAlign: TextAlign.center, style: context.headline),
          const SizedBox(height: AppSpacing.s8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.body.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.s20),
            SolidButton.secondary(label: actionLabel, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
