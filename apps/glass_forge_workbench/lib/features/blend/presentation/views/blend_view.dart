import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_cubit.dart';
import 'package:glass_forge_workbench/features/blend/presentation/cubit/blend_state.dart';
import 'package:glass_forge_workbench/features/blend/presentation/widgets/blend_stage.dart';
import 'package:glass_forge_workbench/features/blend/presentation/widgets/instrument/blend_controls_group.dart';

/// Shapes that fold into one another, with the fold's width under a
/// finger.
///
/// The stage takes most of the screen and the instrument collapses to the
/// three numbers that matter, because everything this screen has to say is
/// said by the shapes themselves — and by the line under them stating, in
/// pixels, what they ought to be doing.
class BlendView extends StatelessWidget {
  /// Creates the view.
  const BlendView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BlendCubit(),
      child: Scaffold(
        backgroundColor: AppColors.stageGround,
        body: Column(
          children: [
            Expanded(
              flex: 65,
              child: BlocBuilder<BlendCubit, BlendState>(
                buildWhen: (previous, current) =>
                    previous.blend != current.blend ||
                    previous.separation != current.separation ||
                    previous.arrangement != current.arrangement ||
                    previous.backdrop != current.backdrop,
                builder: (context, state) {
                  final cubit = context.read<BlendCubit>();
                  return BlendStage(
                    state: state,
                    onDragged: cubit.dragSeparation,
                    onBackdropChanged: cubit.setBackdrop,
                  );
                },
              ),
            ),
            Expanded(
              flex: 35,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                child: BlocBuilder<BlendCubit, BlendState>(
                  buildWhen: (previous, current) =>
                      previous.blend != current.blend ||
                      previous.separation != current.separation ||
                      previous.arrangement != current.arrangement,
                  builder: (context, state) {
                    final cubit = context.read<BlendCubit>();
                    return BlendControlsGroup(
                      state: state,
                      onBlendChanged: cubit.setBlend,
                      onSeparationChanged: cubit.setSeparation,
                      onArrangementChanged: cubit.setArrangement,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
