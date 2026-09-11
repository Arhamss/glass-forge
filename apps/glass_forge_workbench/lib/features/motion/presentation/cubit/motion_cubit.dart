import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/motion_release.dart';
import 'package:glass_forge_workbench/utils/enums/motion_spring_channel.dart';

/// Drives the motion playground: three springs, a rubber band, a friction
/// coefficient and a deformation curve.
class MotionCubit extends Cubit<MotionState> {
  /// Creates the cubit.
  ///
  /// [initialState] exists so a test can start from springs that are not
  /// sitting on the package defaults. The settle thresholds [_rebuild] is
  /// careful to carry through a retune are invisible while they hold those
  /// defaults, and an invariant nobody can observe is an invariant nobody
  /// can check.
  MotionCubit({MotionState initialState = const MotionState()})
    : super(initialState);

  /// Points the duration and bounce sliders at a different spring.
  void setChannel(MotionSpringChannel channel) =>
      emit(state.copyWith(channel: channel));

  /// Sets the selected spring's period, in milliseconds.
  ///
  /// The period, not the settle time: a spring with a 500 ms duration is
  /// still moving after 500 ms, and Apple's vocabulary means the former.
  void setDuration(double milliseconds) => _editSpring(
    (spring) => _rebuild(
      spring,
      duration: Duration(milliseconds: milliseconds.round()),
    ),
  );

  /// Sets the selected spring's overshoot, from -1 through 0 to 1.
  void setBounce(double bounce) =>
      _editSpring((spring) => _rebuild(spring, bounce: bounce));

  /// Sets what a fully pressed surface scales to.
  void setPressScale(double value) => emit(state.copyWith(pressScale: value));

  /// Sets how far past rest the surface may be dragged.
  void setOverdragLimit(double value) =>
      emit(state.copyWith(overdragLimit: value));

  /// Sets how much of the pointer's movement reaches the surface at rest.
  void setOverdragResistance(double value) =>
      emit(state.copyWith(overdragResistance: value));

  /// Sets what letting go does.
  void setRelease(MotionRelease release) =>
      emit(state.copyWith(release: release));

  /// Sets the velocity a free fling retains per second.
  void setDecayDrag(double value) => emit(state.copyWith(decayDrag: value));

  /// Sets the stretch ratio approached at infinite speed.
  void setMaxStretch(double value) => emit(state.copyWith(maxStretch: value));

  /// Sets the speed at which half the available stretch is reached.
  void setHalfSpeed(double value) => emit(state.copyWith(halfSpeed: value));

  /// Picks the backdrop the specimen moves over.
  void setBackdrop(GlassBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  /// Puts every knob back where `InteractiveGlass` starts, keeping the
  /// backdrop and the spring you were editing.
  void resetToDefaults() =>
      emit(MotionState(channel: state.channel, backdrop: state.backdrop));

  /// Rebuilds a spring, keeping the settle thresholds it was carrying.
  ///
  /// `GlassMotion` has no `copyWith`, and dropping the thresholds would
  /// silently return the spring to a tolerance measured in thousandths of
  /// a pixel — hundreds of frames of invisible creep on something driving
  /// a shader.
  GlassMotion _rebuild(
    GlassMotion spring, {
    Duration? duration,
    double? bounce,
  }) {
    return GlassMotion(
      duration: duration ?? spring.duration,
      bounce: bounce ?? spring.bounce,
      settleDistance: spring.settleDistance,
      settleVelocity: spring.settleVelocity,
    );
  }

  void _editSpring(GlassMotion Function(GlassMotion spring) transform) {
    final next = transform(state.editedSpring);
    emit(switch (state.channel) {
      MotionSpringChannel.follow => state.copyWith(follow: next),
      MotionSpringChannel.settle => state.copyWith(settle: next),
      MotionSpringChannel.press => state.copyWith(press: next),
    });
  }
}
