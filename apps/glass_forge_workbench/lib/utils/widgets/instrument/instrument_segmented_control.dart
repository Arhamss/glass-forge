import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/primitives/pressable_scale.dart';

/// A solid segmented control for the tinker sheets. The selected option
/// carries a fill and a brighter label, never colour alone.
class InstrumentSegmentedControl<T> extends StatelessWidget {
  const InstrumentSegmentedControl({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<T> values;

  /// The label for each entry in [values], by index.
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(3),
        child: Row(
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: PressableScale(
                  onTap: values[i] == selected
                      ? () {}
                      : () => onChanged(values[i]),
                  haptic: values[i] != selected,
                  pressedScale: 0.96,
                  isSelected: values[i] == selected,
                  semanticLabel: labels[i],
                  child: AnimatedContainer(
                    duration: AppMotion.select,
                    curve: AppMotion.selectCurve,
                    constraints: const BoxConstraints(minHeight: 38),
                    alignment: Alignment.center,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      color: values[i] == selected
                          ? AppColors.selectedFill
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: values[i] == selected
                            ? AppColors.hairlineStrong
                            : AppColors.transparent,
                      ),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.callout.copyWith(
                        color: values[i] == selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
