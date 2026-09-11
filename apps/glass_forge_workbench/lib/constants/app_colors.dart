import 'dart:ui';

/// The workbench's one palette. Dark only: glass needs rich content behind it,
/// and chrome that recedes.
///
/// Contrast pairs are asserted in `test/constants/contrast_test.dart` with the
/// WCAG 2.1 formula, so a token that drifts below AA fails the suite.
abstract class AppColors {
  static const ground = Color(0xFF0B0C0F);
  static const surface = Color(0xFF131519);
  static const surfaceRaised = Color(0xFF1A1D23);
  static const hairline = Color(0x14FFFFFF);
  static const hairlineStrong = Color(0x29FFFFFF);

  static const textPrimary = Color(0xFFF3F4F6);
  static const textSecondary = Color(0xFFA3A9B4);
  static const textTertiary = Color(0xFF80868F);

  /// Selected, on, active, live. Never decoration.
  static const accent = Color(0xFFD4F25A);
  static const onAccent = Color(0xFF0B0C0F);
  static const accentSoft = Color(0x29D4F25A);

  // A lit glass edge: brightest where the light lands, top-start, fading out
  // toward the far corner. Shared by the static glass stand-in and the tab
  // selector, which are both paint pretending to be glass.
  static const glassRimLight = Color(0x47FFFFFF);
  static const glassRimFade = Color(0x0FFFFFFF);
  static const glassSheen = Color(0x1AFFFFFF);

  /// Painted inside chrome glass, under its icons and labels, so they stay
  /// legible over a bright photo without changing the material itself.
  static const glassChromeScrim = Color(0x4D0B0C0F);
  static const glassShadow = Color(0x47000000);

  /// A message has to be read at a glance, over whatever it lands on, so a
  /// toast's glass carries a heavier ground than chrome does.
  static const glassMessageScrim = Color(0x8C0B0C0F);

  /// The fill behind a selected option on solid chrome.
  static const selectedFill = Color(0x1AFFFFFF);

  static const danger = Color(0xFFFF6B5E);
  static const scrim = Color(0xE60B0C0F);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);

  // Transitional names for the Lab screens, removed when Phase 3 rebuilds
  // them on the new chrome.
  static const stageGround = ground;
  static const stageRaised = surface;
  static const stageAccent = accent;
  static const stageForeground = textPrimary;
  static const stageForegroundMuted = textSecondary;
  static const stageForegroundSubtle = textTertiary;
  static const stageBorder = hairlineStrong;
  static const stageDivider = hairline;
}
