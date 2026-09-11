# Workbench Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `glass_forge_workbench` into a practical glass component showcase — a floating glass tab bar, a realistic Showcase screen, a component catalog with playgrounds, a house-material editor, and the engineering tools under Lab — on a cleaned-up codebase.

**Architecture:** Presentation-only features (no network, no persistence) on flutter_bloc cubits and GoRouter's `StatefulShellRoute.indexedStack`. A glass kit of fifteen widgets in `lib/utils/widgets/glass/` built only on `glass_forge`'s public API plus app tokens. A house material (`HouseGlassCubit` → `HouseGlass` inherited widget) feeds every kit component. Playgrounds are one generic page driven by per-component "story" files.

**Tech Stack:** Flutter 3.47 / Dart 3.13, flutter_bloc 9, go_router 17, glass_forge (path), motor 1.1 (tab selector spring), flutter_svg, gen-l10n.

**Spec:** `docs/superpowers/specs/2026-09-11-workbench-redesign-design.md`. Comps: `docs/design/comps/0{1..4}-*.jpg`.

## Global Constraints

- Colours only from `AppColors`; spacing from `AppSpacing` (4·8·12·16·20·24·32·40·48); radii from `AppRadius` (8·12·16·24·pill); durations from `AppMotion`.
- Type: Geist (UI) and Geist Mono (numbers and units), via the `context.<style>` extension. No `TextStyle(` outside `app_text_style.dart`.
- Accent `#D4F25A` only for selected/on/active/live.
- Icons only through `AppSvgIcon(AssetPaths.x)` — Phosphor SVGs, regular inactive, fill selected. No `Icons.*`.
- Every user-facing string in `lib/l10n/arb/app_en.arb` via `context.l10n` (widgets) or `Localization` (non-widget code). English only.
- One public class per file, package imports only, `EdgeInsetsDirectional`, `buildWhen` on every `BlocBuilder`.
- No `setState`: ephemeral gesture state is a `ValueNotifier` owned and disposed by its widget.
- No `// ignore:`; `flutter analyze` zero issues; `flutter test` green before every commit.
- Touch targets ≥ 44 pt. Every custom control has `Semantics`. Reduce Motion (`MediaQuery.disableAnimationsOf`) honoured by every animation.
- Do not modify anything under `packages/glass_forge`.
- Commits: conventional prefix, no AI co-author line (workbench CLAUDE.md).
- Commands run from `apps/glass_forge_workbench`: `flutter analyze`, `flutter test`, `flutter gen-l10n`.

## File structure (end state of this plan)

```
lib/
  app/view/{app_page.dart, app_view.dart}
  bootstrap.dart, main_{development,staging,production}.dart
  constants/{app_colors, app_text_style, app_spacing, app_radius, app_motion, asset_paths, export}.dart
  go_router/{exports, router, routes}.dart
  l10n/{arb/app_en.arb, gen/…, l10n.dart, localization_service.dart}
  features/
    shell/presentation/views/workbench_shell.dart
    house_glass/presentation/cubit/{house_glass_cubit, house_glass_state}.dart
    house_glass/data/models/material_preset.dart
    showcase/data/models/{place, place_category}.dart
    showcase/data/place_catalog.dart
    showcase/presentation/{cubit/…, views/showcase_view.dart, widgets/…}
    components/…            (Phase 2)
    material_studio/…       (Phase 2; the old `showcase` Specimen feature, renamed)
    lab/presentation/views/lab_view.dart, widgets/lab_tool_row.dart
    blend/ tiers/ motion/ surfaces/ sampling_probe/   (existing; restyled Phase 3)
  utils/
    enums/…, extensions/…, helpers/{haptic_helper, demonstration_glass_material}.dart
    widgets/
      glass/navigation/{glass_tab_bar, glass_tab_bar_item, glass_tab_selector, glass_circle_button, glass_top_bar, glass_segmented_control}.dart
      glass/buttons/glass_button.dart   glass/controls/{glass_switch, glass_slider, glass_stepper}.dart
      glass/cards/{glass_media_card, glass_stat_card}.dart   glass/feedback/glass_toast.dart
      glass/overlays/{glass_bottom_sheet, glass_context_menu, glass_mini_player, glass_search_bar}.dart
      glass/house_glass.dart
      primitives/{app_svg_icon, pressable_scale, section_label}.dart
      layout/{shell_insets, top_scrim}.dart
      stage/… (existing backdrops)
```

---

# Phase 0 — Cleanup and foundation

### Task 0.1: Strip the dead template

**Files:**
- Delete: `lib/features/onboarding/`, `lib/app/view/splash.dart`, `lib/core/` (all of it: api_service, app_preferences, di, endpoints, field_validators, locale, models), `lib/config/` (env, flavor_config, remote_config), `env/`, `lib/utils/response_data_model/`, `lib/utils/helpers/` except `haptic_helper.dart` and `demonstration_glass_material.dart`, `lib/utils/extensions/{null_check,string_extensions}.dart`, `lib/constants/constants.dart`, `lib/utils/widgets/{blur_overlay,filter_icon_widget}.dart`, every file in `lib/utils/widgets/core_widgets/` except `button.dart`, `app_bar.dart`, `loading_widget.dart`, `sliding_tab.dart` (still used by Specimen, Motion and the probe until Phase 3), `lib/l10n/arb/app_es.arb`, `assets/animation/`, `firebase/`, unused SVGs in `assets/vectors/` (keep `arrow_left_icon.svg`).
- Modify: `lib/go_router/router.dart` (drop splash, login, redirect, `appContext`, `getCurrentLocation`, `isCurrentRoute`), `lib/go_router/routes.dart`, `lib/go_router/exports.dart`, `lib/app/view/app_page.dart`, `lib/app/view/app_view.dart`, `lib/bootstrap.dart`, `lib/main_*.dart`, `lib/exports.dart`, `lib/constants/export.dart`, `lib/constants/asset_paths.dart`, `lib/utils/widgets/core_widgets/export.dart` (package imports), `lib/l10n/localization_service.dart`, `lib/l10n/arb/app_en.arb`, `pubspec.yaml`, `android/app/build.gradle.kts` (google-services copy task).

- [ ] **Step 1:** Run `flutter test` and record the baseline (51 passing).
- [ ] **Step 2:** Delete the files above. In `router.dart` set `initialLocation: AppRoutes.specimen`, remove `redirect`, the splash/login `GoRoute`s and the static helpers.
- [ ] **Step 3:** `bootstrap.dart` becomes:

```dart
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final view = binding.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(await builder());
}
```

  Each `main_*.dart` becomes `Future<void> main() => bootstrap(() => const App());`.
- [ ] **Step 4:** `app_page.dart`: `App` returns `const AppView()` (no Phoenix, no LocaleCubit, no OnboardingCubit). `app_view.dart`: `AppView` is a `StatelessWidget`; `MaterialApp.router` with `theme: AppTheme.dark` (Task 0.2), `localizationsDelegates`/`supportedLocales` from `AppLocalizations`, `builder: (context, child) { Localization.update(AppLocalizations.of(context)); return AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light.copyWith(statusBarColor: AppColors.transparent, systemNavigationBarColor: AppColors.transparent), child: child!); }`. `FlutterNativeSplash.remove()` moves into a post-frame callback in `bootstrap` after `runApp`.
- [ ] **Step 5:** `pubspec.yaml`: remove `dio, http, hive_ce, hive_ce_flutter, get_it, cached_network_image, shimmer, smooth_page_indicator, toastification, package_info_plus, url_launcher, flutter_phoenix, device_info_plus, crypto, envied, chucker_flutter, device_preview` and dev `mocktail, intl_utils, hive_ce_generator, envied_generator, build_runner` (keep `bloc_test` only if a test imports it — grep first). Keep `intl` and `flutter_localizations` (gen-l10n). Add `motor: ^1.1.0`. Assets: declare `assets/vectors/icons/`, `assets/images/photos/`, `assets/fonts/` only.
- [ ] **Step 6:** Remove the google-services copy task in `android/app/build.gradle.kts` and any reference to `firebase/`.
- [ ] **Step 7:** `flutter pub get && flutter gen-l10n && flutter analyze && flutter test`. Expected: analyzer clean (fix fallout in live files only), 51 tests pass. Fix `workbench_routing_test.dart` so it asserts routes resolve without a redirect.
- [ ] **Step 8:** Verify no dangling references: `grep -rnE "Injector|AppPreferences|ApiService|Endpoints|FlavorConfig|ToastHelper|AppLogger|LocaleCubit|Phoenix|DevicePreview" lib test` returns nothing.

### Task 0.2: Tokens, fonts, theme

**Files:**
- Create: `assets/fonts/geist/Geist-{Regular,Medium,SemiBold,Bold}.ttf`, `assets/fonts/geist-mono/GeistMono-{Regular,Medium,SemiBold}.ttf`, `lib/constants/app_spacing.dart`, `lib/constants/app_radius.dart`, `lib/constants/app_motion.dart`, `lib/app/view/app_theme.dart`, `test/constants/contrast_test.dart`
- Modify: `lib/constants/app_colors.dart`, `lib/constants/app_text_style.dart`, `lib/constants/export.dart`, `pubspec.yaml` (fonts), every call site of removed text styles
- Delete: `assets/fonts/bbb-poppins/`, `assets/fonts/sf-pro-rounded/`, `test/constants/stage_contrast_test.dart` (superseded)

**Interfaces — Produces:**

```dart
abstract class AppColors {
  static const ground = Color(0xFF0B0C0F);
  static const surface = Color(0xFF131519);
  static const surfaceRaised = Color(0xFF1A1D23);
  static const hairline = Color(0x14FFFFFF);
  static const hairlineStrong = Color(0x29FFFFFF);
  static const textPrimary = Color(0xFFF3F4F6);
  static const textSecondary = Color(0xFFA3A9B4);
  static const textTertiary = Color(0xFF80868F);
  static const accent = Color(0xFFD4F25A);
  static const onAccent = Color(0xFF0B0C0F);
  static const accentSoft = Color(0x29D4F25A);
  static const danger = Color(0xFFFF6B5E);
  static const scrim = Color(0xE60B0C0F);
  static const transparent = Color(0x00000000);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  // Transitional aliases for the lab screens until Phase 3 rebuilds them.
  static const stageGround = ground;
  static const stageRaised = surface;
  static const stageAccent = accent;
  static const stageForeground = textPrimary;
  static const stageForegroundMuted = textSecondary;
  static const stageForegroundSubtle = textTertiary;
  static const stageBorder = hairlineStrong;
  static const stageDivider = hairline;
}
abstract class AppSpacing { static const s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s20 = 20.0, s24 = 24.0, s32 = 32.0, s40 = 40.0, s48 = 48.0; static const gutter = s16; }
abstract class AppRadius { static const r8 = 8.0, r12 = 12.0, r16 = 16.0, r24 = 24.0, rPill = 999.0; }
abstract class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const select = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 360);
  static const fadeThrough = Duration(milliseconds: 180);
  static const stagger = Duration(milliseconds: 40);
  static const presetTween = Duration(milliseconds: 280);
  static const selectCurve = Curves.easeOutCubic;
}
abstract class AppFonts { static const sans = 'Geist'; static const mono = 'GeistMono'; }
extension AppTextStyle on BuildContext {
  TextStyle get display;   // 34/40 w600 -0.6
  TextStyle get title;     // 22/28 w600 -0.3
  TextStyle get headline;  // 17/22 w600 -0.2
  TextStyle get body;      // 15/21 w400
  TextStyle get bodyMedium;// 15/21 w500
  TextStyle get callout;   // 14/20 w500
  TextStyle get calloutRegular; // 14/20 w400
  TextStyle get caption;   // 12/16 w400
  TextStyle get captionMedium; // 12/16 w500
  TextStyle get overline;  // 11/14 w500 +0.8 (callers uppercase the string)
  TextStyle get mono;      // GeistMono 14/20 w500, tabular
  TextStyle get monoSmall; // GeistMono 12/16 w500, tabular
}
class AppTheme { static ThemeData get dark; } // Geist, ground scaffold, accent selection, no splash ink, Cupertino page transitions on both platforms
```

Default text colour for every style is `AppColors.textPrimary`.

- [ ] **Step 1: Write the failing contrast test**

```dart
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
double contrast(Color a, Color b) {
  final l1 = _luminance(a), l2 = _luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}
void main() {
  const grounds = {'ground': AppColors.ground, 'surface': AppColors.surface, 'surfaceRaised': AppColors.surfaceRaised};
  for (final e in grounds.entries) {
    test('textSecondary on ${e.key} ≥ 4.5', () => expect(contrast(AppColors.textSecondary, e.value), greaterThanOrEqualTo(4.5)));
    test('textTertiary on ${e.key} ≥ 4.5', () => expect(contrast(AppColors.textTertiary, e.value), greaterThanOrEqualTo(4.5)));
    test('accent on ${e.key} ≥ 3 (non-text)', () => expect(contrast(AppColors.accent, e.value), greaterThanOrEqualTo(3)));
  }
  test('onAccent on accent ≥ 4.5', () => expect(contrast(AppColors.onAccent, AppColors.accent), greaterThanOrEqualTo(4.5)));
}
```

- [ ] **Step 2:** Run `flutter test test/constants/contrast_test.dart` — FAIL (tokens missing).
- [ ] **Step 3:** Download fonts. Geist static TTFs come from the `vercel/geist-font` GitHub release zip (`fonts/Geist/ttf/`, `fonts/GeistMono/ttf/`); verify with `file *.ttf` that each is a TrueType font. Declare families `Geist` (400/500/600/700) and `GeistMono` (400/500/600) in `pubspec.yaml`; delete the old font folders and declarations. Add Geist's OFL notice to the repo-root `THIRD_PARTY.md`.
- [ ] **Step 4:** Write the token files and `AppTheme` per the interface block. Rewrite `app_text_style.dart` (keep `TextStyleModifiers` only if a live call site uses it; otherwise delete).
- [ ] **Step 5:** Repoint every call site: `h1…h5*` → `title`/`headline`, `p1` → `body`, `p1Medium`/`p1Bold` → `bodyMedium`, `p2` → `calloutRegular`, `p2Medium`/`p2Bold` → `callout`, `caption*` unchanged, `overline` unchanged, and every `fontFeatures: [FontFeature.tabularFigures()]` number → `context.mono` / `context.monoSmall`.
- [ ] **Step 6:** `flutter test && flutter analyze` — contrast test passes, analyzer clean.

### Task 0.3: Icons and primitives

**Files:**
- Create: `assets/vectors/icons/*.svg` (Phosphor, see list), `lib/utils/widgets/primitives/app_svg_icon.dart`, `lib/utils/widgets/primitives/pressable_scale.dart`, `lib/utils/widgets/primitives/section_label.dart`, `test/utils/widgets/primitives/pressable_scale_test.dart`
- Modify: `lib/constants/asset_paths.dart`, `lib/exports.dart`, `THIRD_PARTY.md` (Phosphor MIT)

Icons (regular + `-fill` where marked \*): `squares-four*`, `stack*`, `cube*`, `flask*`, `user`, `bell`, `magnifying-glass`, `x`, `bookmark-simple*`, `play*`(fill only), `pause*`(fill only), `heart*`, `house*`, `compass*`, `caret-left`, `caret-right`, `arrow-counter-clockwise`, `code`, `copy`, `check`, `plus`, `minus`, `share-network`, `map-pin`, `thermometer`, `navigation-arrow`, `sliders-horizontal`, `info`, `trash`, `dots-three`. Source: `https://raw.githubusercontent.com/phosphor-icons/core/main/assets/{regular,fill}/<name>{,-fill}.svg`. `AssetPaths` constants are camelCase of the name, `…Fill` for fills (e.g. `AssetPaths.squaresFour`, `AssetPaths.squaresFourFill`).

**Interfaces — Produces:**

```dart
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(this.asset, {this.size = 24, this.color = AppColors.textPrimary, this.semanticLabel, super.key});
}
class PressableScale extends StatefulWidget {
  const PressableScale({required this.onTap, required this.child, this.pressedScale = 0.97, this.haptic = true, this.semanticLabel, this.behavior = HitTestBehavior.opaque, super.key});
  // ValueNotifier<bool> pressed; AnimatedScale(AppMotion.press); AppHaptics.tap() on commit;
  // Semantics(button: true, enabled: onTap != null ? null : false, label: semanticLabel).
  // Reduce Motion: scale stays 1.0.
}
class SectionLabel extends StatelessWidget { const SectionLabel(this.text, {super.key}); } // overline, textTertiary, uppercased
```

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('PressableScale scales down while pressed and fires onTap once', (tester) async {
  var taps = 0;
  await tester.pumpWidget(MaterialApp(home: Center(child: PressableScale(onTap: () => taps++, child: const SizedBox(width: 80, height: 80)))));
  final gesture = await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
  await tester.pump(AppMotion.press);
  expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, lessThan(1));
  await gesture.up();
  await tester.pumpAndSettle();
  expect(taps, 1);
  expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
});
testWidgets('PressableScale does not scale under Reduce Motion', (tester) async {
  await tester.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: Center(child: PressableScale(onTap: () {}, child: const SizedBox(width: 80, height: 80))))));
  await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
  await tester.pump(AppMotion.press);
  expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
});
```

- [ ] **Step 2:** Run — FAIL. **Step 3:** Download icons, write the three widgets. **Step 4:** Run — PASS. `flutter analyze` clean.

### Task 0.4: Phase 0 commit

- [ ] `flutter analyze` (0 issues), `flutter test` (all pass), launch on the iPhone 17 Pro simulator and confirm the five sections still work with the new type and colours and the status bar is light.
- [ ] `git add -A apps/glass_forge_workbench THIRD_PARTY.md docs/superpowers docs/design/comps && git commit -m "refactor(workbench): strip template scaffolding; new tokens, Geist, Phosphor icons"` — the four in-flight app edits (dome default, dome preset) are included; `packages/glass_forge` is not staged.

---

# Phase 1 — Tab bar, shell, Showcase

### Task 1.1: House material

**Files:**
- Create: `lib/features/house_glass/data/models/material_preset.dart`, `lib/features/house_glass/presentation/cubit/house_glass_cubit.dart`, `lib/features/house_glass/presentation/cubit/house_glass_state.dart`, `lib/utils/widgets/glass/house_glass.dart`, `test/features/house_glass/house_glass_cubit_test.dart`
- Modify: `lib/app/view/app_page.dart` (provide the cubit and `HouseGlass` above `AppView`)

**Interfaces — Produces:**

```dart
enum MaterialPreset { dome, regular, clear, tinted, demonstration }
extension MaterialPresetX on MaterialPreset {
  GlassMaterial get material => switch (this) {
    MaterialPreset.dome => GlassMaterial.dome(),
    MaterialPreset.regular => GlassMaterial.regular(brightness: Brightness.dark),
    MaterialPreset.clear => GlassMaterial.clear(),
    MaterialPreset.tinted => GlassMaterial.dome().copyWith(tint: AppColors.accent, tintOpacity: 0.16),
    MaterialPreset.demonstration => demonstrationGlassMaterial(),
  };
  String get label; // via Localization
}
class HouseGlassState extends Equatable { const HouseGlassState({required this.material, this.preset}); final GlassMaterial material; final MaterialPreset? preset; /* null once edited */ }
class HouseGlassCubit extends Cubit<HouseGlassState> {
  HouseGlassCubit() : super(HouseGlassState(material: MaterialPreset.dome.material, preset: MaterialPreset.dome));
  void applyPreset(MaterialPreset preset);
  void update(GlassMaterial material); // clears preset unless it still equals one
}
class HouseGlass extends InheritedWidget {
  const HouseGlass({required this.material, required super.child, super.key});
  final GlassMaterial material;
  static GlassMaterial of(BuildContext context); // falls back to GlassMaterial.dome() when absent
}
```

- [ ] **Step 1: Failing tests**

```dart
test('starts on the dome preset', () {
  final cubit = HouseGlassCubit();
  expect(cubit.state.preset, MaterialPreset.dome);
  expect(cubit.state.material, GlassMaterial.dome());
});
test('applyPreset swaps material and preset', () {
  final cubit = HouseGlassCubit()..applyPreset(MaterialPreset.clear);
  expect(cubit.state.material, GlassMaterial.clear());
  expect(cubit.state.preset, MaterialPreset.clear);
});
test('update with an edited material clears the preset', () {
  final cubit = HouseGlassCubit()..update(GlassMaterial.dome().copyWith(thickness: 31));
  expect(cubit.state.preset, isNull);
});
test('update back to a preset\'s exact material re-selects it', () {
  final cubit = HouseGlassCubit()..update(GlassMaterial.clear());
  expect(cubit.state.preset, MaterialPreset.clear);
});
```

- [ ] **Step 2:** FAIL. **Step 3:** Implement; `update` sets `preset: MaterialPreset.values.firstWhereOrNull((p) => p.material == material)` (write the loop inline; no `collection` dependency). **Step 4:** PASS.

### Task 1.1b: Glass zones, static surface, `KitGlassLayer` (flutter#187820 guard)

**Files:**
- Create: `lib/utils/widgets/glass/zones/glass_priority.dart`, `…/zones/glass_zones.dart` (registry + `GlassZonesScope` inherited notifier), `…/zones/kit_glass_layer.dart`, `…/zones/render_glass_zone_reporter.dart`, `lib/utils/widgets/glass/glass_static_surface.dart`, `test/utils/widgets/glass/zones/glass_zones_test.dart`, `test/utils/widgets/glass/zones/kit_glass_layer_test.dart`
- Modify: `lib/app/view/app_page.dart` (provide one `GlassZones` above `AppView`)

**Interfaces — Produces:**

```dart
enum GlassPriority { content, chrome, overlay }

class GlassZones extends ChangeNotifier {
  void report(Object owner, Rect globalRect, GlassPriority priority); // notifies only when the rect or priority actually changed
  void withdraw(Object owner);
  /// Whether [owner]'s layer at [globalRect] must render static: some *other* zone of strictly higher priority intersects it (non-empty intersection).
  bool mustYield(Object owner, Rect globalRect, GlassPriority priority);
}
class GlassZonesScope extends InheritedNotifier<GlassZones> { static GlassZones? maybeOf(BuildContext context); }

/// The one way kit components open a GlassLayer.
class KitGlassLayer extends StatefulWidget {
  const KitGlassLayer({required this.priority, required this.shape, required this.child, this.material, super.key});
  // Renders GlassLayer(material ?? HouseGlass.of(context), child: Glass(shape: shape, child: child)) when live;
  // GlassStaticSurface(shape: shape, material: …, child: child) when yielding or when
  // MediaQuery.highContrastOf / the platform's Reduce Transparency is on (read via glass_forge AccessibilitySignals).
  // A RenderGlassZoneReporter under it reports localToGlobal(Offset.zero) & size on every paint (post-frame, deduped).
  // Crossfades live⇄static over 120 ms (instant under Reduce Motion). Withdraws its zone in dispose.
}
class GlassStaticSurface extends StatelessWidget {
  const GlassStaticSurface({required this.shape, required this.material, this.child, super.key});
  // ClipPath to shape; fill = material tint at max(tintOpacity, 0.35) over AppColors.surface at 0.55 alpha;
  // 1 px rim: LinearGradient white 0.28 (top-start) → white 0.06 (bottom-end); inner top highlight 0.10.
}
```

- [ ] **Step 1: Failing registry tests**

```dart
test('content yields to overlapping chrome, not the other way round', () {
  final zones = GlassZones();
  const bar = Rect.fromLTWH(16, 760, 358, 64);
  const caption = Rect.fromLTWH(24, 740, 342, 88);
  zones.report('bar', bar, GlassPriority.chrome);
  zones.report('caption', caption, GlassPriority.content);
  expect(zones.mustYield('caption', caption, GlassPriority.content), isTrue);
  expect(zones.mustYield('bar', bar, GlassPriority.chrome), isFalse);
});
test('touching edges do not count as overlap', () {
  final zones = GlassZones()..report('bar', const Rect.fromLTWH(0, 100, 100, 50), GlassPriority.chrome);
  expect(zones.mustYield('c', const Rect.fromLTWH(0, 0, 100, 100), GlassPriority.content), isFalse);
});
test('equal priorities never yield to each other', () {
  final zones = GlassZones()..report('a', const Rect.fromLTWH(0, 0, 100, 100), GlassPriority.chrome);
  expect(zones.mustYield('b', const Rect.fromLTWH(50, 50, 100, 100), GlassPriority.chrome), isFalse);
});
test('withdrawn zones stop forcing a yield', () {
  final zones = GlassZones()..report('sheet', const Rect.fromLTWH(0, 0, 400, 400), GlassPriority.overlay);
  zones.withdraw('sheet');
  expect(zones.mustYield('bar', const Rect.fromLTWH(0, 300, 400, 64), GlassPriority.chrome), isFalse);
});
test('reporting an unchanged rect does not notify', () {
  var notified = 0;
  final zones = GlassZones()..addListener(() => notified++);
  zones.report('a', const Rect.fromLTWH(0, 0, 10, 10), GlassPriority.content);
  zones.report('a', const Rect.fromLTWH(0, 0, 10, 10), GlassPriority.content);
  expect(notified, 1);
});
```

- [ ] **Step 2: Failing widget test** — a `Stack` with a chrome `KitGlassLayer` at the bottom and a content `KitGlassLayer` that is moved (via a `ValueNotifier<double>` top offset) from clear space into the chrome rect: after `pumpAndSettle`, `find.byType(GlassLayer)` counts 2 while clear and 1 while overlapping, and `find.byType(GlassStaticSurface)` counts 0 then 1. Under `MediaQueryData(highContrast: true)` both render static.
- [ ] **Step 3:** FAIL. **Step 4:** Implement. **Step 5:** PASS.

### Task 1.2: `GlassTabBar`

**Files:**
- Create: `lib/utils/widgets/glass/navigation/glass_tab_bar_item.dart`, `…/glass_tab_bar.dart`, `…/glass_tab_selector.dart`, `lib/utils/helpers/tab_geometry.dart`, `test/utils/widgets/glass/glass_tab_bar_test.dart`, `test/utils/helpers/tab_geometry_test.dart`

**Interfaces — Produces:**

```dart
@immutable
class GlassTabBarItem { const GlassTabBarItem({required this.label, required this.icon, required this.activeIcon, this.badge = false}); final String label; final String icon; final String activeIcon; final bool badge; }

class GlassTabBar extends StatefulWidget {
  const GlassTabBar({required this.items, required this.currentIndex, required this.onChanged,
    this.showLabels = true, this.material, this.squash = 0.8,
    this.selectorDuration = const Duration(milliseconds: 420), super.key});
  static const double heightWithLabels = 64;
  static const double heightIconsOnly = 56;
}

abstract class TabGeometry {
  /// Alignment x in [-1, 1] for [index] of [count].
  static double alignFor(int index, int count) => count <= 1 ? 0 : index / (count - 1) * 2 - 1;
  /// The tab under [localX] on a bar [width] wide, mirrored for RTL.
  static int indexAt(double localX, double width, int count, {required bool rtl});
  /// Alignment that follows a finger at [localX], clamped to the first/last slot centre.
  static double alignAt(double localX, double width, int count, {required bool rtl});
  /// Squash-and-stretch scale for a selector moving at [velocity] alignment-units/s.
  static Offset squashScale(double velocity, {required double squash}); // (sx, sy); identity at 0
}
```

Behaviour (see comp `01-showcase.jpg` bottom): capsule bar, `KitGlassLayer(priority: GlassPriority.chrome, shape: GlassSuperellipse(radius: BorderRadius.circular(height / 2)), material: material)`; selector inset 4 pt, width `1/count`, a **painted** lit capsule (`GlassTabSelector`: white 0.14 fill, 1 px rim gradient white 0.40 → 0.08, inner top highlight; never a backdrop pass — spec §4 rule 2), positioned by `motor`'s `VelocityMotionBuilder<double>` with `Motion.bouncySpring(duration: selectorDuration, snapToEnd: true)` towards `TabGeometry.alignFor` (or the drag alignment while scrubbing), transformed by `squashScale(velocity)`. Tabs: `AppSvgIcon` 24 pt (`activeIcon` in `accent` when selected, `icon` in `textSecondary` otherwise), label `captionMedium` below, both `AnimatedDefaultTextStyle`/`TweenAnimationBuilder` over `AppMotion.select`. Badge: 8 pt accent dot at the icon's top-end. Horizontal drag scrubs: `ValueNotifier<double?> _dragAlign`; `AppHaptics.toggle()` whenever `indexAt` changes; on end, `AppHaptics.tap()` and `onChanged` if different. Tap on a different tab: `AppHaptics.tap()` + `onChanged`. Labels use `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`. Semantics: container `explicitChildNodes`, each tab `Semantics(button: true, selected:, label: item.label, excludeSemantics: true)`. Reduce Motion: selector jumps (no spring, no squash).

- [ ] **Step 1: Failing geometry tests**

```dart
test('alignFor spans -1..1', () {
  expect(TabGeometry.alignFor(0, 4), -1);
  expect(TabGeometry.alignFor(3, 4), 1);
  expect(TabGeometry.alignFor(0, 1), 0);
});
test('indexAt maps a finger to its slot and mirrors in RTL', () {
  expect(TabGeometry.indexAt(10, 400, 4, rtl: false), 0);
  expect(TabGeometry.indexAt(390, 400, 4, rtl: false), 3);
  expect(TabGeometry.indexAt(10, 400, 4, rtl: true), 3);
  expect(TabGeometry.indexAt(-50, 400, 4, rtl: false), 0);
  expect(TabGeometry.indexAt(999, 400, 4, rtl: false), 3);
});
test('alignAt clamps to the outer slot centres', () {
  expect(TabGeometry.alignAt(0, 400, 4, rtl: false), -1);
  expect(TabGeometry.alignAt(400, 400, 4, rtl: false), 1);
  expect(TabGeometry.alignAt(200, 400, 4, rtl: false), closeTo(0, 1e-9));
});
test('squashScale is identity at rest and stretches along motion', () {
  expect(TabGeometry.squashScale(0, squash: 0.8), const Offset(1, 1));
  final s = TabGeometry.squashScale(12, squash: 0.8);
  expect(s.dx, greaterThan(1)); // stretched along x
  expect(s.dy, lessThan(1));    // squashed across
  expect(TabGeometry.squashScale(12, squash: 0), const Offset(1, 1));
});
```

  (Note the stretch direction: the selector *stretches* along its travel and *squashes* across it, the opposite of KiBU's `_jellyTransform`, which compressed along travel. Stretch-along-travel is what reads as liquid.)
- [ ] **Step 2: Failing widget tests**

```dart
Widget _host({required int index, required ValueChanged<int> onChanged, double textScale = 1}) => MaterialApp(
  home: MediaQuery(data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(16),
      child: GlassTabBar(currentIndex: index, onChanged: onChanged, items: const [
        GlassTabBarItem(label: 'Showcase', icon: AssetPaths.squaresFour, activeIcon: AssetPaths.squaresFourFill),
        GlassTabBarItem(label: 'Components', icon: AssetPaths.stack, activeIcon: AssetPaths.stackFill),
        GlassTabBarItem(label: 'Material', icon: AssetPaths.cube, activeIcon: AssetPaths.cubeFill),
        GlassTabBarItem(label: 'Lab', icon: AssetPaths.flask, activeIcon: AssetPaths.flaskFill),
      ]))))));

testWidgets('tapping a tab reports its index', (tester) async {
  int? picked;
  await tester.pumpWidget(_host(index: 0, onChanged: (i) => picked = i));
  await tester.tap(find.text('Material'));
  expect(picked, 2);
});
testWidgets('scrubbing commits the tab under the finger on release', (tester) async {
  int? picked;
  await tester.pumpWidget(_host(index: 0, onChanged: (i) => picked = i));
  final start = tester.getCenter(find.text('Showcase'));
  final end = tester.getCenter(find.text('Lab'));
  await tester.dragFrom(start, end - start);
  await tester.pumpAndSettle();
  expect(picked, 3);
});
testWidgets('selected tab is announced as selected', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(_host(index: 1, onChanged: (_) {}));
  expect(tester.getSemantics(find.text('Components')), matchesSemantics(label: 'Components', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true));
  handle.dispose();
});
testWidgets('no overflow at 2x text on a 320 pt screen', (tester) async {
  await tester.pumpWidget(_host(index: 0, onChanged: (_) {}, textScale: 2));
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 3:** FAIL. **Step 4:** Implement `TabGeometry`, `GlassTabBarItem`, `GlassTabSelector` (the moving glass pill), `GlassTabBar`. **Step 5:** PASS; analyzer clean.

### Task 1.3: Shell, routes, insets

**Files:**
- Create: `lib/features/shell/presentation/views/workbench_shell.dart` (moved from `features/navigation`), `lib/utils/widgets/layout/shell_insets.dart`, `lib/utils/enums/workbench_tab.dart` (replaces `workbench_section.dart`), `lib/features/lab/presentation/views/lab_view.dart`, `lib/features/lab/presentation/widgets/lab_tool_row.dart`, `lib/utils/enums/lab_tool.dart`, `test/features/shell/workbench_routing_test.dart`
- Delete: `lib/features/navigation/`, `lib/utils/enums/workbench_section.dart`, `test/features/navigation/`
- Modify: `lib/go_router/{router,routes}.dart`

**Interfaces — Produces:**

```dart
enum WorkbenchTab { showcase, components, material, lab }  // declaration order == branch order
extension WorkbenchTabX on WorkbenchTab { String get label; String get icon; String get activeIcon; String get path; }
enum LabTool { tiers, blend, motion, surfaces, samplingProbe }
extension LabToolX on LabTool { String get title; String get summary; String get routeName; }
abstract class ShellInsets {
  static const double tabBarMargin = AppSpacing.s16;
  /// Space a scrollable must leave at its end so its last item clears the floating tab bar.
  static double bottomClearance(BuildContext context) =>
      GlassTabBar.heightWithLabels + tabBarMargin + math.max(MediaQuery.paddingOf(context).bottom, AppSpacing.s8);
}
```

Routes: branches `/showcase`, `/components`, `/material`, `/lab`; root-navigator pushes `/lab/tiers`, `/lab/blend`, `/lab/motion`, `/lab/surfaces`, `/lab/sampling-probe` (existing views; `/lab/surfaces` → `GalleryView`). `initialLocation: AppRoutes.showcase`. Interim for this phase: the Components branch shows `ComponentsView` (Task 1.7) and the Material branch shows the existing `SpecimenView`. `WorkbenchShell`: `Stack(children: [shell, Positioned(start: 16, end: 16, bottom: max(padding.bottom, 8) + 8, child: GlassTabBar(...))])` on an `AppColors.ground` `Scaffold` with `resizeToAvoidBottomInset: false`; the navigation shell body fades through on branch change (`AnimatedSwitcher` is wrong for an indexed stack — use a `TweenAnimationBuilder<double>` on opacity keyed by `currentIndex`, 0 → 1 over `AppMotion.fadeThrough`, skipped under Reduce Motion). Lab hub: `display` title "Lab", `LabToolRow` per tool (`PressableScale`, title `headline`, summary `calloutRegular`/`textSecondary`, caret) pushing `routeName`.

- [ ] **Step 1: Failing routing test** — for each `WorkbenchTab`, `AppRouter.router.configuration.findMatch(Uri.parse(tab.path))` is non-empty; for each `LabTool`, `router.namedLocation(tool.routeName)` resolves; the initial location is `/showcase`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS. Existing lab view tests still pass (they pump the views directly).

### Task 1.4: Photos

**Files:** Create `assets/images/photos/{alpine_lake, tokyo_rain, sea_cliffs, flower_market, desert_dunes, northern_lights, coastal_town, forest_fog, album_night_drive}.jpg`; modify `lib/constants/asset_paths.dart`, `THIRD_PARTY.md`.

- [ ] Generate each with `higgsfield generate create gpt_image_2 --prompt "<scene>, editorial travel photograph, natural light, rich colour, no text, no people facing camera" --aspect_ratio 3:4 --resolution 2k --quality high --wait` (album art at `1:1`), download, resize with `sips -Z 1440 -s format jpeg -s formatOptions 80`. Each file < 400 KB. Record the source ("generated with Higgsfield GPT Image 2 for this project") in `THIRD_PARTY.md`.

### Task 1.5: Kit components for Showcase

**Files:** Create under `lib/utils/widgets/glass/`: `navigation/glass_circle_button.dart`, `navigation/glass_top_bar.dart`, `navigation/glass_segmented_control.dart`, `overlays/glass_search_bar.dart`, `cards/glass_media_card.dart`, `cards/glass_stat_card.dart`, `overlays/glass_mini_player.dart`, `buttons/glass_button.dart`, `overlays/glass_bottom_sheet.dart`, `feedback/glass_toast.dart`, `overlays/glass_context_menu.dart`. Tests: `test/utils/widgets/glass/<name>_test.dart` for each.

**Interfaces — Produces:**

```dart
class GlassCircleButton extends StatelessWidget { const GlassCircleButton({required this.icon, required this.semanticLabel, required this.onPressed, this.badge = false, this.material, super.key}); static const double size = 40; static const double target = 44; }
class GlassTopBar extends StatelessWidget { const GlassTopBar({required this.title, this.leading, this.trailing, this.large = false, super.key}); } // leading/trailing: GlassCircleButton; lays out inside top safe area; title display (large) or headline (centred)
class GlassSegmentedControl<T> extends StatefulWidget { const GlassSegmentedControl({required this.values, required this.labelOf, required this.selected, required this.onChanged, this.material, super.key}); } // selector = GlassTabSelector; drag-to-scrub via TabGeometry
class GlassSearchBar extends StatefulWidget { const GlassSearchBar({required this.hint, required this.onChanged, this.material, super.key}); } // owns + disposes TextEditingController/FocusNode; clear button when non-empty; 48 pt tall
class GlassMediaCard extends StatelessWidget { const GlassMediaCard({required this.image, required this.title, required this.subtitle, this.chip, this.trailing, this.onTap, this.onLongPress, this.aspectRatio = 4 / 5, super.key}); } // photo behind, caption Glass in its own GlassLayer
class GlassStatCard extends StatelessWidget { const GlassStatCard({required this.label, required this.value, required this.unit, this.delta, super.key}); }
class GlassMiniPlayer extends StatelessWidget { const GlassMiniPlayer({required this.artwork, required this.title, required this.subtitle, required this.isPlaying, required this.onPlayPause, super.key}); static const double height = 64; }
class GlassButton extends StatelessWidget {
  const GlassButton.primary({required this.label, required this.onPressed, this.icon, this.isLoading = false, super.key}); // accent-tinted glass, onAccent label
  const GlassButton.secondary({required this.label, required this.onPressed, this.icon, this.isLoading = false, super.key}); // clear glass, textPrimary label
}
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}); // GlassBottomSheet: grabber, drag-to-dismiss, bottom inset aware
void showGlassToast(BuildContext context, {required String message, String? icon}); // OverlayEntry; drops from top safe area; 2.4 s; swipe up dismisses; removes itself; announces via SemanticsService
class GlassContextMenu extends StatelessWidget { const GlassContextMenu({required this.actions, required this.child, super.key}); }
class GlassContextAction { const GlassContextAction({required this.label, required this.icon, required this.onSelected, this.destructive = false}); }
```

Every component that draws glass does it through `KitGlassLayer` (Task 1.1b), sized tightly to itself, with priority: `chrome` for the circle button, top bar, search bar, segmented control and mini-player; `content` for the media card caption and stat card; `overlay` for the sheet, toast and context menu. The segmented control's selector is painted like the tab selector. Buttons inside a glass sheet are painted glass-look (`GlassStaticSurface`-styled) — a live pass inside the sheet's own pass would be stacked above it.

Each component test covers: renders without overflow at 2.0× text on a 320 pt screen; semantics label/role; the primary interaction callback; plus component-specific checks (search clear button clears and reports `''`; segmented drag commits; toast removes itself after its duration; sheet dismisses on drag down; context menu opens on long-press and fires the action).

- [ ] For each component: write its failing test, implement, pass, analyze. Visuals per comp `01-showcase.jpg`: 40 pt circles, 48 pt search capsule, segmented 40 pt track, card radius 24 with caption panel inset 8 and radius 18, mini-player 64 pt capsule, sheet top radius 28.

### Task 1.6: Showcase screen

**Files:**
- Create: `lib/features/showcase/data/models/place.dart`, `place_category.dart`, `lib/features/showcase/data/place_catalog.dart`, `lib/features/showcase/presentation/cubit/{showcase_cubit,showcase_state}.dart`, `lib/features/showcase/presentation/views/showcase_view.dart`, `lib/features/showcase/presentation/widgets/{showcase_header, showcase_feed, place_card, place_sheet, showcase_player_dock}.dart`, `test/features/showcase/showcase_cubit_test.dart`, `test/features/showcase/showcase_view_test.dart`
- Rename: existing `lib/features/showcase/` (Specimen) → `lib/features/material_studio/` with `git mv`; update imports and tests.

**Interfaces — Produces:**

```dart
enum PlaceCategory { forYou, nearby, saved }
class Place extends Equatable { const Place({required this.id, required this.title, required this.region, required this.distanceKm, required this.temperatureC, required this.photo, required this.nearby}); }
class ShowcaseState extends Equatable {
  const ShowcaseState({this.category = PlaceCategory.forYou, this.saved = const {}, this.query = '', this.isPlaying = false});
  List<Place> get visiblePlaces; // category filter (saved uses `saved`), then query match on title/region, case-insensitive
  bool isSaved(Place p);
}
class ShowcaseCubit extends Cubit<ShowcaseState> { void setCategory(PlaceCategory c); void toggleSaved(Place p); void setQuery(String q); void togglePlaying(); }
```

- [ ] **Step 1: Failing cubit tests** — `visiblePlaces` for forYou returns all; nearby returns only `nearby`; saved returns only saved; query "lake" returns the alpine lake; toggling saved twice restores; saved with no saves is empty.
- [ ] **Step 2:** FAIL. **Step 3:** Implement cubit and catalog (6 places over the generated photos). **Step 4:** PASS.
- [ ] **Step 5: View** per comp `01-showcase.jpg` and spec §7: `Stack` — feed `CustomScrollView` painted first (top padding = header height + top inset; bottom padding = `ShellInsets.bottomClearance + GlassMiniPlayer.height + 12`); a top scrim (ground → transparent) under the header for title legibility; the header (`GlassTopBar` large "Discover" with person and bell circles, `GlassSearchBar`, `GlassSegmentedControl<PlaceCategory>`) and the player dock. Card tap → `showGlassSheet` with `PlaceSheet` (title, region, distance and temperature in mono, `GlassButton.primary` "Get directions", `GlassButton.secondary` save/unsave). Bookmark → `toggleSaved` + `showGlassToast` ("Saved to your list" / "Removed from your list"). Long-press → `GlassContextMenu` (Save, Share, Hide). Empty result (saved with nothing, or no query match) → an empty state with one line and a `GlassButton.secondary` that clears the filter. Entrance stagger (40 ms) on first build only, skipped under Reduce Motion.
- [ ] **Step 6: View tests** — pumps at 320×640 and 2.0× text without exceptions; tapping "Saved" with nothing saved shows the empty state; bookmarking a card then selecting "Saved" shows it; tapping a card opens the sheet.

### Task 1.7: Components catalog (list only)

**Files:** Create `lib/utils/enums/component_id.dart` (15 values with `family`, `title`, `summary`, `glyph` via `Localization`), `lib/utils/enums/component_family.dart`, `lib/features/components/presentation/{cubit/components_catalog_cubit.dart, cubit/components_catalog_state.dart, views/components_view.dart, widgets/component_row.dart, widgets/catalog_empty_state.dart}`, tests.

- [ ] Failing tests: state getter `groups` returns families in order with their components; query filters on title and summary; an unmatched query yields no groups. Then the view per comp `02-components.jpg`, rows are `PressableScale` with no destination in this phase (`onTap: null`, no caret) — Phase 2 wires the playground route and the caret.

### Task 1.8: l10n for everything touched in Phase 1

- [ ] Every string introduced in Tasks 1.1–1.7 lives in `app_en.arb` with a `@description`; enum labels read `Localization.<key>`; `localization_service.dart` exposes each key. `flutter gen-l10n` clean.

### Task 1.9: Phase 1 verification and commit

- [ ] `flutter analyze` zero, `flutter test` green.
- [ ] Run on the iPhone 17 Pro simulator; screenshot Showcase (top, scrolled, sheet open, toast), Components, Lab; compare against `01-showcase.jpg` and `02-components.jpg` and fix drift.
- [ ] Send screenshots to the user (checkpoint).
- [ ] `git commit -m "feat(workbench): glass tab bar, Showcase screen and the glass kit behind it"`.

---

# Phase 2 — Playgrounds, remaining kit, Material (expanded after the checkpoint)

- 2.1 `GlassSwitch`, `GlassSlider` (lens thumb), `GlassStepper` — tests as in 1.5.
- 2.2 Story system: `StoryKnob` (sealed: `StepperKnob`, `ToggleKnob`, `SliderKnob`, `ChoiceKnob`), `KnobValues` (immutable, typed getters), `ComponentStory`, `componentStories` map keyed by `ComponentId`, one story file per component with `build` and `code`. Tests: each story's `code(defaults)` snapshot string; every `ComponentId` has a story.
- 2.3 `PlaygroundCubit` (knob values, backdrop, material override, reset) + `PlaygroundView` per comp `03-playground.jpg`: `GlassTopBar` (back, reset), stage with backdrop thumbnails, solid tinker sheet with Variants · Material · Code. Wire catalog rows → `/components/:id` with caret.
- 2.4 Material studio per comp `04-material.jpg`: In context / Shape stage, presets row (tween 280 ms), grouped knobs with irrelevant knobs hidden, Copy as Dart (non-default fields only; unit-tested), toast. Replaces the interim `SpecimenView` on the Material branch.
- 2.5 l10n, verification, commit `feat(workbench): component playgrounds, house material studio`.

# Phase 3 — Lab on the new chrome, audit sweep, polish (expanded after Phase 2)

- 3.1 Shared `LabScaffold` (GlassTopBar + stage + tinker sheet) and backdrop thumbnail row; rebuild Tiers, Blend, Motion, Surfaces, Sampling Probe on it with the spec §7 fixes; move widget logic into state getters; fix the probe mode race (latest-request token).
- 3.2 Delete the transitional `stage*` colour aliases and the remaining template widgets (`button`, `app_bar`, `loading_widget`, `sliding_tab`).
- 3.3 Rewrite `apps/glass_forge_workbench/CLAUDE.md` for the app as it is; retire `docs/design/workbench-design.md` with a pointer to the new spec.
- 3.4 `impeccable` critique pass and fixes; all copy through `humanizer`.
- 3.5 Screenshots: iPhone 17 Pro and an SE-size simulator at 1.0× and 2.0× text; one run on the physical iPhone.
- 3.6 Commit `refactor(workbench): lab tools on the new chrome; audit fixes`.
