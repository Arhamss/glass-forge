import 'dart:math' as math;

import 'package:glass_forge_workbench/exports.dart';

/// Proves the renderer doesn't shimmer along a high-frequency, off-axis
/// edge.
///
/// A diagonal line crosses every scanline at a slightly different
/// sub-pixel offset, which is exactly the condition that produces visible
/// aliasing or shimmer if the glass's edge sampling isn't stable frame to
/// frame. The checkerboard backdrop tests axis-aligned snapping; this one
/// tests the off-axis case a checkerboard can't reach.
class DiagonalsBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const DiagonalsBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.stageGround,
      child: SizedBox.expand(child: CustomPaint(painter: DiagonalsPainter())),
    );
  }
}

/// Paints [DiagonalsBackdrop]'s stripes.
class DiagonalsPainter extends CustomPainter {
  /// Creates the painter.
  const DiagonalsPainter();

  static const _stripeWidth = 3.0;

  // Backdrop content, not UI chrome — deliberately outside AppColors, the
  // same way a photograph's pixels would be.
  static const _lightStripe = Color(0xFF3A4258);
  static const _darkStripe = Color(0xFF0A0E17);

  @override
  void paint(Canvas canvas, Size size) {
    final diagonal = size.width + size.height;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(math.pi / 4)
      ..translate(-diagonal / 2, -diagonal / 2);

    var offset = 0.0;
    var useLightStripe = true;
    while (offset < diagonal) {
      canvas.drawRect(
        Rect.fromLTWH(offset, 0, _stripeWidth, diagonal),
        Paint()..color = useLightStripe ? _lightStripe : _darkStripe,
      );
      offset += _stripeWidth;
      useLightStripe = !useLightStripe;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiagonalsPainter oldDelegate) => false;
}
