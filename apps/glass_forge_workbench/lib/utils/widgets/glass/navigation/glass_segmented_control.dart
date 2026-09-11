import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/helpers/reduce_motion.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_tab_selector.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/segment_scrubber.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/glass_priority.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A glass track of two to five options with a selector that slides — and
/// can be scrubbed — between them.
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.material,
    super.key,
  });

  static const double height = 40;
  static const double _inset = 3;

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Null uses the house material.
  final GlassMaterial? material;

  @override
  Widget build(BuildContext context) {
    final animate = !context.reduceMotion;
    return SizedBox(
      height: height,
      child: KitGlassLayer(
        priority: GlassPriority.chrome,
        material: material,
        shape: const GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(height / 2)),
        ),
        child: ColoredBox(
          color: AppColors.glassChromeScrim,
          child: SegmentScrubber(
            count: values.length,
            currentIndex: values.indexOf(selected),
            onChanged: (index) => onChanged(values[index]),
            inset: _inset,
            builder: (context, alignment, shownIndex, select) => Stack(
              children: [
                Positioned.fill(
                  child: GlassTabSelector(
                    alignment: alignment,
                    count: values.length,
                    squash: 0.6,
                    duration: const Duration(milliseconds: 380),
                    animate: animate,
                  ),
                ),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Row(
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: PressableScale(
                            onTap: () => select(i),
                            haptic: false,
                            pressedScale: 0.94,
                            isSelected: i == shownIndex,
                            semanticLabel: labelOf(values[i]),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: AppMotion.select,
                                style: context.callout.copyWith(
                                  color: i == shownIndex
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                                child: Text(
                                  labelOf(values[i]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
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
    );
  }
}
