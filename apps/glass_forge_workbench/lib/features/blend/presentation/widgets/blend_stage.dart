import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_state.dart';
import 'package:glass_forge_workbench/features/blend/presentation/widgets/blend_field.dart';
import 'package:glass_forge_workbench/features/blend/presentation/widgets/blend_verdict_caption.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/glass_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

/// The blend stage: every shape in one group, one layer, one backdrop.
///
/// Drag sideways anywhere on it to spread the shapes. The separation
/// slider in the instrument does the same thing to the same number, which
/// is both the precise control and the way to work this screen without
/// dragging at all.
class BlendStage extends StatelessWidget {
  /// Creates the stage.
  const BlendStage({
    required this.state,
    required this.onDragged,
    required this.onBackdropChanged,
    super.key,
  });

  /// Everything on the stage, and the numbers describing it.
  final BlendState state;

  /// Called with the horizontal travel of a drag on the stage.
  final ValueChanged<double> onDragged;

  /// Called when a different backdrop is picked from the rail.
  final ValueChanged<GlassBackdrop> onBackdropChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => onDragged(details.delta.dx),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GlassBackdropSurface(backdrop: state.backdrop),
              GlassLayer(
                material: demonstrationGlassMaterial(),
                child: GlassBlendGroup(
                  blend: state.blend,
                  child: BlendField(
                    centres: state.nodeCentres,
                    diameter: BlendState.nodeDiameter,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PositionedDirectional(
          top: 12,
          start: 16,
          end: 16,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StageCaption(text: 'Drag sideways to spread'),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlendVerdictCaption(
                edgeGap: state.edgeGap,
                blend: state.blend,
                isOverlapping: state.isOverlapping,
                expectsMerge: state.expectsMerge,
                separateNoun: state.arrangement.noun,
              ),
              const SizedBox(height: 12),
              BackdropRail(
                selected: state.backdrop,
                onChanged: onBackdropChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
