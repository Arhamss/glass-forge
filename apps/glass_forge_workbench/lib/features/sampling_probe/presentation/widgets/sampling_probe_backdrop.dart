import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_backdrop_style.dart';

/// The probe's backdrop, in one of two styles.
///
/// [SamplingProbeBackdropStyle.stress] is a 1-physical-pixel checkerboard
/// over the top half and fine diagonal stripes over the bottom half — both
/// sit at or above the display's Nyquist limit, which is exactly where
/// nearest-neighbour texel snapping (flutter#186945) is most visible as
/// shimmer under a moving displacement. A coarser pattern would under-report
/// the effect, so this is deliberately the worst case, not a typical one.
///
/// [SamplingProbeBackdropStyle.realistic] is a smooth gradient standing in
/// for photographic content: no sub-pixel-period detail anywhere for
/// nearest-neighbour sampling to snap between. Frame time measured against
/// it isolates the shader's fixed per-pixel tap cost (four taps for the
/// bilinear candidate, one or three for the shipped default, regardless of
/// what the backdrop actually contains) from the stress backdrop's
/// worst-case *content* — see `docs/reference/backdrop_sampling.md` for why
/// the two numbers can differ and what that does and does not tell you.
///
/// Painted with one `drawRawPoints`/`drawRect` call per region rather than
/// one draw call per cell, which would be tens of thousands of draw calls
/// and jank the first frame.
class SamplingProbeBackdrop extends StatelessWidget {
  /// Creates the backdrop.
  const SamplingProbeBackdrop({required this.style, super.key});

  /// Which backdrop to paint.
  final SamplingProbeBackdropStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SamplingProbeBackdropPainter(
        style: style,
        physicalPixel: 1 / MediaQuery.devicePixelRatioOf(context),
      ),
      size: Size.infinite,
    );
  }
}

class _SamplingProbeBackdropPainter extends CustomPainter {
  const _SamplingProbeBackdropPainter({
    required this.style,
    required this.physicalPixel,
  });

  final SamplingProbeBackdropStyle style;

  /// One physical screen pixel, in logical units, at the current DPR.
  final double physicalPixel;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case SamplingProbeBackdropStyle.stress:
        final splitY = size.height / 2;
        _paintCheckerboard(canvas, Rect.fromLTWH(0, 0, size.width, splitY));
        _paintDiagonalStripes(
          canvas,
          Rect.fromLTWH(0, splitY, size.width, size.height - splitY),
        );
      case SamplingProbeBackdropStyle.realistic:
        _paintGradient(canvas, Offset.zero & size);
    }
  }

  void _paintCheckerboard(Canvas canvas, Rect region) {
    final darkCells = <double>[];
    var row = 0;
    for (
      var y = region.top + physicalPixel / 2;
      y < region.bottom;
      y += physicalPixel, row++
    ) {
      var column = 0;
      for (
        var x = region.left + physicalPixel / 2;
        x < region.right;
        x += physicalPixel, column++
      ) {
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

  void _paintGradient(Canvas canvas, Rect region) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(region.topLeft, region.bottomRight, [
        AppColors.surfaceRaised,
        AppColors.textSecondary,
        AppColors.textTertiary,
      ]);
    canvas.drawRect(region, paint);
  }

  @override
  bool shouldRepaint(_SamplingProbeBackdropPainter oldDelegate) =>
      oldDelegate.physicalPixel != physicalPixel || oldDelegate.style != style;
}
