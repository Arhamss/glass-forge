import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/cubit/gallery_state.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/gallery_stage.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_resolution_group.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_roster_group.dart';
import 'package:glass_forge_workbench/features/gallery/presentation/widgets/instrument/gallery_size_group.dart';

/// The five semantic surfaces, one at a time, drawn twice: once in a light
/// app and once in a dark one, over the same backdrop and at the size the
/// role really ships at.
///
/// The screen exists to make one rule legible — small elements flip their
/// whole scheme from what is behind them, large ones only adapt — so the
/// size slider and the roster of verdicts get as much room as the glass
/// does.
class GalleryView extends StatelessWidget {
  /// Creates the view.
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GalleryCubit(),
      child: Scaffold(
        backgroundColor: AppColors.stageGround,
        body: Column(
          children: [
            Expanded(
              flex: 55,
              child: BlocBuilder<GalleryCubit, GalleryState>(
                buildWhen: (previous, current) =>
                    previous.role != current.role ||
                    previous.backdrop != current.backdrop ||
                    previous.shortSide != current.shortSide,
                builder: (context, state) {
                  return GalleryStage(
                    role: state.role,
                    size: state.surfaceSize,
                    lightStyle: state.styleFor(Brightness.light),
                    darkStyle: state.styleFor(Brightness.dark),
                    backdrop: state.backdrop,
                    onBackdropChanged: context.read<GalleryCubit>().setBackdrop,
                  );
                },
              ),
            ),
            Expanded(
              flex: 45,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BlocBuilder<GalleryCubit, GalleryState>(
                      buildWhen: (previous, current) =>
                          previous.role != current.role ||
                          previous.backdrop != current.backdrop ||
                          previous.shortSide != current.shortSide,
                      builder: (context, state) => GalleryRosterGroup(
                        state: state,
                        onRoleChanged: context.read<GalleryCubit>().setRole,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<GalleryCubit, GalleryState>(
                      buildWhen: (previous, current) =>
                          previous.shortSide != current.shortSide,
                      builder: (context, state) => GallerySizeGroup(
                        shortSide: state.shortSide,
                        onShortSideChanged: context
                            .read<GalleryCubit>()
                            .setShortSide,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<GalleryCubit, GalleryState>(
                      buildWhen: (previous, current) =>
                          previous.role != current.role ||
                          previous.backdrop != current.backdrop ||
                          previous.shortSide != current.shortSide,
                      builder: (context, state) => GalleryResolutionGroup(
                        role: state.role,
                        size: state.surfaceSize,
                        adaptation: state.adaptation,
                        lightStyle: state.styleFor(Brightness.light),
                        darkStyle: state.styleFor(Brightness.dark),
                        minimumContrast: GalleryState.surfaces
                            .of(state.role)
                            .minimumContrast,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
