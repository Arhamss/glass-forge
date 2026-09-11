import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/features/material_studio/data/models/studio_stage_mode.dart';
import 'package:glass_forge_workbench/features/material_studio/presentation/cubit/material_studio_state.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';

class MaterialStudioCubit extends Cubit<MaterialStudioState> {
  MaterialStudioCubit() : super(const MaterialStudioState());

  void setMode(StudioStageMode mode) => emit(state.copyWith(mode: mode));

  void setGroup(MaterialGroup group) => emit(state.copyWith(group: group));
}
