import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';

/// The thing you grab.
///
/// Everything on this screen exists to change how this one surface
/// answers a finger, so it is deliberately large, plain, and the only
/// thing on the stage.
class MotionSpecimen extends StatelessWidget {
  /// Creates the specimen.
  const MotionSpecimen({required this.state, super.key});

  /// Every spring, band and curve the specimen runs under.
  final MotionState state;

  /// The specimen's side, in logical pixels.
  ///
  /// Big enough to land a thumb on without aiming, small enough that its
  /// travel across the stage is obvious.
  static const _side = 160.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Glass specimen. Drag it, throw it, or press it.',
      child: InteractiveGlass(
        // Retuning a spring in place asks `InteractiveGlass` to build a
        // second controller against a `SingleTickerProviderStateMixin`,
        // which is one ticker per State and throws on the second. Keying
        // on the tuning instead gives each set of numbers its own State,
        // and it matches what the widget already documents: these are
        // construction-time tuning, so the surface re-seats when they
        // change.
        key: ValueKey<Object>((
          state.follow,
          state.settle,
          state.press,
          state.pressScale,
          state.overdragLimit,
          state.overdragResistance,
          state.release,
          state.decayDrag,
          state.maxStretch,
          state.halfSpeed,
        )),
        pressScale: state.pressScale,
        jiggle: state.jiggle,
        followMotion: state.follow,
        settleMotion: state.settle,
        pressMotion: state.press,
        drag: state.drag,
        child: const SizedBox(
          width: _side,
          height: _side,
          child: Glass(
            shape: GlassSuperellipse(
              radius: BorderRadius.all(Radius.circular(44)),
            ),
          ),
        ),
      ),
    );
  }
}
