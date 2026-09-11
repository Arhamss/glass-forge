/// How many shapes the blend playground puts on the stage.
///
/// Two proves the fold exists. Three proves it is not pairwise — a fold
/// that only ever merged the nearest neighbour would look right with two
/// shapes and wrong the moment a third arrived.
enum BlendArrangement {
  /// Two shapes, side by side.
  pair,

  /// Three shapes, equal distances apart.
  triad,
}

/// Counts and labels for [BlendArrangement].
extension BlendArrangementX on BlendArrangement {
  /// How many shapes this arrangement places.
  int get count => switch (this) {
    BlendArrangement.pair => 2,
    BlendArrangement.triad => 3,
  };

  /// The label on the segmented control.
  String get label => switch (this) {
    BlendArrangement.pair => 'Two shapes',
    BlendArrangement.triad => 'Three shapes',
  };

  /// The word for however many shapes there are, for the verdict line.
  String get noun => switch (this) {
    BlendArrangement.pair => 'two shapes',
    BlendArrangement.triad => 'three shapes',
  };
}
