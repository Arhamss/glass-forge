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

  static String get appName => _instance.appName;
  static String get back => _instance.back;
  static String get samplingProbe => _instance.samplingProbe;
  static String get resetToDefaults => _instance.resetToDefaults;
  static String get presetDome => _instance.presetDome;
  static String get presetRegular => _instance.presetRegular;
  static String get presetClear => _instance.presetClear;
  static String get presetTinted => _instance.presetTinted;
  static String get presetDemonstration => _instance.presetDemonstration;
}
