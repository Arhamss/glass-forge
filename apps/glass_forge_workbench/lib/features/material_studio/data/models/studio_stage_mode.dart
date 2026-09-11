import 'package:glass_forge_workbench/l10n/localization_service.dart';

/// What the Material stage shows: the material worn by real components, or
/// one plain shape with nothing to distract from the glass.
enum StudioStageMode { inContext, shape }

extension StudioStageModeX on StudioStageMode {
  String get label => switch (this) {
    StudioStageMode.inContext => Localization.stageInContext,
    StudioStageMode.shape => Localization.stageShape,
  };
}
