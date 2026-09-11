import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:glass_forge_workbench/exports.dart';

/// A high-frequency backdrop for the sampling probe: a 1-physical-pixel
/// checkerboard over the top half, fine diagonal stripes over the bottom
/// half.
///
/// Both patterns sit at or above the display's Nyquist limit, which is
/// exactly where nearest-neighbour texel snapping (flutter#186945) is most
/// visible as shimmer under a moving displacement. A coarser pattern would
/// under-report the effect. Drawn as one `drawRawPoints` call per half
/// rather than one `drawRect` per cell, which would be tens of thousands of
/// draw calls and jank the first frame.
class SamplingProbeBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const SamplingProbeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SamplingProbeBackdropPainter(
        physicalPixel: 1 / MediaQuery.devicePixelRatioOf(context),
      ),
      size: Size.infinite,
    );
  }
}

class _SamplingProbeBackdropPainter extends CustomPainter {
  const _SamplingProbeBackdropPainter({required this.physicalPixel});

  /// One physical screen pixel, in logical units, at the current DPR.
  final double physicalPixel;

  @override
  void paint(Canvas canvas, Size size) {
    final splitY = size.height / 2;
    _paintCheckerboard(canvas, Rect.fromLTWH(0, 0, size.width, splitY));
    _paintDiagonalStripes(
      canvas,
      Rect.fromLTWH(0, splitY, size.width, size.height - splitY),
    );
  }

  void _paintCheckerboard(Canvas canvas, Rect region) {
    final darkCells = <double>[];
    var row = 0;
    for (var y = region.top + physicalPixel / 2;
        y < region.bottom;
        y += physicalPixel, row++) {
      var column = 0;
      for (var x = region.left + physicalPixel / 2;
          x < region.right;
          x += physicalPixel, column++) {
        if ((row + column).isEven) {
          darkCells
            ..add(x)
            ..add(y);
        }
      }
    }
    canvas
      ..save()
      ..clipRect(region)
      ..drawRect(region, Paint()..color = AppColors.surface)
      ..drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(darkCells),
        Paint()
          ..color = AppColors.textPrimary
          ..strokeWidth = physicalPixel
          ..strokeCap = StrokeCap.square,
      )
      ..restore();
  }

  void _paintDiagonalStripes(Canvas canvas, Rect region) {
    final paint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = physicalPixel;
    final period = 2 * physicalPixel;
    final diagonal = region.width + region.height;
    canvas
      ..save()
      ..clipRect(region)
      ..drawRect(region, Paint()..color = AppColors.surface);
    for (var offset = 0.0; offset < diagonal; offset += period) {
      canvas.drawLine(
        Offset(region.left + offset, region.top),
        Offset(region.left, region.top + offset),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SamplingProbeBackdropPainter oldDelegate) =>
      oldDelegate.physicalPixel != physicalPixel;
}
