import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_rim_painter.dart';

/// A glass-looking surface that never reads the backdrop.
///
/// Stands in for live glass wherever a backdrop pass is not allowed: under a
/// layer that outranks it, and everywhere under Reduce Transparency. Plain
/// paint only — even a blur backdrop filter here would put a shader pass
/// above another filter, which is the bug this exists to avoid.
class GlassStaticSurface extends StatelessWidget {
  const GlassStaticSurface({
    required this.shape,
    required this.material,
    this.child,
    super.key,
  });

  final GlassShape shape;
  final GlassMaterial material;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(
      AppColors.surfaceRaised,
      material.tint,
      material.tintOpacity.clamp(0, 1),
    )!.withValues(alpha: 0.86);
    return LayoutBuilder(
      builder: (context, constraints) {
        final border = shape.toBorder(constraints.biggest);
        return ClipPath(
          clipper: ShapeBorderClipper(shape: border),
          child: CustomPaint(
            foregroundPainter: GlassRimPainter(border: border),
            child: DecoratedBox(
              decoration: ShapeDecoration(shape: border, color: fill),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
