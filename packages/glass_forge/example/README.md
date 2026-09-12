# glass_forge example

Five scenes over five photographs. Each one is a working screen rather than a
swatch, and everything on them is the package's own API — there is no wrapper
layer between the reader and `GlassLayer`, `Glass`, `GlassMaterial`,
`InteractiveGlass` and `GlassSurface`.

```sh
cd packages/glass_forge/example
flutter run
```

Impeller is required for the refracting path. On anything else — Skia, the
web backends — `ui.ImageFilter.shader` throws, the frost is applied on its
own, and the app still runs. That is the package's degradation story, not a
broken build.

## The scenes

| Scene | What it shows |
|---|---|
| **Lens** | `GlassMaterial.dome()`: a sphere cap over the whole interior, so the middle magnifies and the rim compresses. Draggable, with a live `edgeRefraction` slider and the three shapes. |
| **Edge** | `GlassMaterial.regular(brightness:)` and `.clear()` side by side, both fitted against real iOS 27 captures. Each carries a letterform, because the real difference between them is what happens to a label: regular exists to keep one readable over anything, clear is for media-rich content where the foreground is already bold. |
| **Blend** | `GlassBlendGroup`: two ovals whose distance fields smooth-min into one another. Drag the right one and the neck stretches with it. |
| **Motion** | `InteractiveGlass`: press, drag, fling, spring home, with squash and stretch read off the spring's own velocity. Three springs and a stretch limit. |
| **System** | The five `GlassSurface` roles on one screen, the tier the engine resolved, and `ResolvedTier.describe()` explaining why. |

## Reading the code

`lib/main.dart` is the whole architecture: the tier scope, the theme, the one
glass layer, the tab bar, and the Lens scene. The other four scenes are in
`lib/src/scenes/`, and they are all the same shape — a specimen, a control
row, and the line of code that produced what is on screen.

## Four rules the composition follows

Each of these was a bug in this repository first.

1. **At most one glass surface at any point on screen.** On a physical iPhone a
   glass surface drawn over another reads a stale frame, including its own
   previous output, and washes out white within a few frames
   ([flutter#187820](https://github.com/flutter/flutter/issues/187820)). The
   simulator renders it correctly, so it ships by accident. Nothing here
   overlaps: the specimen sits above the control panel, the panel above the tab
   bar, and every control drawn *on* a glass surface is paint. Raising the
   scrim removes every other surface in the same frame rather than fading over
   them.
2. **Paint what the glass refracts behind the layer, never inside it.** A
   backdrop filter can only bend what is already beneath it. The photographs
   and the one scrim are painted before the `GlassLayer`; everything inside it
   is drawn on top.
3. **The backdrop must be coarser than the displacement.** The glass moves what
   is behind it by tens of pixels. A pattern finer than that is pushed through
   whole periods and lands looking identical, so the glass appears to do
   nothing. Every photograph here was chosen for large structure — a ridge
   line, a painted terrace, a curtain of light.
4. **Bars and pills get explicit heights.** A `Container` with an `alignment`
   in a bounded slot expands to fill it and swallows the screen.

There is a fifth that is easy to miss: anything pinned to the top of an
edge-to-edge surface needs its own safe-area inset, or it prints through the
clock.

## Assets

| | |
|---|---|
| Photographs | Generated for this project. Five of them, 1.7 MB in total, each picked for large structure. |
| Geist, Geist Mono | [SIL Open Font License 1.1](assets/licenses/geist_ofl.txt), © 2024 The Geist Project Authors. Registered with `LicenseRegistry` in `main()`, so the Licences button in the System scene shows the full text. |

Two dependencies, `flutter` and `glass_forge`. An example that also teaches a
router or a state-management library is mostly teaching those; `Navigator`,
`setState` and `ValueNotifier` carry this one.

## Enabling Flutter GPU

`glass_forge` uses Flutter GPU for its accelerated geometry pass, and this
example opts in the way a consumer would:

- iOS — `FLTEnableFlutterGPU` in `ios/Runner/Info.plist`.
- Android — `io.flutter.embedding.android.EnableFlutterGPU` in
  `android/app/src/main/AndroidManifest.xml`.

Without either key the package still renders. It resolves one tier down, onto
the runtime-effect producer, which is what the System scene's `geometry` row
reports.
