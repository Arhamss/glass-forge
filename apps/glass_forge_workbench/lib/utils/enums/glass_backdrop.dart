/// The five synthetic backdrops the showcase renders glass specimens over.
///
/// Per docs/design/workbench-design.md, backdrops are the product surface,
/// not styling — each one proves something specific about the renderer
/// rather than just decorating the stage.
enum GlassBackdrop {
  /// True 1-physical-pixel checkerboard. Worst case for texel snapping.
  checkerboard,

  /// Fine diagonal stripes. Worst case for edge shimmer.
  diagonals,

  /// Synthesised photographic detail — the realistic case.
  photographic,

  /// Smooth multi-point colour field. Shows tint and saturation behaviour.
  gradientMesh,

  /// Pure black. The rim-flicker test upstream issue #112 was about.
  pureBlack,
}

/// Display strings for [GlassBackdrop].
extension GlassBackdropX on GlassBackdrop {
  /// The label shown on the backdrop-picker rail.
  String get label => switch (this) {
    GlassBackdrop.checkerboard => 'Checkerboard',
    GlassBackdrop.diagonals => 'Diagonals',
    GlassBackdrop.photographic => 'Photographic',
    GlassBackdrop.gradientMesh => 'Gradient mesh',
    GlassBackdrop.pureBlack => 'Void',
  };
}
