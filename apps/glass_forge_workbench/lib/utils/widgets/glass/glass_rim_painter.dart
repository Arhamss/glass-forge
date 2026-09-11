import 'package:glass_forge_workbench/exports.dart';

/// A one-pixel lit edge traced along a shape: bright where the light lands,
/// fading toward the far corner. Paint only, so it can sit anywhere glass
/// cannot.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter({required this.border, this.strength = 1});

  final ShapeBorder border;

  /// Scales the rim's opacity, for a selector that should read brighter than
  /// the bar it rides on.
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.glassRimLight.withValues(
          alpha: (AppColors.glassRimLight.a * strength).clamp(0, 1),
        ),
        AppColors.glassRimFade,
      ],
    );
    canvas.drawPath(
      border.getInnerPath(rect.deflate(0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.strength != strength;
}
