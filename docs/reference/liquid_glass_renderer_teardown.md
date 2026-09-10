# Reference: liquid_glass_renderer 0.2.0-dev.4 teardown

Rewritten 2026-09-10 from a full source read of
`~/.pub-cache/hosted/pub.dev/liquid_glass_renderer-0.2.0-dev.4`.
Upstream: https://github.com/whynotmake-it/flutter_liquid_glass
License: MIT, Copyright 2025 Tim Lehmann for whynotmake.it

> **Supersedes the 2026-08-28 version of this file**, which described a
> single-pass `uShapeData` architecture. That has not been the shipping design
> since 0.1.1-dev.22. The correction is in §2 and it matters: it changes which
> parts are worth vendoring.

## Provenance

| Fact | Value |
|---|---|
| Latest published | `0.2.0-dev.4`, 2025-11-13 |
| Versions | 31, every one a prerelease |
| Stable release | never |
| pub.dev | 886 likes, 150/160 points, 25,239 downloads/30d |
| Declared platforms | iOS, Android, macOS |
| GitHub | 440 stars, 80 forks, **pushed 2026-09-10** |
| Open issues | 34 |

**The repo is not stalled — it is mid-rewrite.** `main` last took substantive
commits 2026-04-24; since then work has moved to a stack of `codex/*` branches.
See `upstream_rewrite.md` for the rewrite analysis. The "vendor what is
stalled" rule in `PROJECT_BRIEF.md` §5 was written against the pub.dev release
cadence and does not describe the repo.

## Licensing caveat — read before copying any shader

`liquid_glass_filter.frag` carries a header crediting **Shadertoy `wccSDf`**
for the refraction math, and iquilezles.org for the SDFs. Shadertoy's default
licence is **CC BY-NC-SA 3.0** — non-commercial and share-alike, which is not
MIT-compatible. The MIT licence on the package does not launder an upstream
CC BY-NC-SA dependency.

The per-shader licence of `wccSDf` could not be confirmed (Shadertoy blocks
automated fetches), so treat the exact terms as unverified — but the risk is
real enough to design around.

**Consequence for glass_forge: shader math is re-derived from published
formulas, not copied.** Every formula we need (iq's `sdRoundedBox`, quadratic
smooth-min, sphere-cap height, `refract` + exit distance, 3-tap chromatic
aberration, dual-Kawase kernels, Rákos tap-merging, hemisphere lighting) is
available formula-level or from MIT/Apache/CC0 sources. See
`shader_techniques.md` for the citation list.

## 1. Public API surface

Exports: `LiquidGlass` (+ `.grouped`, `.withOwnLayer`), `LiquidGlassLayer`,
`LiquidGlassBlendGroup`, `FakeGlass`, `GlassGlow`, `GlassGlowLayer`,
`LiquidStretch`, `RawLiquidStretch`, `OffsetResistanceExtension`,
`LiquidGlassSettings`, the `LiquidShape` sealed family, `LgrLogs`.
`lib/experimental.dart` exports `Glassify` only.

`LiquidGlassFilter`, `MultiShaderBuilder`, `ShaderKeys`, `GlassGroupLink`,
`GeometryRenderLink` are unexported. `LiquidGlassFilter` is unreachable dead
code — its `paintLiquidGlass` body is commented out.

### `LiquidGlassSettings` — ten fields, several mis-documented

| Field | Default | Where it lands | Note |
|---|---|---|---|
| `visibility` | 1.0 | not a uniform; scales the other `effective*` getters + an `Opacity` on the child | animating it forces a geometry rebuild every frame |
| `glassColor` | `ARGB(0,255,255,255)` | `uGlassColor` (final pass) | |
| `thickness` | 20 | `uOpticalProps.z` (both passes) | **not DPR-scaled** — see §5 |
| `blur` | 5 | not a uniform; `ImageFilter.blur` sigma | doc says "Defaults to 0" — **wrong** |
| `chromaticAberration` | .01 | `uOpticalProps.y` (final) | uploaded to the geometry pass too, where it is never read |
| `lightAngle` | π/2 | pre-resolved to `uLightDirection = (cos, sin)` | |
| `lightIntensity` | .5 | `uLightConfig.x` | |
| `ambientStrength` | 0 | `uLightConfig.y` | |
| `refractiveIndex` | 1.2 | `uOpticalProps.x` (geometry) | `uRefractiveIndex` in the final pass is **never read**; doc says "Defaults to 1.51" — **wrong** |
| `saturation` | 1.5 | `uLightConfig.z` | doc says "Defaults to 1.0" — **wrong** |

`copyWith` declares a `blend` parameter that is **never used** — a leftover
from when blend lived in settings. The package's own golden test
(`liquid_glass_test.dart`) calls `copyWith(blend: …)` for four values, so all
four "merging_blend_values" goldens render the same default of 20. **The test
suite is not testing what its name claims.**

README documents `outlineIntensity`, which was removed in 0.1.1-dev.5. The
README sample does not compile. (Upstream issues #129, #130.)

## 2. The actual render pipeline — two passes, not one

```
Pass 0  shape registration (CPU)
        RenderLiquidGlass.attach -> GlassGroupLink.registerShape
        -> notifyListeners -> markGeometryNeedsUpdate

Pass 1  geometry matte, per blend group          [offscreen, Paint.shader]
        liquid_glass_geometry_blended.frag
        sceneSDF -> normal via dFdx/dFdy -> hemisphere height
        -> refract() -> encode (dispX, dispY, height/thickness, alpha)
        into RGBA8 via displacement_encoding.glsl

Pass 2  composite all group mattes, per layer     [offscreen, toImageSync]
        drawn in SCREEN space, at physical resolution

Pass 3  blur backdrop                             [BackdropFilterLayer]
        ImageFilter.blur(TileMode.mirror, sigma = effectiveBlur)
        inside context.pushClipPath(union of shape outer paths)

Pass 4  glass shader backdrop                     [BackdropFilterLayer]
        ImageFilter.shader(liquid_glass_final_render.frag)
        sampler 0 = engine-supplied backdrop, sampler 1 = composite matte
        inside context.pushClipRect
```

The backdrop-capture primitive is **`BackdropFilterLayer`, twice per layer**.
No `saveLayer`, no `ImageFiltered`. `ImageFilter.isShaderFilterSupported` gates
the whole thing, with a `FakeGlass` fallback on Skia.

`BackdropKey` is set **only on the blur layer**, and only when the caller
passes `useBackdropGroup: true`. The shader readback is never deduplicated.

### The deferred-child-painting trick, and why it costs so much

`RenderLiquidGlass.paint` is a no-op guarded by
`// ignore: must_call_super`. Children are painted later, from the layer, via
`paintFromLayer` -> `pushTransform(getTransformTo(layer), super.paint)`.

This one decision is the root cause of:

- children invisible until **both** shaders finish loading (first-use flash)
- children always drawn at the layer's z-position — anything between the layer
  and the shape in a `Stack` renders *under* the glass
- a `LiquidGlass` painted by anything other than its layer (Hero flight,
  `RenderRepaintBoundary.toImage`) draws **nothing**
- one-frame refraction lag on paint-only transforms (see below)

**Frame-N lag.** Transform changes are detected in
`GeometryTransformTrackingLayer.addToScene` — i.e. during compositing of frame
N — which calls `markNeedsPaint`, so frame N+1 rebuilds. Layout-driven moves
are same-frame; paint-only transforms (`Transform`, `AnimatedScale`,
`LiquidStretch`) refract **one frame behind** their own child content.

## 3. Batching

- `GlassGroupLink._shapes` is a `Map<RenderLiquidGlass, (LiquidShape, bool)>`;
  `shapeEntries` allocates a fresh list on every call, and is called 2× in
  `gatherShapeData` and 2× per paint.
- Packing: `uNumShapes`, then 6 floats per shape —
  `type, cx*dpr, cy*dpr, w*dpr, h*dpr, r*dpr`.
- `MAX_SHAPES 16`. The source comment explains it: *"Reduced from 64 to 16
  shapes to fit Impeller's uniform buffer limit (16*6=96 floats vs 384)."*
- **Overflow throws from inside `paint()`** — `UnsupportedError`. Red error box
  in debug; in release, `FlutterError.reportError` and the entire layer plus
  all its children stop painting. Not an assert, not a silent drop.
- `uBlend` folds shapes with iq's quadratic smooth-min,
  `min(d1,d2) - e^2*0.25/k` where `e = max(k-|d1-d2|, 0)`. Unrolled for <=4
  shapes, dynamic loop for 5..16. Group bounds inflate by `blend * .25`, which
  is the correct max bulge of that smin.

**Blend/blur mismatch.** The blur clip path is the union of each shape's
individual `getOuterPath` — *not* the blended SDF. So the smooth-union "neck"
between merging shapes is refracted but never blurred. This is the README's
"blur introduces artifacts when blending shapes."

## 4. Shapes

`RawShapeType`: `squircle(1)`, `ellipse(2)`, `roundedRectangle(3)`, `none(0)`.

- **`sdfSquircle` is not a superellipse.** It is term-for-term identical to
  `sdfRRect` (`sqrt(maxQ.x^2+maxQ.y^2)` is just `length(max(q,0))`). But the
  *clip* for that shape uses a real `RoundedSuperellipseBorder`. So on every
  `LiquidRoundedSuperellipse` the refraction dome and the child clip disagree
  at the corners.
- `sdfEllipse` is the cheap `k1(k1-1)/k2` approximation, not a true distance.
  Its gradient magnitude is not 1, so height and the derivative-based normal
  are distorted for non-circular ovals, and smooth-min blends ellipses at a
  different apparent distance than rects.
- Corner radius clamps to half the shorter side, so a huge radius yields a
  capsule. Uniform radii only — no per-corner radii.
- `side` is accepted by every shape and **never reaches the shader**.

`liquid_glass_arbitrary.frag` (`Glassify`, experimental) is a different
pipeline: no SDF, no shape list. It rasterises the child twice through a
*separate* `SceneBuilder`, reconstructs a pseudo-SDF from blurred alpha, and
derives a "normal" from the direction to a local centre of mass using a
**21x21 = 441-sample loop per fragment**. Only the child's alpha is used.

## 5. Defects worth knowing before forking

### Correctness
1. **Rotation and non-uniform scale refract in the wrong direction.**
   Displacement is encoded in group-local axes and applied in screen axes with
   no basis change.
2. `sdfSquircle` / clip mismatch (§4).
3. **Derivatives after a non-uniform early return.** `dFdx`/`dFdy` are called
   after a `foregroundAlpha < 0.01` early-out, so quads straddling the boundary
   get undefined derivatives — garbage normals in the outermost AA band, which
   is exactly where they are most visible. Likely the cause of upstream #85
   (jagged corners on Pixel 3/4).
4. **Stale blur clip on shape change** — `_lastPath` is only recomputed in
   `performLayout`, so animating `borderRadius` updates refraction while the
   blur clip keeps the old outline.
5. **Stale composite after group removal** — `unregisterGeometry` does not set
   the dirty flag, though `registerGeometry` does.
6. `copyWith(blend:)` no-op (§1), and the goldens that depend on it.
7. **`ShaderKeys.lighting` points at a shader file that does not exist**, and
   the test config precaches it — so every test run reports a
   `FragmentProgram.fromAsset` failure.
8. `RawFakeGlass.updateRenderObject` assigns `_backdropKey` directly, bypassing
   the setter, so a key change never marks needs-paint.

### Precision
1. **`thickness` is the only geometric uniform not multiplied by DPR.** The
   refraction rim is `thickness` *physical* pixels, so a 3x phone renders a rim
   one third the intended width. All goldens are macOS-only at 1x, so the test
   suite structurally cannot catch this.
2. **8-bit displacement encoding** over +/-10x thickness. Quantisation step is
   `20*thickness/255` ~= 0.078*thickness px — about 1.6 physical px at the
   default thickness of 20. Banding is baked into the format.
3. **`precision mediump float`** in all four `.frag` files, while `fragCoord`
   and `uShapeData` carry physical pixel coordinates in the thousands. Half
   precision loses sub-pixel accuracy above 2048. (Upstream issue #57.)
4. **The default `chromaticAberration = 0.01` fails the `< 0.01` fast path** —
   so a default install pays 3 backdrop samples per fragment for a 0.5% effect.
   `render.glsl` uses `0.001` for the same test; the thresholds disagree.
5. Inline lighting magic numbers throughout the final pass; AA width hardcoded
   in physical px; `baseHeight = thickness*8`.

### Per-frame cost
- **2 backdrop readbacks per layer per frame**, every frame the engine
  produces, whether or not anything changed. `blur: 0` still pushes a full
  backdrop pass.
- `alwaysNeedsAddToScene = true` on the tracking mixin **defeats retained
  rendering** for the entire layer subtree.
- Three `GeometryTransformTrackingLayer`s per single glass (layer, group,
  shape), each doing an O(depth) `getTransformTo(null)` plus a `Matrix4`
  allocation in `addToScene` every frame.
- The `layout()` override sets `needsGeometryUpdate = true` on **every**
  `layout()` call, before `super.layout`'s constraints short-circuit. Glass
  inside any scrollable therefore re-runs `toImageSync` every scroll frame even
  when nothing moved relative to it.
- The "skip rebuild" path still marks the render link dirty, so any
  `notifyListeners` on a group triggers a composite `toImageSync`.
- Per paint: new `Path` per shape, new `ImageFilter.blur`, new
  `ImageFilter.shader`, uniform upload and `setImageSampler` regardless of
  change, eager string interpolation for log calls, and a `StringBuffer` built
  per geometry rebuild regardless of log level.
- Skia fallback logs a warning on **every build**.

### Leaks
- `flutter_shaders` 0.1.3's `ShaderBuilder` has **no `dispose()`** and creates a
  fresh `FragmentShader` per state. Because an ungrouped `LiquidGlass`
  silently auto-creates its own group, **every plain glass widget leaks a
  `FragmentShader` on unmount.**
- `RenderLiquidGlassBlendGroup` adds a link listener in its constructor and
  never removes it in `dispose`.
- `Glassify` never disposes the `Scene`s from its foreign `SceneBuilder` — two
  leaked `Scene`s per capture — and bypasses retained rendering, so it
  re-captures (2x `toImageSync`) on every scene build.

### Scaling
| Axis | Cost |
|---|---|
| Layer bounding box | RGBA8 composite at DPR^2. A bar at top and bottom of a 1179x2556 screen in one layer is a ~12 MB composite per rebuild. |
| Layers | linear — 2 backdrop passes + 1 composite + 1 `FragmentShader` each |
| Shapes per group | `sceneSDF` is O(N) per fragment over the group's inflated bounds |
| Tree depth | 3 `getTransformTo(null)` per glass per frame |

`toImageSync` textures cannot be released immediately (flutter/flutter#138627),
so animation means transient texture churn.

## 6. What to vendor, what to rewrite

### Vendor the ideas, re-derive the code
- **The displacement-matte concept.** Baking SDF/normal/height into a texture
  so *static* glass costs one texture sample is the right architecture. Keep
  it; replace the RGBA8 quantisation with 16-bit displacement split across two
  channels, or store normal+height and refract at sample time.
- Core SDF math — rounded-rect distance, quadratic smooth-min with `k/4` bounds
  inflation, normal derivation. Small, standard, iq-derived. **Re-derive from
  iquilezles.org, do not copy the file** (see the licensing caveat above).
- `applySaturation` / `applyGlassColor` — trivial colour ops.
- The two-`BackdropFilterLayer` composition as a *reference* for layering blur,
  shader and `glassContainsChild` correctly. The `pushClipPath` / `pushClipRect`
  split is the right shape. Fix the blur clip to follow the blended outline.

### Vendor nearly as-is
- `stretch.dart` in full — the volume-preserving scale math and `withResistance`
  are self-contained, defect-free, and directly serve gesture-reactive motion.
- `glass_glow.dart` — self-contained.
- `fake_glass.dart`'s saturation matrix and gradient-stroke specular
  approximation — a good cheap tier, already written. Fix the setter bypass.
- `snap_rect_to_pixels.dart` — 20 correct lines.

### Rewrite
- **The entire invalidation and caching layer** (`GeometryRenderLink`,
  `GlassGroupLink`, `maybeRebuildGeometry`, `_buildGeometryImage`, the
  three-way transform-tracking mixin). It carries the rebuild-on-any-layout
  bug, the dirty-on-skip bug, the one-frame lag, the missing unregister dirty
  flag, the screen-space composite that must be re-rasterised on any layer
  move, and the stale path. Keeping the composite in **layer space** and
  updating only a uniform offset on translation removes most of the churn.
- **The deferred child painting.** Paint children in place; let the layer own
  only the backdrop passes.
- The lighting shader — one parameterised implementation instead of three
  divergent copies with inline magic numbers.
- `Glassify` / the arbitrary-shape path — 441 samples per fragment for a
  quantity that is not a normal.
- Replace `flutter_shaders`' `ShaderBuilder` with an owned loader that disposes
  its shaders and exposes precache.

### Delete
`liquid_glass_filter.frag` (compiled into every app, referenced by nothing),
`shared.glsl` (~230 of 257 lines duplicate `render.glsl`),
`liquid_glass_filter.dart`, `multi_shader_builder.dart`,
`TransformTrackingRepaintBoundaryMixin`, `ShaderKeys.lighting`,
`ShaderKeys.legacyLiquidGlass`, `desiredMatteSize`, `copyWith(blend:)`.
