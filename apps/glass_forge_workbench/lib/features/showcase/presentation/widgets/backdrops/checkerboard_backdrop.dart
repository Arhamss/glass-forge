import 'package:glass_forge_workbench/exports.dart';

/// The backdrop that makes refraction legible: bold, high-contrast squares
/// whose displacement at the specimen's rim is unmistakable.
///
/// Feature size is the whole point. Refraction is only visible as the
/// *offset of a recognisable feature*, so the backdrop's structure has to be
/// larger than the displacement — at a 64pt edge refraction, a 3pt stripe is
/// pushed through twenty-one whole periods and lands looking exactly like
/// itself. This was originally a 1-*physical*-pixel checkerboard, chosen to
/// expose half-pixel texel-snapping errors; at that size it averages to flat
/// grey, shows nothing to a viewer, and costs over a million rects a paint.
/// The high-frequency snapping case belongs to the diagonals backdrop, whose
/// off-axis stripes catch it without having to be invisible.
class CheckerboardBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const CheckerboardBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.stageGround,
      child: SizedBox.expand(
        child: CustomPaint(painter: CheckerboardPainter()),
      ),
    );
  }
}

/// Paints [CheckerboardBackdrop]'s grid.
///
/// Public (not `_`-prefixed) so a widget test can construct it directly and
/// assert [squareSize] stays large enough to survive being refracted.
class CheckerboardPainter extends CustomPainter {
  /// Creates the painter.
  const CheckerboardPainter();

  /// Edge length of one checker square, in logical pixels.
  ///
  /// Comfortably larger than the largest edge refraction the instrument
  /// offers, so the displacement at the rim reads as a *bent* square rather
  /// than an identical one a few periods over.
  double get squareSize => 28;

  // Backdrop content, not UI chrome — deliberately outside AppColors, the
  // same way a photograph's pixels would be.
  static const _lightSquare = Color(0xFF48536E);

  @override
  void paint(Canvas canvas, Size size) {
    final square = squareSize;
    final columns = (size.width / square).ceil();
    final rows = (size.height / square).ceil();

    final lightSquares = Path();
    final darkSquares = Path();

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final rect = Rect.fromLTWH(
          column * square,
          row * square,
          square,
          square,
        );
        if ((row + column).isEven) {
          lightSquares.addRect(rect);
        } else {
          darkSquares.addRect(rect);
        }
      }
    }

    canvas
      ..drawPath(lightSquares, Paint()..color = _lightSquare)
      ..drawPath(darkSquares, Paint()..color = AppColors.stageGround);
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) => false;
}
