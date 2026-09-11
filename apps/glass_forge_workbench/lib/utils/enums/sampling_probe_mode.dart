/// Which backdrop-sampling shader the sampling probe screen renders through.
enum SamplingProbeMode {
  /// The shipped shader: `final_render.frag`, nearest-neighbour backdrop.
  shipped,

  /// The measurement-only variant: `final_render_bilinear_probe.frag`.
  bilinearReconstruction,
}

/// Display strings for [SamplingProbeMode].
extension SamplingProbeModeX on SamplingProbeMode {
  /// The label shown on the mode toggle.
  String get label => switch (this) {
    SamplingProbeMode.shipped => 'Shipped',
    SamplingProbeMode.bilinearReconstruction => 'Bilinear',
  };
}
