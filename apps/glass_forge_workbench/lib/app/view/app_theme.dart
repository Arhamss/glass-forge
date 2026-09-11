import 'package:flutter/cupertino.dart';
import 'package:glass_forge_workbench/exports.dart';

abstract class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      surface: AppColors.ground,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppFonts.sans,
      scaffoldBackgroundColor: AppColors.ground,
      canvasColor: AppColors.ground,
      // Feedback comes from each control's own press state and haptics, not
      // from Material ink spreading under glass.
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentSoft,
        selectionHandleColor: AppColors.accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
