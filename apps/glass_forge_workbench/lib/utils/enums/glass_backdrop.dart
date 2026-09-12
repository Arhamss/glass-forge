import 'dart:ui';

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
    GlassBackdrop.checkerboard => 'Checker',
    GlassBackdrop.diagonals => 'Lines',
    GlassBackdrop.photographic => 'Photo',
    GlassBackdrop.gradientMesh => 'Mesh',
    GlassBackdrop.pureBlack => 'Void',
  };

  /// The mean colour of this backdrop, for surfaces that need to be told
  /// what is behind them.
  ///
  /// Backdrop content, not UI chrome, so deliberately outside AppColors —
  /// the same reasoning the painters themselves carry.
  ///
  /// `GlassSurface.backdrop` takes a single colour, and nothing in the
  /// package samples the real thing yet, so these are measured by hand off
  /// the painters: the average of the checkerboard's two squares, of the
  /// stripes at equal coverage, and of the blob fields over the stage
  /// ground. Every one of the five is dark, because the stage is — so a
  /// flipping surface settles on the dark scheme over all of them, which is
  /// the honest answer rather than a missing case.
  Color get meanColor => switch (this) {
    GlassBackdrop.checkerboard => const Color(0xFF293042),
    GlassBackdrop.diagonals => const Color(0xFF222837),
    GlassBackdrop.photographic => const Color(0xFF4A3742),
    GlassBackdrop.gradientMesh => const Color(0xFF594552),
    GlassBackdrop.pureBlack => const Color(0xFF000000),
  };
}
