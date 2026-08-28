# glass_forge — project brief

> Scaffolded 2026-08-28. Nothing here is built yet; this is the thinking, the
> research, and the plan, written down while it was fresh.

**One line:** liquid glass for Flutter that is honest about the GPU it is
running on — real refraction where the device can afford it, a graceful
climb-down everywhere else, with the frame timings published.

---

## 1. Is this possible?

Yes. But it is worth being precise about which third of it is hard, because
the hard third is also the part worth owning.

| Layer | Difficulty | Why |
|---|---|---|
| The glass look — SDF shapes, refraction, specular, chromatic aberration | **Solved** | `liquid_glass_renderer` already does this well, and it is MIT. This is not where the work is. |
| SkSL / web compatibility | **Small** | A ~10-line shader refactor. Detailed in §4. |
| **Performance across the whole device range** | **Hard — and this is the product** | Nobody in the Flutter glass space has done this properly. See §3. |

The mistake would be to build "another glass package." The reference
implementation is good. What does not exist is a glass system that stays at
60fps on a 4-year-old Android mid-ranger, and that can prove it.

---

## 2. Why this is worth doing at all — the evidence from KiBU

KiBU is the forcing function, and its numbers make the case:

- **63 files** blur something — 42 of them via `BackdropFilter`, the rest via
  a raw `ImageFilter.blur`.
- **1 file** uses real refraction (`nav_glass_indicator.dart`).
- **18 distinct blur sigmas** are in use: `1, 2, 4, 6, 8, 12, 13.25, 14, 15,
  18, 20, 24, 30, 40, 50, 70, 80, 100`. The `13.25` is the tell — that is not a
  scale, that is somebody eyeballing a value until it looked right.

Two things fall out of that:

1. The app's "glass" is ~98% Gaussian blur cosplaying as glass. There is a
   large, real visual upgrade available.
2. There is no blur scale. Eighteen ad-hoc sigmas is a design system waiting to
   be written — which is a package concern, not an app concern.

`BackdropFilter` is also, per-widget, among the most expensive things in
Flutter: it forces a `saveLayer` and a framebuffer read-back, which defeats the
tile-based deferred rendering that mobile GPUs rely on. Sixty-three blurred
surfaces is not a free position to be in. Any honest version of this package has to make that
better, not just prettier.

---

## 3. The actual thesis: tiered rendering

Real liquid glass is three passes: capture the backdrop → blur it → sample it
back with an SDF-derived displacement. That is genuinely expensive, and the
cost is not uniform across the devices KiBU ships to.

So the widget API stays constant and the **strategy** varies:

| Tier | Condition | What renders |
|---|---|---|
| **T3 Full** | Impeller + Vulkan, modern GPU | Refraction, chromatic aberration, specular highlight, shape blending |
| **T2 Reduced** | Impeller + OpenGL ES | Refraction at lower sample count, no chromatic aberration, clamped blur |
| **T1 Cheap** | Low-end / thermally throttled | `BackdropFilter` + gradient border + baked specular sheen |
| **T0 Static** | Weakest devices, *and* accessibility | Solid translucent fill, no blur, no readback |

T0 is not only a performance floor — it is also the correct answer for
"reduce transparency" accessibility settings, which almost no Flutter glass
package honours today. That earns the tier system its keep twice.

**Non-negotiables that follow from this:**

- One widget API. Callers never branch on tier; the package does.
- A global override, so an app can pin a tier for testing or for a settings toggle.
- Batching is the default, not an opt-in. The reference already does the right
  thing here (`MAX_SHAPES 16`, six floats per shape, one shader pass per
  layer) — but exposes it as something you have to know to reach for.
- **Ship measurements.** A benchmark harness plus published frame timings on
  named devices. No competing package does this, and it is the single most
  credible differentiator available.

---

## 4. The SkSL bug, and its fix

Worth writing down while it is understood, because it is the one concrete
upstream defect found.

**Symptom.** `liquid_glass_filter.frag` fails to compile to SkSL:

```
error: initializers are not permitted on arrays (or structs containing arrays)
    float param_2[96] = shapeData;
```

**Cause.** In `lib/assets/shaders/sdf.glsl`, arrays are passed into functions
*by value*:

```glsl
float getShapeSDFFromArray(int index, vec2 p, float shapeData[MAX_SHAPES * 6])
float sceneSDF(vec2 p, int numShapes, float shapeData[MAX_SHAPES * 6], float blend)
```

`spirv-cross` lowers a by-value array parameter into a local copy
(`float param_2[96] = shapeData;`). GLSL permits that. **SkSL does not.**

**Fix.** `uShapeData` is already a uniform and therefore globally visible in
the shader. Drop the array parameter from both signatures and index the
uniform directly. Roughly ten lines across `sdf.glsl` and the two `.frag`
files that call in.

**Scope note — this does not currently affect KiBU.** Since Flutter 3.29,
Android without Vulkan falls back to *Impeller's* OpenGL ES backend, not Skia,
and Skia is gone from iOS entirely. SkSL is the **web/CanvasKit** path.
So this is a prerequisite for web support and for upstream health, not a
live mobile bug. Do not let it drive the schedule.

---

## 5. What to take from where

**From `liquid_glass_renderer` (MIT, Tim Lehmann / whynotmake.it) — vendor.**
The shader corpus is the valuable part: `sdf.glsl`, `liquid_glass_filter.frag`,
`liquid_glass_final_render.frag`, `displacement_encoding.glsl`, plus the
layer/render-object plumbing. It is stalled at `0.2.0-dev.4`, ~9–10 months old,
31 published versions and never a stable release. Vendoring a stalled MIT
package is reasonable.

**From `motor` (MIT, same author) — depend, do not vendor.**
Spring physics is what makes glass feel *liquid* under a drag or a press.
But `motor` reached **1.1.0 stable** and is maintained. Vendoring a healthy
package is how you inherit work for no reason. Add it as a dependency.

The rule: vendor what is stalled, depend on what is alive.

---

## 6. Licensing and attribution — read before publishing

Both upstream packages are **MIT**. MIT permits fork, modify, publish,
sublicense and sell. The one binding condition:

> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.

Concretely, before this goes public:

- [ ] `THIRD_PARTY.md` reproducing `Copyright 2025 Tim Lehmann for whynotmake.it`
      and the full MIT text.
- [ ] Per-file header on every vendored shader naming its origin.
- [ ] README credit, above the fold, with a link to
      `github.com/whynotmake-it/flutter_liquid_glass`.
- [ ] **Open the SkSL issue upstream and offer the fix as a PR first.**

That last one is not a legal duty — it is judgement. The author's code is
already in KiBU twice (`motor` and the renderer), the fix is ten lines, and
"we found this and sent it back" is a far better first contact with the Flutter
community than a renamed copy appearing on pub.dev. Do it before publishing,
whatever upstream decides.

---

## 7. Naming

`glass_forge` is a placeholder chosen at scaffold time. Checked on pub.dev,
2026-08-28:

| Name | Status |
|---|---|
| `glass_forge` | **available** |
| `forge_glass` | available |
| `glassworks` | available |
| `liquid_glass` | taken |
| `lucent` | taken |

Reserve the name early if any of this is going ahead — it costs nothing.

---

## 8. Suggested first weekend

Deliberately not "start building the shader." The riskiest assumption is that
tiering is achievable at all, so test that first.

1. **Prove the measurement rig.** A test harness that renders N glass surfaces
   and reports frame build/raster times. Without this the whole thesis is a
   vibe.
2. **Detect the tier.** Establish what Flutter actually exposes about the
   renderer at runtime, and what has to come from `device_info_plus` plus a
   heuristic. *This is the real unknown — it may be the thing that decides
   whether the package is viable.* Timebox it.
3. **Vendor + attribute** the renderer, fix the SkSL array bug, confirm it
   compiles for web.
4. **One widget, two tiers.** `GlassSurface` rendering T3 and T1 only, switched
   by a manual override. Skip auto-detection for now.
5. **Point it at KiBU.** Replace `nav_glass_indicator.dart` and two or three of
   the 63 blur sites. Measure before and after on a real mid-range Android.

If step 2 stalls, the honest answer may be a manual-tier package rather than an
auto-tiering one. That is still worth shipping — but find out in a weekend,
not in a month.

---

## 9. Open questions

- Can render backend (Vulkan vs GLES) be read at runtime from Dart, or must the
  tier be inferred from device class? **Biggest unknown; gates the design.**
- Should tiering respond to *live* thermal throttling, or be decided once at
  startup? Live is better and much harder.
- Does the 16-shape batch limit hold for KiBU, or does a busy screen exceed it?
- Is web support worth the SkSL work at all, given KiBU is mobile-only?
- Does this stay a KiBU-internal package first, and get published only once it
  has earned its claims?

---

## 10. Honest cost note

This is a public shader package: a maintenance commitment that lands on
whoever has the least slack. It is being considered mid-launch, with the team
going 15 → 12 at month end. None of that makes it a bad idea — but the
sequencing in §8 exists so that a weekend produces a real answer about
viability rather than a half-built renderer that has to be carried.

Ship KiBU first. This keeps.
