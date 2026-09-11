import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_item.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/app_svg_icon.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// One tab's icon and label. Selection shows as the filled glyph and the
/// accent together, never colour alone.
class GlassTabBarTab extends StatelessWidget {
  const GlassTabBarTab({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
    super.key,
  });

  final GlassTabBarItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  static const double _badgeSize = 8;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accent : AppColors.textSecondary;
    return PressableScale(
      onTap: onTap,
      haptic: false,
      pressedScale: 0.9,
      isSelected: isSelected,
      semanticLabel: item.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.select,
                child: AppSvgIcon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  color: color,
                ),
              ),
              if (item.badge)
                const PositionedDirectional(
                  top: -2,
                  end: -3,
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
          if (showLabel) ...[
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppMotion.select,
              style: context.captionMedium.copyWith(color: color),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
