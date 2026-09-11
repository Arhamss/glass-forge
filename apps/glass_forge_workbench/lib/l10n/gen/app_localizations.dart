// dart format off
// coverage:ignore-file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Glass Forge Workbench'**
  String get appName;

  /// Accessibility label for a back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Title of the backdrop sampling diagnostic screen
  ///
  /// In en, this message translates to:
  /// **'Sampling probe'**
  String get samplingProbe;

  /// Button that restores every control on a screen
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetToDefaults;

  /// Material preset name
  ///
  /// In en, this message translates to:
  /// **'Dome'**
  String get presetDome;

  /// Material preset name
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get presetRegular;

  /// Material preset name
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get presetClear;

  /// Material preset name
  ///
  /// In en, this message translates to:
  /// **'Tinted'**
  String get presetTinted;

  /// Material preset name
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get presetDemonstration;

  /// Tab bar label
  ///
  /// In en, this message translates to:
  /// **'Showcase'**
  String get tabShowcase;

  /// Tab bar label
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get tabComponents;

  /// Tab bar label
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get tabMaterial;

  /// Tab bar label
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get tabLab;

  /// Lab screen title
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get labTitle;

  /// Lab screen subtitle
  ///
  /// In en, this message translates to:
  /// **'The instruments behind the kit'**
  String get labSubtitle;

  /// Lab tool title
  ///
  /// In en, this message translates to:
  /// **'Tiers'**
  String get labToolTiers;

  /// Lab tool summary
  ///
  /// In en, this message translates to:
  /// **'Which tier this device renders, and the signals behind it'**
  String get labToolTiersSummary;

  /// Lab tool title
  ///
  /// In en, this message translates to:
  /// **'Blend'**
  String get labToolBlend;

  /// Lab tool summary
  ///
  /// In en, this message translates to:
  /// **'Shapes that pool into one another as they meet'**
  String get labToolBlendSummary;

  /// Lab tool title
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get labToolMotion;

  /// Lab tool summary
  ///
  /// In en, this message translates to:
  /// **'Springs, drag and squash, with every constant live'**
  String get labToolMotionSummary;

  /// Lab tool title
  ///
  /// In en, this message translates to:
  /// **'Surfaces'**
  String get labToolSurfaces;

  /// Lab tool summary
  ///
  /// In en, this message translates to:
  /// **'The five semantic roles, in a light app and a dark one'**
  String get labToolSurfacesSummary;

  /// Lab tool title
  ///
  /// In en, this message translates to:
  /// **'Sampling probe'**
  String get labToolProbe;

  /// Lab tool summary
  ///
  /// In en, this message translates to:
  /// **'Bilinear against shipped sampling, frame by frame'**
  String get labToolProbeSummary;

  /// Showcase screen title
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get showcaseTitle;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search places'**
  String get showcaseSearchHint;

  /// Clear button label
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// Feed filter
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get categoryForYou;

  /// Feed filter
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get categoryNearby;

  /// Feed filter
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get categorySaved;

  /// Profile button label and sheet title
  ///
  /// In en, this message translates to:
  /// **'Your trips'**
  String get yourTrips;

  /// Bell button label and sheet title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Card subtitle: region and distance
  ///
  /// In en, this message translates to:
  /// **'{region} · {distance} km'**
  String placeSubtitle(String region, String distance);

  /// Distance readout
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String placeDistance(String distance);

  /// Button that saves a place
  ///
  /// In en, this message translates to:
  /// **'Save to list'**
  String get savePlace;

  /// Button that removes a saved place
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get unsavePlace;

  /// Accessibility label of the bookmark button
  ///
  /// In en, this message translates to:
  /// **'Save {place}'**
  String bookmarkPlace(String place);

  /// Accessibility label of the filled bookmark button
  ///
  /// In en, this message translates to:
  /// **'Remove {place} from saved'**
  String unbookmarkPlace(String place);

  /// Toast after saving
  ///
  /// In en, this message translates to:
  /// **'Saved to your list'**
  String get placeSavedToast;

  /// Toast after removing
  ///
  /// In en, this message translates to:
  /// **'Removed from your list'**
  String get placeRemovedToast;

  /// Context menu action
  ///
  /// In en, this message translates to:
  /// **'Copy name'**
  String get copyName;

  /// Toast after copying
  ///
  /// In en, this message translates to:
  /// **'Name copied'**
  String get nameCopiedToast;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get emptySavedTitle;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark on any place and it will wait for you here.'**
  String get emptySavedBody;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No places match'**
  String get emptySearchTitle;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'Try another name, or a region.'**
  String get emptySearchBody;

  /// Empty state action
  ///
  /// In en, this message translates to:
  /// **'Show all places'**
  String get showAllPlaces;

  /// Media button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Media button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Stat card label
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statSaved;

  /// Stat card unit
  ///
  /// In en, this message translates to:
  /// **'places'**
  String get statSavedUnit;

  /// Stat card label
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get statNearest;

  /// Stat card unit
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get statNearestUnit;

  /// Trips sheet empty text
  ///
  /// In en, this message translates to:
  /// **'Places you save show up here, nearest first.'**
  String get tripsEmpty;

  /// Notifications sheet footer
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get notificationsAllRead;

  /// Catalog title
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get componentsTitle;

  /// Catalog subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} glass parts, all live'**
  String componentsSubtitle(String count);

  /// Catalog search hint
  ///
  /// In en, this message translates to:
  /// **'Search components'**
  String get componentsSearchHint;

  /// Catalog empty title
  ///
  /// In en, this message translates to:
  /// **'No parts match'**
  String get componentsEmptyTitle;

  /// Catalog empty body
  ///
  /// In en, this message translates to:
  /// **'Try a family, like cards or overlays.'**
  String get componentsEmptyBody;

  /// Component family
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get familyNavigation;

  /// Component family
  ///
  /// In en, this message translates to:
  /// **'Buttons & controls'**
  String get familyControls;

  /// Component family
  ///
  /// In en, this message translates to:
  /// **'Cards & content'**
  String get familyContent;

  /// Component family
  ///
  /// In en, this message translates to:
  /// **'Overlays'**
  String get familyOverlays;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Tab bar'**
  String get componentTabBar;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'Floating capsule with a liquid selector'**
  String get componentTabBarSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Top bar'**
  String get componentTopBar;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A title between glass circle buttons'**
  String get componentTopBarSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Circle button'**
  String get componentCircleButton;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'One icon on a glass disc'**
  String get componentCircleButtonSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Segmented control'**
  String get componentSegmented;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A sliding selector you can scrub'**
  String get componentSegmentedSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get componentButton;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'Primary and secondary capsules'**
  String get componentButtonSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get componentSwitch;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A glass knob on a lit track'**
  String get componentSwitchSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Slider'**
  String get componentSlider;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A lens that magnifies its track'**
  String get componentSliderSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Stepper'**
  String get componentStepper;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'Minus, a value, plus'**
  String get componentStepperSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Media card'**
  String get componentMediaCard;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A photo with a glass caption'**
  String get componentMediaCardSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Stat card'**
  String get componentStatCard;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'The number first, then the words'**
  String get componentStatCardSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Toast'**
  String get componentToast;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A capsule that drops in and leaves'**
  String get componentToastSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Bottom sheet'**
  String get componentSheet;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A floating glass sheet with detents'**
  String get componentSheetSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Context menu'**
  String get componentContextMenu;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'Long-press actions on glass'**
  String get componentContextMenuSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Mini player'**
  String get componentMiniPlayer;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'What is playing, in one capsule'**
  String get componentMiniPlayerSummary;

  /// Component name
  ///
  /// In en, this message translates to:
  /// **'Search bar'**
  String get componentSearchBar;

  /// Component summary
  ///
  /// In en, this message translates to:
  /// **'A glass field with a clear button'**
  String get componentSearchBarSummary;

  /// Playground backdrop
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get backdropPhoto;

  /// Playground backdrop
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get backdropCity;

  /// Playground backdrop
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get backdropMesh;

  /// Playground backdrop
  ///
  /// In en, this message translates to:
  /// **'Checker'**
  String get backdropChecker;

  /// Playground backdrop
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get backdropBlack;

  /// Playground pane
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get paneVariants;

  /// Playground pane
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get paneMaterial;

  /// Playground pane
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get paneCode;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get knobTabs;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get knobLabels;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get knobBadge;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Squash'**
  String get knobSquash;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Selector spring'**
  String get knobSpring;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Leading'**
  String get knobLeading;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Trailing'**
  String get knobTrailing;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get knobIcon;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get knobOptions;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get knobStyle;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get knobLoading;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get knobDisabled;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get knobFullWidth;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get knobPhoto;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Corner chip'**
  String get knobChip;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Action button'**
  String get knobAction;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Aspect'**
  String get knobAspect;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get knobDelta;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Destructive action'**
  String get knobDestructive;

  /// Knob
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get knobMax;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get optionNone;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get optionBack;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get optionProfile;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get optionShare;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get optionMore;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get optionHeart;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get optionBell;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get optionPlus;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get optionPrimary;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get optionSecondary;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Lake'**
  String get optionLake;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get optionCity;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Cliffs'**
  String get optionCliffs;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get optionUp;

  /// Knob option
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get optionDown;

  /// Demo tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get demoHome;

  /// Demo tab
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get demoExplore;

  /// Demo tab
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get demoSaved;

  /// Demo tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get demoProfile;

  /// Demo tab
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get demoInbox;

  /// Demo segment
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get demoDay;

  /// Demo segment
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get demoWeek;

  /// Demo segment
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get demoMonth;

  /// Demo segment
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get demoYear;

  /// Demo top bar title
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get demoTitle;

  /// Demo button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get demoContinue;

  /// Demo stepper label
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get demoGuests;

  /// Demo slider label
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get demoBrightness;

  /// Demo switch
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get demoWifi;

  /// Demo switch
  ///
  /// In en, this message translates to:
  /// **'Airplane mode'**
  String get demoAirplane;

  /// Demo stat
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get demoSteps;

  /// Demo stat unit
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get demoStepsUnit;

  /// Demo trigger
  ///
  /// In en, this message translates to:
  /// **'Show a toast'**
  String get demoShowToast;

  /// Demo toast
  ///
  /// In en, this message translates to:
  /// **'Saved to your list'**
  String get demoToastMessage;

  /// Demo trigger
  ///
  /// In en, this message translates to:
  /// **'Open the sheet'**
  String get demoOpenSheet;

  /// Demo sheet
  ///
  /// In en, this message translates to:
  /// **'A sheet of glass'**
  String get demoSheetTitle;

  /// Demo sheet
  ///
  /// In en, this message translates to:
  /// **'It floats above the screen and bends whatever is behind it. Drag it down to close.'**
  String get demoSheetBody;

  /// Demo hint
  ///
  /// In en, this message translates to:
  /// **'Long-press the card'**
  String get demoLongPress;

  /// Demo destructive action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get demoDelete;

  /// Demo hint
  ///
  /// In en, this message translates to:
  /// **'Tap it'**
  String get demoTapHint;

  /// Stepper minus label
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// Stepper plus label
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// Playground material pane switch
  ///
  /// In en, this message translates to:
  /// **'Use the house material'**
  String get useHouseMaterial;

  /// Playground material pane note
  ///
  /// In en, this message translates to:
  /// **'Off gives this playground its own material, starting from the house one.'**
  String get useHouseMaterialNote;

  /// Code pane button
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// Toast after copying code
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopiedToast;

  /// Variants pane empty text
  ///
  /// In en, this message translates to:
  /// **'Nothing to tune here. Try the Material pane, or a different backdrop.'**
  String get noKnobs;

  /// Label above material presets
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// Label above backdrop choices
  ///
  /// In en, this message translates to:
  /// **'Backdrop'**
  String get backdrop;

  /// Material knob group
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get groupGeometry;

  /// Material knob group
  ///
  /// In en, this message translates to:
  /// **'Optics'**
  String get groupOptics;

  /// Material knob group
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get groupLight;

  /// Material knob group
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get groupTint;

  /// Material knob group
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get groupModel;

  /// Material knob group tab
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get groupShape;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get knobThickness;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Edge refraction'**
  String get knobEdgeRefraction;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Refraction spread'**
  String get knobRefractionSpread;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get knobHighlight;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Contour'**
  String get knobContour;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get knobFrost;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Chromatic aberration'**
  String get knobChromatic;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get knobSaturation;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Tint opacity'**
  String get knobTintOpacity;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get knobProfile;

  /// Material knob
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get knobVariant;

  /// Glass profile
  ///
  /// In en, this message translates to:
  /// **'Edge band'**
  String get profileEdgeBand;

  /// Glass profile
  ///
  /// In en, this message translates to:
  /// **'Dome'**
  String get profileDome;

  /// Glass variant
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get variantRegular;

  /// Glass variant
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get variantClear;

  /// Material studio title
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get materialTitle;

  /// Material studio subtitle
  ///
  /// In en, this message translates to:
  /// **'One glass, worn by every screen'**
  String get materialSubtitle;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Copy as Dart'**
  String get copyAsDart;

  /// Toast
  ///
  /// In en, this message translates to:
  /// **'Material copied as Dart'**
  String get copiedAsDartToast;

  /// Stage mode
  ///
  /// In en, this message translates to:
  /// **'In context'**
  String get stageInContext;

  /// Stage mode
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get stageShape;

  /// Sample card title
  ///
  /// In en, this message translates to:
  /// **'Glass card'**
  String get demoCardTitle;

  /// Sample card body
  ///
  /// In en, this message translates to:
  /// **'Tune it here and every screen follows.'**
  String get demoCardBody;

  /// Note under geometry for domes
  ///
  /// In en, this message translates to:
  /// **'A dome bends across its whole face, so spread has nothing to do.'**
  String get domeSpreadNote;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
