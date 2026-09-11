import 'package:glass_forge_workbench/exports.dart';

/// A row of selectable tints for `GlassMaterial.tint`.
class TintSwatchRow extends StatelessWidget {
  /// Creates the row.
  const TintSwatchRow({required this.selected, required this.onChanged, super.key});

  /// The tint currently applied to the material.
  final Color selected;

  /// Called with the newly picked tint.
  final ValueChanged<Color> onChanged;

  // Selectable tint values for demonstrating GlassMaterial.tint — material
  // content, not semantic UI colour, so deliberately outside AppColors.
  // The same way PhotographicBackdrop's blob colours are.
  static const _swatches = [
    Color(0x00FFFFFF),
    Color(0xFFF4F1EA),
    Color(0xFF2B3A55),
    Color(0xFFB98442),
    Color(0xFF3E6E58),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final swatch in _swatches) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(swatch),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: swatch.a == 0 ? AppColors.stageGround : swatch,
                    border: Border.all(
                      color: swatch == selected
                          ? AppColors.stageForeground
                          : AppColors.stageBorder,
                      width: swatch == selected ? 2 : 1,
                    ),
                  ),
                  child: const SizedBox(width: 24, height: 24),
                ),
              ),
            ),
          ),
          if (swatch != _swatches.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
