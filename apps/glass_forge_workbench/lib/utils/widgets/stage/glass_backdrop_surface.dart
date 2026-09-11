import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/checkerboard_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/diagonals_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/gradient_mesh_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/photographic_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/void_backdrop.dart';

/// Paints whichever backdrop [backdrop] names, filling its parent.
///
/// Every stage in the workbench renders its glass over one of these five,
/// so the switch lives here rather than being repeated per screen.
class GlassBackdropSurface extends StatelessWidget {
  /// Creates the surface.
  const GlassBackdropSurface({required this.backdrop, super.key});

  /// Which backdrop to paint.
  final GlassBackdrop backdrop;

  @override
  Widget build(BuildContext context) {
    return switch (backdrop) {
      GlassBackdrop.checkerboard => const CheckerboardBackdrop(),
      GlassBackdrop.diagonals => const DiagonalsBackdrop(),
      GlassBackdrop.photographic => const PhotographicBackdrop(),
      GlassBackdrop.gradientMesh => const GradientMeshBackdrop(),
      GlassBackdrop.pureBlack => const VoidBackdrop(),
    };
  }
}
