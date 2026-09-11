import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

class GlassContextMenuRow extends StatelessWidget {
  const GlassContextMenuRow({
    required this.action,
    required this.onTap,
    super.key,
  });

  final GlassContextAction action;
  final VoidCallback onTap;

  static const double _minHeight = 48;
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? AppColors.danger : AppColors.textPrimary;
    return PressableScale(
      onTap: onTap,
      semanticLabel: action.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              AppSvgIcon(action.icon, size: _iconSize, color: color),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.body.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
