import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/glass_rim_painter.dart';

/// Glass drawn on glass: a sheen and a lit rim over whatever the outer glass
/// already shows, with no backdrop read of its own.
class GlassInsetSurface extends StatelessWidget {
  const GlassInsetSurface({
    required this.shape,
    this.tint,
    this.child,
    super.key,
  });

  final GlassShape shape;

  /// A solid tint for surfaces that must stand out, such as a primary
  /// button. Null keeps it clear.
  final Color? tint;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    return LayoutBuilder(
      builder: (context, constraints) {
        final border = shape.toBorder(constraints.biggest);
        return CustomPaint(
          foregroundPainter: GlassRimPainter(border: border, strength: 1.4),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: border,
              color: tint,
              gradient: tint == null
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.glassSheen, AppColors.glassRimFade],
                    )
                  : null,
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: border),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
