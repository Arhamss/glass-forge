import 'package:glass_forge_workbench/l10n/localization_service.dart';

enum ComponentFamily { navigation, controls, content, overlays }

extension ComponentFamilyX on ComponentFamily {
  String get label => switch (this) {
    ComponentFamily.navigation => Localization.familyNavigation,
    ComponentFamily.controls => Localization.familyControls,
    ComponentFamily.content => Localization.familyContent,
    ComponentFamily.overlays => Localization.familyOverlays,
  };
}
