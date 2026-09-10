# Reference: the upstream 0.3.0 rewrite

Captured 2026-09-10 from a full clone of
https://github.com/whynotmake-it/flutter_liquid_glass and its PR/issue history.
Analysed branch tip: `codex/renderer-performance-final` (`ccea41f`, 2026-09-02).

> **Why this file exists.** `PROJECT_BRIEF.md` §5 says "vendor what is stalled,
> depend on what is alive," and classified this package as stalled. That was
> true of the pub.dev release cadence and false of the repo. There is a large,
> unreleased rewrite in flight. Most of its ideas are good and several fix
> defects we independently found in `0.2.0-dev.4`.

## 1. Where the work lives

`main` is stale — last commit 2026-04-24. The last published tag is
`liquid_glass_renderer-v0.2.0-dev.4` (2025-11-13). **No tag or release exists
after dev.4**, but `main` carries 23 unpublished commits past it.

The rewrite is a stack of `codex/*` branches, all rebased onto `main`:

| Branch | Tip | Role |
|---|---|---|
| `codex/liquid-glass-1.0-prerelease` | 2026-09-02 | **PR #157**, "rebuild liquid glass for 0.3.0-dev.1" — open, not draft |
| `codex/liquid-glass-benchmarks` | 09-02 | PR #160, device benchmarks |
| `codex/apple-glass-harness` | 09-02 | PR #165, Apple visual fitting pipeline |
| `codex/apple-glass-references` | 09-02 | PR #167, audited Apple capture corpus |
| `codex/renderer-performance-final` | 09-02 | PR #166, review guide — the stack tip |
| `codex/nested-glass-workbench` | 09-03 | showcase example |
| `codex/glass-opacity-checkpoint` | **09-10** | unfinished opacity-under-ancestor work |
| `codex/renderer-flutter-3.44` | 09-08 | **PR #169**, draft, "DO NOT MERGE" — 3.44 backport |
| `codex/web-flutter-3.44` | — | **PR #154**, draft — the SkSL/web fix (see §5) |

The branch naming and a Cursor agent footer on PR #151 indicate the rewrite is
substantially agent-authored with the maintainer reviewing.

Diffstat `main` -> `codex/renderer-performance-final`: 711 files,
+46,832/−4,850. Most of that is `example/tool/` harness (466 files); the
renderer proper is 17 modified + 8 added + 2 deleted Dart files plus a wholly
new shader set.

**Status: PR #157 has sat open since 2026-08-28 against the author's own main,
with no visible review activity, while the branch continues to move.** Whether
0.3.0 ships is unknown.

## 2. Licensing — three licences, not one

| Scope | Licence |
|---|---|
| `0.2.0-dev.4` and `main` | **MIT**, `Copyright 2025 Tim Lehmann for whynotmake.it` |
| `perf/independent-layer-stack` onward, **all `codex/*` branches** | **Apache-2.0** (switched in `1d73af3`, 2026-08-12; no appended copyright line) |
| `lib/src/internal/multi_shader_builder.dart` (both) | **BSD**, `Copyright 2013 The Flutter Authors` — derived from `flutter_shaders`' `ShaderBuilder` |
| `motor` | MIT, `Copyright (c) 2024 Tim Lehmann for whynotmake.it` |

Shader file headers on both trees read `// Copyright 2025, Tim Lehmann for
whynotmake.it`. `liquid_glass_filter.frag` additionally credits Shadertoy
`wccSDf`, iquilezles.org, and @dkwingsmt for the squircle SDF — see the
licensing caveat in `liquid_glass_renderer_teardown.md`.

**Consequence: lifting an idea from §4 below is an Apache-2.0 + NOTICE
obligation, not MIT.** Ideas and formulas are not copyrightable; the
distinction matters only if code is copied. Our position is to re-derive.

## 3. Architecture: dev.4 vs the rewrite

**dev.4** — geometry fragment shader drawn into a `PictureRecorder`, converted
with `Picture.toImageSync`; layer re-composites all group mattes into a second
**screen-space** image with another `toImageSync`; then **two stacked
`BackdropFilterLayer`s** (blur, then shader). Two backdrop captures, two CPU-side
image conversions, and any ancestor motion forces a full matte rebuild.

**Rewrite** — a **Flutter GPU** render pass draws a full-screen quad into a
`devicePrivate` RGBA8 `gpu.Texture`, exposed via `Texture.asImage()`. Uniforms
are an std140 block reflected at runtime. Shaders compile to a `.shaderbundle`
through a native-assets build hook. Then **one** `BackdropFilterLayer` whose
filter is `ImageFilter.compose(inner: blur, outer: ImageFilter.shader(...))`.
The matte is **layer-local**; ancestor transforms are compositor-only, with a
per-frame affine mapping `FlutterFragCoord` back into matte space.

| | dev.4 | rewrite |
|---|---|---|
| Backdrop captures per layer | 2 | **1** |
| Offscreen image conversions | 2 (`toImageSync`) | 0 (GPU texture) |
| Matte space | screen | **layer-local** |
| Shape encoding | 6 floats, no rotation | 3×vec4 + 3×vec4 RSE params, **exact affine** |
| Blend groups per pass | 1 | **many** (sign-encoded markers) |
| Idle glass | still 2 captures | drops the filter entirely |
| Floor | Flutter 3.29-ish | **3.47 + Dart 3.13 + `flutter_gpu` (beta)** |

Measured, from their own `PERFORMANCE_AUDIT.md`: right-sizing Flutter GPU host
buffers removed ~66 MB and took raster p95 from 12.05 to 6.82 ms in the
16-independent-layer case. 16 shapes in **one** layer: 386 MB / 1.59 ms.
The same 16 as independent layers: 588 MB / 6.57 ms. **Grouping is worth ~4x.**

## 4. Ideas worth taking

Ordered by value to a pipeline that keeps runtime-effect shaders rather than
adopting Flutter GPU.

### 4.1 Global uniform reads + sign-encoded group markers
SDF helpers read `uShapeData` as a global instead of taking it as a parameter —
their in-file comment names the exact SkSL failure. Multiple blend groups plus
standalone shapes share one pass via a sign-encoded marker in `placement.w`:
negative starts a new group, and the magnitude carries the blend. This is what
lets sibling shapes share one backdrop sample **without** blending together;
dev.4 wrapped every standalone shape in a dummy `blend: 0` group.

### 4.2 Rotation- and scale-correct SDFs
Per shape, transform origin and both basis vectors into matte space, invert the
2x2, and store the **minimum singular value** as the distance scale — so local
SDF distances stay a valid lower bound in screen pixels under non-uniform
scale. Their comment explains why the transformed AABB must not be used
("would apply scale a second time"). This fixes the whole class of
`Transform`/`LiquidStretch`-on-grouped-shapes defects.

### 4.3 Bounds culling before the expensive SDF
A Euclidean box distance under the same basis is a valid lower bound; skip the
primitive when `bound >= groupResult.distance + groupBlend`. Plus a whole-pixel
early exit using squared distances and a smoothing budget.
**Measured: 3.60 -> 3.08 ms/frame GPU (dynamic 16 shapes), 3.76 -> 2.88
(sparse 16 in motion)** — 14% to 23%. They also record that an L-infinity bound
culled less and was slower.

### 4.4 Exact Flutter-matching shape SDFs
The rounded-superellipse distance is lifted from Flutter 3.47's own
`impeller/entity/shaders/uber_sdf.frag`, with symmetric scale folded out and a
CPU-side precompute mirroring Flutter's per-geometry setup so the six-step
bisection is not repeated per fragment. The ellipse gets a Newton solve,
replacing dev.4's closed form that "divided by |p| near the center, producing a
zero/direction-dependent pinhole for non-circular ovals."

**Why this matters:** the glass silhouette then matches `ClipRSuperellipse` and
`ClipOval` child clips **exactly**. dev.4 does not — see the squircle/clip
mismatch in the teardown.

### 4.5 Centred half-pixel antialiasing
```glsl
float pixelSize = length(vec2(dFdx(sd), dFdy(sd)));
float fade = clamp(uOpticalProps.y, 0.0, 1.0) * max(pixelSize, 1e-4);
float materialAlpha = 1.0 - smoothstep(-fade, fade, sd);
```
replaces dev.4's fixed inside-only `smoothstep(-2.0, 0.0, sd)`. Requires
reserving half a physical pixel of padding outside the shape in the matte, and
clamping optical depth to `min(sd, 0.0)`.

**Constraint we inherit: `fwidth` is unavailable in runtime effects even on
Impeller** (they measured it). Their final pass therefore uses a fixed 0.75 px
feather. Derivatives are also rejected on web (flutter#180959), so a
web-capable shader cannot use `dFdx` either.

### 4.6 The displacement codec — the fix for 8-bit banding
dev.4 stored RG = displacement around 0.5, B = height, A = alpha. The rewrite
stores:

- **RG** = unit surface normal, asymmetric 0..254 coding so −1, 0 and +1 are all
  exactly representable
- **B** = signed edge distance with a sqrt compander on both sides
- **A** = one-sided displacement *magnitude* with a sqrt compander

```glsl
float linearMagnitude    = clamp(-displacementMagnitude / maxDisplacement, 0.0, 1.0);
float normalizedMagnitude = 1.0 - sqrt(1.0 - linearMagnitude);
// decode
float inverseMagnitude    = 1.0 - encoded.a;
float normalizedMagnitude = 1.0 - inverseMagnitude * inverseMagnitude;
return decodeSurfaceNormal(encoded) * (-normalizedMagnitude * maxDisplacement);
```

Their rationale names the disease precisely: "fewer than two code points per
physical pixel at common thicknesses, which the narrow contour/highlight ramps
exposed as concentric bands." That is the mechanism behind upstream #57 (edge
artifacts at mediump) and #130 (artifacts at high `lightIntensity`).

Pair it with `effectiveDisplacementScale = max(1e-3, 1.05 * edgeRefraction)` so
code points are not spent on unreachable range. dev.4 used
`maxDisplacement = thickness * 10`, which wastes most of the range.

### 4.7 Observable `edgeRefraction` in px, not refractive index
`ratio = edgeRefraction / (8 * thickness); index = sqrt(1 + ratio^2)`.

Their `MODEL_DESIGN.md` explains the reasoning: "Apple does not expose a
physical refractive index. Displacement is SDF-profile-driven with a
per-surface amplitude. Our `refractiveIndex` + `thickness` pair is a physical
re-parameterization of that amplitude." Users think in pixels of edge
distortion, not in IOR.

### 4.8 One composed backdrop filter
`ImageFilter.compose(inner: blur, outer: ImageFilter.shader(...))` — one
capture instead of two. Their audit also documents why a parallel sharp +
blurred branch **cannot** be built with public APIs: `ImageFilter.shader`
receives one sequential input.

### 4.9 Native `ImageFilter` reuse keyed on a uniform snapshot
**The engine copies a shader's uniforms into the native image filter when that
filter is first converted** (`ReusableFragmentShader::as_image_filter`). So a
filter wrapping a shader may only be reused while a snapshot of
`(geometryImage, materialImage, matteBounds, dpr, settingsRevision,
coordinateMapping)` compares equal. dev.4 rebuilt `ImageFilter.shader(...)` on
every paint.

This is also *why* dev.4 could not put ancestor translation into uniforms —
doing so forced a new filter every frame and hit flutter#138627.

### 4.10 Layer-local matte, compositor-only ancestor motion
`matteTransform => Matrix4.identity()`, with the reason: "baking
`getTransformTo(null)` into the matte would apply scale and rotation here and
then a second time during compositing."

Supporting machinery: a 2x2 + offset written into uniforms mapping
`FlutterFragCoord` into matte space; a hook in
`updateSubtreeNeedsAddToScene` that runs after paint and before retained-render
dirtiness propagates; for a pure shared translation, moving the retained
`OffsetLayer` and only re-snapshotting the filter if the coordinate mapping
changed; and reusing the matte outright when every geometry node moved by the
same delta.

Invalidation uses a **monotonic revision counter** instead of deep shape
comparison — measured **735.8 ns vs 5.7 ns per check**.

### 4.11 `RetainedGlassClip` — the answer to the scroll bugs
Walks each shape's ancestors up to the layer, collects `RenderClipRect/RRect/
RSuperellipse/Oval/Path` and `RenderViewportBase`, keeps the common prefix, and
re-pushes them as native clip engine layers wrapped in forward/inverse
transforms **outside** the moving `OffsetLayer`. The header comment states the
principle: *"scrolling moves material through a viewport, not the viewport
through the material."*

This is the structural fix for upstream #124, #136, #101, #68, #33 — and for
the reason `liquid_glass_widgets` documents that its premium tier "may not
render correctly inside ListView on Impeller."

### 4.12 Immutable matte generations
Every geometry change allocates a **new** texture; the renderer releases only
its own handle, and previously submitted scenes keep theirs. Without this,
expanding one grouped pill "changed 1,760 and 3,870 stationary-button pixels"
because the shared matte was overwritten while an older frame still sampled it.

Cost is explicit and they state it: median footprint 435 -> 458 MiB.
**Rule to keep regardless of pipeline: never mutate a texture the compositor
may still be reading.**

### 4.13 Pixel bucketing and tie-stable snapping
Backdrop-filter clip bounds are expanded to 64 px buckets, because "backdrop
image filters allocate an offscreen Impeller render target for their clip
bounds; small animated transform changes otherwise produce a differently sized
target on nearly every frame." Textures bucket the same way.
`snapToPixel` uses `floor(x*dpr + 0.5)` so a matte crossing the origin does not
change size by a pixel. Adaptive 16/32/64 buckets and 32 px filter buckets were
tried and rejected.

### 4.14 Shadow pass with material cutout
One `saveLayer`, draw each `BoxShadow` with `BlurStyle.normal`, then `dstOut`
every shape deflated by 0.5 px so offset shadows do not bleed through
translucent glass. Painted **before** the backdrop filter so Gaussian support
does not expand the shader clip. Bounds reserve
`convertRadiusToSigma(r) * 3` because "reserving only the radius clips the
low-energy tail." Uses `drawRSuperellipse`/`drawOval`/`drawRRect` rather than
`drawPath`.

### 4.15 Per-shape appearance without a second capture
A 1/8-resolution "material contributor" texture tracks the two nearest
primitives and a blend width through the smooth union; the final pass samples
contributor ids nearest-neighbour and the weight bilinearly, then reads tint
and response rows appended to the same texture. Three shader variants selected
by `#define` so uniform layers compile the work out entirely.
**Measured cost: noise-level at 4 and 16 shapes.** This is upstream #117.

### 4.16 Fitted iOS-27 colour model
Derived by their harness from real `.buttonStyle(.glass)` captures on an iOS 27
simulator — numbers that would otherwise cost weeks of eyeballing:

```
neutral light : vec4(253, 252, 253)/255, a = 0.407
neutral dark  : vec4(57.14/255),         a = 0.56
lightScale    = 0.7606 + 0.2394 * L^0.9067
tintTone      = lightScale * tint^(1 + 0.0704*(1 - L))
```
Rec.709 luma, chosen because it "shows lower blue/cyan transfer error" in their
colour-card fit. Fitted presets: `ios27ToolbarLight` saturation .9, gamma .9,
vibrancy .15; `ios27ToolbarDark` 2.6, .58, .1. Fitted geometry:
`thickness 12, edgeRefraction 27.42`.

### 4.17 Lighting rewrite
Paired source/return highlights from `abs(dot(normal, -light))` with a wrap
envelope; contour from the same SDF composited *under* the highlights so
specular eclipses the dark edge; bevel shadow with a smoothstep-wrapped facing
to avoid a half-plane seam, and a `pow(luminance, 0.25)` response so it
"remains exactly zero for a truly black surface" — the fix for upstream #112.

**Highlight colour is incident white, not backdrop-derived.** dev.4 derived it
from the refracted backdrop, which is why it produced the cyan/green fringes in
upstream #135.

### 4.18 GLES-safe sampling, precision, CA threshold
`mirrorBackgroundUV` mirrors only displaced samples that leave the texture, to
avoid GLES decal-black without clamping on Metal. `precision highp float` in
the final pass, because "mediump turns the coordinate subtraction into visible
shimmer on large layers" — matching upstream #57. The chromatic-aberration
branch is skipped when `abs(CA) * maxDisplacement <= 0.25` **px**, rather than
dev.4's unit-free `CA < 0.01` which its own default fails.

### 4.19 FakeGlass consolidation
One `BackdropFilterLayer` (blur composed with a colour matrix) clipped to the
union path for all fake shapes, then one analytic surface draw per shape using
the same contour/bevel/highlight contract as real glass, then children — same
z-order as real glass. Tint, saturation and a secant approximation of
`pow(x, gamma)` fold into a single 4x5 colour matrix.

**Pixel 10 toolbar: raster p95 20.8% *faster* than real glass.** For context,
the *old* FakeGlass was 185% **slower** than real glass at raster p95.

### 4.20 Documented dead ends — free negative results
- Mixed clear/blur two-layer approximation: **rejected**, 16 shapes at raster
  p95 +179% on macOS, total p95 +123% on Pixel 10, +328 MB.
- 13-tap one-pass frost: "produced repeated source-image ghosts."
- `BackdropKey` auto-assignment: rejected.
- Tight viewport scissor: failed 7 goldens.
- Coordinate-texture ring on Android: did not fix pacing.
- Translation-only shader permutation, mutable coordinate texture with a stable
  filter (+~150 MB), identity-transfer branch, L-infinity bound, sparse
  partitioning: all measured and removed.

### 4.21 Widget ergonomics
`LiquidGlass.auto` joins an existing layer unless a `LiquidGlass` ancestor sits
between; nested glass gets its own layer inheriting scope settings and never
the outer `backdropKey`; blend groups are scoped to their render link so a
nested layer's shapes cannot register in an outer group; a debug-only warning
fires for compatible non-overlapping sibling layers that could share one
capture. Flutter GPU is initialised in a post-frame callback because "Android's
Impeller context is not available until its first surface frame."

### 4.22 The intended production architecture
Their `nested-glass-workbench` example wraps the **entire app in one
`LiquidGlassLayer`**, with every control (`GlassButton`, `GlassSlider`,
`GlassSwitch`, `GlassSegmentedControl`) a `LiquidGlass.grouped` shape:
*"every control below is carved from the single shared LiquidGlassLayer around
the whole app, so the entire page costs one backdrop sample."*

This is the opposite of how nearly every bug reporter uses the package
(`withOwnLayer` per widget). Directly relevant to KiBU's 63 blur sites: the fix
is architectural, not per-widget.

## 5. The SkSL fix, precisely

Our brief estimated "roughly ten lines." That is wrong. The real fix lives on
`codex/web-flutter-3.44` (draft PR #154) and needs **five** distinct changes:

1. `#define MAX_SHAPES 16` before the `#include`, and the include moved **after**
   the `uniform float uShapeData[MAX_SHAPES*6]` declaration so helpers see the
   global.
2. **SkSL requires uniform-array indices to be compile-time constants.** So
   `getShapeSDFFromArray(int index, vec2 p)` is implemented as a
   `RETURN_SHAPE_SDF(I)` macro expanded for 0..15.
3. `sceneSDF(vec2 p)` reads `uNumShapes`/`uBlend` as globals; the dynamic loop
   becomes `for (int i = 1; i < MAX_SHAPES; i++) { if (i >= numShapes) break; ... }`
   — constant bounds with an early exit.
4. Normals use central finite differences of `sceneSDF` under
   `#ifdef SKIA_GRAPHICS_BACKEND` (1 px epsilon), `dFdx`/`dFdy` otherwise.
   **Unverified: whether impellerc actually defines `SKIA_GRAPHICS_BACKEND`
   for the SkSL target.** Their PR body claims `flutter build web --debug`
   succeeded on 3.44.6.
5. **SkSL rejects `sampler2D` function parameters** — replaced by a
   `#define BACKGROUND_TEXTURE` set by the includer.

Ignore `tim-lehmann/web-shader-compat`, which instead sets `dx = dy = 0.0` — a
degraded hack.

Note that even with this fixed, **real glass still requires
`ImageFilter.shader`, which is Impeller-only.** Skia/web gets the fake path.

## 6. What the rewrite drops or regresses

- **Glassify / arbitrary shapes / text** removed entirely.
- `liquid_glass_filter.frag` single-pass path removed.
- **Settings removed**: `lightAngle` (hard-coded top light), `ambientStrength`
  (forced 0), `refractiveIndex`, `glassColor`, `blur`, `lightIntensity`,
  `visibility` (moved to appearance/visibility objects).
- **Platform floor rises** to Flutter 3.47 / Dart 3.13 plus `flutter_gpu`
  (beta), `flutter_gpu_shaders`, and a `hooks` native-assets build hook.
- **First-frame pop**: real glass cannot render until the async Flutter GPU load
  completes, so the layer builds FakeGlass first and then `setState`s. Not
  documented as a limitation.
- **Memory rises** from immutable matte generations: 435 -> 458 MiB median,
  peaking to 562 MiB in a resize animation; their own memory-slope gate failed.
- **Web/Skia still unsupported** for real glass.
- **Ancestor `Opacity` (#118/#24) still unsolved** — `codex/glass-opacity-checkpoint`
  is 2,257 lines of experiment behind an environment flag, not production.
- FakeGlass in a blend group does not union. `BoxShadow.blurStyle` ignored.
- 16-shape cap retained.
- `curvatureLighting` is declared in settings with **no shader consumer** found
  on the analysed branch — apparently vestigial.

## 7. Repo health

440 stars, 80 forks, created 2025-06-13, last push 2026-09-10. No GitHub
releases, tags only. Sole substantive author: Tim Lehmann (294 commits); three
other humans with one commit each.

**Responsiveness, computed over 55 issues opened by others:**

| Period | Opened | Got a maintainer reply |
|---|---|---|
| 2025 | 43 | 35 |
| **2026** | **12** | **0** |

Median time to first reply (2025): 0.8 days; p75 3.3 d; p90 25.6 d.
External PRs #152, #143, #141, #133 are unmerged; nothing external merged since
2025. No `CONTRIBUTING.md`. Golden tests run only on `main` or on PRs labelled
`goldens`, on macOS runners.

Read this as: the author is active on his own agent-driven rewrite and not on
inbound triage. A PR from us would queue behind a five-PR breaking rewrite that
changes every file we would touch.

## 8. Forks with real divergence

- **`vespr-wallet/flutter_liquid_glass_plus`** — 31 commits ahead, published to
  pub.dev as `liquid_glass_plus` 0.3.2. Removed Glassify, `LiquidGlassFilter`,
  and **`LiquidGlassBlendGroup`** (per-shape geometry instead); added per-shape
  `frosted`, FakeGlass with fake refraction, `LiquidTransform`, presets, and its
  own SkSL/web fix. Their blend-group removal is a design choice we would not
  copy, but the SkSL commit and FakeGlass-refraction approach are worth reading.
- **`sdegenaar`** — 4 ahead; the widget set that became `liquid_glass_widgets`.
- **`KevinVan720`** — arbitrary-shape SDF from quadratic Béziers packed into a
  texture. Stale since 2025-07, but the technique is interesting for the
  arbitrary-shape gap.
- **`DDefiebre`** — the zero-size / non-finite guard for #149 and #131.

## 9. Not established

- Whether PR #157 will merge or 0.3.0 will ship.
- Whether impellerc defines `SKIA_GRAPHICS_BACKEND` (the web fix depends on it).
- The rewrite's behaviour on real Skia web beyond FakeGlass — never built.
- Whether `curvatureLighting` is wired on a later branch.
