# glass_forge example

A catalogue of the package's API: 33 entries in seven groups, index to
detail. Each entry is one capability, live — the real widget on screen, a
knob or two that move it, and the Dart that produced exactly what you are
looking at, ready to copy. Everything on screen is the package's own API;
where the example needs a control of its own it is painted, and it says so.

```sh
cd example
flutter run
```

Impeller is required for the refracting path. On anything else — Skia, the
web backends — `ui.ImageFilter.shader` throws, the frost is applied on its
own, and the app still runs. That is the package's degradation story, not a
broken build.

## The groups

| Group | Entries | What it covers |
|---|---|---|
| **Surfaces** | 6 | `Glass`, `GlassLayer`, `GlassMaterial`, `GlassVariant`, `GlassProfile`, and all eight material fields moved together. The rim-versus-dome split, and why regular adapts to its backdrop where clear does not. |
| **Shapes** | 4 | `GlassRoundedRectangle`, `GlassOval`, `GlassSuperellipse`, and `GlassBlendGroup` — two shapes closer than `blend` joining through a smooth neck rather than stacking as cut-outs. |
| **Motion** | 7 | `InteractiveGlass` and the six values that tune it: `GlassJiggle`, `GlassPressStretch`, `GlassOverdrag`, `GlassDecay`, `GlassMotion`, `GlassReduceMotion`. |
| **Composition** | 4 | `GlassPresence`, `GlassHostScope`, `GlassGlow`, and cross-pass overlap — the one illegal composition, provoked on purpose with the debug warning captured live. |
| **Chrome** | 4 | `GlassDetentSheet` and its detents, controller and scroll physics: one gesture crossing from the sheet into the list inside it and back. |
| **Design system** | 5 | `GlassTheme`, `GlassSurface`, `GlassTokens`, `GlassTintStep`, `GlassLegibility` — the five semantic roles, and the contrast arithmetic behind every tint promise. |
| **Adaptation** | 3 | `GlassTierScope`, `GlassTierEngine`, `GeometryTier` — the four signals that resolve a tier, and the pin that overrules three of them but never accessibility. |

An entry names the symbol you would search for, so the index doubles as a
map of the public API. Two entries are named for a subject rather than a
symbol — *Material knobs* and *Cross-pass overlap* — because neither is one
class.

## Reading the code

`lib/main.dart` is the whole architecture in one file: the tier scope, the
theme, and the index as `home`. The catalogue itself is under
`lib/src/catalogue/` —

- `catalogue.dart` — the seven groups, and the lookup a see-also chip uses
  to decide whether it has anywhere to send you.
- `catalogue_entry.dart` — `CatalogueEntry` and `Knob`. Both the widget and
  the snippet are functions of the same knob list, which is what makes it
  impossible for the code shown to disagree with the thing rendered above
  it.
- `index_page.dart`, `entry_page.dart` — the two screens, and the handoff
  between them.
- `entries/` — one file per group.

A see-also name is a pill when the catalogue has an entry to open, and
plain text when it does not. Eight of the names cross-referenced here are
real exported symbols the catalogue deliberately spends no entry on; they
are worth naming, but they do not get to look like a tap.

## Four rules the composition follows

Each of these was a bug in this repository first.

1. **At most one glass surface at any point on screen.** On a physical
   iPhone a glass surface drawn over another reads a stale frame, including
   its own previous output, and washes out white within a few frames
   ([flutter#187820](https://github.com/flutter/flutter/issues/187820)). The
   simulator renders it correctly, so it ships by accident. Nothing here
   overlaps: one `GlassLayer` per page, the specimen bare on the
   photograph, and every control drawn *on* a glass surface is paint.
   Pushing an entry is a handoff, not a cross-fade — the index's glass
   finishes fading before the entry's begins, so there is never a frame
   carrying two backdrop passes over the same region.
2. **Paint what the glass refracts behind the layer, never inside it.** A
   backdrop filter can only bend what is already beneath it. The photograph
   is painted before the `GlassLayer`; everything inside it is drawn on
   top.
3. **The backdrop must be coarser than the displacement.** The glass moves
   what is behind it by tens of pixels. A pattern finer than that is pushed
   through whole periods and lands looking identical, so the glass appears
   to do nothing. Every photograph here was chosen for large structure — a
   ridge line, a painted terrace, a curtain of light.
4. **Bars and pills get explicit heights.** A `Container` with an
   `alignment` in a bounded slot expands to fill it and swallows the
   screen.

There is a fifth that is easy to miss: anything pinned to the top of an
edge-to-edge surface needs its own safe-area inset, or it prints through the
clock.

## Assets

| | |
|---|---|
| Photographs | Generated for this project. Five of them, 1.6 MB in total, each picked for large structure and each with its backdrop colours measured in `lib/src/backdrop_info.dart`. The catalogue paints one of the five — the index and every entry page share it, so paging between them never swaps the picture. |
| Geist, Geist Mono | [SIL Open Font License 1.1](assets/licenses/geist_ofl.txt), © 2024 The Geist Project Authors. Registered with `LicenseRegistry` in `main()`, and the **Licences** button in the index's top bar opens the full text. |

Two dependencies, `flutter` and `glass_forge`. An example that also teaches a
router or a state-management library is mostly teaching those; `Navigator`
and `setState` carry this one.

## Enabling Flutter GPU

`glass_forge` uses Flutter GPU for its accelerated geometry pass, and this
example opts in the way a consumer would:

- iOS — `FLTEnableFlutterGPU` in `ios/Runner/Info.plist`.
- Android — `io.flutter.embedding.android.EnableFlutterGPU` in
  `android/app/src/main/AndroidManifest.xml`.

Without either key the package still renders. It resolves one tier down, onto
the runtime-effect producer, which is what the **GeometryTier** entry in the
Adaptation group reports.
