import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/checkerboard_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/gradient_mesh_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrops/void_backdrop.dart';

/// Paints a playground backdrop edge to edge, clipped to its box.
class PlaygroundBackdropSurface extends StatelessWidget {
  const PlaygroundBackdropSurface({required this.backdrop, super.key});

  final PlaygroundBackdrop backdrop;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: switch (backdrop) {
        PlaygroundBackdrop.photo => Image.asset(
          AssetPaths.photoSeaCliffs,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        PlaygroundBackdrop.city => Image.asset(
          AssetPaths.photoTokyoRain,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        PlaygroundBackdrop.mesh => const GradientMeshBackdrop(),
        PlaygroundBackdrop.checker => const CheckerboardBackdrop(),
        PlaygroundBackdrop.black => const VoidBackdrop(),
      },
    );
  }
}
