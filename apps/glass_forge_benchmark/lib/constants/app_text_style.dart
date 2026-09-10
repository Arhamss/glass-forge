import 'package:flutter/material.dart';
import 'package:glass_forge_benchmark/constants/app_colors.dart';

abstract class AppFonts {
  static const heading = 'BBBPoppins';
  static const body = 'SFProRounded';
}

extension AppTextStyle on BuildContext {
  TextStyle _heading(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    FontStyle fontStyle = FontStyle.normal,
    double height = 1.3,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: AppFonts.heading,
      fontSize: size,
      fontWeight: weight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle _body(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    FontStyle fontStyle = FontStyle.normal,
    double height = 1.3,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: size,
      fontWeight: weight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  TextStyle get display => _heading(43, FontWeight.w400, height: 1.2);

  TextStyle get h1 => _heading(32, FontWeight.w400, height: 1.2);
  TextStyle get h1Medium => _heading(32, FontWeight.w500, height: 1.2);
  TextStyle get h1Bold => _heading(32, FontWeight.w700, height: 1.2);

  TextStyle get h2 => _heading(28, FontWeight.w400, height: 1.2);
  TextStyle get h2Medium => _heading(28, FontWeight.w500, height: 1.2);
  TextStyle get h2Bold => _heading(28, FontWeight.w700, height: 1.2);

  TextStyle get h3 => _heading(24, FontWeight.w400);
  TextStyle get h3Medium => _heading(24, FontWeight.w500);
  TextStyle get h3Bold => _heading(24, FontWeight.w700);

  TextStyle get h4 => _heading(20, FontWeight.w400);
  TextStyle get h4Medium => _heading(20, FontWeight.w500);
  TextStyle get h4Bold => _heading(20, FontWeight.w700);

  TextStyle get h5 => _heading(18, FontWeight.w400);
  TextStyle get h5Medium => _heading(18, FontWeight.w500);
  TextStyle get h5Bold => _heading(18, FontWeight.w700);

  TextStyle get p1 => _body(16, FontWeight.w400);
  TextStyle get p1Medium => _body(16, FontWeight.w500);
  TextStyle get p1Bold => _body(16, FontWeight.w700);

  TextStyle get p2 => _body(14, FontWeight.w400);
  TextStyle get p2Medium => _body(14, FontWeight.w500);
  TextStyle get p2Bold => _body(14, FontWeight.w700);

  TextStyle get caption => _body(12, FontWeight.w400);
  TextStyle get captionMedium => _body(12, FontWeight.w500);
  TextStyle get captionBold => _body(12, FontWeight.w700);

  TextStyle get overline => _body(10, FontWeight.w400);
}

extension TextStyleModifiers on TextStyle {
  TextStyle get primary => copyWith(color: AppColors.textPrimary);
  TextStyle get secondary => copyWith(color: AppColors.textOnPrimary);
  TextStyle get light => copyWith(color: AppColors.textSecondary);
  TextStyle get hint => copyWith(color: AppColors.textTertiary);
}

extension TextStyleWithStyle on TextStyle {
  TextStyle withStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    String? fontFamily,
  }) {
    return copyWith(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
    );
  }
}
