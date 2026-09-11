import 'package:glass_forge_workbench/l10n/localization_service.dart';

/// What a playground's stage shows behind the component: two photographs for
/// the real case, and three patterns that expose what photographs hide.
enum PlaygroundBackdrop { photo, city, mesh, checker, black }

extension PlaygroundBackdropX on PlaygroundBackdrop {
  String get label => switch (this) {
    PlaygroundBackdrop.photo => Localization.backdropPhoto,
    PlaygroundBackdrop.city => Localization.backdropCity,
    PlaygroundBackdrop.mesh => Localization.backdropMesh,
    PlaygroundBackdrop.checker => Localization.backdropChecker,
    PlaygroundBackdrop.black => Localization.backdropBlack,
  };
}
