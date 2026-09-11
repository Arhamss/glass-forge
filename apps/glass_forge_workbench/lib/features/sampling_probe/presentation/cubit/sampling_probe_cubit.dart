import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:glass_forge/debug.dart' as glass_forge_debug;
import 'package:glass_forge_workbench/features/sampling_probe/presentation/cubit/sampling_probe_state.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_mode.dart';

/// How many recent frames the rolling frame-time average is computed over.
const _frameSampleWindow = 120;

/// Drives the sampling probe screen: the shipped/bilinear toggle, the
/// displacement slider, and a rolling frame-time readout.
///
/// `GlassLayer` warms up its own shaders and paints unglassed until they are
/// ready, so this cubit has nothing to await before rendering — [init]
/// exists only to start the frame-timing listener.
class SamplingProbeCubit extends Cubit<SamplingProbeState> {
  /// Creates the cubit. Call [init] once the screen is on-screen.
  SamplingProbeCubit() : super(const SamplingProbeState());

  final List<int> _frameMicros = [];

  /// Starts recording frame timings for the readout.
  void init() {
    FlutterNativeSplash.remove();
    SchedulerBinding.instance.addTimingsCallback(_recordFrameTimings);
  }

  /// Switches which backdrop-sampling shader the probe's glass renders
  /// through, and resets the frame-time average for the new mode.
  void setMode(SamplingProbeMode mode) {
    glass_forge_debug.debugBilinearBackdropSampling =
        mode == SamplingProbeMode.bilinearReconstruction;
    _frameMicros.clear();
    emit(state.copyWith(mode: mode, averageFrameMs: 0));
  }

  /// Sets the peak edge displacement fed to `GlassMaterial`.
  void setEdgeRefraction(double value) =>
      emit(state.copyWith(edgeRefraction: value));

  void _recordFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameMicros.add(timing.totalSpan.inMicroseconds);
    }
    final overflow = _frameMicros.length - _frameSampleWindow;
    if (overflow > 0) {
      _frameMicros.removeRange(0, overflow);
    }
    if (_frameMicros.isEmpty) {
      return;
    }
    final averageMicros =
        _frameMicros.reduce((a, b) => a + b) / _frameMicros.length;
    emit(state.copyWith(averageFrameMs: averageMicros / 1000));
  }

  @override
  Future<void> close() {
    SchedulerBinding.instance.removeTimingsCallback(_recordFrameTimings);
    glass_forge_debug.debugBilinearBackdropSampling = false;
    return super.close();
  }
}
