import 'package:glass_forge_workbench/exports.dart';

/// The instrument panel's low-opacity technical grid.
///
/// Per the design bible, texture is reserved for the instrument (a subtle
/// technical grid) while the stage carries real content — this is the
/// panel's half of that split.
class InstrumentGridTexture extends StatelessWidget {
  /// Creates the texture.
  const InstrumentGridTexture({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: InstrumentGridPainter()),
    );
  }
}

/// Paints [InstrumentGridTexture]'s grid lines.
class InstrumentGridPainter extends CustomPainter {
  /// Creates the painter.
  const InstrumentGridPainter();

  static const _spacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.stageDivider.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant InstrumentGridPainter oldDelegate) => false;
}
