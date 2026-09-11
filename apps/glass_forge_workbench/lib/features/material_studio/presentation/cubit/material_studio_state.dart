import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/features/material_studio/data/models/studio_stage_mode.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';

/// Where the studio is looking. The material itself belongs to the house
/// material cubit, not to this screen.
class MaterialStudioState extends Equatable {
  const MaterialStudioState({
    this.mode = StudioStageMode.inContext,
    this.group = MaterialGroup.optics,
  });

  final StudioStageMode mode;
  final MaterialGroup group;

  MaterialStudioState copyWith({StudioStageMode? mode, MaterialGroup? group}) =>
      MaterialStudioState(mode: mode ?? this.mode, group: group ?? this.group);

  @override
  List<Object?> get props => [mode, group];
}
