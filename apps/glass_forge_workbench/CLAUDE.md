# Project: GlassForgeWorkbench

## Overview
The showcase and tuning bench for `glass_forge` (`packages/glass_forge`). A
floating glass tab bar switches four tabs:

- **Showcase** — a travel "Discover" feed built only from the glass kit.
- **Components** — the fifteen kit parts; each opens a playground (live part
  over a chosen backdrop, with Variants · Material · Code panes).
- **Material** — the one *house material* every kit component wears: presets
  that morph app-wide, every knob, Copy as Dart.
- **Lab** — Tiers, Blend, Motion, Surfaces and the Sampling probe, each pushed
  full-screen.

Design spec: `docs/superpowers/specs/2026-09-11-workbench-redesign-design.md`.
Reference comps: `docs/design/comps/`.

There is no network, no persistence and no login. Presentation-only features
on flutter_bloc cubits and GoRouter.

## Directory structure
```
lib/
├── app/view/            # App (providers), AppView (MaterialApp.router), AppTheme
├── bootstrap.dart       # edge-to-edge, portrait on phones, splash, licences
├── constants/           # AppColors, AppSpacing, AppRadius, AppMotion, text styles, AssetPaths
├── features/
│   ├── shell/           # WorkbenchShell: the tabs + floating GlassTabBar + scroll edge fades
│   ├── showcase/        # the Discover screen (data/place_catalog.dart is its sample content)
│   ├── components/      # catalog, playground, stories/ (one story per kit part)
│   ├── material_studio/ # the Material tab
│   ├── house_glass/     # HouseGlassCubit + MaterialPreset
│   ├── lab/             # the Lab index
│   └── blend/ tiers/ motion/ gallery/ sampling_probe/   # the Lab tools ("gallery" is Surfaces)
├── go_router/           # AppRoutes, AppRouteNames, AppRouter
├── l10n/                # ARB (English), generated code, Localization
└── utils/
    ├── enums/ extensions/ helpers/
    └── widgets/
        ├── glass/       # THE GLASS KIT — see below
        ├── primitives/  # AppSvgIcon, PressableScale, SolidButton, SolidCircleButton, EmptyState…
        ├── instrument/  # solid tinker-sheet controls (panel, slider, segmented, value row)
        ├── material/    # the material knob groups, preset chips
        ├── stage/       # Lab backdrops and rail
        ├── layout/      # ShellInsets
        └── tool/        # ToolTopBar, LabToolFrame
integration_test/tour_test.dart   # drives every screen on a device, screenshots each step
```

## The glass kit (`lib/utils/widgets/glass/`)
Fifteen components built only on glass_forge's public API plus app tokens:
`GlassTabBar`, `GlassTopBar`, `GlassCircleButton`, `GlassSegmentedControl`,
`GlassButton`, `GlassSwitch`, `GlassSlider`, `GlassStepper`, `GlassMediaCard`,
`GlassStatCard`, `showGlassToast`, `showGlassSheet`, `GlassContextMenu`,
`GlassMiniPlayer`, `GlassSearchBar`. Kit components take their strings as
parameters; the caller localizes.

### Composition rules — these come from real device bugs
On a physical iPhone a shader backdrop filter painted above an overlapping
backdrop filter reads a stale frame, including its own output, and washes out
white (flutter#187820). The simulator does not show it.

1. **All kit glass goes through `KitGlassLayer`** (never a raw `GlassLayer` in
   a kit component). It sizes one layer to one shape, reports its on-screen
   rect to `GlassZones`, and renders `GlassStaticSurface` (paint only) while a
   higher-priority layer overlaps it. Priorities: `content` < `chrome` <
   `overlay`.
2. **Never nest.** A kit layer inside another paints `GlassInsetSurface`
   automatically; don't fight it.
3. **Never wrap glass in `Opacity`/`FadeTransition`/`AnimatedOpacity`, or in
   `ClipRRect`/`ClipPath`/`ClipOval`.** Animate glass with transforms. Clip the
   photo, not the caption. A `ClipRect` around a backdrop painter is fine.
4. **Paint what glass refracts behind it**, never inside the layer.
5. **Selectors are painted** (`GlassTabSelector`), never a second glass pass
   over the bar.
6. **Materials:** the house material (`HouseGlass.of`) drives the kit;
   `HouseGlass.overlayOf` adds a frost floor for glass that carries text to
   read (sheets, menus, toasts). Lab tools keep their own materials.
7. **Tool screens use solid chrome** (`ToolTopBar`, `SolidCircleButton`), so
   the specimen is the only glass on screen.
8. **Changes that reach glass rendering need a physical-iPhone check** before
   they ship.

## Design tokens
- Colours: `AppColors` only (dark palette, one accent `#D4F25A` for
  selected/on/live; contrast asserted in `test/constants/contrast_test.dart`).
- Spacing `AppSpacing` (4·8·12·16·20·24·32·40·48, gutter 16), radii
  `AppRadius` (8·12·16·24·pill), durations `AppMotion`.
- Type: Geist for words, Geist Mono for every number and unit, via
  `context.display/title/headline/body/bodyMedium/callout/calloutRegular/caption/captionMedium/overline/mono/monoSmall`.
- Icons: Phosphor SVGs through `AppSvgIcon(AssetPaths.x)` — regular at rest,
  `…Fill` when selected. No `Icons.*`.
- Reduce Motion: `context.reduceMotion` (reads both `disableAnimations` and
  iOS Reduce Motion).

## Localization
Every user-facing string lives in `lib/l10n/arb/app_en.arb` (English only).
Widgets use `context.l10n.key`; enums, extensions and state use
`Localization.key`. Add the matching getter to
`lib/l10n/localization_service.dart`, then run `flutter gen-l10n`.

## Layout
- Every screen draws edge to edge under light system bars. Chrome at the top
  insets itself by `MediaQuery.paddingOf(context).top`.
- Scrollables inside a tab pad their end by `ShellInsets.bottomClearance`.
- Phones are portrait-only; tablets keep all orientations.
- Rows that pair a label with a value: label `Expanded`, value `Flexible`.

---

## Coding Standards & Quality Rules

### Code Cleanliness
- **Delete unused code** — Remove unused imports, variables, methods, classes, widgets, models, and files. No dead code in the codebase.
- **No commented-out code** — If code is removed, delete it entirely. Git history preserves it if needed. No commented-out files either.
- **No useless comments** — Don't restate what the code does. No doc comments on self-explanatory methods. No `// Section` separators. No `// ===== Section =====` dividers. Only comment where the "why" isn't obvious.
- **Resolve all analyzer hints** — Do not suppress with `// ignore:` unless absolutely necessary. Fix the underlying issue. Run `dart analyze` and ensure zero issues.
- **No TODO comments in committed code** — resolve them before committing or track in issue tracker.

### View Rules
- Views should be **very clean** — no business logic, no data transformations
- **No `_buildXyz()` methods** — extract into separate `StatelessWidget` files in `widgets/`
- **No private widgets in view files** — extract to their own `StatelessWidget` files
- **No business logic in views** — views call cubit methods; cubits handle logic. No increment/decrement methods, no data formatting, no link generation, no conditional computation in views.
- **No `setState()`** — use Cubit state management exclusively
- **View files should not exceed ~1000 lines** — refactor if they do
- Dispose all controllers (`TextEditingController`, `ScrollController`, `FocusNode`, `AnimationController`, `Timer`, etc.) in `dispose()`
- Cache cubit references in local variables when using multiple cubits

### Widget Rules
- Each extracted widget in its **own `.dart` file** as a `StatelessWidget`
- **One class per file** — never put multiple widget classes in a single file. No private `_HelperWidget` classes inside another widget file.
- Widget files go in `feature/presentation/widgets/` organized by concern (subfolders, not flat dumps)
- No business logic in widgets — only UI rendering
- Pass data via constructor parameters, not by reading cubits internally (unless necessary for actions)
- **Exception:** Self-contained bottom sheets that return a result via `Navigator.pop` may use `ValueNotifier` + `ValueListenableBuilder` for ephemeral selection state. This is strictly for UI-only state that doesn't affect feature business state.

### Inline vs Extract — Know the Difference
- **Keep inline** when the code is simple, readable, and used once:
  - A `Padding` with a `Text` — just write it inline
  - A `Row` with 2–3 children — inline is fine
  - A ternary for show/hide: `isVisible ? Widget() : const SizedBox.shrink()`
  - Simple decoration (`Container` with color/border/radius) — inline
- **Extract to a separate widget file** when:
  - The subtree is 30+ lines or 3+ nesting levels deep
  - The same pattern appears in 2+ places — extract immediately
  - The widget has its own logic (onTap handlers, formatting, conditional rendering)
  - It makes the parent screen hard to read
- **Never extract** a 5-line widget into its own file just for the sake of "clean architecture" — that's over-modularization, not cleanliness

### No Over-Engineering
- **No abstract base classes** for a single implementation — just write the class directly
- **No utility functions** used only once — inline the logic
- **No wrapper widgets** that just pass through all props to a child — that's pointless indirection
- **No unnecessary `Container`** — don't wrap a `Text` in a `Container` just for padding, use `Padding` directly. Don't wrap in `Column`/`Row` when there's only one child.
- **No premature generalization** — write the specific thing first. Only generalize when you have 2+ concrete uses.
- **Three similar lines is better than a premature abstraction** — copy-paste is fine until a real pattern emerges

### Cubit Lifecycle
- **Never fetch data in the cubit constructor** — use an `init()` method called from the screen
- Simple setters are one-liners: `void setEmail(String v) => emit(state.copyWith(email: v));`
- **Don't create a method for every tiny state change** — if you have 5 fields that just need setters, a few generic setters are fine
- **Reset state explicitly** — provide a `resetState()` method when the cubit is reused across navigation (e.g., onboarding flows)

### Type Safety
- **Never use `dynamic`** when the type is known — use the actual type
- **Prefer `Object?` over `dynamic`** when you need a top type (forces null checks)
- **No `as` casts without null safety** — use `as Type?` with null fallback, never bare `as Type` on API data

### BlocBuilder / BlocListener
- **Always use `buildWhen`** on `BlocBuilder` to limit rebuilds
- **Always use `listenWhen`** on `BlocListener` to limit side effects
- **If `listenWhen` checks 5+ variables, split the listener** — use separate focused listeners with `MultiBlocListener`
- Extract complex listener logic into named methods

```dart
BlocListener<MyCubit, MyState>(
  listenWhen: (prev, curr) => prev.deleteState != curr.deleteState,
  listener: _handleDeleteState,
  child: ...
)
```

### Enums & Extensions
- Create enums for **any finite set of values** (statuses, types, roles, actions, filters)
- String comparisons like `== 'active'` or `== 'pending'` in models/widgets are violations — use enums with `fromString` factories
- Create **enum extensions** for display names, colors, icons — don't scatter switch statements
- Enum files go in `utils/enums/` (shared) or `data/models/` (feature-specific)
- **Never define enums inline** in widget files — always in their own file

```dart
enum OrderStatus { pending, confirmed, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get displayName => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    OrderStatus.pending => AppColors.warning,
    OrderStatus.confirmed => AppColors.info,
    OrderStatus.delivered => AppColors.success,
    OrderStatus.cancelled => AppColors.error,
  };

  static OrderStatus fromString(String value) => switch (value) {
    'pending' => OrderStatus.pending,
    'confirmed' => OrderStatus.confirmed,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.pending,
  };
}
```

### Naming
- **No spelling mistakes** in class names, variable names, file names, or widget names — typos in code are permanent
- All names should be descriptive and self-documenting
- Files: `snake_case` — e.g., `user_profile_screen.dart`
- Classes: `PascalCase` — e.g., `UserProfileScreen`
- Variables/methods: `camelCase` — e.g., `loadUserProfile()`
- Constants: `camelCase` — e.g., `defaultPageSize`
- Enums: `PascalCase` for type, `camelCase` for values — e.g., `OrderStatus.confirmed`

### Imports
- **Use package imports** — never relative imports (`import 'package:glass_forge_workbench/...'` not `import '../../../'`)
- Use `exports.dart` barrel file for commonly used packages (Flutter, BLoC, GoRouter, constants, core widgets)

### Git Commits
- **No `Co-Authored-By: Claude` or any AI co-author lines** in commit messages
- Use conventional commit prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, etc.

---


### Spacing & Layout Consistency
- Use `SizedBox` for gaps, not single-side `Padding`
- Spacing and radii only from `AppSpacing` / `AppRadius`
- Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`

### Models
- One model per file, `Equatable`, immutable, `copyWith` where it is edited

## Quick Reference Checklist
- [ ] Glass only through `KitGlassLayer`; no opacity or clip layers around it
- [ ] Views: no `_build` methods, no `setState`, no logic; one class per file
- [ ] `buildWhen` on every `BlocBuilder`, `listenWhen` on every `BlocListener`
- [ ] Tokens only: `AppColors`, `AppSpacing`, `AppRadius`, `AppMotion`, text styles
- [ ] Icons only through `AppSvgIcon`; strings only through l10n
- [ ] Touch targets ≥ 44 pt; `Semantics` on every custom control
- [ ] Nothing overflows a 320 pt screen at 2× text
- [ ] Package imports only; no dead code, no `// ignore:`
- [ ] `flutter analyze` zero, `flutter test` green, tour passes

## Commands
```bash
flutter run --flavor development -t lib/main_development.dart
flutter analyze
flutter test
flutter gen-l10n
scripts/tour_screenshots.sh <device-id> <output-dir>   # drives every screen, saves screenshots
```
