// dart format off
// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Glass Forge Workbench';

  @override
  String get back => 'Back';

  @override
  String get samplingProbe => 'Sampling probe';

  @override
  String get resetToDefaults => 'Reset to defaults';

  @override
  String get presetDome => 'Dome';

  @override
  String get presetRegular => 'Regular';

  @override
  String get presetClear => 'Clear';

  @override
  String get presetTinted => 'Tinted';

  @override
  String get presetDemonstration => 'Demo';
}
