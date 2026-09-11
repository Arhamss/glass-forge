import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:glass_forge_workbench/utils/widgets/material/material_group.dart';

extension MaterialGroupX on MaterialGroup {
  String get label => switch (this) {
    MaterialGroup.shape => Localization.groupShape,
    MaterialGroup.optics => Localization.groupOptics,
    MaterialGroup.light => Localization.groupLight,
    MaterialGroup.tint => Localization.groupTint,
  };
}
