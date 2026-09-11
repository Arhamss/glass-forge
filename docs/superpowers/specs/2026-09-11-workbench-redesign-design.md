# Glass Forge Workbench — redesign

**Date:** 2026-09-11 · **Status:** approved (design + comps) · **Scope:** `apps/glass_forge_workbench`

Comps: `docs/design/comps/01-showcase.jpg`, `02-components.jpg`, `03-playground.jpg`,
`04-material.jpg`. `05-showcase-amber-rejected.jpg` is kept only as the record of
the accent decision.

This supersedes `docs/design/workbench-design.md` ("instrument, not brochure").
That document's one idea — the controls must stay legible, so the tinker panel
is never glass — survives. Its other idea, that a glass demo should mostly not
be made of glass, does not: the audience wants to see real components made of
glass, in real contexts, and to tune them.

---

## 1. Goal and audience

A practical showcase for `glass_forge` that doubles as the team's tuning bench.

- **Someone evaluating the package** opens it and, within one screen, sees a
  believable app built entirely from glass components, then drills into any one
  of them to see its variants and copy its code.
- **The team** uses the same app to tinker: one house material drives every
  screen, every component has a playground, and a tuned material exports as Dart.

Success: every screen is usable one-handed on an iPhone SE and a Pro Max, at
text scale 1.0–2.0, with nothing under the status bar, nothing clipped, and the
glass reading as clear lensed glass rather than frosted plastic.

## 2. Anchors

| Reference | What we take |
|---|---|
| iOS 26 Music / Photos | Glass only on the navigation and control layer; content scrolls beneath it. |
| Halide Mark II | A pro instrument over a live view: thumb-zone controls, mono readouts with units, haptic detents, one accent for "active". |
| Linear (iOS) | Calm list density, crisp type, one accent. The catalog is built on this. |
| KiBU (our app) | Tab bar selector on a bouncy spring with velocity squash; drag-to-scrub with a haptic tick per tab; 40 pt glass circles in 44 pt targets; press-scale on everything. |

Principles only. No identity, no proprietary asset.

## 3. Information architecture

A floating **glass tab bar** — the app's real navigation, built from the kit's
own `GlassTabBar` — switches four branches of a `StatefulShellRoute.indexedStack`:

| Tab | Icon (Phosphor) | Route | Purpose |
|---|---|---|---|
| Showcase | `squares-four` | `/showcase` | A realistic "Discover" screen built only from the kit. |
| Components | `stack` | `/components` | Catalog, grouped, searchable. |
| Material | `cube` | `/material` | The house material editor. |
| Lab | `flask` | `/lab` | Engineering tools. |

Full-screen tools are pushed on the **root** navigator so the tab bar steps
aside: `/components/:id` (playground), `/lab/tiers`, `/lab/blend`,
`/lab/motion`, `/lab/surfaces`, `/lab/sampling-probe`.

The app opens on **Showcase**. Branches keep their state (indexed stack). Tab
switches fade through (180 ms); pushes use the platform slide.

Removed: splash route, login route, the auth redirect. Nothing is behind a login.

## 4. The glass kit

Fifteen components in `lib/utils/widgets/glass/<family>/`, one public widget per
file. Each is built only on the public `glass_forge` API plus the app's tokens,
so promoting one into the package is a token swap, not a rewrite.

Every kit component:
- takes an optional `material`; null means the house material from `HouseGlass`
  (§6);
- is interactive through `InteractiveGlass` (press squash) or `PressableScale`,
  with a haptic on commit;
- carries `Semantics` (role, label, selected/toggled state) and a ≥ 44 pt hit
  target even when the drawn shape is smaller;
- respects Reduce Motion: springs collapse to instant, squash is off.

| Family | Component | Behaviour that matters |
|---|---|---|
| Navigation | `GlassTabBar` | Floating capsule, icon + optional label, 2–5 tabs, optional badge. Selector is a painted lit capsule (never a second glass pass — §4 rules) sliding on a bouncy spring (`motor` `VelocityMotionBuilder`) with velocity squash-and-stretch. Drag across the bar to scrub; a haptic tick at each tab boundary; release commits. |
| | `GlassTopBar` | Leading/trailing `GlassCircleButton`s, centred or large title. Sits inside the top safe area. |
| | `GlassCircleButton` | 40 pt glass disc, 44 pt target, one icon. |
| | `GlassSegmentedControl` | Glass track, sliding glass selector (same spring as the tab bar), drag-to-scrub. |
| Buttons & controls | `GlassButton` | Capsule; `.primary` (accent-tinted glass, dark label) and `.secondary` (clear glass, light label); optional leading icon; loading state. |
| | `GlassSwitch` | Glass knob travelling a track; the track fills with the accent when on. |
| | `GlassSlider` | Solid track, glass lens thumb that magnifies the track beneath it. |
| | `GlassStepper` | Capsule with − value +; value in mono; long-press repeats. |
| Cards & content | `GlassMediaCard` | Photo with a glass caption panel and an optional glass chip and action circle. |
| | `GlassStatCard` | Number-first glass card: mono value, unit, delta, label. |
| | `GlassToast` | Glass capsule that drops from the top safe area and auto-dismisses; swipe up to dismiss. `showGlassToast(context, …)`. |
| Overlays | `GlassBottomSheet` | Glass sheet with grabber, detents, drag to dismiss. `showGlassSheet(context, …)`. |
| | `GlassContextMenu` | Long-press a child; glass menu scales from the touch point. |
| | `GlassMiniPlayer` | Capsule: artwork, title, subtitle, play/pause circle. |
| | `GlassSearchBar` | Capsule text field with icon and clear button. |

Glass budget: a screen renders its glass in as few `GlassLayer`s as its
materials allow (one pass per distinct material, `MAX_SHAPES` 8 per layer).
Every layer is sized tightly to its component.

### Composition rules (hard)

These come from flutter#187820, verified against the issue itself: on a
physical iPhone, a shader `BackdropFilter` painted **above an overlapping
`BackdropFilter`** — siblings in one `Stack`, the reporter's case being "a
draggable lens indicator over a glass tab bar" — samples a stale previous-frame
backdrop including its own output, and converges to a white wash within a few
frames. The simulator and Android composite correctly. It was auto-closed, not
fixed. Overlap is by **layer bounds**, not shape bounds: a filter covers its
layer's whole clip.

1. **At most one glass pass at any point on screen.**
2. **The tab selector is painted, not glass** — a lit capsule (translucent
   fill, gradient rim, inner highlight) that keeps the spring, squash and scrub.
   A second backdrop pass over the bar is the repro verbatim.
3. **Glass zones.** Every kit component that owns a layer wraps it in
   `KitGlassLayer(priority: …)`, which reports the layer's global rect to a
   `GlassZones` registry at the app root. Priorities: `content` < `chrome` <
   `overlay`. Wherever a layer's rect meets a higher-priority zone, it renders
   `GlassStaticSurface` — the same shape, a translucent tinted fill and a
   gradient rim, no backdrop read — and returns to live glass once clear,
   crossfading over 120 ms. So a caption scrolling under the tab bar goes static
   only while it overlaps, and chrome beneath an open glass sheet or context
   menu goes static only while that overlay is up.
4. **Reduce Transparency** renders every kit component as `GlassStaticSurface`
   — the same path, so accessibility and the device workaround share one code
   path.
5. **Tool screens use solid chrome.** Playgrounds and Lab tools push
   full-screen above the tab bar; their top-bar buttons are solid, so the
   specimen is the only glass on screen.
6. **What glass refracts is painted behind its layer**, never inside it. A
   layer wrapping its own backdrop samples the scaffold instead (`843f23f`).
   Layers are never nested.
7. **Materials by purpose:** the house material drives the kit (Showcase,
   playgrounds, Material). Lab tools keep their own — Blend and Motion the
   dome, Tiers the demonstration material, and Surfaces each role's own
   resolved material, which is that screen's whole subject.
8. **Physical-device gate:** Phase 1 is not done until Showcase has been
   scrolled, a sheet opened and the tab bar scrubbed on a physical iPhone with
   no white-wash.

## 5. Playgrounds

One generic playground renders every component. A component contributes one
**story** file — no per-component feature folder.

```dart
class ComponentStory {
  final ComponentId id;             // enum: family, title, summary live on it
  final List<StoryKnob> knobs;      // stepper / toggle / slider / choice
  final Widget Function(BuildContext, KnobValues) build;
  final String Function(KnobValues) code;
}
```

`PlaygroundCubit(story)` holds `KnobValues` (immutable), the backdrop, and an
optional local material override. The page:

- **Top:** `GlassTopBar` — back circle, component title, reset circle.
- **Stage (~55 %):** the component live over the chosen backdrop, centred in
  the space above the sheet. A row of backdrop thumbnails pinned to the stage's
  bottom edge: Photo · Mesh · Checker · Stripes · Black.
- **Tinker sheet (solid, never glass):** segmented tabs **Variants · Material ·
  Code**. Variants renders the story's knobs; Material overrides the house
  material for this playground only (with "Use house material"); Code shows the
  snippet for the current knob values in Geist Mono with a Copy button.

## 6. House material

`HouseGlassCubit`, provided once above the router, holds the material every kit
component uses unless told otherwise. `HouseGlass` (an `InheritedWidget` fed by
the cubit) is how components read it without each one depending on the cubit.

Default: `GlassMaterial.dome()` — the in-flight renderer work's answer to
"frosted" glass.

The **Material** tab edits it:
- **Stage:** "In context" (a glass card, a `GlassButton`, a `GlassCircleButton`
  over a photo) or "Shape" (one plain specimen, the old Specimen screen).
- **Presets:** Dome · Regular · Clear · Tinted · Demo. Picking one tweens every
  numeric field over 280 ms; discrete fields (variant, profile) switch at the
  midpoint.
- **Knobs:** grouped Shape · Optics · Light · Tint, each group fits without
  scrolling on an iPhone SE. Knobs a material ignores are hidden, not disabled
  (e.g. refraction spread on a dome).
- **Copy as Dart:** the material as a `GlassMaterial(...)` literal, only
  non-default fields, to the clipboard, with a `GlassToast`.

State is session-only for v1 (no persistence).

## 7. Screens

### Showcase — "Discover"
Comp: `01-showcase.jpg`. A travel-photo feed.
- Header over the feed: `GlassCircleButton` (person) · "Discover" · `GlassCircleButton`
  (bell, with a badge dot). `GlassSearchBar` below. `GlassSegmentedControl`
  For you · Nearby · Saved, which filters the feed.
- Feed: `GlassMediaCard`s over bundled photos, a `GlassStatCard` inline.
  The feed scrolls **under** the header and the tab bar — that is what gives the
  glass something to refract.
- `GlassMiniPlayer` docked above the tab bar; play/pause toggles.
- Tap a card → `GlassBottomSheet` with place details and a `GlassButton`.
  Bookmark → `GlassToast` "Saved". Long-press a card → `GlassContextMenu`.
- Entrance: header and first cards fade-rise staggered 40 ms. Reduce Motion: none.

### Components
Comp: `02-components.jpg`. Large title "Components", subtitle "15 glass parts,
all live", `GlassSearchBar` filtering by title and summary. Grouped rows
(Navigation / Buttons & controls / Cards & content / Overlays): a 36 pt tile
with a line glyph, title, one-line summary, chevron. Empty search → an empty
state with a "Clear search" action. A dim, blurred photographic band sits
behind the header so the search bar's glass has something to bend.

### Playground
Comp: `03-playground.jpg`. §5.

### Material
Comp: `04-material.jpg`. §6.

### Lab
Hub: large title "Lab", one row per tool with a one-line purpose. Tools keep
their current behaviour, rebuilt on the new chrome (stage + tinker sheet +
`GlassTopBar`), fixing the audit:

- **Tiers:** the specimen is centred in the space above the caption and
  backdrop row, not in the whole stage; ladder rows wrap at large text.
- **Blend:** the triad is centred on its own centroid; separation is clamped
  to what the stage can show.
- **Motion:** unchanged behaviour; the reset becomes a top-bar circle.
- **Surfaces** (was Gallery): the size slider's maximum is the pane's real
  height, so every readout describes what is drawn; the caption is inset.
- **Sampling probe:** dark theme; `GlassSegmentedControl` replaces the
  template `SlidingTab`; the mode race is fixed (a stale warm-up completion is
  ignored).

## 8. Visual system

### Colour (`AppColors`, dark only)
| Token | Value | Use |
|---|---|---|
| `ground` | `#0B0C0F` | App background |
| `surface` | `#131519` | Tinker sheet, rows |
| `surfaceRaised` | `#1A1D23` | Pressed rows, control tracks |
| `hairline` | `#FFFFFF` @ 8 % | Dividers, control borders |
| `textPrimary` | `#F3F4F6` | Titles, values |
| `textSecondary` | `#A3A9B4` | Body, labels (8.2 : 1 on ground) |
| `textTertiary` | `#80868F` | Captions, section labels (≥ 4.6 : 1 on every surface) |
| `accent` | `#D4F25A` | Selected, on, active, live. Nothing decorative. |
| `onAccent` | `#0B0C0F` | Text on accent |
| `danger` | `#FF6B5E` | Destructive |

Contrast pairs are asserted in `test/constants/contrast_test.dart`, computed
with the WCAG 2.1 formula.

### Type
**Geist** (UI) and **Geist Mono** (every number and unit), both OFL, bundled.
SF Pro Rounded and BBBPoppins are removed (SF Pro is licensed for Apple
platforms only; the app also ships to Android).

| Style | Size / line | Weight | Tracking |
|---|---|---|---|
| `display` | 34 / 40 | 600 | −0.6 |
| `title` | 22 / 28 | 600 | −0.3 |
| `headline` | 17 / 22 | 600 | −0.2 |
| `body` | 15 / 21 | 400 | 0 |
| `callout` | 14 / 20 | 500 | 0 |
| `caption` | 12 / 16 | 400 | 0 |
| `overline` | 11 / 14 | 500 | +0.8, uppercase |
| `mono` | 14 / 20 | 500 | 0 |
| `monoSmall` | 12 / 16 | 500 | 0 |

Values always carry a unit: `27.4 px`, `0.35 ×`, `0.42 s`, `4.5 : 1`.

### Space, radius, motion
- `AppSpacing`: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48. Screen gutter 16.
- `AppRadius`: 8 (small tiles) · 12 (chips, controls) · 16 (rows) · 24 (sheets,
  cards) · pill.
- `AppMotion`: press 120 ms easeOut · select 220 ms easeOutCubic · sheet 360 ms
  · fade-through 180 ms · stagger 40 ms. Glass springs come from
  `glass_forge`'s `GlassMotion`.

### Icons
One source: Phosphor (MIT) SVGs in `assets/vectors/icons/`, registered in
`AssetPaths`, drawn with `AppSvgIcon`. Regular weight inactive, fill when
selected. No `Icons.*` anywhere.

### Texture
Photographs on stages and the feed; an ultra-subtle grain on `ground` headers.
No blobs, no gradients for their own sake.

## 9. Layout, insets, system UI

- Light status-bar icons everywhere (`SystemUiOverlayStyle.light`), true
  edge-to-edge on Android and iOS; the Android-15 `SafeArea` wrap in `AppView`
  is removed.
- `WorkbenchScaffold` is the one place insets are handled: chrome placed at the
  top is offset by `MediaQuery.paddingOf(context).top`; scrollables pad their
  end by the floating tab bar's height plus the bottom inset, so the last item
  is reachable and never hidden.
- Portrait only on phones (shortest side < 600); tablets keep all orientations.
- Every row that pairs a label with a value: label `Expanded`, value
  `Flexible`, and at text scale ≥ 1.5 the value drops beneath the label.

## 10. Accessibility floor

- Contrast per §8, including selected states and control borders (≥ 3 : 1 for
  non-text).
- Touch targets ≥ 44 pt; slider thumbs get an expanded hit area.
- Every custom control: `Semantics` with role, label, value and state; no
  double-announced labels (`excludeSemantics` on inner text).
- Colour is never the only signal: selection is fill + weight/icon change.
- Reduce Motion honoured by every animation, including the probe's.
- Text scales to 2.0 without overflow on a 320 pt-wide screen — asserted in
  widget tests for every row type and the tab bar.

## 11. Code and conventions

Follows `apps/glass_forge_workbench/CLAUDE.md`, which is rewritten to describe
the app that exists (no API, Hive, socket, Firebase sections).

- **Delete** the dead template: onboarding/login/splash, API/env/endpoints,
  Hive preferences, DI, remote config, locale cubit, Phoenix, device preview,
  toastification, ~29 unused core widgets, unused helpers and assets, the
  6.9 MB runtime splash image. This also fixes the clean-checkout build (the
  gitignored `env_*.g.dart` files are no longer referenced).
- **Keep and use l10n:** every user-facing string in `app_en.arb`, read through
  `context.l10n`. The untranslated `app_es.arb` is removed.
- Logic out of widgets: string building and verdicts move to state getters or
  enum extensions (tier status, blend verdict, gallery pair formatting, probe
  arithmetic).
- One class per file, package imports, `AppColors`/`AppSpacing`/`AppRadius`
  tokens, `buildWhen` on every `BlocBuilder`, no `setState` anywhere — a kit
  component's ephemeral gesture state (scrub position, drag offset) lives in a
  `ValueNotifier` it owns and disposes, the pattern KiBU's `TopNavPill` uses —
  no `// ignore:`, `flutter analyze` at zero.
- The in-flight renderer work under `packages/glass_forge` is not touched.

## 12. Testing and verification

- Unit: `PlaygroundCubit`, `HouseGlassCubit` (presets, tween end-state, Copy as
  Dart output), each story's `code()` for default knobs, state getters moved out
  of widgets.
- Widget: tab bar selection, scrub commit, semantics; playground knob → build;
  catalog search and empty state; overflow at 2.0× on 320 pt for rows, tab bar,
  top bar; contrast table.
- Existing lab tests are kept and updated for the new chrome.
- Manual: iPhone 17 Pro simulator and an iPhone SE-size simulator, screenshots
  of every screen at 1.0× and 2.0× text; one run on the physical iPhone.
- `flutter analyze` zero and `flutter test` green before each phase's commit.

## 13. Out of scope (v1)

Persisting the house material; a light app theme; tablet-specific layouts
beyond not breaking; promoting kit components into `glass_forge`.

## 14. Phases

0. Cleanup and foundation — dead code out, tokens, fonts, icons, scaffold,
   press/haptics, l10n migration, system UI.
1. `GlassTabBar` + shell, then Showcase and the components it needs.
   **Checkpoint: screenshots to the user.**
2. Remaining components, the playground system and stories, Components catalog,
   Material.
3. Lab hub and tools on the new chrome, audit sweep, `impeccable` critique,
   copy through `humanizer`, small-phone and large-text screenshots.

One commit per phase, conventional prefix, no AI co-author line.
