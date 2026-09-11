import 'package:glass_forge_workbench/l10n/gen/app_localizations.dart';

/// Static localization accessor for use in non-widget code
/// (validators, formatters, models, utilities) where BuildContext
/// is not available.
///
/// In widgets/screens, prefer `context.l10n.keyName` instead.
///
/// Usage:
/// ```dart
/// import 'package:glass_forge_workbench/l10n/localization_service.dart';
///
/// final text = Localization.appName;
/// ```
class Localization {
  Localization._();

  static late AppLocalizations _instance;

  /// Called automatically by AppView on every build/locale change.
  /// Do not call manually.
  static void update(AppLocalizations localizations) {
    _instance = localizations;
  }

  static String get appName => _instance.appName;
  static String get back => _instance.back;
  static String get samplingProbe => _instance.samplingProbe;
  static String get resetToDefaults => _instance.resetToDefaults;
  static String get presetDome => _instance.presetDome;
  static String get presetRegular => _instance.presetRegular;
  static String get presetClear => _instance.presetClear;
  static String get presetTinted => _instance.presetTinted;
  static String get presetDemonstration => _instance.presetDemonstration;
  static String get tabShowcase => _instance.tabShowcase;
  static String get tabComponents => _instance.tabComponents;
  static String get tabMaterial => _instance.tabMaterial;
  static String get tabLab => _instance.tabLab;
  static String get labTitle => _instance.labTitle;
  static String get labSubtitle => _instance.labSubtitle;
  static String get labToolTiers => _instance.labToolTiers;
  static String get labToolTiersSummary => _instance.labToolTiersSummary;
  static String get labToolBlend => _instance.labToolBlend;
  static String get labToolBlendSummary => _instance.labToolBlendSummary;
  static String get labToolMotion => _instance.labToolMotion;
  static String get labToolMotionSummary => _instance.labToolMotionSummary;
  static String get labToolSurfaces => _instance.labToolSurfaces;
  static String get labToolSurfacesSummary => _instance.labToolSurfacesSummary;
  static String get labToolProbe => _instance.labToolProbe;
  static String get labToolProbeSummary => _instance.labToolProbeSummary;
  static String get showcaseTitle => _instance.showcaseTitle;
  static String get showcaseSearchHint => _instance.showcaseSearchHint;
  static String get clearSearch => _instance.clearSearch;
  static String get categoryForYou => _instance.categoryForYou;
  static String get categoryNearby => _instance.categoryNearby;
  static String get categorySaved => _instance.categorySaved;
  static String get yourTrips => _instance.yourTrips;
  static String get notifications => _instance.notifications;
  static String placeSubtitle(String region, String distance) =>
      _instance.placeSubtitle(region, distance);
  static String placeDistance(String distance) =>
      _instance.placeDistance(distance);
  static String get savePlace => _instance.savePlace;
  static String get unsavePlace => _instance.unsavePlace;
  static String bookmarkPlace(String place) => _instance.bookmarkPlace(place);
  static String unbookmarkPlace(String place) =>
      _instance.unbookmarkPlace(place);
  static String get placeSavedToast => _instance.placeSavedToast;
  static String get placeRemovedToast => _instance.placeRemovedToast;
  static String get copyName => _instance.copyName;
  static String get nameCopiedToast => _instance.nameCopiedToast;
  static String get emptySavedTitle => _instance.emptySavedTitle;
  static String get emptySavedBody => _instance.emptySavedBody;
  static String get emptySearchTitle => _instance.emptySearchTitle;
  static String get emptySearchBody => _instance.emptySearchBody;
  static String get showAllPlaces => _instance.showAllPlaces;
  static String get play => _instance.play;
  static String get pause => _instance.pause;
  static String get statSaved => _instance.statSaved;
  static String get statSavedUnit => _instance.statSavedUnit;
  static String get statNearest => _instance.statNearest;
  static String get statNearestUnit => _instance.statNearestUnit;
  static String get tripsEmpty => _instance.tripsEmpty;
  static String get notificationsAllRead => _instance.notificationsAllRead;
  static String get componentsTitle => _instance.componentsTitle;
  static String componentsSubtitle(String count) =>
      _instance.componentsSubtitle(count);
  static String get componentsSearchHint => _instance.componentsSearchHint;
  static String get componentsEmptyTitle => _instance.componentsEmptyTitle;
  static String get componentsEmptyBody => _instance.componentsEmptyBody;
  static String get familyNavigation => _instance.familyNavigation;
  static String get familyControls => _instance.familyControls;
  static String get familyContent => _instance.familyContent;
  static String get familyOverlays => _instance.familyOverlays;
  static String get componentTabBar => _instance.componentTabBar;
  static String get componentTabBarSummary => _instance.componentTabBarSummary;
  static String get componentTopBar => _instance.componentTopBar;
  static String get componentTopBarSummary => _instance.componentTopBarSummary;
  static String get componentCircleButton => _instance.componentCircleButton;
  static String get componentCircleButtonSummary =>
      _instance.componentCircleButtonSummary;
  static String get componentSegmented => _instance.componentSegmented;
  static String get componentSegmentedSummary =>
      _instance.componentSegmentedSummary;
  static String get componentButton => _instance.componentButton;
  static String get componentButtonSummary => _instance.componentButtonSummary;
  static String get componentSwitch => _instance.componentSwitch;
  static String get componentSwitchSummary => _instance.componentSwitchSummary;
  static String get componentSlider => _instance.componentSlider;
  static String get componentSliderSummary => _instance.componentSliderSummary;
  static String get componentStepper => _instance.componentStepper;
  static String get componentStepperSummary =>
      _instance.componentStepperSummary;
  static String get componentMediaCard => _instance.componentMediaCard;
  static String get componentMediaCardSummary =>
      _instance.componentMediaCardSummary;
  static String get componentStatCard => _instance.componentStatCard;
  static String get componentStatCardSummary =>
      _instance.componentStatCardSummary;
  static String get componentToast => _instance.componentToast;
  static String get componentToastSummary => _instance.componentToastSummary;
  static String get componentSheet => _instance.componentSheet;
  static String get componentSheetSummary => _instance.componentSheetSummary;
  static String get componentContextMenu => _instance.componentContextMenu;
  static String get componentContextMenuSummary =>
      _instance.componentContextMenuSummary;
  static String get componentMiniPlayer => _instance.componentMiniPlayer;
  static String get componentMiniPlayerSummary =>
      _instance.componentMiniPlayerSummary;
  static String get componentSearchBar => _instance.componentSearchBar;
  static String get componentSearchBarSummary =>
      _instance.componentSearchBarSummary;
  static String get backdropPhoto => _instance.backdropPhoto;
  static String get backdropCity => _instance.backdropCity;
  static String get backdropMesh => _instance.backdropMesh;
  static String get backdropChecker => _instance.backdropChecker;
  static String get backdropBlack => _instance.backdropBlack;
  static String get paneVariants => _instance.paneVariants;
  static String get paneMaterial => _instance.paneMaterial;
  static String get paneCode => _instance.paneCode;
  static String get knobTabs => _instance.knobTabs;
  static String get knobLabels => _instance.knobLabels;
  static String get knobBadge => _instance.knobBadge;
  static String get knobSquash => _instance.knobSquash;
  static String get knobSpring => _instance.knobSpring;
  static String get knobLeading => _instance.knobLeading;
  static String get knobTrailing => _instance.knobTrailing;
  static String get knobIcon => _instance.knobIcon;
  static String get knobOptions => _instance.knobOptions;
  static String get knobStyle => _instance.knobStyle;
  static String get knobLoading => _instance.knobLoading;
  static String get knobDisabled => _instance.knobDisabled;
  static String get knobFullWidth => _instance.knobFullWidth;
  static String get knobPhoto => _instance.knobPhoto;
  static String get knobChip => _instance.knobChip;
  static String get knobAction => _instance.knobAction;
  static String get knobAspect => _instance.knobAspect;
  static String get knobDelta => _instance.knobDelta;
  static String get knobDestructive => _instance.knobDestructive;
  static String get knobMax => _instance.knobMax;
  static String get optionNone => _instance.optionNone;
  static String get optionBack => _instance.optionBack;
  static String get optionProfile => _instance.optionProfile;
  static String get optionShare => _instance.optionShare;
  static String get optionMore => _instance.optionMore;
  static String get optionHeart => _instance.optionHeart;
  static String get optionBell => _instance.optionBell;
  static String get optionPlus => _instance.optionPlus;
  static String get optionPrimary => _instance.optionPrimary;
  static String get optionSecondary => _instance.optionSecondary;
  static String get optionLake => _instance.optionLake;
  static String get optionCity => _instance.optionCity;
  static String get optionCliffs => _instance.optionCliffs;
  static String get optionUp => _instance.optionUp;
  static String get optionDown => _instance.optionDown;
  static String get demoHome => _instance.demoHome;
  static String get demoExplore => _instance.demoExplore;
  static String get demoSaved => _instance.demoSaved;
  static String get demoProfile => _instance.demoProfile;
  static String get demoInbox => _instance.demoInbox;
  static String get demoDay => _instance.demoDay;
  static String get demoWeek => _instance.demoWeek;
  static String get demoMonth => _instance.demoMonth;
  static String get demoYear => _instance.demoYear;
  static String get demoTitle => _instance.demoTitle;
  static String get demoContinue => _instance.demoContinue;
  static String get demoGuests => _instance.demoGuests;
  static String get demoBrightness => _instance.demoBrightness;
  static String get demoWifi => _instance.demoWifi;
  static String get demoAirplane => _instance.demoAirplane;
  static String get demoSteps => _instance.demoSteps;
  static String get demoStepsUnit => _instance.demoStepsUnit;
  static String get demoShowToast => _instance.demoShowToast;
  static String get demoToastMessage => _instance.demoToastMessage;
  static String get demoOpenSheet => _instance.demoOpenSheet;
  static String get demoSheetTitle => _instance.demoSheetTitle;
  static String get demoSheetBody => _instance.demoSheetBody;
  static String get demoLongPress => _instance.demoLongPress;
  static String get demoDelete => _instance.demoDelete;
  static String get demoTapHint => _instance.demoTapHint;
  static String get decrease => _instance.decrease;
  static String get increase => _instance.increase;
  static String get useHouseMaterial => _instance.useHouseMaterial;
  static String get useHouseMaterialNote => _instance.useHouseMaterialNote;
  static String get copyCode => _instance.copyCode;
  static String get codeCopiedToast => _instance.codeCopiedToast;
  static String get noKnobs => _instance.noKnobs;
  static String get presets => _instance.presets;
  static String get backdrop => _instance.backdrop;
  static String get groupGeometry => _instance.groupGeometry;
  static String get groupOptics => _instance.groupOptics;
  static String get groupLight => _instance.groupLight;
  static String get groupTint => _instance.groupTint;
  static String get groupModel => _instance.groupModel;
  static String get groupShape => _instance.groupShape;
  static String get knobThickness => _instance.knobThickness;
  static String get knobEdgeRefraction => _instance.knobEdgeRefraction;
  static String get knobRefractionSpread => _instance.knobRefractionSpread;
  static String get knobHighlight => _instance.knobHighlight;
  static String get knobContour => _instance.knobContour;
  static String get knobFrost => _instance.knobFrost;
  static String get knobChromatic => _instance.knobChromatic;
  static String get knobSaturation => _instance.knobSaturation;
  static String get knobTintOpacity => _instance.knobTintOpacity;
  static String get knobProfile => _instance.knobProfile;
  static String get knobVariant => _instance.knobVariant;
  static String get profileEdgeBand => _instance.profileEdgeBand;
  static String get profileDome => _instance.profileDome;
  static String get variantRegular => _instance.variantRegular;
  static String get variantClear => _instance.variantClear;
  static String get materialTitle => _instance.materialTitle;
  static String get materialSubtitle => _instance.materialSubtitle;
  static String get copyAsDart => _instance.copyAsDart;
  static String get copiedAsDartToast => _instance.copiedAsDartToast;
  static String get stageInContext => _instance.stageInContext;
  static String get stageShape => _instance.stageShape;
  static String get demoCardTitle => _instance.demoCardTitle;
  static String get demoCardBody => _instance.demoCardBody;
  static String get domeSpreadNote => _instance.domeSpreadNote;
}
