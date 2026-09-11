import 'package:flutter/material.dart';
import 'package:glass_forge_workbench/app/view/app_theme.dart';
import 'package:glass_forge_workbench/l10n/l10n.dart';

/// Hosts [home] the way the real app does: the workbench theme, the
/// localization delegates, and the static `Localization` that non-widget code
/// (enum labels, formatters) reads.
Widget testApp(Widget home) {
  return MaterialApp(
    theme: AppTheme.dark,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      Localization.update(AppLocalizations.of(context));
      return child ?? const SizedBox.shrink();
    },
    home: home,
  );
}
