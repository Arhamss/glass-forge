import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_item.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_bar_tab.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_selector.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/segment_scrubber.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

/// A floating glass capsule of two to five tabs.
///
/// Tap a tab, or drag across the bar to scrub: the selector follows the
/// finger, ticks at every tab it crosses, and commits on release.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.showLabels = true,
    this.material,
    this.squash = 0.8,
    this.selectorDuration = const Duration(milliseconds: 420),
    super.key,
  }) : assert(
         items.length >= 2 && items.length <= 5,
         'a tab bar holds two to five tabs',
       );

  static const double heightWithLabels = 64;
  static const double heightIconsOnly = 56;
  static const double _selectorInset = 4;

  final List<GlassTabBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool showLabels;

  /// Null uses the house material.
  final GlassMaterial? material;

  /// How much the selector stretches in flight, 0 (rigid) to 1.
  final double squash;
  final Duration selectorDuration;

  @override
  Widget build(BuildContext context) {
    final height = showLabels ? heightWithLabels : heightIconsOnly;
    final animate = !context.reduceMotion;
    return DecoratedBox(
      // Painted before the glass, so the glass bends it too: the bar reads
      // as lifted off the content, and its labels get a darker ground.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 28,
            offset: Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: SizedBox(
        height: height,
        child: KitGlassLayer(
          priority: GlassPriority.chrome,
          material: material,
          shape: GlassSuperellipse(
            radius: BorderRadius.all(Radius.circular(height / 2)),
          ),
          child: ColoredBox(
            color: AppColors.glassChromeScrim,
            child: SegmentScrubber(
              count: items.length,
              currentIndex: currentIndex,
              onChanged: onChanged,
              inset: _selectorInset,
              builder: (context, alignment, shownIndex, select) => Stack(
                children: [
                  Positioned.fill(
                    child: GlassTabSelector(
                      alignment: alignment,
                      count: items.length,
                      squash: squash,
                      duration: selectorDuration,
                      animate: animate,
                    ),
                  ),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: GlassTabBarTab(
                              item: items[i],
                              isSelected: i == shownIndex,
                              showLabel: showLabels,
                              onTap: () => select(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
