import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A button on solid chrome — tinker sheets, empty states, tool screens.
/// On glass, use the kit's `GlassButton` instead.
class SolidButton extends StatelessWidget {
  const SolidButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    super.key,
  }) : _fill = AppColors.accent,
       _foreground = AppColors.onAccent,
       _border = AppColors.transparent;

  const SolidButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    super.key,
  }) : _fill = AppColors.surfaceRaised,
       _foreground = AppColors.textPrimary,
       _border = AppColors.hairlineStrong;

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  /// Whether the button fills the available width.
  final bool expand;

  final Color _fill;
  final Color _foreground;
  final Color _border;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final enabled = onPressed != null;
    return PressableScale(
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: AppMotion.select,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(AppRadius.rPill),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppSvgIcon(icon, size: 18, color: _foreground),
                const SizedBox(width: AppSpacing.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.callout.copyWith(color: _foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
