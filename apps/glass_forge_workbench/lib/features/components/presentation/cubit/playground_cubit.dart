import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/components/data/models/knob_values.dart';
import 'package:glass_forge_workbench/features/components/data/models/story_knob.dart';
import 'package:glass_forge_workbench/features/components/presentation/cubit/playground_state.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/playground_pane.dart';

/// One component's playground: its knobs, what is behind it, and whether it
/// wears its own material or the house one.
class PlaygroundCubit extends Cubit<PlaygroundState> {
  PlaygroundCubit(this._knobs)
    : super(PlaygroundState(values: KnobValues.initial(_knobs)));

  final List<StoryKnob> _knobs;

  void setKnob(String id, Object value) =>
      emit(state.copyWith(values: state.values.set(id, value)));

  void setBackdrop(PlaygroundBackdrop backdrop) =>
      emit(state.copyWith(backdrop: backdrop));

  void setPane(PlaygroundPane pane) => emit(state.copyWith(pane: pane));

  void setMaterialOverride(GlassMaterial? material) =>
      emit(state.copyWith(materialOverride: () => material));

  /// Every knob back to where it started. The backdrop and pane stay put:
  /// they are where the user is looking, not what they were tuning.
  void reset() => emit(
    state.copyWith(
      values: KnobValues.initial(_knobs),
      materialOverride: () => null,
    ),
  );
}
