import 'package:glass_forge_workbench/l10n/localization_service.dart';

enum PlaygroundPane { variants, material, code }

extension PlaygroundPaneX on PlaygroundPane {
  String get label => switch (this) {
    PlaygroundPane.variants => Localization.paneVariants,
    PlaygroundPane.material => Localization.paneMaterial,
    PlaygroundPane.code => Localization.paneCode,
  };
}
