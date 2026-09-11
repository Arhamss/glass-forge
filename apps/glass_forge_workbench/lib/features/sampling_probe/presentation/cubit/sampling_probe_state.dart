import 'package:equatable/equatable.dart';
import 'package:glass_forge_workbench/utils/enums/sampling_probe_mode.dart';

/// State for the sampling probe cubit.
class SamplingProbeState extends Equatable {
  /// Creates a state.
  const SamplingProbeState({
    this.mode = SamplingProbeMode.shipped,
    this.edgeRefraction = 27.42,
    this.averageFrameMs = 0,
  });

  /// Which shader variant is bound.
  final SamplingProbeMode mode;

  /// Peak edge displacement fed to `GlassMaterial`, in logical pixels.
  final double edgeRefraction;

  /// Rolling average total frame time, in milliseconds, since [mode] last
  /// changed.
  final double averageFrameMs;

  /// Returns a copy with the given fields replaced.
  SamplingProbeState copyWith({
    SamplingProbeMode? mode,
    double? edgeRefraction,
    double? averageFrameMs,
  }) {
    return SamplingProbeState(
      mode: mode ?? this.mode,
      edgeRefraction: edgeRefraction ?? this.edgeRefraction,
      averageFrameMs: averageFrameMs ?? this.averageFrameMs,
    );
  }

  @override
  List<Object?> get props => [mode, edgeRefraction, averageFrameMs];
}
