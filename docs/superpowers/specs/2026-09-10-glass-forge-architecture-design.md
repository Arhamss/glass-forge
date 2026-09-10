# glass_forge — architecture design

Date: 2026-09-10
Status: **awaiting review**
Supersedes the planning content of `PROJECT_BRIEF.md` §3, §5, §8, §9.

This is the umbrella design: locked decisions, the invariants every subsystem
obeys, the package layout, and the decomposition into sub-projects. Each
sub-project gets its own spec; this file is what they all agree on.

Research backing every claim here lives in `docs/reference/`. Where this
document asserts a number or a constraint, the citation is there.

---

## 1. What changed since the brief

The brief was written 2026-08-28 against Flutter 3.44 and a set of assumptions
that research has since falsified. Four of them mattered.

| Brief said | Actually |
|---|---|
| "Vendor what is stalled" — upstream is stalled | The repo was **pushed today**. There is a large unreleased rewrite (PR #157) moving to Flutter GPU. `upstream_rewrite.md` |
| Upstream is single-pass `uShapeData` | It has been **two-pass** since 0.1.1-dev.22. Our own reference doc was wrong. |
| The SkSL fix is "~10 lines" | It needs **five** distinct changes; SkSL also rejects non-constant array indices, non-constant loop initialisers, and sampler parameters. |
| Runtime tier detection is "the biggest unknown; gates the design" | **Solved.** Two release-safe mechanisms. `flutter_rendering_capabilities.md` §1 |

Two further findings reshape the design:

- **`BackdropGroup`/`BackdropKey` landed in stable 3.29.** Multiple blurred
  surfaces can share one backdrop capture. This attacks the readback problem
  more directly than tiering does.
- **Stacking two `BackdropFilter`s is broken on physical iPhones**
  (flutter#187820 — the upper one reads a stale previous-frame backdrop
  including its own output). Upstream's architecture is exactly two stacked
  filters. We cannot copy it.

---

## 2. Locked decisions

| Decision | Choice | Consequence |
|---|---|---|
| Publishing | **Deferred.** Build first. | No semver pressure. But shaders stay clean-room so publishing remains possible without rework. |
| Fork posture | **Vendor + aggressively extend.** Ideas from upstream, code re-derived. | See §3 on licensing. |
| Platforms | **Full matrix** — iOS, Android, web, macOS, Windows, Linux | Forces analytic normals (derivatives are rejected on web) and a real fallback path (`ImageFilter.shader` is Impeller-only). |
| Flutter floor | **3.47** | No GLES Y-flip conditionals. `BackdropGroup`, `ImageFilter.shader`, `ImageFilterConfig.blur` all assumable. |
| Geometry producer | **Both** — Flutter GPU and runtime-effect, behind one interface, selected by tier | §5.2 |
| Packaging | **One package.** Everything ships in `glass_forge`. | §6 |
| Customisation | **Layered**: tokens -> presets -> settings -> raw shader | Sub-project 4 |
| Motion | **All four**: spring properties, gesture/press, morph/merge, ambient | Sub-project 3 |
| Apple parity | **Faithful**, then superset | `apple_liquid_glass_spec.md` is the contract |
| Consumer | **Standalone.** KiBU is historical context, not an integration target. | The workbench app is the validation surface. |

---

## 3. Licensing position

Upstream is **not** under one licence. Published release and `main` are MIT;
the rewrite branches are **Apache-2.0** (switched 2026-08-12); one file is
**BSD** (Flutter Authors); and the upstream refraction math is credited to a
Shadertoy original whose default licence is **CC BY-NC-SA 3.0** — non-commercial
and share-alike, which no MIT wrapper launders.

**Rule: formulas and techniques are not copyrightable. Code is.**
We read formulas, cite sources, and write our own implementations. Nothing is
pasted. The full provenance table is in `shader_techniques.md` §0, and
`THIRD_PARTY.md` carries the licence map.

This costs us nothing — every formula we need is available formula-level or
from MIT/Apache/CC0 sources — and it keeps publishing open.

---

## 4. The ten invariants

Every subsystem obeys these. They are extracted from measured upstream
failures, not from taste.

1. **One backdrop capture per layer.** Never two stacked `BackdropFilter`s —
   flutter#187820 makes that architecture unsound on real iPhones. Blur and
   shader compose into a single filter via `ImageFilter.compose`.
2. **Never mutate a texture the compositor may still read.** Geometry changes
   allocate a new texture generation; the producer releases only its own
   handle. Upstream measured the alternative: an expanding pill corrupted 1,760
   and 3,870 pixels of stationary siblings.
3. **The matte is layer-local, never screen-space.** Ancestor transforms are
   compositor-only, mapped into matte space by a per-frame affine uniform.
   Baking `getTransformTo(null)` applies scale twice — once in the matte, once
   in compositing.
4. **Invalidate by monotonic revision, never by deep comparison.** Measured:
   735.8 ns versus 5.7 ns per check.
5. **Children paint in place.** Never the deferred `paintFromLayer` trick. It
   is the single root cause of upstream's z-order surprises, first-frame
   invisibility, broken Hero flights, broken `toImage`, and one-frame lag.
6. **Analytic SDF normals only.** `dFdx`/`dFdy` are rejected on web
   (flutter#180959), undefined after non-uniform early returns, and blocky at
   corners. `fwidth` is unavailable in runtime effects even on Impeller.
7. **Every geometric quantity is DPR-scaled, and every threshold is in
   pixels.** Upstream's `thickness` is the one uniform it forgot to scale, so
   its rim is a third the intended width on a 3x phone; and its
   chromatic-aberration default fails its own unit-free cutoff.
8. **Shader source is SkSL-legal by construction**: constant loop bounds with
   an early `break`, constant array indices, uniform arrays read as globals, no
   sampler parameters. Even where we only run on Impeller, this keeps the Skia
   path compilable.
9. **Reuse native `ImageFilter`s keyed on a uniform snapshot.** The engine
   copies uniforms into the native filter at first conversion, so a filter may
   only be reused while `(textures, bounds, dpr, settingsRevision,
   coordinateMapping)` compares equal.
10. **Bucket allocation-sized quantities.** Backdrop clip bounds and textures
    round up to 64 px, because backdrop filters allocate an offscreen render
    target per clip-bounds size and small animated changes otherwise reallocate
    every frame. `snapToPixel` uses `floor(x*dpr + 0.5)` so a matte crossing
    the origin does not change size by a pixel.

---

## 5. Architecture

### 5.1 The render graph

```
GlassLayer                       one backdrop capture, one shared SDF scene
 |
 +- RetainedClipChain            ancestor clips re-pushed OUTSIDE the moving
 |                               offset layer  ("scrolling moves material
 |                               through a viewport, not the viewport
 |                               through the material")
 |
 +- GlassScene                   registered shapes in layer-local space,
 |                               each with an inverse affine basis and a
 |                               min-singular-value distance scale
 |
 +- GeometryProducer  <strategy>  scene -> immutable matte generation
 |    +- GpuGeometryProducer         flutter_gpu, devicePrivate texture
 |    +- RuntimeGeometryProducer     Paint.shader + toImageSync
 |    +- NullGeometryProducer        cheap/static tiers: no matte at all
 |
 +- GlassComposition             ONE BackdropFilterLayer:
 |                               ImageFilter.compose(
 |                                 inner: blur,
 |                                 outer: ImageFilter.shader(finalPass))
 |
 +- children                     painted in place, normally
```

### 5.2 Two geometry producers, one interface

```dart
abstract interface class GeometryProducer {
  GeometryCapabilities get capabilities;
  MatteGeneration produce(GlassScene scene, MatteRequest request);
  void releaseGeneration(MatteGeneration generation);
  Future<void> warmUp();
}
```

Both producers ship in the package. `GpuGeometryProducer` reports
`available: false` when Flutter GPU cannot initialise — an older Flutter, a
Skia backend, a shader bundle that did not build — and the registry falls
through to the runtime producer.

Selection is a **tier output**, not a compile-time constant — so a device that
thermally throttles can fall back from the GPU producer to the runtime producer
to no matte at all, without the widget tree noticing.

Known cost of the GPU path, to be measured and gated: upstream reports a
first-frame pop (real glass cannot render until the async load completes) and
a memory rise from immutable generations (435 -> 458 MiB median in their
harness). Both are acceptable *if* the producer is optional and tier-selected;
neither is acceptable as the only path.

### 5.3 The shape model

Six floats per shape is not enough — it cannot express rotation. Ours carries:

- **type** and **corner parameters**
- **inverse 2x2 basis + origin**, so the SDF is evaluated in local space
- **distance scale** = the basis's **minimum singular value**, so local
  distances remain a valid lower bound in screen pixels under non-uniform scale
  (a transformed AABB would apply scale twice)
- **group marker**, sign-encoded: negative starts a new blend group and carries
  the blend width; positive continues one

The group marker is what lets multiple blend groups *and* ungrouped shapes
share a single pass and a single backdrop capture. Upstream's shipped version
wraps every ungrouped shape in a dummy `blend: 0` group instead.

Shapes: rounded rectangle, ellipse (Newton solve, not the pinhole
approximation), and rounded superellipse **lifted from Flutter's own
`uber_sdf.frag`** so the glass silhouette matches `ClipRSuperellipse` exactly.
Upstream's "squircle" is mathematically a rounded rect while its clip is a real
superellipse — they disagree at every corner.

### 5.4 The material model — Apple-faithful

Per `apple_liquid_glass_spec.md`, Apple's lensing is an **edge band with an
undistorted interior**, parameterised by band width and displacement amount
over an SDF that stores distance and direction. It is not a whole-surface
physical refraction.

So the core material is:

- **edge-band displacement** along the analytic SDF normal, with a convex
  squircle profile (best fit to Apple per the ray-trace study), and an
  **interior early-out**
- **`edgeRefraction` in pixels** as the observable parameter, with IOR derived
  (`ratio = edgeRefraction / (8*thickness); n = sqrt(1 + ratio^2)`) — users
  think in pixels of distortion, and Apple exposes no refractive index
- **two opposing rim highlights**, incident-white coloured (not
  backdrop-derived, which is what produces upstream's cyan/green fringing),
  guarded by `pow(luminance, 0.25)` so a truly black surface does not flicker
- **rim-gated 3-tap chromatic aberration** with a **pixel-space** threshold
- **Regular and Clear variants only**, with Clear taking a 35% dark scrim on
  bright backdrops

### 5.5 The matte codec

If the matte is RGBA8, naive encoding bands visibly. Ours:

- **RG** = unit surface normal, asymmetric 0..254 so -1, 0, +1 are exact
- **B** = signed edge distance, sqrt-companded both sides
- **A** = displacement magnitude, sqrt-companded
- range sized to `1.05 * edgeRefraction`, not `thickness * 10`, so code points
  are not spent on unreachable values

The GPU producer may use a higher-precision format where available; the codec
is an interface, not a constant.

### 5.6 The tier model

The brief's T0-T3 was a single axis. Research says tiering is a **capability
vector**, and the named tiers are presets over it:

| Axis | Values |
|---|---|
| geometry producer | gpu / runtime / none |
| refraction | edge-band full / reduced samples / none |
| blur | Impeller Gaussian / half-res dual-Kawase / none |
| chromatic aberration | 3-tap / off |
| specular | two-lobe / baked gradient / none |
| backdrop captures | shared group / per-layer / none |

Three input signals, not one:

1. **Static capability probe at startup** — `isShaderFilterSupported` for
   Impeller; a 1x1 `IMPELLER_TARGET_OPENGLES` shader probe read back through
   `toImageSync` + `toByteData` for GLES-vs-not; `Platform` for Metal-vs-Vulkan;
   and a timed offscreen GPU probe (run twice — the first pass includes
   pipeline-state creation).
2. **Live thermal channel** — `glass_forge_platform`, wrapping Android
   `PowerManager` thermal status and headroom, and iOS `ProcessInfo.thermalState`
   plus low-power mode.
3. **Rolling frame watchdog** — p90 of `rasterDuration` and `totalSpan` against
   `1000/refreshRate`, plus missed-vsync count. **`rasterDuration` is CPU encode
   time, not GPU time** — GPU cost shows only as backpressure, so this is a
   saturation signal, never a millisecond measurement.

**Accessibility is a tier input, not a separate branch.** Reduce Transparency
pins the static tier; Reduce Motion disables elasticity; Increase Contrast
forces the near-opaque bordered treatment.

### 5.7 Accessibility

Flutter does not expose Reduce Transparency at all — the iOS bitmask builder
never reads `isReduceTransparencyEnabled`, and Android has no equivalent. Every
competing package approximates it via `MediaQuery.highContrast` and documents
the resulting hole.

`glass_forge_platform` provides the real signal over an `EventChannel`. When
the package is absent, the core falls back to the `highContrast` approximation
and **says so** in a debug diagnostic rather than pretending.

Also: `reduceMotion` must be read from `dart:ui`, not `MediaQuery` —
`MediaQueryData.disableAnimations` is documented *not* to be set by iOS Reduce
Motion.

### 5.8 Shader warm-up

Custom `FragmentProgram`s still compile at load on Impeller, and pipeline
**variants** (different blend mode, sample count, attachment format) compile
**synchronously on first draw**. That is the first-frame jank source.

So: `fromAsset` at startup, then draw each shader once offscreen with the
*exact* Paint, blend mode and saveLayer configuration production will use.
This composes with the GPU timing probe in §5.6 — one offscreen pass does both.

---

## 6. Package layout

**One package. `flutter pub add glass_forge` and everything works.**

```
glass_forge/                    pub workspace
  packages/
    glass_forge/                THE package. Rendering, both geometry
                                producers, tier engine, motion, tokens, and
                                the native signals (Swift / Kotlin / macOS).
  apps/
    glass_forge_workbench/      visual workbench
    glass_forge_benchmark/      device benchmark harness
```

An earlier draft split this three ways — core, a Flutter GPU accelerator, and
a native-signals plugin — to keep the build hook and the native code off
consumers who did not want them. That was wrong, for a reason worth recording
so nobody re-proposes it:

**Splitting pushes a tier decision onto the caller.** The whole thesis of this
package is "callers never branch on tier; the package does." A consumer who
skipped the native-signals package would silently receive the
`MediaQuery.highContrast` approximation of Reduce Transparency — the exact
defect this package exists to fix, and the one every competitor documents in
its own README. Shipping that as a *packaging* decision would be
self-inflicted. Cost isolation is not worth a wrong default.

What the single package must therefore guarantee:

- **The Flutter GPU build hook fails soft.** If the shader bundle cannot be
  built — an unsupported toolchain, an experimental API that moved — the hook
  warns and the package still works through the runtime-effect producer. A
  consumer's build must never break because of an optimisation they never
  asked for.
- **`flutter_gpu` is loaded behind a capability check**, not a hard import
  path, so a Flutter release that changes it degrades to the runtime producer
  rather than failing to compile.
- **Native signals degrade explicitly.** Where the platform cannot answer,
  the tier engine falls back to the `highContrast` approximation *and says so*
  in a debug diagnostic, rather than pretending the answer is "off".

---

## 7. Decomposition

Each gets its own spec and its own build cycle.

| # | Sub-project | Delivers | Depends on |
|---|---|---|---|
| **1** | **Renderer core** | Shape model, SDF shaders, both geometry producers, composition, invalidation graph, retained clips | — |
| **2** | **Tier engine** | Capability probe, thermal channel, frame watchdog, accessibility signals, tier presets | 1 (to have something to degrade) |
| 3 | **Motion** | Spring properties, gesture/press/fling, morph and merge, ambient (gyro, scroll, idle) | 1 |
| 4 | **Design system** | Tokens, blur scale, semantic surfaces, presets, theming | 1, 3 |
| 5 | **Benchmark harness** | Device traces, frame timing capture, regression gates | built alongside 1 |
| 6 | **Workbench app** | Test surfaces, visual comparison, tier forcing | continuous |

**Build order: 1 and 5 together, then 2, then 3, then 4.** The harness is not
a deliverable that comes after — tiers cannot be tuned without measurement, and
performance claims made without it are guesses.

---

## 8. Open questions

Carried forward deliberately; none blocks sub-project 1.

1. **Ancestor `Opacity`** breaks glass rendering upstream (#118, #24) and is
   **still unsolved on their rewrite branches** — their attempt is 2,257 lines
   behind an environment flag. We inherit the problem. Needs its own
   investigation.
2. **Whether `impellerc` defines `SKIA_GRAPHICS_BACKEND`** — upstream's web fix
   depends on it and it is unverified. Affects our Skia normal fallback.
3. **The iOS 26 Metal uniform-binding cap** ("~30", single unverified source).
   If real, it constrains the uniform layout and forces `vec4` packing.
4. **Runtime-int indexing into uniform arrays** — reported broken
   (flutter#148577) yet shipped by upstream on Impeller. Must be verified per
   backend before the shape loop depends on it.
5. **Whether Apple renders chromatic aberration at all.** Reviewers see
   fringing; neither runtime teardown lists a dispersion parameter.
6. **Arbitrary shapes** (upstream #35). Upstream's approach costs 441 samples
   per fragment and was dropped in the rewrite. A Bézier-SDF-to-texture approach
   exists in a stale fork. Out of scope for sub-project 1.
