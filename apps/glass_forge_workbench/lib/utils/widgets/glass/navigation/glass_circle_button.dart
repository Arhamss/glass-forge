import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A 40 pt glass disc holding one icon, centred in a 44 pt target.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.badge = false,
    this.iconColor = AppColors.textPrimary,
    this.material,
    this.priority = GlassPriority.chrome,
    super.key,
  });

  static const double size = 40;
  static const double target = 44;
  static const double _badgeSize = 9;

  final String icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// A small accent dot at the top-end edge, for something unread.
  final bool badge;
  final Color iconColor;

  /// Null uses the house material.
  final GlassMaterial? material;
  final GlassPriority priority;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      pressedScale: 0.9,
      child: SizedBox.square(
        dimension: target,
        child: Center(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: KitGlassLayer(
                    priority: priority,
                    material: material,
                    shape: const GlassOval(),
                    child: ColoredBox(
                      color: AppColors.glassChromeScrim,
                      child: Center(
                        child: AppSvgIcon(icon, size: 20, color: iconColor),
                      ),
                    ),
                  ),
                ),
                if (badge)
                  const PositionedDirectional(
                    top: 1,
                    end: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: _badgeSize),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
