import 'package:glass_forge/glass_forge.dart';

/// Display copy and demonstration sizes for `glass_forge`'s five semantic
/// roles.
extension GlassSurfaceRoleX on GlassSurfaceRole {
  /// The name shown in the roster.
  String get label => switch (this) {
    GlassSurfaceRole.navigationBar => 'Navigation bar',
    GlassSurfaceRole.sheet => 'Sheet',
    GlassSurfaceRole.card => 'Card',
    GlassSurfaceRole.control => 'Control',
    GlassSurfaceRole.scrim => 'Scrim',
  };

  /// What the role is for, in the words a consumer would use.
  String get blurb => switch (this) {
    GlassSurfaceRole.navigationBar => 'A nav bar, tab bar or toolbar.',
    GlassSurfaceRole.sheet => 'A sheet, popover or sidebar.',
    GlassSurfaceRole.card => 'A card down in the content layer.',
    GlassSurfaceRole.control => 'A button, toggle or segmented control.',
    GlassSurfaceRole.scrim => 'The dimming layer under a modal.',
  };

  /// The width this role is drawn at on the gallery stage, in logical
  /// pixels.
  ///
  /// Real widths, not a shared column: a control that spanned the screen
  /// would look like a bar, and the flip gate reads the *shorter* side, so
  /// getting the width wrong changes the answer.
  double get demonstrationWidth => switch (this) {
    GlassSurfaceRole.navigationBar => 320,
    GlassSurfaceRole.sheet => 320,
    GlassSurfaceRole.card => 320,
    GlassSurfaceRole.control => 132,
    GlassSurfaceRole.scrim => 320,
  };

  /// The height this role starts at, in logical pixels.
  ///
  /// iOS's own: a 52 pt bar, a 44 pt control, a sheet at its first detent.
  double get naturalShortSide => switch (this) {
    GlassSurfaceRole.navigationBar => 52,
    GlassSurfaceRole.sheet => 180,
    GlassSurfaceRole.card => 120,
    GlassSurfaceRole.control => 44,
    GlassSurfaceRole.scrim => 200,
  };
}
