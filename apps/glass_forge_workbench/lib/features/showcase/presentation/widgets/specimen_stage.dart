import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/checkerboard_backdrop.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/diagonals_backdrop.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/gradient_mesh_backdrop.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/photographic_backdrop.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/backdrops/void_backdrop.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/widgets/stage/backdrop_rail.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// The stage zone shared by every showcase screen: a live glass specimen
/// over a swappable backdrop, edge-to-edge with no chrome on top of it.
///
/// The backdrop-picker rail is the one exception — it sits as a thin strip
/// pinned to the stage's bottom edge, per docs/design/workbench-design.md.
class SpecimenStage extends StatelessWidget {
  /// Creates the stage.
  const SpecimenStage({
    required this.backdrop,
    required this.onBackdropChanged,
    required this.child,
    super.key,
  });

  /// The backdrop currently rendered behind [child].
  final GlassBackdrop backdrop;

  /// Called when a different backdrop is picked from the rail.
  final ValueChanged<GlassBackdrop> onBackdropChanged;

  /// The live glass specimen shown over the backdrop.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        switch (backdrop) {
          GlassBackdrop.checkerboard => const CheckerboardBackdrop(),
          GlassBackdrop.diagonals => const DiagonalsBackdrop(),
          GlassBackdrop.photographic => const PhotographicBackdrop(),
          GlassBackdrop.gradientMesh => const GradientMeshBackdrop(),
          GlassBackdrop.pureBlack => const VoidBackdrop(),
        },
        Center(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: BackdropRail(selected: backdrop, onChanged: onBackdropChanged),
        ),
      ],
    );
  }
}
