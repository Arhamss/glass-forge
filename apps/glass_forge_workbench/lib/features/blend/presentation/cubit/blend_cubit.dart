import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_state.dart';
import 'package:glass_forge_workbench/utils/enums/blend_arrangement.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';

/// Drives the blend playground: how wide the merge is, how far apart the
/// shapes are, and how many of them there are.
class BlendCubit extends Cubit<BlendState> {
  /// Creates the cubit.
  BlendCubit() : super(const BlendState());

  /// Sets the merge width, in logical pixels.
  void setBlend(double value) => emit(state.copyWith(blend: value));

  /// Sets the centre-to-centre distance, in logical pixels.
  void setSeparation(double value) =>
      emit(state.copyWith(separation: _clamped(value)));

  /// Pulls the shapes apart or pushes them together by a drag on the stage.
  ///
  /// Doubled because the gesture spreads the whole arrangement: a finger
  /// travelling one way moves the near shape towards it and the far shape
  /// away by the same amount, so the centres separate by twice the travel.
  void dragSeparation(double delta) =>
      emit(state.copyWith(separation: _clamped(state.separation + delta * 2)));

  /// Sets how many shapes are on the stage.
  void setArrangement(BlendArrangement arrangement) =>
      emit(state.copyWith(arrangement: arrangement));

  /// Picks the backdrop the fold is judged against.
  void setBackdrop(GlassBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  double _clamped(double value) =>
      value.clamp(BlendState.minSeparation, BlendState.maxSeparation);
}
