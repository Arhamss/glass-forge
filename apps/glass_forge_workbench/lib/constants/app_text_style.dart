import 'package:flutter/material.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';

abstract class AppFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

/// The type scale. Geist for words, Geist Mono for every number and unit.
extension AppTextStyle on BuildContext {
  TextStyle _sans(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: AppColors.textPrimary,
    );
  }

  TextStyle _mono(double size, double lineHeight) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  TextStyle get display => _sans(34, 40, FontWeight.w600, letterSpacing: -0.6);
  TextStyle get title => _sans(22, 28, FontWeight.w600, letterSpacing: -0.3);
  TextStyle get headline => _sans(17, 22, FontWeight.w600, letterSpacing: -0.2);
  TextStyle get body => _sans(15, 21, FontWeight.w400);
  TextStyle get bodyMedium => _sans(15, 21, FontWeight.w500);
  TextStyle get callout => _sans(14, 20, FontWeight.w500);
  TextStyle get calloutRegular => _sans(14, 20, FontWeight.w400);
  TextStyle get caption => _sans(12, 16, FontWeight.w400);
  TextStyle get captionMedium => _sans(12, 16, FontWeight.w500);

  /// Section labels. Callers upper-case the string themselves, so the copy in
  /// the ARB file stays in sentence case.
  TextStyle get overline => _sans(11, 14, FontWeight.w500, letterSpacing: 0.8);

  TextStyle get mono => _mono(14, 20);
  TextStyle get monoSmall => _mono(12, 16);
}
