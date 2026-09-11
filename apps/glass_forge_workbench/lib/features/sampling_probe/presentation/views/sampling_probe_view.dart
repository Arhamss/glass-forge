import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/cubit/sampling_probe_cubit.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/cubit/sampling_probe_state.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_canvas.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_displacement_slider.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_frame_readout.dart';
import 'package:glass_forge_workbench/features/sampling_probe/presentation/widgets/sampling_probe_mode_toggle.dart';

/// Task 19's measurement screen: a high-frequency backdrop under an
/// animating glass shape, with a toggle between the shipped
/// nearest-neighbour backdrop sampler and a bilinear-reconstruction
/// candidate, a displacement slider, and a live frame-time readout.
///
/// See `docs/reference/backdrop_sampling.md` for what this measured and the
/// decision it produced.
class SamplingProbeView extends StatelessWidget {
  /// Creates the view.
  const SamplingProbeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SamplingProbeCubit()..init(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: customAppBar(context: context, title: 'Sampling probe'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 360,
                  child: BlocBuilder<SamplingProbeCubit, SamplingProbeState>(
                    buildWhen: (previous, current) =>
                        previous.mode != current.mode ||
                        previous.edgeRefraction != current.edgeRefraction,
                    builder: (context, state) => ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SamplingProbeCanvas(
                        mode: state.mode,
                        edgeRefraction: state.edgeRefraction,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<SamplingProbeCubit, SamplingProbeState>(
                  buildWhen: (previous, current) =>
                      previous.mode != current.mode,
                  builder: (context, state) => SamplingProbeModeToggle(
                    mode: state.mode,
                    onChanged: context.read<SamplingProbeCubit>().setMode,
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<SamplingProbeCubit, SamplingProbeState>(
                  buildWhen: (previous, current) =>
                      previous.edgeRefraction != current.edgeRefraction,
                  builder: (context, state) => SamplingProbeDisplacementSlider(
                    edgeRefraction: state.edgeRefraction,
                    onChanged: context.read<SamplingProbeCubit>().setEdgeRefraction,
                  ),
                ),
                const SizedBox(height: 8),
                BlocBuilder<SamplingProbeCubit, SamplingProbeState>(
                  buildWhen: (previous, current) =>
                      previous.averageFrameMs != current.averageFrameMs,
                  builder: (context, state) => SamplingProbeFrameReadout(
                    averageFrameMs: state.averageFrameMs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
