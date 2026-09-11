import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/l10n/localization_service.dart';
import 'package:glass_forge_workbench/utils/enums/component_family.dart';

/// Every component in the glass kit, in catalog order.
enum ComponentId {
  tabBar,
  topBar,
  circleButton,
  segmentedControl,
  button,
  glassSwitch,
  slider,
  stepper,
  mediaCard,
  statCard,
  toast,
  bottomSheet,
  contextMenu,
  miniPlayer,
  searchBar,
}

extension ComponentIdX on ComponentId {
  ComponentFamily get family => switch (this) {
    ComponentId.tabBar ||
    ComponentId.topBar ||
    ComponentId.circleButton ||
    ComponentId.segmentedControl => ComponentFamily.navigation,
    ComponentId.button ||
    ComponentId.glassSwitch ||
    ComponentId.slider ||
    ComponentId.stepper => ComponentFamily.controls,
    ComponentId.mediaCard ||
    ComponentId.statCard ||
    ComponentId.toast => ComponentFamily.content,
    ComponentId.bottomSheet ||
    ComponentId.contextMenu ||
    ComponentId.miniPlayer ||
    ComponentId.searchBar => ComponentFamily.overlays,
  };

  String get title => switch (this) {
    ComponentId.tabBar => Localization.componentTabBar,
    ComponentId.topBar => Localization.componentTopBar,
    ComponentId.circleButton => Localization.componentCircleButton,
    ComponentId.segmentedControl => Localization.componentSegmented,
    ComponentId.button => Localization.componentButton,
    ComponentId.glassSwitch => Localization.componentSwitch,
    ComponentId.slider => Localization.componentSlider,
    ComponentId.stepper => Localization.componentStepper,
    ComponentId.mediaCard => Localization.componentMediaCard,
    ComponentId.statCard => Localization.componentStatCard,
    ComponentId.toast => Localization.componentToast,
    ComponentId.bottomSheet => Localization.componentSheet,
    ComponentId.contextMenu => Localization.componentContextMenu,
    ComponentId.miniPlayer => Localization.componentMiniPlayer,
    ComponentId.searchBar => Localization.componentSearchBar,
  };

  String get summary => switch (this) {
    ComponentId.tabBar => Localization.componentTabBarSummary,
    ComponentId.topBar => Localization.componentTopBarSummary,
    ComponentId.circleButton => Localization.componentCircleButtonSummary,
    ComponentId.segmentedControl => Localization.componentSegmentedSummary,
    ComponentId.button => Localization.componentButtonSummary,
    ComponentId.glassSwitch => Localization.componentSwitchSummary,
    ComponentId.slider => Localization.componentSliderSummary,
    ComponentId.stepper => Localization.componentStepperSummary,
    ComponentId.mediaCard => Localization.componentMediaCardSummary,
    ComponentId.statCard => Localization.componentStatCardSummary,
    ComponentId.toast => Localization.componentToastSummary,
    ComponentId.bottomSheet => Localization.componentSheetSummary,
    ComponentId.contextMenu => Localization.componentContextMenuSummary,
    ComponentId.miniPlayer => Localization.componentMiniPlayerSummary,
    ComponentId.searchBar => Localization.componentSearchBarSummary,
  };

  String get glyph => switch (this) {
    ComponentId.tabBar => AssetPaths.tabs,
    ComponentId.topBar => AssetPaths.appWindow,
    ComponentId.circleButton => AssetPaths.radioButton,
    ComponentId.segmentedControl => AssetPaths.listDashes,
    ComponentId.button => AssetPaths.cursorClick,
    ComponentId.glassSwitch => AssetPaths.toggleRight,
    ComponentId.slider => AssetPaths.slidersHorizontal,
    ComponentId.stepper => AssetPaths.plusMinus,
    ComponentId.mediaCard => AssetPaths.image,
    ComponentId.statCard => AssetPaths.chartBar,
    ComponentId.toast => AssetPaths.bellSimpleRinging,
    ComponentId.bottomSheet => AssetPaths.arrowSquareUp,
    ComponentId.contextMenu => AssetPaths.list,
    ComponentId.miniPlayer => AssetPaths.playCircle,
    ComponentId.searchBar => AssetPaths.textbox,
  };
}
