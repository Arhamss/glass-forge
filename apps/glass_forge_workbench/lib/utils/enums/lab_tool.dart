import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';

/// The engineering tools under the Lab tab.
enum LabTool { tiers, blend, motion, surfaces, samplingProbe }

extension LabToolX on LabTool {
  String get title => switch (this) {
    LabTool.tiers => Localization.labToolTiers,
    LabTool.blend => Localization.labToolBlend,
    LabTool.motion => Localization.labToolMotion,
    LabTool.surfaces => Localization.labToolSurfaces,
    LabTool.samplingProbe => Localization.labToolProbe,
  };

  String get summary => switch (this) {
    LabTool.tiers => Localization.labToolTiersSummary,
    LabTool.blend => Localization.labToolBlendSummary,
    LabTool.motion => Localization.labToolMotionSummary,
    LabTool.surfaces => Localization.labToolSurfacesSummary,
    LabTool.samplingProbe => Localization.labToolProbeSummary,
  };

  String get icon => switch (this) {
    LabTool.tiers => AssetPaths.gauge,
    LabTool.blend => AssetPaths.circlesThree,
    LabTool.motion => AssetPaths.handGrabbing,
    LabTool.surfaces => AssetPaths.cards,
    LabTool.samplingProbe => AssetPaths.crosshair,
  };

  String get routeName => switch (this) {
    LabTool.tiers => AppRouteNames.labTiers,
    LabTool.blend => AppRouteNames.labBlend,
    LabTool.motion => AppRouteNames.labMotion,
    LabTool.surfaces => AppRouteNames.labSurfaces,
    LabTool.samplingProbe => AppRouteNames.labSamplingProbe,
  };
}
