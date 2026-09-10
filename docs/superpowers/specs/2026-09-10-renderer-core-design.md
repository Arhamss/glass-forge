# Sub-project 1 — renderer core

Date: 2026-09-10
Status: **awaiting review**
Parent: `2026-09-10-glass-forge-architecture-design.md`

Delivers the thing everything else sits on: a shape/SDF model, two geometry
producers, a single-capture composition, and an invalidation graph that does
not re-rasterise the world on every scroll frame.

**Out of scope**: tier *selection* (sub-project 2 — this exposes the knobs and
a manual override), motion, tokens, semantic widgets.

---

## 1. Goals and non-goals

**Goals**

1. Render Apple-faithful edge-band glass — one or many shapes, blended — with
   **one backdrop capture per layer**.
2. Be correct under rotation, non-uniform scale, and scrolling. Upstream is
   correct under none of these.
3. Cost approximately nothing when nothing changed.
4. Compile as valid SkSL even though the shader only runs on Impeller, so the
   Skia/web fallback path stays open.
5. Expose the geometry producer as a swappable strategy so the GPU path is
   opt-in and tier-selectable.

**Non-goals**

- Arbitrary shapes. Three primitives only.
- Solving ancestor `Opacity`. Documented as a known limitation (open question 1).
- Automatic tier selection.

---

## 2. Public API

Deliberately small. Everything else is internal.

```dart
// --- the layer: one backdrop capture, one SDF scene -----------------------
class GlassLayer extends StatefulWidget {
  const GlassLayer({
    required this.child,
    this.material = const GlassMaterial(),
    this.strategy,             // null => registry picks; sub-project 2 automates
    this.backdropKey,          // participate in an ancestor BackdropGroup
  });
}

// --- a shape in the nearest layer ----------------------------------------
class Glass extends StatelessWidget {
  const Glass({
    required this.shape,
    this.child,
    this.material,             // per-shape override; null => layer material
    this.blendGroup,           // null => ungrouped (shares the capture, no blend)
    this.containsChild = false,
    this.clipBehavior = Clip.antiAlias,
  });
}

// --- grouping: shapes inside merge via smooth-min ------------------------
class GlassBlendGroup extends StatelessWidget {
  const GlassBlendGroup({required this.child, this.blend = 20.0});
}

// --- shapes ---------------------------------------------------------------
sealed class GlassShape { }
class GlassRoundedRectangle extends GlassShape { final BorderRadiusGeometry radius; }
class GlassOval            extends GlassShape { }
class GlassSuperellipse    extends GlassShape { final BorderRadiusGeometry radius; }

// --- the material ---------------------------------------------------------
class GlassMaterial {
  const GlassMaterial({
    this.variant        = GlassVariant.regular,   // regular | clear
    this.thickness      = 12.0,                   // logical px
    this.edgeRefraction = 27.42,                  // logical px of edge displacement
    this.refractionSpread = 0.0,                  // 0 = edge band, 1 = reach half-minor
    this.frost          = 5.0,                    // blur sigma, logical px
    this.chromaticAberration = 0.0,
    this.tint           = const Color(0x00FFFFFF),
    this.saturation     = 1.0,
    this.highlight      = 1.0,
    this.highlightAngle,                          // null => top light
    this.contour        = 0.0,
    this.bevelShadow    = 0.0,
  });

  // Apple-fitted presets (see apple_liquid_glass_spec.md)
  factory GlassMaterial.regular({Brightness brightness});
  factory GlassMaterial.clear({Brightness brightness});
}

enum GlassVariant { regular, clear }
```

Defaults for `thickness` and `edgeRefraction` are upstream's harness-fitted
values from real iOS 27 captures, not eyeballed.

**Note on `Glass` without a `GlassLayer`.** Upstream asserts in debug and
null-crashes in release. We instead create an implicit single-shape layer and
emit a debug diagnostic explaining the cost. Silently working badly is worse
than working, but crashing in release is worse than both.

**Note on group overflow.** Upstream throws `UnsupportedError` from inside
`paint()`, which in release means the layer and all its children stop painting.
We instead split into an additional pass and emit a debug diagnostic. Shape
count degrades performance; it must never blank the UI.

---

## 3. Internal structure

```
packages/glass_forge/lib/src/
  shapes/
    glass_shape.dart              sealed shape family
    shape_geometry.dart           resolved shape: basis, inverse, distanceScale,
                                  corner params, group marker
    superellipse_params.dart      Flutter uber_sdf precompute mirror
  scene/
    glass_scene.dart              registered shapes in layer-local space
    scene_revision.dart           monotonic revision counter
    blend_group_link.dart         group membership, scoped to its layer
  geometry/
    geometry_producer.dart        the strategy interface
    matte_generation.dart         immutable texture + bounds + revision
    matte_codec.dart              encode/decode contract
    runtime_geometry_producer.dart    Paint.shader + toImageSync
    gpu_geometry_producer.dart        Flutter GPU, behind a capability check
    null_geometry_producer.dart       cheap tiers: no matte
    producer_registry.dart        availability probing + tier-driven selection
  composition/
    glass_composition.dart        the single BackdropFilterLayer
    filter_snapshot.dart          uniform snapshot for native filter reuse
    retained_clip_chain.dart      ancestor clips outside the offset layer
    pixel_buckets.dart            64px bucketing, tie-stable snapping
  rendering/
    render_glass_layer.dart
    render_glass_shape.dart
    transform_tracking.dart
  shaders/
    shader_library.dart           owned loader: dispose + precache + warm-up
  material/
    glass_material.dart
    apple_presets.dart            fitted iOS 27 constants

packages/glass_forge/shaders/
  common/sdf.glsl                 shape distances, smooth-min, culling bounds
  common/codec.glsl               matte encode/decode
  common/profile.glsl             edge-band height + displacement
  geometry.frag                   runtime-effect geometry pass
  final_render.frag               composition pass
  probe.frag                      1x1 backend probe (sub-project 2 uses it)
```

---

## 4. The geometry producer interface

```dart
abstract interface class GeometryProducer {
  GeometryCapabilities get capabilities;
  Future<void> warmUp();
  MatteGeneration? produce(GlassScene scene, MatteRequest request);
  void release(MatteGeneration generation);
  void dispose();
}

class MatteGeneration {
  final ui.Image texture;        // or gpu.Texture.asImage()
  final Rect bounds;             // LAYER-LOCAL, not screen
  final int sceneRevision;
  final MatteCodec codec;
  // Immutable. Never overwritten. Released only by its own producer,
  // and only once no submitted scene can still reference it.
}
```

**Invariant 2 in practice:** `produce` always returns a *new* generation. The
producer keeps a small free-list keyed on bucketed size, and a generation
returns to the list only after the frame that last referenced it has been
submitted and replaced.

`RuntimeGeometryProducer` draws one `drawRect` with `Paint()..shader` into a
`PictureRecorder` and converts with `toImageSync`. It must guard
`!bounds.isFinite || width <= 0 || height <= 0` — the missing guard is upstream
issues #149 and #131, both crash reports.

`GpuGeometryProducer` renders a full-screen quad into a `devicePrivate`
texture and exposes it via `Texture.asImage()`. It ships in the same package
but is guarded: `capabilities.available` is false when Flutter GPU cannot
initialise, when the shader bundle did not build, or when the backend is Skia.
The registry then falls through to the runtime producer. A consumer never has
to know either exists.

---

## 5. Shaders

### 5.1 Geometry pass

Inputs: shape array, group markers, optical parameters, matte size.
Output: encoded matte per §5.5 of the parent design.

```glsl
// SkSL-legal by construction:
//   - uShapeData declared BEFORE the include; helpers read it as a global
//   - constant array indices via a macro expanded 0..MAX_SHAPES-1
//   - constant loop bounds with an early break
//   - no sampler2D function parameters
#define MAX_SHAPES 16
uniform vec4 uShapeData[MAX_SHAPES * 3];   // basis, inverse, corner+marker
#include "common/sdf.glsl"
```

Per fragment:
1. **Bounds cull** — a Euclidean box distance under the shape's own basis is a
   valid lower bound; skip when `bound >= best + blendWidth`. Measured by
   upstream at 14–23% GPU.
2. Evaluate the SDF in **local space** via the inverse basis, scale the result
   by the **minimum singular value**.
3. Fold groups with quadratic smooth-min, order deterministic (smooth-min is
   not associative).
4. **Analytic** gradient for the normal — never `dFdx`.
5. Edge-band height profile (convex squircle), interior early-out.
6. Encode.

Antialiasing: centred half-pixel coverage. `fwidth` is unavailable in runtime
effects, so the pixel size comes from the analytic transform basis, which is
exact and portable. The matte reserves half a physical pixel of padding.

`MAX_SHAPES = 16` matches Impeller's uniform buffer limit (16 × 6 floats = 96).
Our layout is wider (3 × vec4 per shape), so **the real limit must be measured,
not assumed** — that is a task in the plan, not a constant to guess.

### 5.2 Composition pass

One `BackdropFilterLayer`:

```dart
ImageFilter.compose(
  inner: ImageFilter.blur(sigmaX: frost, sigmaY: frost, tileMode: TileMode.mirror),
  outer: ImageFilter.shader(finalShader),
)
```

The shader samples the matte, decodes normal and displacement, samples the
backdrop once (or three times when chromatic aberration exceeds the pixel-space
threshold), applies tint/saturation/variant, and adds the two-lobe rim
highlight with the black-surface guard.

`precision highp float` — `mediump` turns the coordinate subtraction into
visible shimmer on large layers (upstream #57).

Uniform layout must respect: the **first float uniform is a `vec2` overwritten
by the engine** with the input size, and at least one `sampler2D` is required.

**Known engine defect to design around:** the backdrop sampler is
nearest-neighbour by default (flutter#186945), so warped lookups snap between
texels. Until `filterQuality` ships we should evaluate whether a small
in-shader bilinear reconstruction is cheaper than the shimmer is ugly. **This
needs measurement, and is a task in the plan.**

---

## 6. Invalidation

The part upstream gets most wrong, and where most of the win is.

**Dirty only on real change.** Upstream sets `needsGeometryUpdate` on *every*
`layout()` call before constraints short-circuit, so glass in any scrollable
re-rasterises every scroll frame. We compare a monotonic `sceneRevision`, bumped
only when a shape's resolved geometry, group membership, or material actually
changes.

**Translation is not invalidation.** If every shape moved by the same delta and
the revision is unchanged, shift the matte bounds and reuse the generation.

**Ancestor motion is compositor-only.** The matte is layer-local; a per-frame
affine (`uFilterToMatteBasis`, `uFilterToMatteOffset`) maps `FlutterFragCoord`
into matte space. For a pure shared translation, move the retained `OffsetLayer`
and only re-snapshot the filter if the coordinate mapping changed.

**Filter reuse.** `FilterSnapshot` captures `(matteTexture, bounds, dpr,
materialRevision, coordinateMapping)`. The native `ImageFilter` is rebuilt only
when the snapshot differs — because the engine copies uniforms into the native
filter at first conversion.

**Retained clips.** `RetainedClipChain` walks each shape's ancestors to the
layer, collects clip and viewport render objects, keeps the common prefix, and
re-pushes them as native clip layers wrapped in forward/inverse transforms
**outside** the moving offset layer. This is the structural fix for the whole
scroll-bug family (#124, #136, #101, #33).

**Idle is free.** When every material resolves to no visible glass, the backdrop
filter is not pushed at all. Upstream pushes a full backdrop pass even at
`blur: 0`.

---

## 7. Testing

Correctness is mostly *visual*, which is where upstream's suite failed — its
blend goldens all render the same image because the parameter they vary is a
no-op, and its shader precache points at a file that does not exist.

| Layer | Approach |
|---|---|
| Shape math | Unit tests against analytically-known distances; assert gradient magnitude ~1 where the SDF claims to be exact |
| Codec | Round-trip property tests: encode->decode error under the stated bound across the full parameter range |
| Invalidation | **Instrumented counters.** Assert `produce()` call counts across scroll, translate, rotate, resize, and idle. This is the regression surface that matters most and the one upstream has none of. |
| Transform correctness | Golden per transform class: rotation, non-uniform scale, nested transforms |
| Goldens | Multi-DPR (1x, 2x, 3x) — upstream's are macOS-1x-only, which is structurally why its DPR bug survived |
| SkSL legality | CI compiles every shader for the Skia target. Non-negotiable: upstream shipped broken SkSL twice |
| Leaks | Assert every `FragmentShader` and `MatteGeneration` is disposed on unmount |

Every fixed upstream defect gets a named regression test. The list in
`competitive_landscape.md` §3 is the starting checklist.

---

## 8. Acceptance criteria

1. A layer with 1 and with 16 shapes, blended and unblended, renders correctly
   on iOS, Android-Vulkan, Android-GLES and macOS.
2. **Exactly one backdrop capture per layer per frame**, asserted by an
   instrumented counter.
3. Rotated and non-uniformly scaled glass refracts in the correct direction —
   the specific thing upstream gets wrong.
4. Glass inside a `ListView` scrolls without disappearing, tearing or
   re-rasterising its matte. `produce()` call count is **zero** across a scroll
   where no shape geometry changed.
5. A static layer schedules no work: zero `produce()` calls, zero filter
   rebuilds.
6. Every shader compiles as SkSL in CI.
7. No leaked `FragmentShader` or texture across 1,000 mount/unmount cycles.
8. Both producers pass the same golden suite.
9. Benchmark harness reports frame timings for a fixed scene on a real device,
   with the numbers recorded — the baseline everything later is measured against.

---

## 9. Risks

| Risk | Response |
|---|---|
| `flutter_gpu` is beta; its API can break | It lives in a separate opt-in package. Core never depends on it. |
| The real uniform-array limit is unknown for our wider layout | Measure it first. `MAX_SHAPES` is a measured constant, not a guess. |
| Nearest-neighbour backdrop sampling (flutter#186945) may make refraction shimmer regardless | Measure early. Fall back to in-shader reconstruction if needed; document if not. |
| Runtime-int uniform-array indexing is reported broken (flutter#148577) but shipped by upstream | Verify per backend before the shape loop depends on it. Macro-expanded constant indices avoid it entirely. |
| Retained clip chains are subtle and can break in ways goldens miss | Instrumented counters plus explicit scroll/viewport tests. |
| Immutable generations raise memory (upstream: 435 -> 458 MiB) | Bucketed free-list; measure footprint as an acceptance criterion, not an afterthought. |
