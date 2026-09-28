# glass_forge

Liquid glass for Flutter: real refraction where the GPU allows, graceful
degradation everywhere else.

One package, one `pub add`. Rendering, tiering, motion, design tokens and the
native accessibility signals all live here, because a consumer should never
have to assemble a library themselves to get correct behaviour.

```dart
GlassLayer(
  material: GlassMaterial.regular(brightness: Brightness.dark),
  child: Stack(
    children: [
      const YourContent(),
      const Align(
        alignment: Alignment.bottomCenter,
        child: Glass(
          shape: GlassRoundedRectangle(
            radius: BorderRadius.all(Radius.circular(28)),
          ),
          child: SizedBox(height: 56, child: YourTabBar()),
        ),
      ),
    ],
  ),
)
```

The [example app](example/) is a playground: three live scenes — a lens you
drag and reshape, drops that melt together, and a set of everyday controls —
under a sheet with a knob for every field of `GlassMaterial`, presets that
morph into one another, a quality-tier pin, and a button that copies the
material you ended up with as Dart.

## How it works, in one paragraph

A `GlassLayer` captures the backdrop behind it once. Every `Glass` inside it
registers a shape into a shared signed-distance field, which is baked into a
compact RGBA8 **matte** — surface normal, edge distance and displacement
magnitude, one texel per pixel. A single `BackdropFilter` per material then
reads that matte and bends the captured backdrop along the normals, inside a
narrow band at each shape's edge. The interior is left undistorted, which is
what Apple's material does and what makes it read as glass rather than as a
lens.

That "one capture per layer" is a hard invariant, not an implementation
detail: a shader filter stacked *above* another backdrop filter reads a stale
previous-frame backdrop on physical iPhones ([flutter#187820]), which shows up
as a progressive white-wash.

[flutter#187820]: https://github.com/flutter/flutter/issues/187820

## Shapes and blending

`GlassRoundedRectangle`, `GlassOval` and `GlassSuperellipse` (Apple's
continuous-curvature squircle). Shapes in a `GlassBlendGroup` smooth-min into
one another in the distance field, so they merge like liquid rather than
overlapping like two cut-outs:

```dart
const GlassBlendGroup(
  blend: 24,
  child: Row(children: [Glass(shape: GlassOval()), Glass(shape: GlassOval())]),
)
```

Blend width is in logical pixels. Because the smooth-min is not associative,
registration order is load-bearing and is preserved deliberately.

## Motion

`InteractiveGlass` gives a surface press, drag, fling and spring-home, with
squash-and-stretch **derived from the spring's live velocity** rather than
animated as a separate channel — which is what keeps it physically coherent
instead of looking like a rectangle being scaled.

```dart
InteractiveGlass(
  drag: const GlassDrag(),
  settleMotion: const GlassMotion.smooth(),
  onTap: () {},
  child: const Glass(shape: GlassOval()),
)
```

Springs are specified the way Apple specifies them — **duration and bounce**,
not stiffness and damping. `GlassMotion.bouncy/.snappy/.smooth/.interactive`
cover the common cases.

This is built on [`motor`], with the gaps filled: `motor` has no decay
simulation (so `GlassDecay` wraps `FrictionSimulation`), no rubber-banding
despite a changelog entry claiming it (`GlassOverdrag`), no follow primitive
that avoids reallocating simulations per pointer event (`SpringAxis`), and no
reduce-motion handling at all — it stores an `AnimationBehavior` on every
controller and never reads it back.

[`motor`]: https://pub.dev/packages/motor

## Controls

`GlassButton` resolves `GlassSurfaceRole.control` for its material, shape and
label colour, and never draws glass on glass: built on content it is real
glass over `InteractiveGlass`; built under `GlassHostScope` — inside a glass
toolbar, say — it paints a flat tint with a scale on press instead.

```dart
GlassButton(
  onPressed: () {},
  child: const Text('Continue'),
)
```

`onPressed: null` disables it. Every control in this package shares
`GlassControlFrame` for semantics, keyboard activation (Enter and Space) and
a 44 × 44 minimum hit target that grows the tap area, never the glass.

`GlassSwitch` is a track and a knob: the track is always painted — real
glass on a 64 × 28 capsule this thin reads as a smear, not a control — and
only the knob, the one lens-profile element Apple's own switch has, becomes
glass, and only on content.

```dart
GlassSwitch(
  value: enabled,
  onChanged: (next) => setState(() => enabled = next),
)
```

The knob drags, flicks and settles to whichever side it ends up past, on
the theme's `settle` spring; a tap toggles it outright.

`GlassSlider` is a painted track and fill under a thumb — real glass on
content, painted under `GlassHostScope` — that can be dragged from anywhere
in its 44-point-tall hit area, not only from the thumb itself.

```dart
GlassSlider(
  value: volume,
  onChanged: (next) => setState(() => volume = next),
)
```

The thumb stretches along the track under a fast drag, through
`GlassJiggle`; `divisions` snaps it to evenly spaced steps, and the arrow
keys step it by one division, or a tenth of the range without one.

`GlassSegmentedControl` is a row of mutually exclusive choices under a
travelling pill — real glass on content, painted under `GlassHostScope`.

```dart
GlassSegmentedControl<int>(
  segments: const [
    GlassSegment(value: 0, label: Text('Day')),
    GlassSegment(value: 1, label: Text('Week')),
    GlassSegment(value: 2, label: Text('Month')),
  ],
  selected: range,
  onChanged: (next) => setState(() => range = next),
)
```

The pill can be dragged from anywhere in the control, not only from the
pill itself, and snaps to the nearest segment on release; a tap on a
segment, or the arrow keys while one is focused, select it outright. Each
segment is its own semantics node — a selectable button, `isSelected` on
exactly the chosen one.

`GlassTextField` wraps `EditableText` — real glass on content, painted
under `GlassHostScope` — rather than reimplementing IME, composing text or
tap-to-place-caret handling.

```dart
GlassTextField(
  controller: controller,
  placeholder: 'Search',
  onChanged: (value) => print(value),
)
```

Focus reads as the glass lighting up: the material's highlight and tint
opacity animate brighter on the theme's `settle` spring, never a painted
ring on top. The caret and selection are painted above the glass as a
`Stack` sibling, never inside it, so they are never refracted, and a
focused field inside a scroll view calls `Scrollable.ensureVisible` to
track the keyboard's own show/hide animation clear of it. With no Material
ancestor required, the field shows the real system selection menu
(`SystemContextMenu`) wherever the device supports it — iOS 16 and
above — and nothing elsewhere by default; `contextMenuBuilder` and
`selectionControls` let an app that already imports Material or Cupertino
pass its own toolbar and drag handles in. Typing, arrow-key caret movement
and the platform's own copy/paste shortcuts all keep working regardless.

## Tiering

Glass is expensive, and the honest answer on a cold-throttled mid-range phone
is *less glass*. Wrap the app once:

```dart
GlassTierScope(child: MyApp())
```

The engine resolves a tier from four inputs: GPU capability, thermal state,
observed frame health, and the user's accessibility settings. Capability,
thermal and accessibility impose **absolute** ceilings — statements about the
device and the user. Frame health steps down **relatively** from wherever
those left it, because it is a statement about workload. So a strained frame
rate on a hot device lands lower than the same frame rate on a cool one.

`ResolvedTier.describe()` reports *why* the current tier was chosen, not just
which one it is.

| Tier | Renders |
|---|---|
| **full** | Everything: refraction, dispersion, specular, blending, and the dome lens |
| **balanced** | The dome without dispersion — 12 backdrop reads per fragment down to 4 |
| **reduced** | The lens flattens to Apple's edge band, keeping tint, saturation, frost and light |
| **flat** | No refraction: the frost, the tint and a contrasting border |
| **off** | Nothing is rendered at all |

Degradation is also the default when the renderer simply cannot run. On Skia
and the web backends `ui.ImageFilter.shader` throws, so the frost is applied
on its own and the refraction, rim and contour do not happen. You do not have
to opt in to that.

## Accessibility

- **Reduce Transparency** is read through a native channel, because Flutter's
  accessibility bitmask never reports it on iOS and Android has no public
  equivalent. When the platform cannot answer it returns `null`, and callers
  treat that as *unknown* rather than *off* — rendering full glass to someone
  who asked for less is the one failure worth engineering against.
- **Reduce Motion** honours both engine bits. `AccessibilityFeatures.reduceMotion`
  is documented as iOS-only and `disableAnimations` is what Android sets from
  its animator duration scale, so either alone is silently wrong on one
  platform.
- **Increase Contrast** drives surfaces toward near-opaque plus a border.

## Design system

Tokens (blur, radius, depth, tint ramps), five semantic surfaces, and theming:

```dart
GlassTheme(
  data: GlassThemeData.dark,
  child: GlassSurface.navigationBar(child: YourBar()),
)
```

Every tint step is the *minimum* opacity that clears its stated WCAG contrast
threshold over the worst backdrop in its scheme, and the tests assert both
directions — that it clears, and that slightly less does not.

Surfaces adapt by size, following Apple: small elements like a control flip
light/dark against their background, large ones like a sheet adapt without
flipping. The gate is thinness, not area.

## Chrome

`GlassScaffold` makes the one-`GlassLayer` composition rule the default
instead of something to get right by hand: your background and body paint
behind the layer, your bars are the only glass inside it, and the body gets
padding back so a `ListView` clears the bars on its own.

```dart
GlassScaffold(
  background: const ColoredBox(color: Color(0xFF101820)),
  topBar: GlassSurface.navigationBar(child: YourTitle()),
  body: ListView(children: rows),
)
```

Each bar fades through its own presence, tied to the enclosing route: full
while nothing covers the screen, ramping to none as a sheet or another route
arrives over it, so the two are never both a backdrop filter over the same
pixels.

## Presets

`GlassMaterial.regular(brightness:)` and `GlassMaterial.clear()` are fitted
against real iOS 27 captures. Those numbers are measured data — see
`lib/src/material/apple_presets.dart` for provenance — and are deliberately
not rounded to look tidy.

They are tuned for what Apple uses them for: a small navigation surface over
bright, content-rich material. They are not a good demo of refraction at
large sizes, where a lower tint and a narrower band read far better.

## Measuring it

`benchmark/run_scene_benchmarks.dart` runs 16 scenes, each varying exactly one
axis, and reports p50/p90/p99/worst rather than a mean. Budgets live in
`benchmark/budgets.json` so a change to them is a reviewable diff.

```
flutter run --profile -t benchmark/run_scene_benchmarks.dart
```

It refuses to gate on a debug-mode report. A debug build carries the full
assert overhead, so those numbers say nothing about shipped performance — the
harness marks such a run untrustworthy rather than letting it quietly pass.

## Status and known limits

- The budgets shipped in `benchmark/budgets.json` are **seed values, not
  measured data**. No profile-mode capture on real hardware has been taken
  yet.
- `containsChild` on `Glass` is accepted and not yet wired.
- Backdrop luminance for surface adaptation is caller-supplied; nothing
  samples it automatically yet.
- Where two materials' shapes overlap, the later pass samples the earlier
  one's glass. Apple's own guidance is not to stack glass on glass; put
  overlapping surfaces in one material or one blend group.
- `flutter test` cannot rasterise a backdrop filter faithfully, so rendering
  is verified on the Impeller lane
  (`flutter test --tags impeller --run-skipped --enable-impeller`) rather
  than through `toImage()`.

## Requirements

Impeller for the refracting path; anything else degrades to blur. Flutter GPU
is used for the accelerated geometry producer where available and needs
`FLTEnableFlutterGPU` in `Info.plist` on iOS, or the
`io.flutter.embedding.android.EnableFlutterGPU` metadata key on Android.

## Credit

Built on [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass)
by Tim Lehmann / whynotmake.it (MIT), whose shader corpus and 16-shape
batching design are the foundation here. Spring motion comes from
[`motor`](https://github.com/whynotmake-it/rivership/tree/main/packages/motor)
by the same author.

## License

MIT — see [`LICENSE`](LICENSE) and [`THIRD_PARTY.md`](THIRD_PARTY.md).
