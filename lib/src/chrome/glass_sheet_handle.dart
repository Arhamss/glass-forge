import 'package:flutter/widgets.dart';

/// The grab indicator shared by this package's sheets.
///
/// Drawn, not a `Glass` of its own: a capsule of glass on a sheet of glass is
/// a second refraction over the first, which is the stacked filter this
/// package exists to avoid. `GlassHostScope` is the general form of this rule.
class GlassSheetHandle extends StatelessWidget {
  /// Creates a handle drawn in [color].
  const GlassSheetHandle({required this.color, super.key});

  /// The surface's label colour; drawn at low alpha.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            // Apple's own indicator is a low-contrast fill, not the label
            // colour at full strength: it is an affordance, not content.
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}
