import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/motion_specimen.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/helpers/demonstration_glass_material.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/glass_backdrop_surface.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/stage_caption.dart';

/// The motion stage: one specimen, a backdrop to move it over, and
/// nothing else competing for the thumb.
///
/// The specimen sits below centre on purpose. Dead centre on a phone is
/// the one place a thumb has to stretch for, and this is a screen you work
/// with your hands rather than read.
class MotionStage extends StatelessWidget {
  /// Creates the stage.
  const MotionStage({
    required this.state,
    required this.onBackdropChanged,
    super.key,
  });

  /// Everything the specimen moves under.
  final MotionState state;

  /// Called when a different backdrop is picked from the rail.
  final ValueChanged<GlassBackdrop> onBackdropChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GlassBackdropSurface(backdrop: state.backdrop),
        Align(
          alignment: const Alignment(0, 0.2),
          child: GlassLayer(
            material: demonstrationGlassMaterial(),
            child: MotionSpecimen(state: state),
          ),
        ),
        const PositionedDirectional(
          top: 12,
          start: 16,
          end: 16,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StageCaption(text: 'Drag it, then let go'),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BackdropRail(
            selected: state.backdrop,
            onChanged: onBackdropChanged,
          ),
        ),
      ],
    );
  }
}
