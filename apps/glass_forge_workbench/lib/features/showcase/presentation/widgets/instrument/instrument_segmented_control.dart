import 'package:glass_forge_workbench/exports.dart';

/// A labelled pill-segmented control for the instrument panel.
///
/// Colour-only selection fails the same way `BackdropRail` documents, so
/// the selected option always carries a text label and a background fill,
/// never colour alone.
class InstrumentSegmentedControl<T> extends StatelessWidget {
  /// Creates the control.
  const InstrumentSegmentedControl({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The selectable values, in display order.
  final List<T> values;

  /// The label shown for each entry in [values], by index.
  final List<String> labels;

  /// The currently selected value.
  final T selected;

  /// Called with the newly picked value.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.stageGround,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stageBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(values[i]),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? AppColors.stageForeground.withValues(alpha: 0.12)
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: context.captionMedium.copyWith(
                      color: values[i] == selected
                          ? AppColors.stageForeground
                          : AppColors.stageForegroundMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
