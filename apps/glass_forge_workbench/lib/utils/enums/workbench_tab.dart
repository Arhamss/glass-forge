import 'package:glass_forge_workbench/exports.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';

/// The four tabs of the workbench. Declaration order is the order of the
/// shell's branches and of the tabs in the bar.
enum WorkbenchTab { showcase, components, material, lab }

extension WorkbenchTabX on WorkbenchTab {
  String get label => switch (this) {
    WorkbenchTab.showcase => Localization.tabShowcase,
    WorkbenchTab.components => Localization.tabComponents,
    WorkbenchTab.material => Localization.tabMaterial,
    WorkbenchTab.lab => Localization.tabLab,
  };

  String get icon => switch (this) {
    WorkbenchTab.showcase => AssetPaths.squaresFour,
    WorkbenchTab.components => AssetPaths.stack,
    WorkbenchTab.material => AssetPaths.cube,
    WorkbenchTab.lab => AssetPaths.flask,
  };

  String get activeIcon => switch (this) {
    WorkbenchTab.showcase => AssetPaths.squaresFourFill,
    WorkbenchTab.components => AssetPaths.stackFill,
    WorkbenchTab.material => AssetPaths.cubeFill,
    WorkbenchTab.lab => AssetPaths.flaskFill,
  };

  String get path => switch (this) {
    WorkbenchTab.showcase => AppRoutes.showcase,
    WorkbenchTab.components => AppRoutes.components,
    WorkbenchTab.material => AppRoutes.material,
    WorkbenchTab.lab => AppRoutes.lab,
  };
}
