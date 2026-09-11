import 'package:equatable/equatable.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/components/data/models/knob_values.dart';
import 'package:glass_forge_workbench/utils/enums/playground_backdrop.dart';
import 'package:glass_forge_workbench/utils/enums/playground_pane.dart';

class PlaygroundState extends Equatable {
  const PlaygroundState({
    required this.values,
    this.backdrop = PlaygroundBackdrop.photo,
    this.pane = PlaygroundPane.variants,
    this.materialOverride,
  });

  final KnobValues values;
  final PlaygroundBackdrop backdrop;
  final PlaygroundPane pane;

  /// A material for this playground alone. Null follows the house material.
  final GlassMaterial? materialOverride;

  PlaygroundState copyWith({
    KnobValues? values,
    PlaygroundBackdrop? backdrop,
    PlaygroundPane? pane,
    GlassMaterial? Function()? materialOverride,
  }) {
    return PlaygroundState(
      values: values ?? this.values,
      backdrop: backdrop ?? this.backdrop,
      pane: pane ?? this.pane,
      materialOverride: materialOverride == null
          ? this.materialOverride
          : materialOverride(),
    );
  }

  @override
  List<Object?> get props => [values, backdrop, pane, materialOverride];
}
