import 'package:glass_forge_workbench/exports.dart';

/// Proves the renderer snaps glass edges to true device pixels rather than
/// logical ones.
///
/// A checkerboard is the sharpest test available for texel snapping: any
/// half-pixel error in the geometry shows up as a visible shimmer or a
/// misaligned seam along the specimen's edge. To actually test that, the
/// squares must be exactly 1 *physical* pixel wide — at a 3x device pixel
/// ratio, a square sized to 1 *logical* pixel would be 3 physical pixels
/// wide and hide the error it exists to catch.
class CheckerboardBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const CheckerboardBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ColoredBox(
      color: AppColors.stageGround,
      child: SizedBox.expand(
        child: CustomPaint(
          painter: CheckerboardPainter(devicePixelRatio: devicePixelRatio),
        ),
      ),
    );
  }
}

/// Paints [CheckerboardBackdrop]'s grid at exactly 1 physical pixel per
/// square.
///
/// Public (not `_`-prefixed) so a widget test can construct it directly and
/// assert [squareSize] tracks the device pixel ratio rather than being
/// pinned to a fixed logical size.
class CheckerboardPainter extends CustomPainter {
  /// Creates the painter for the given [devicePixelRatio].
  const CheckerboardPainter({required this.devicePixelRatio});

  /// The device pixel ratio the checker squares are sized against.
  final double devicePixelRatio;

  /// Edge length of one checker square, in logical pixels.
  ///
  /// The canvas a [CustomPainter] draws into is scaled to the device pixel
  /// ratio at composite time, so a square this size in logical units
  /// rasterises to exactly one physical pixel.
  double get squareSize => 1 / devicePixelRatio;

  // Backdrop content, not UI chrome — deliberately outside AppColors, the
  // same way a photograph's pixels would be.
  static const _lightSquare = Color(0xFF2A3242);

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
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) =>
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
