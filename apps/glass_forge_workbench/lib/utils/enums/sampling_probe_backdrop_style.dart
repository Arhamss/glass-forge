/// Which backdrop the sampling probe paints behind the glass shape.
enum SamplingProbeBackdropStyle {
  /// The 1-physical-pixel checkerboard and diagonal stripes: deliberately
  /// at the display's Nyquist limit, where texel snapping is most visible.
  stress,

  /// A smooth, low-frequency gradient standing in for photographic
  /// content: no sub-pixel-period detail for nearest-neighbour sampling to
  /// snap between, so frame time measured here isolates the shader's fixed
  /// per-pixel tap cost from the stress backdrop's worst-case content.
  realistic,
}

/// Display strings for [SamplingProbeBackdropStyle].
extension SamplingProbeBackdropStyleX on SamplingProbeBackdropStyle {
  /// The label shown on the backdrop style toggle.
  String get label => switch (this) {
    SamplingProbeBackdropStyle.stress => 'Stress',
    SamplingProbeBackdropStyle.realistic => 'Realistic',
  };
}
