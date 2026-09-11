// dart format off
// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Glass Forge Workbench';

  @override
  String get back => 'Back';

  @override
  String get samplingProbe => 'Sampling probe';

  @override
  String get resetToDefaults => 'Reset to defaults';

  @override
  String get presetDome => 'Dome';

  @override
  String get presetRegular => 'Regular';

  @override
  String get presetClear => 'Clear';

  @override
  String get presetTinted => 'Tinted';

  @override
  String get presetDemonstration => 'Demo';

  @override
  String get tabShowcase => 'Showcase';

  @override
  String get tabComponents => 'Components';

  @override
  String get tabMaterial => 'Material';

  @override
  String get tabLab => 'Lab';

  @override
  String get labTitle => 'Lab';

  @override
  String get labSubtitle => 'The instruments behind the kit';

  @override
  String get labToolTiers => 'Tiers';

  @override
  String get labToolTiersSummary => 'Which tier this device renders, and the signals behind it';

  @override
  String get labToolBlend => 'Blend';

  @override
  String get labToolBlendSummary => 'Shapes that pool into one another as they meet';

  @override
  String get labToolMotion => 'Motion';

  @override
  String get labToolMotionSummary => 'Springs, drag and squash, with every constant live';

  @override
  String get labToolSurfaces => 'Surfaces';

  @override
  String get labToolSurfacesSummary => 'The five semantic roles, in a light app and a dark one';

  @override
  String get labToolProbe => 'Sampling probe';

  @override
  String get labToolProbeSummary => 'Bilinear against shipped sampling, frame by frame';

  @override
  String get showcaseTitle => 'Discover';

  @override
  String get showcaseSearchHint => 'Search places';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get categoryForYou => 'For you';

  @override
  String get categoryNearby => 'Nearby';

  @override
  String get categorySaved => 'Saved';

  @override
  String get yourTrips => 'Your trips';

  @override
  String get notifications => 'Notifications';

  @override
  String placeSubtitle(String region, String distance) {
    return '$region · $distance km';
  }

  @override
  String placeDistance(String distance) {
    return '$distance km';
  }

  @override
  String get savePlace => 'Save to list';

  @override
  String get unsavePlace => 'Remove from list';

  @override
  String bookmarkPlace(String place) {
    return 'Save $place';
  }

  @override
  String unbookmarkPlace(String place) {
    return 'Remove $place from saved';
  }

  @override
  String get placeSavedToast => 'Saved to your list';

  @override
  String get placeRemovedToast => 'Removed from your list';

  @override
  String get copyName => 'Copy name';

  @override
  String get nameCopiedToast => 'Name copied';

  @override
  String get emptySavedTitle => 'Nothing saved yet';

  @override
  String get emptySavedBody => 'Tap the bookmark on any place and it will wait for you here.';

  @override
  String get emptySearchTitle => 'No places match';

  @override
  String get emptySearchBody => 'Try another name, or a region.';

  @override
  String get showAllPlaces => 'Show all places';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get statSaved => 'Saved';

  @override
  String get statSavedUnit => 'places';

  @override
  String get statNearest => 'Nearest';

  @override
  String get statNearestUnit => 'km';

  @override
  String get tripsEmpty => 'Places you save show up here, nearest first.';

  @override
  String get notificationsAllRead => 'You\'re all caught up.';

  @override
  String get componentsTitle => 'Components';

  @override
  String componentsSubtitle(String count) {
    return '$count glass parts, all live';
  }

  @override
  String get componentsSearchHint => 'Search components';

  @override
  String get componentsEmptyTitle => 'No parts match';

  @override
  String get componentsEmptyBody => 'Try a family, like cards or overlays.';

  @override
  String get familyNavigation => 'Navigation';

  @override
  String get familyControls => 'Buttons & controls';

  @override
  String get familyContent => 'Cards & content';

  @override
  String get familyOverlays => 'Overlays';

  @override
  String get componentTabBar => 'Tab bar';

  @override
  String get componentTabBarSummary => 'Floating capsule with a liquid selector';

  @override
  String get componentTopBar => 'Top bar';

  @override
  String get componentTopBarSummary => 'A title between glass circle buttons';

  @override
  String get componentCircleButton => 'Circle button';

  @override
  String get componentCircleButtonSummary => 'One icon on a glass disc';

  @override
  String get componentSegmented => 'Segmented control';

  @override
  String get componentSegmentedSummary => 'A sliding selector you can scrub';

  @override
  String get componentButton => 'Button';

  @override
  String get componentButtonSummary => 'Primary and secondary capsules';

  @override
  String get componentSwitch => 'Switch';

  @override
  String get componentSwitchSummary => 'A glass knob on a lit track';

  @override
  String get componentSlider => 'Slider';

  @override
  String get componentSliderSummary => 'A lens that magnifies its track';

  @override
  String get componentStepper => 'Stepper';

  @override
  String get componentStepperSummary => 'Minus, a value, plus';

  @override
  String get componentMediaCard => 'Media card';

  @override
  String get componentMediaCardSummary => 'A photo with a glass caption';

  @override
  String get componentStatCard => 'Stat card';

  @override
  String get componentStatCardSummary => 'The number first, then the words';

  @override
  String get componentToast => 'Toast';

  @override
  String get componentToastSummary => 'A capsule that drops in and leaves';

  @override
  String get componentSheet => 'Bottom sheet';

  @override
  String get componentSheetSummary => 'A floating glass sheet with detents';

  @override
  String get componentContextMenu => 'Context menu';

  @override
  String get componentContextMenuSummary => 'Long-press actions on glass';

  @override
  String get componentMiniPlayer => 'Mini player';

  @override
  String get componentMiniPlayerSummary => 'What is playing, in one capsule';

  @override
  String get componentSearchBar => 'Search bar';

  @override
  String get componentSearchBarSummary => 'A glass field with a clear button';

  @override
  String get backdropPhoto => 'Photo';

  @override
  String get backdropCity => 'City';

  @override
  String get backdropMesh => 'Mesh';

  @override
  String get backdropChecker => 'Checker';

  @override
  String get backdropBlack => 'Black';

  @override
  String get paneVariants => 'Variants';

  @override
  String get paneMaterial => 'Material';

  @override
  String get paneCode => 'Code';

  @override
  String get knobTabs => 'Tabs';

  @override
  String get knobLabels => 'Labels';

  @override
  String get knobBadge => 'Badge';

  @override
  String get knobSquash => 'Squash';

  @override
  String get knobSpring => 'Selector spring';

  @override
  String get knobLeading => 'Leading';

  @override
  String get knobTrailing => 'Trailing';

  @override
  String get knobIcon => 'Icon';

  @override
  String get knobOptions => 'Options';

  @override
  String get knobStyle => 'Style';

  @override
  String get knobLoading => 'Loading';

  @override
  String get knobDisabled => 'Disabled';

  @override
  String get knobFullWidth => 'Full width';

  @override
  String get knobPhoto => 'Photo';

  @override
  String get knobChip => 'Corner chip';

  @override
  String get knobAction => 'Action button';

  @override
  String get knobAspect => 'Aspect';

  @override
  String get knobDelta => 'Change';

  @override
  String get knobDestructive => 'Destructive action';

  @override
  String get knobMax => 'Maximum';

  @override
  String get optionNone => 'None';

  @override
  String get optionBack => 'Back';

  @override
  String get optionProfile => 'Profile';

  @override
  String get optionShare => 'Share';

  @override
  String get optionMore => 'More';

  @override
  String get optionHeart => 'Heart';

  @override
  String get optionBell => 'Bell';

  @override
  String get optionPlus => 'Plus';

  @override
  String get optionPrimary => 'Primary';

  @override
  String get optionSecondary => 'Secondary';

  @override
  String get optionLake => 'Lake';

  @override
  String get optionCity => 'City';

  @override
  String get optionCliffs => 'Cliffs';

  @override
  String get optionUp => 'Up';

  @override
  String get optionDown => 'Down';

  @override
  String get demoHome => 'Home';

  @override
  String get demoExplore => 'Explore';

  @override
  String get demoSaved => 'Saved';

  @override
  String get demoProfile => 'Profile';

  @override
  String get demoInbox => 'Inbox';

  @override
  String get demoDay => 'Day';

  @override
  String get demoWeek => 'Week';

  @override
  String get demoMonth => 'Month';

  @override
  String get demoYear => 'Year';

  @override
  String get demoTitle => 'Trips';

  @override
  String get demoContinue => 'Continue';

  @override
  String get demoGuests => 'Guests';

  @override
  String get demoBrightness => 'Brightness';

  @override
  String get demoWifi => 'Wi-Fi';

  @override
  String get demoAirplane => 'Airplane mode';

  @override
  String get demoSteps => 'Steps';

  @override
  String get demoStepsUnit => 'today';

  @override
  String get demoShowToast => 'Show a toast';

  @override
  String get demoToastMessage => 'Saved to your list';

  @override
  String get demoOpenSheet => 'Open the sheet';

  @override
  String get demoSheetTitle => 'A sheet of glass';

  @override
  String get demoSheetBody => 'It floats above the screen and bends whatever is behind it. Drag it down to close.';

  @override
  String get demoLongPress => 'Long-press the card';

  @override
  String get demoDelete => 'Delete';

  @override
  String get demoTapHint => 'Tap it';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get useHouseMaterial => 'Use the house material';

  @override
  String get useHouseMaterialNote => 'Off gives this playground its own material, starting from the house one.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopiedToast => 'Code copied';

  @override
  String get noKnobs => 'Nothing to tune here. Try the Material pane, or a different backdrop.';

  @override
  String get presets => 'Presets';

  @override
  String get backdrop => 'Backdrop';

  @override
  String get groupGeometry => 'Geometry';

  @override
  String get groupOptics => 'Optics';

  @override
  String get groupLight => 'Light';

  @override
  String get groupTint => 'Tint';

  @override
  String get groupModel => 'Model';

  @override
  String get groupShape => 'Shape';

  @override
  String get knobThickness => 'Thickness';

  @override
  String get knobEdgeRefraction => 'Edge refraction';

  @override
  String get knobRefractionSpread => 'Refraction spread';

  @override
  String get knobHighlight => 'Highlight';

  @override
  String get knobContour => 'Contour';

  @override
  String get knobFrost => 'Frost';

  @override
  String get knobChromatic => 'Chromatic aberration';

  @override
  String get knobSaturation => 'Saturation';

  @override
  String get knobTintOpacity => 'Tint opacity';

  @override
  String get knobProfile => 'Profile';

  @override
  String get knobVariant => 'Variant';

  @override
  String get profileEdgeBand => 'Edge band';

  @override
  String get profileDome => 'Dome';

  @override
  String get variantRegular => 'Regular';

  @override
  String get variantClear => 'Clear';

  @override
  String get materialTitle => 'Material';

  @override
  String get materialSubtitle => 'One glass, worn by every screen';

  @override
  String get copyAsDart => 'Copy as Dart';

  @override
  String get copiedAsDartToast => 'Material copied as Dart';

  @override
  String get stageInContext => 'In context';

  @override
  String get stageShape => 'Shape';

  @override
  String get demoCardTitle => 'Glass card';

  @override
  String get demoCardBody => 'Tune it here and every screen follows.';

  @override
  String get domeSpreadNote => 'A dome bends across its whole face, so spread has nothing to do.';
}
