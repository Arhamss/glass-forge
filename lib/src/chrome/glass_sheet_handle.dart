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

  /// The grabber's size, iOS's own: 36 × 5 points, fully rounded.
  static const Size _size = Size(36, 5);

  /// The grabber's alpha over the label colour. Apple's own indicator is a
  /// low-contrast fill, not the label colour at full strength: it is an
  /// affordance, not content.
  static const double _alpha = 0.3;

  /// Clear space above and below the grabber.
  static const double _verticalPadding = 8;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      child: Center(
        child: Container(
          width: _size.width,
          height: _size.height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: _alpha),
            borderRadius: BorderRadius.circular(_size.height / 2),
          ),
        ),
      ),
    );
  }
}
