import 'dart:ui';

abstract class AppColors {
  // ── Background & Surfaces ──
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F3F6);
  static const surfaceMuted = Color(0xFFE7EBEF);
  static const navBar = Color(0xFFFFFFFF);

  // ── Primary ──
  static const primary = Color(0xFF0D121C);
  static const primaryLight = Color(0xFF2A3240);
  static const primaryMuted = Color(0xFF4A5568);
  static const primarySoft = Color(0xFFE8EBF0);

  // ── Text ──
  static const textPrimary = Color(0xFF0D121C);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF697586);
  static const textTertiary = Color(0xFF9AA4B2);

  // ── Status ──
  static const success = Color(0xFF22C661);
  static const error = Color(0xFFE8534E);
  static const warning = Color(0xFFE8A83D);
  static const info = Color(0xFF3B82F6);

  // ── Borders & Dividers ──
  static const border = Color(0xFFE1E5EA);
  static const divider = Color(0xFFECEFF2);

  // ── Shadows ──
  static const shadowLight = Color(0x0F000000);
  static const shadowMedium = Color(0x1A000000);

  // ── Misc ──
  static const disabled = Color(0xFFBDBDBD);
  static const transparent = Color(0x00000000);

  // ── Overlays ──
  static const overlayText = Color(0xFFFFFFFF);
  static const overlayTextMuted = Color(0xB3FFFFFF);
  static const overlayScrim = Color(0xFF000000);
}
