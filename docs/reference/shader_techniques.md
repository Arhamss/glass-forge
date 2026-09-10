# Reference: shader techniques and their provenance

Captured 2026-09-10. This file exists for two reasons: to record the techniques
worth implementing, and to record **where each formula comes from and under
what licence**, so that nothing with a viral or non-commercial licence ends up
in `glass_forge`.

## 0. The licensing rule

**Formulas and techniques are not copyrightable. Code is.** So the working rule
is: read the formula, cite the source, write our own implementation. Never
paste.

This matters more here than in most projects, because the most widely copied
liquid-glass refraction shader in the Flutter ecosystem traces to Shadertoy,
whose default licence is **CC BY-NC-SA 3.0** — non-commercial and share-alike.
See `liquid_glass_renderer_teardown.md` for details.

| Source | Licence | Safe to copy? |
|---|---|---|
| iquilezles.org articles (SDFs, smooth-min, gradients) | MIT snippets | Formula-level; re-derive |
| Kyant0/AndroidLiquidGlass, TIANLI0/FluidGlass, Abdullajon1881, Kashif-E/KMPLiquidGlass | Apache-2.0 | Only with NOTICE + attribution |
| liquid_glass_renderer `main`/dev.4 | MIT | Yes, with attribution — **except** shader math credited to Shadertoy |
| liquid_glass_renderer `codex/*` rewrite branches | **Apache-2.0** | Only with NOTICE |
| `multi_shader_builder.dart` (both trees) | **BSD, Flutter Authors** | Needs the Flutter BSD notice |
| liquid_glass_widgets, liquid_glass_easy, oc_liquid_glass, Prismal, shuding, rdev, QWEA0, himanshu-lal4 | MIT | Yes, with attribution |
| Loop_Box / sentinelcmd Godot shaders | CC0 | Freely |
| **All Shadertoy entries** | **CC BY-NC-SA 3.0** by default | **No** |
| ShatteredGlass, lucasromerodb, DnV1eX/LiquidGlassKit, HadesPTIT | **No licence file** | **No** — read for understanding only |

Everything we actually need is available formula-level or from MIT/Apache/CC0
sources.

## 1. Distance functions

**Rounded box** (iq):
```glsl
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}
```
A `vec4 r` variant selects the per-corner radius by quadrant.

**Smooth-min**, quadratic (iq) — fastest, never overestimates:
```glsl
float smin(float a, float b, float k) {
    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}
```
**It is not associative** — blend order changes the result, so the order must be
deterministic. An exponential variant exists but costs more.

The correct bounds inflation for this smin is **k/4**.

**Superellipse / squircle: there is no exact closed-form SDF.** The honest
options are:
- raise the rounded-rect exponent to 4 for a "distance-like metric" (Levien)
- `pow(|x|,8) + pow(|y|,8)` (Godot port, CC BY-NC-SA — formula only)
- **lift Flutter's own rounded-superellipse distance** from
  `impeller/entity/shaders/uber_sdf.frag`, which is what upstream's rewrite
  does, with a CPU-side precompute so the bisection is not repeated per
  fragment

The third is strongly preferred: it makes the glass silhouette match
`ClipRSuperellipse` **exactly**, which no other approach does.

**Ellipse**: the cheap `k1(k1-1)/k2` approximation is *not* a true distance —
its gradient magnitude is not 1, so heights and normals are distorted for
non-circular ovals, and it divides by `|p|` near the centre, producing a
direction-dependent pinhole. A Newton solve is the correct fix.

## 2. Normals — three ways, and only one works everywhere

| Method | Cost | Verdict |
|---|---|---|
| **Analytic gradient** | cheapest | **Use this.** Artifact-free, works on every backend. Does not survive `smin` unions perfectly, but the error is small and bounded. |
| `dFdx`/`dFdy` | cheap | **Rejected on web** (flutter#180959) and per-2x2-quad, so it aliases at creases and corners. Also undefined after a non-uniform early return — the cause of upstream's AA-band artifacts. |
| Central differences | 4 extra SDF evals | Fallback for SkSL where derivatives are unavailable. |

The decision falls out of the platform matrix: **web support makes analytic
normals mandatory.** That is convenient, because it also fixes upstream's
corner aliasing (#85) and undefined-derivative bug in one move.

Note `fwidth` is unavailable in runtime effects **even on Impeller**, so
derivative-based antialiasing width must come from an analytic estimate or a
fixed feather.

## 3. Edge / height profiles — the main look knob

| Profile | Formula | Character |
|---|---|---|
| Circular cap, flat inside | `h = sqrt(t^2 - (t+sd)^2)` | Upstream dev.4. Curvature **discontinuity** where the flat top meets the bevel. |
| Quarter-circle cheap | `y = 1 - sqrt(1 - x^2)`, or `x^2/2` | Cheapest defensible. |
| `circleMap` + dome | `d = (1 - sqrt(1-t^2)) * amount`, `grad = normalize(gradSd + depth * normalize(p))` | **Kyant0.** The dome term is what makes pills read as domed rather than bevelled. |
| Power ramp | `band = clamp(-d/edge, 0, 1); curve = pow(1-band, 1.6)` | No `sqrt`, no `refract`. Not physical. |
| **Convex squircle** | `y = fourth-root(1 - (1-x)^4)` | **Best match to Apple** (kube.io ray-trace study). |
| Exponential | `exp(-k*(w+offset)^2)` | Softest falloff. |

Apple's own model is an **edge band with an undistorted interior**
(`inputInnerRefractionHeight` / `inputInnerRefractionAmount`), which is both
cheaper and more faithful than refracting the whole surface. See
`apple_liquid_glass_spec.md` §3.

**Displacement**, two families:
- **Non-physical**: `disp = grad * curve * strength`. Cheap, direct, and what
  most shipping implementations use.
- **Single-refraction slab**: `r = refract(vec3(0,0,-1), n, 1/ior);
  disp = r.xy * (h + 8t)/|r.z|`. Physical, and the `8t` base is what makes the
  flat centre still magnify slightly.

Upstream's rewrite re-parameterises IOR as an **observable edge displacement in
pixels** — `ratio = edgeRefraction/(8*thickness); index = sqrt(1 + ratio^2)` —
on the grounds that Apple exposes no refractive index and users think in
pixels. Worth copying as a design decision.

**Interior early-out** (Kyant0): `if (-sd >= refractionHeight) return
content(coord);` — a large win when most of the shape is undistorted.

**Union necks**: the SDF gradient is discontinuous along the medial axis and in
the "neck" between merging shapes. Both fade the lens where the gradient
collapses and taper refraction to zero over the outer band, to avoid a
"cracked glass" look.

## 4. Chromatic aberration

Three taps along the displacement:
```
R at (1 + 0.5c) * d,   G at d,   B at (1 - 0.5c) * d
```
Because the offset is proportional to displacement, **the fringe is
automatically zero on flat regions** — rim-only for free.

Cheaper still: gate on the SDF with a `smoothstep` so the interior is a single
tap. Prettier: 7-tap spectral weighting (Kyant0), concentrating in corners, at
about 2.3x the fetch cost.

**Threshold in pixels, not units.** Upstream dev.4 skips CA when `CA < 0.01` —
and its own default is exactly `0.01`, so every default install pays three taps
for an invisible effect. The rewrite instead skips when
`abs(CA) * maxDisplacement <= 0.25` px, which is the right formulation.

Sensible magnitudes run from ~0.018 up to ~0.25 before it reads as a rainbow.

On tile-based mobile GPUs the extra taps hit the same cache lines as the centre
tap, so their marginal cost is well below the first tap.

## 5. Blur — with real numbers

The low-end tier lives or dies here.

**Dual filter / dual Kawase** (Bjørge, ARM, SIGGRAPH 2015):
- downsample: 5 taps at half resolution — centre x4 plus 4 diagonals at
  +/- half-texel, divided by 8
- upsample: 8 taps — 4 axis at +/-2 half-texel weight 1, 4 diagonal at
  +/- half-texel weight 2, divided by 12

Measured at a 97x97-equivalent blur, 1080p, Mali-T760 MP8: "the dual filter is
the fastest, closely followed by the kawase filter," and it needs **only 7% of
the total bandwidth of the linear-sampling Gaussian, and less than half of
Kawase.** PSNR differences are "very minor."

**Kawase vs Gaussian** (Strugar, Intel 2014): Kawase runs **1.5x to 3.0x
faster** than an optimised separable Gaussian, with the advantage largest at
big kernels and on low-power GPUs; quality "fair from ideal… acceptable."
And crucially: **half-resolution intermediates cut cost to roughly one sixth.**

**Linear-sampling tap merge** (Rakos 2010): 9 taps become 5 fetches via
bilinear sampling, about 60% faster than discrete.
`offset = {0, 1.3846153846, 3.2307692308}`,
`weight = {0.2270270270, 0.3162162162, 0.0702702703}`.

**Pyramid / CoD:AW** (Jimenez 2014): 13-tap downsample (36 texels via
bilinear), 3x3 tent upsample, 5-6 mips.

### The Flutter constraint

**A dual-Kawase chain is not expressible in a single `FragmentProgram`** —
there are no render targets and no mip access. The options are:

1. multiple half-size `ImageFilter.shader` / `ImageFilter.compose` passes
2. pre-downsample the captured backdrop in Dart (`toImageSync` at 1/2 scale)
3. lean on Impeller's own downsampled Gaussian via `ImageFilter.blur`

Given that Impeller's blur already downsamples above sigma 4 and merges taps
bilinearly, option 3 is the sane default and option 2 is the lever for the
cheap tier. Upstream measured a 13-tap one-pass frost and rejected it — it
"produced repeated source-image ghosts."

## 6. Specular without an environment map

- **Two-lobe rim** (upstream, and matching Apple's two highlight layers):
  `rim = 1/(1 + 0.89*(sd/1.5)^2)`,
  `intensity = max(0, n·L) + 0.8 * max(0, n·(-L))`.
- **Fake 3D normal** from the 2D gradient: `N3 = normalize(vec3(grad, 0.6))`,
  with two lights at `+/-(cos a, sin a, 0.5)`. Blinn-Phong from there.
- **Dual specular powers** (14 and 20) plus Beer-Lambert rim darkening
  reproduces the iOS 26/27 darker perimeter.
- **Schlick Fresnel**: `pow(1 - max(dot(h,v), 0), 5)`.
- **Two-colour hemisphere ambient**: `ground + up*(sky-ground)` where
  `up = 0.5 + 0.5*dot(n, upVector)`.

**Highlight colour: use incident white, not the refracted backdrop.** Upstream
dev.4 derives highlight colour from the backdrop, which is why it produces
cyan/green fringes (upstream #135). The rewrite switched to incident white.

**Black-surface guard**: scale the bevel/rim response by
`pow(luminance, 0.25)` so it is exactly zero on a truly black surface —
otherwise the rim flickers (upstream #112).

**Gyroscope coupling** is just feeding `uLightDirection` from the
accelerometer per frame.

## 7. Encoding a displacement matte in RGBA8

If the matte is 8-bit (and `toImageSync` gives no float option), naive encoding
bands badly. Upstream measured "fewer than two code points per physical pixel
at common thicknesses."

The better packing:
- **RG** = unit surface normal, asymmetric 0..254 coding so −1, 0, +1 are all
  exactly representable
- **B** = signed edge distance with a sqrt compander on both sides
- **A** = one-sided displacement **magnitude** with a sqrt compander

```glsl
float linear     = clamp(-magnitude / maxDisplacement, 0.0, 1.0);
float normalized = 1.0 - sqrt(1.0 - linear);            // encode
float inverse    = 1.0 - encoded.a;                     // decode
float decoded    = 1.0 - inverse * inverse;
```

And size the range to what is actually reachable —
`maxDisplacement = 1.05 * edgeRefraction`, not `thickness * 10`, so code points
are not spent on unreachable values.

Alternatives worth considering: 16-bit displacement split across two channels,
or storing normal + height and doing the refraction at sample time.

## 8. Antialiasing

Centred half-pixel coverage:
```glsl
float pixelSize = length(vec2(dFdx(sd), dFdy(sd)));   // Impeller only
float fade      = clamp(aa, 0.0, 1.0) * max(pixelSize, 1e-4);
float alpha     = 1.0 - smoothstep(-fade, fade, sd);
```
This requires reserving **half a physical pixel of padding outside the shape**
in the matte, and clamping optical depth to `min(sd, 0)`.

Where derivatives are unavailable (web, and `fwidth` even on Impeller), fall
back to a fixed feather — upstream uses 0.75 px — or derive the pixel size
analytically from the transform basis, which is exact and portable.

## 9. Culling

A Euclidean box distance under the shape's own basis is a **valid lower bound**
on its SDF, so a primitive can be skipped when
`bound >= currentBest + blendWidth`.

Measured by upstream: **3.60 -> 3.08 ms/frame GPU** for 16 dynamic shapes, and
**3.76 -> 2.88** for 16 sparse shapes in motion. They also tried an L-infinity
bound, which culled less and ran slower.

Combine with a whole-pixel early exit using squared distances plus a smoothing
budget.

## 10. Transform correctness

To support rotation and non-uniform scale, store per shape an **inverse 2x2
basis plus offset**, and evaluate the SDF in local space:
`localPoint = inverseBasis * (p - origin)`.

The returned local distance must be scaled back to screen pixels by the
**minimum singular value** of the basis, so it remains a valid lower bound:
```
trace        = |axisX|^2 + |axisY|^2
discriminant = max(0, trace^2 - 4*det^2)
distanceScale = sqrt(max(0, (trace - sqrt(discriminant)) * 0.5))
```
Using a transformed AABB instead would apply the scale twice.

## 11. Ecosystem cross-check

Techniques converge across every ecosystem, which is a good sign they're right:

- **Android/Compose** (closest constraints to Flutter): Kyant0's AGSL
  implementation — analytic gradient, interior early-out, `circleMap` profile,
  dome term. `Kashif-E/KMPLiquidGlass` runs the same shader as AGSL on Android
  **and SkSL on iOS/desktop/wasm** — proof the technique survives SkSL's
  restrictions.
- **Web CSS/SVG**: `backdrop-filter: url(#f)` with `feDisplacementMap` fed by a
  generated SDF map. Chrome only; WebKit bug 245510 open since 2022. kube.io's
  is the rigorous version. Notable limitation: "dynamic shape/size changes are
  costly because nearly every tweak forces a full displacement map rebuild" —
  the same invalidation problem we face.
- **Figma's** native Glass effect exposes Light angle/intensity, **Refraction**,
  **Depth** ("how far the curved edge extends inward"), **Dispersion**, and
  **Frost** — independently arriving at the same edge-band parameter model.

## 12. The shortlist

1. Analytic SDF gradient — mandatory for web, and better everywhere.
2. Edge-band lens with an undistorted interior — matches Apple, cheaper.
3. Interior early-out.
4. Rim-gated 3-tap chromatic aberration with a **pixel-space** threshold.
5. Two-lobe rim highlight, incident-white coloured, black-guarded.
6. Smooth-min merging with fixed-size arrays and constant loop bounds.
7. One shared, padded, dirty-tracked backdrop capture per container.
8. Normal+magnitude RGBA8 codec with sqrt companding.
9. Inverse-affine per shape with min-singular-value distance scaling.
10. Bounds culling before the expensive SDF.
11. Half-resolution capture plus dual-Kawase for the cheap tier.
