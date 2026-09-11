import 'dart:math' as math;

import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/extensions/glass_surface_role_extensions.dart';

/// One semantic surface, drawn at the size it really ships at.
///
/// The surface is built through `GlassSurface`, the one-line API a
/// consumer would reach for. [style] is the same role resolved against the
/// same size and backdrop, and it is handed to the enclosing layer because
/// composition is still one filter per layer — when per-shape materials
/// land in the renderer, the surface's own material takes over and this
/// becomes a redundant default rather than a wrong one.
class GallerySurfaceSpecimen extends StatelessWidget {
  /// Creates the specimen.
  const GallerySurfaceSpecimen({
    required this.role,
    required this.size,
    required this.style,
    required this.backdropColor,
    super.key,
  });

  /// Which role is drawn.
  final GlassSurfaceRole role;

  /// The size the role resolves at.
  final Size size;

  /// That role, already resolved against [size] and [backdropColor].
  final GlassSurfaceStyle style;

  /// What the app tells the package is behind the surface.
  final Color backdropColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Only ever narrows, and only the longer side: the height is capped
        // below the narrowest stage we lay out in, so the shorter side —
        // the one the flip gate reads — survives this untouched.
        final width = math.min(size.width, constraints.maxWidth);
        return GlassLayer(
          material: style.material,
          child: SizedBox(
            width: width,
            height: size.height,
            child: GlassSurface(
              role: role,
              backdrop: backdropColor,
              child: Center(
                child: Text(
                  role.label,
                  style: context.captionMedium.copyWith(
                    color: style.labelColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
