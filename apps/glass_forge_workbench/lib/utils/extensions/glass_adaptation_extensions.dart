import 'package:glass_forge/glass_forge.dart';

/// Display copy for `glass_forge`'s [GlassAdaptation].
extension GlassAdaptationX on GlassAdaptation {
  /// The verdict, as a verb, because it describes what the surface does.
  String get verb => switch (this) {
    GlassAdaptation.flip => 'flips',
    GlassAdaptation.adapt => 'adapts',
    GlassAdaptation.none => 'holds',
  };

  /// What that verdict costs the surface, in one line.
  String get consequence => switch (this) {
    GlassAdaptation.flip =>
      'Picks whichever scheme its backdrop reads better in, and ignores '
          'the one the app is running.',
    GlassAdaptation.adapt =>
      'Keeps the app scheme and thickens its tint until the label clears '
          'the role target.',
    GlassAdaptation.none =>
      'Neither. A scrim has to separate by the same amount over '
          'everything, so nothing moves it.',
  };
}
