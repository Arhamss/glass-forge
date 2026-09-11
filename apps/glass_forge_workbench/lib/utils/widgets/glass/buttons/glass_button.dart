import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/house_glass.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A glass capsule button. On a glass sheet it becomes a painted inset, so
/// the sheet stays the only backdrop pass under it.
class GlassButton extends StatelessWidget {
  const GlassButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  }) : _isPrimary = true;

  const GlassButton.secondary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  }) : _isPrimary = false;

  final String label;
  final VoidCallback? onPressed;
  final String? icon;

  /// Swaps the label for a spinner and stops taking taps, so a slow action
  /// cannot be sent twice.
  final bool isLoading;

  /// Whether the button fills the available width.
  final bool expand;

  final bool _isPrimary;

  static const double minHeight = 48;
  static const double _iconSize = 18;
  static const double _spinnerSize = 18;
  static const double _disabledAlpha = 0.4;

  // Clamped to half the height, so this is a capsule at any text size.
  static const _shape = GlassSuperellipse(
    radius: BorderRadius.all(Radius.circular(AppRadius.rPill)),
  );

  // Strong enough to read as the accent over any photo, while the glass
  // still bends what is behind it.
  static const double _primaryTintOpacity = 0.82;

  @override
  Widget build(BuildContext context) {
    final foreground = _isPrimary ? AppColors.onAccent : AppColors.textPrimary;
    // Only the label and icon dim. Fading the glass would need an opacity
    // layer above the backdrop pass, which breaks it on device.
    final color = onPressed == null
        ? foreground.withValues(alpha: _disabledAlpha)
        : foreground;
    final icon = this.icon;

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppSvgIcon(icon, size: _iconSize, color: color),
          const SizedBox(width: AppSpacing.s8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.callout.copyWith(color: color),
          ),
        ),
      ],
    );
    if (isLoading) {
      // The label stays in the layout, invisible, so the button keeps its
      // width and nothing beside it jumps.
      content = Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Visibility.maintain(visible: false, child: content),
          SizedBox.square(
            dimension: _spinnerSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ],
      );
    }

    Widget surface = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s12,
        ),
        child: content,
      ),
    );
    if (!_isPrimary) {
      surface = ColoredBox(color: AppColors.glassChromeScrim, child: surface);
    }

    return PressableScale(
      onTap: isLoading ? null : onPressed,
      pressedScale: 0.96,
      semanticLabel: label,
      child: KitGlassLayer(
        priority: GlassPriority.content,
        shape: _shape,
        material: _isPrimary
            ? HouseGlass.of(context).copyWith(
                tint: AppColors.accent,
                tintOpacity: _primaryTintOpacity,
              )
            : null,
        insetTint: _isPrimary ? AppColors.accent : null,
        child: surface,
      ),
    );
  }
}
