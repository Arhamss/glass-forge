import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_cubit.dart';
import 'package:glass_forge_workbench/features/motion/presentation/cubit/motion_state.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/instrument/motion_deformation_group.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/instrument/motion_release_group.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/instrument/motion_spring_group.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/instrument/motion_touch_group.dart';
import 'package:glass_forge_workbench/features/motion/presentation/widgets/motion_stage.dart';

/// A surface you can grab, with every spring behind it live.
///
/// The stage takes most of the screen and the specimen sits low in it,
/// because nothing written down here is worth as much as thirty seconds of
/// throwing the thing around.
class MotionView extends StatelessWidget {
  /// Creates the view.
  const MotionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MotionCubit(),
      child: Scaffold(
        backgroundColor: AppColors.stageGround,
        body: Column(
          children: [
            Expanded(
              flex: 62,
              child: BlocBuilder<MotionCubit, MotionState>(
                buildWhen: (previous, current) =>
                    previous.follow != current.follow ||
                    previous.settle != current.settle ||
                    previous.press != current.press ||
                    previous.pressScale != current.pressScale ||
                    previous.overdragLimit != current.overdragLimit ||
                    previous.overdragResistance !=
                        current.overdragResistance ||
                    previous.release != current.release ||
                    previous.decayDrag != current.decayDrag ||
                    previous.maxStretch != current.maxStretch ||
                    previous.halfSpeed != current.halfSpeed ||
                    previous.backdrop != current.backdrop,
                builder: (context, state) => MotionStage(
                  state: state,
                  onBackdropChanged: context
                      .read<MotionCubit>()
                      .setBackdrop,
                ),
              ),
            ),
            Expanded(
              flex: 38,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BlocBuilder<MotionCubit, MotionState>(
                      buildWhen: (previous, current) =>
                          previous.channel != current.channel ||
                          previous.editedSpring != current.editedSpring,
                      builder: (context, state) {
                        final cubit = context.read<MotionCubit>();
                        return MotionSpringGroup(
                          channel: state.channel,
                          spring: state.editedSpring,
                          onChannelChanged: cubit.setChannel,
                          onDurationChanged: cubit.setDuration,
                          onBounceChanged: cubit.setBounce,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<MotionCubit, MotionState>(
                      buildWhen: (previous, current) =>
                          previous.pressScale != current.pressScale ||
                          previous.overdragLimit != current.overdragLimit ||
                          previous.overdragResistance !=
                              current.overdragResistance,
                      builder: (context, state) {
                        final cubit = context.read<MotionCubit>();
                        return MotionTouchGroup(
                          pressScale: state.pressScale,
                          overdragLimit: state.overdragLimit,
                          overdragResistance: state.overdragResistance,
                          onPressScaleChanged: cubit.setPressScale,
                          onOverdragLimitChanged: cubit.setOverdragLimit,
                          onOverdragResistanceChanged:
                              cubit.setOverdragResistance,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<MotionCubit, MotionState>(
                      buildWhen: (previous, current) =>
                          previous.release != current.release ||
                          previous.decayDrag != current.decayDrag,
                      builder: (context, state) {
                        final cubit = context.read<MotionCubit>();
                        return MotionReleaseGroup(
                          release: state.release,
                          decayDrag: state.decayDrag,
                          onReleaseChanged: cubit.setRelease,
                          onDecayDragChanged: cubit.setDecayDrag,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<MotionCubit, MotionState>(
                      buildWhen: (previous, current) =>
                          previous.maxStretch != current.maxStretch ||
                          previous.halfSpeed != current.halfSpeed,
                      builder: (context, state) {
                        final cubit = context.read<MotionCubit>();
                        return MotionDeformationGroup(
                          maxStretch: state.maxStretch,
                          halfSpeed: state.halfSpeed,
                          onMaxStretchChanged: cubit.setMaxStretch,
                          onHalfSpeedChanged: cubit.setHalfSpeed,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) => CustomButton(
                        text: 'Put everything back',
                        onPressed: context
                            .read<MotionCubit>()
                            .resetToDefaults,
                        backgroundColor: AppColors.transparent,
                        textColor: AppColors.stageForegroundMuted,
                        borderColor: AppColors.stageBorder,
                        splashColor: AppColors.transparent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                        outsidePadding: EdgeInsetsDirectional.zero,
                        centerContent: true,
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
