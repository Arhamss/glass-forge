import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/glass_backdrop_surface.dart';

/// The specimen screen's stage: a live glass specimen over a swappable
/// backdrop, edge-to-edge with no chrome on top of it.
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
        GlassBackdropSurface(backdrop: backdrop),
        Center(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: BackdropRail(selected: backdrop, onChanged: onBackdropChanged),
        ),
      ],
    );
  }
}
