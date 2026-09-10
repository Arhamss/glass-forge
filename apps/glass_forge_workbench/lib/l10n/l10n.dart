import 'package:flutter/material.dart';
import 'package:glass_forge_workbench/l10n/gen/app_localizations.dart';

export 'package:glass_forge_workbench/l10n/gen/app_localizations.dart';
export 'package:glass_forge_workbench/l10n/localization_service.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
