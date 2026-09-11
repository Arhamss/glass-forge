import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';

extension GlassProfileX on GlassProfile {
  String get label => switch (this) {
    GlassProfile.edgeBand => Localization.profileEdgeBand,
    GlassProfile.dome => Localization.profileDome,
  };
}
