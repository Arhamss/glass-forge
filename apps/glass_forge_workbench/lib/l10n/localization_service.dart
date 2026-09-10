import 'package:glass_forge_workbench/l10n/gen/app_localizations.dart';

/// Static localization accessor for use in non-widget code
/// (validators, formatters, models, utilities) where BuildContext
/// is not available.
///
/// In widgets/screens, prefer `context.l10n.keyName` instead.
///
/// Usage:
/// ```dart
/// import 'package:glass_forge_workbench/l10n/localization_service.dart';
///
/// final text = Localization.appName;
/// ```
class Localization {
  Localization._();

  static late AppLocalizations _instance;

  /// Called automatically by AppView on every build/locale change.
  /// Do not call manually.
  static void update(AppLocalizations localizations) {
    _instance = localizations;
  }

  // ── General ──────────────────────────────────────────────

  static String get appName => _instance.appName;
  static String get login => _instance.login;
  static String get logout => _instance.logout;
  static String get home => _instance.home;
  static String get loginToContinue => _instance.loginToContinue;
  static String get somethingWentWrong => _instance.somethingWentWrong;
}
