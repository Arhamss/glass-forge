# Reference: backdrop sampling quality (Task 19)

Written 2026-09-11. Covers the measurement the renderer-core plan's Task 19
asked for: whether `ImageFilter.shader`'s nearest-neighbour backdrop sampler
(flutter#186945) produces visible shimmer under glass_forge's own
displacement, what a hand-reconstructed bilinear fix would cost, and the
resulting decision.

**Read this before trusting the numbers below**: the visual confirmation this
task set out to get was not obtained. Section "What could not be measured,
and why" explains the specific, reproducible blocker. What follows is a
source-level analysis plus partial live evidence, not a clean device capture.
The decision at the bottom is made under that honesty, not around it.

**A limitation of the probe's own design, not a renderer defect**: the
stress backdrop's 1-physical-pixel checkerboard averages to flat grey at any
viewing distance beyond exact 1:1 pixel inspection — that is the whole point
of choosing it, it sits at the display's Nyquist limit. But *displacing* a
pattern that already reads as flat grey produces the same flat grey, shifted
by an amount nobody can see. The stress backdrop can demonstrate texel
*snapping* under zoomed, pixel-level inspection (which this document does
elsewhere), but it has no macro structure — no edge, no gradient a human eye
can track — for refraction to visibly "bend." A screenshot of the probe that
looks like an undisturbed checkerboard is not evidence the glass isn't
refracting; it is close to what a correctly-refracting probe against *this
specific backdrop* would look like too, at anything other than pixel zoom.
This is why the probe's `SamplingProbeBackdropStyle.realistic` mode (a
smooth gradient) exists — read section "Fix round" in the task report for
its status.

## The probe

`apps/glass_forge_workbench/lib/features/sampling_probe/presentation/views/sampling_probe_view.dart`
— built, `flutter analyze` clean, runs on iOS Simulator and macOS. It shows:

- `SamplingProbeBackdrop`: a genuine 1-physical-pixel checkerboard over the
  top half and 2-physical-pixel diagonal stripes over the bottom half,
  painted with one `drawRawPoints` call per half (not a `drawRect` per cell,
  which would be hundreds of thousands of draw calls).
- `SamplingProbeAnimatedGlass`: one `Glass` shape sweeping left-to-right over
  7 seconds.
- A toggle between the shipped shader (`final_render.frag`, nearest-neighbour
  backdrop) and a bilinear-reconstruction candidate
  (`final_render_bilinear_probe.frag`), a displacement slider, and a live
  rolling frame-time readout.

The toggle flips a global flag
(`debugBilinearBackdropSampling`, `package:glass_forge/src/debug.dart`,
re-exported from `package:glass_forge/debug.dart` — deliberately not part of
`glass_forge.dart`'s public surface) that `GlassComposition.build` reads to
choose which compiled shader to bind. Both shaders share one uniform layout,
so this is a true A/B of the sampling code path alone.

## What the source guarantees, independent of any capture

Read directly from `packages/glass_forge/shaders/final_render.frag`:

```glsl
float magnitude = gfDecodeCompandedMax(encoded.a) * uOptical.x;
vec2 displacement = normal * -magnitude;
vec2 offsetUV = (frag + displacement) / uSize;
...
refracted = texture(uBackdrop, gfMirrorUV(offsetUV)).rgb;   // nearest-neighbour
```

`uOptical.x` is `material.maxDisplacement * devicePixelRatio`
(`GlassComposition._writeUniforms`). For `GlassMaterial.regular()`'s
Apple-fitted preset, `edgeRefraction` is 27.42 logical px, which the probe's
own readout converts to **82.3 physical pixels of peak displacement at
3.0x DPR** (27.42 lpx × 3.0). At 1x that is ~27 physical px, at 2x ~55.

`magnitude` is not constant across the shape — it comes from the SDF-encoded
distance field, so it ramps continuously from 0 at the shape's center to
that peak at its edge. A continuous ramp from 0 to 27–82 physical pixels
necessarily passes through non-integer pixel offsets almost everywhere
along it — that is arithmetic, not a claim requiring a screenshot. Every one
of those non-integer offsets is a point where `texture()`'s nearest-neighbour
default rounds to the nearer texel instead of blending, i.e. a point where
the sampled color can differ visibly from its immediate neighbour by a full
texel step instead of a fraction of one. Whether that reads as "shimmer" to
a human eye, at normal viewing distance, at typical `edgeRefraction` values,
is the empirical question this task could not close out (see below) — but
that the shader produces quantized, non-interpolated samples across a wide,
continuously-varying displacement range is not in question.

## What was measured

- **The checkerboard and stripe patterns render as designed.** A raw-pixel
  dump of a device screenshot (`sim_shipped7.png`, iPhone 17 Pro Simulator,
  3.0x DPR) confirms exact `0x0D121C`/`0xFFFFFF` alternation every physical
  pixel — the backdrop is genuinely at the display's Nyquist limit, not
  approximately so. (It also looks like flat 50% grey in any downsampled
  preview, including this document's own screenshot tooling — a real,
  first-hand demonstration of how a 1px-period pattern aliases under any
  non-1:1 viewing scale, which is the same class of phenomenon flutter#186945
  is about, one level up the pipeline.)
- **The probe builds and runs on a real Impeller/Metal backend.** iOS
  Simulator (iPhone 17 Pro, iOS 26.5, 3.0x DPR): `flutter run --flavor
  production -d <simulator>` launches successfully, logs "Using the Impeller
  rendering backend (Metal)", and falls back cleanly to
  `RuntimeGeometryProducer` (Flutter GPU is off by default in the simulator,
  exactly the documented fail-soft path). macOS desktop: added platform
  support (`apps/glass_forge_workbench/macos/`, `.metadata` restored to list
  it alongside the platforms already declared) and confirmed the app
  launches there too, via the accessibility API reporting a live
  `glass_forge_workbench` process.
- **Frame-time readout, both modes, iOS Simulator, debug build:** shipped
  ≈ 38.5–40.5 ms/frame (~25 fps); bilinear ≈ 41.1 ms/frame (~24 fps). These
  numbers are real captures from the probe's own `SchedulerBinding` timings
  callback, not invented — but see the caveat immediately below before
  reading anything into the ~2.5 ms gap.

  **Never cite these as a performance figure.** A debug build carries the
  full assert and observatory overhead and the Simulator has no real GPU;
  the absolute values say nothing about shipped performance, and the gap
  between two debug numbers is not a measurement of anything. The benchmark
  harness added in sub-project 5 refuses to gate on a debug-mode report for
  exactly this reason (`BenchmarkRunMode` marks it `skippedUntrustworthy`
  rather than letting it pass). Numbers worth quoting come from
  `flutter run --profile -t benchmark/run_scene_benchmarks.dart` on real
  hardware, and none have been captured yet.
- **A known SkSL constraint, re-hit via the brief's own snippet.**
  `shaders/common/sdf.glsl` already documents this, from Task 9: "No
  sampler2D parameters anywhere. SkSL rejects those too." This was not a
  novel discovery — the first version of `gfSampleBilinear` took
  `sampler2D tex` as a function parameter (matching the brief's own GLSL
  snippet, which does the same), inheriting a mistake the codebase had
  already named rather than finding an unknown platform quirk.
  `ShaderLibrary.instance.warmUp()` in the package's own test suite caught
  it immediately:
  `Exception: Asset '.../final_render_bilinear_probe.frag' does not contain
  appropriate runtime stage data for current backend (SkSL). Found stages:
  Vulkan`. spirv-cross compiles the Vulkan/Metal stage fine but silently
  drops the SkSL stage for a shader with a sampler-typed parameter — SkSL's
  runtime-effect target does not support it, even though it compiles
  everywhere else. Fixed by hard-coding the function to read `uBackdrop`
  directly (`packages/glass_forge/shaders/common/sampling.glsl`) — every
  caller only ever samples the backdrop, so nothing generic was lost.
  Re-verified after the fix: `strings` on the compiled asset shows the
  "autogenerated by spirv-cross" SkSL header, and `flutter test
  test/src/shaders/shader_library_test.dart` passes warm-up for all four
  `GlassShaderId`s. This is exactly the kind of defect the "every shader
  compiles as SkSL in CI" gate exists to catch, and it would have shipped
  silently broken (compiling for every native target, failing only the web
  SkSL CI job) had the probe not exercised it.
- **The bilinear shader is not loaded by every consumer.** An earlier version
  of this document claimed zero behaviour change on the strength of the
  debug flag defaulting `false` — true for the flag, but `GlassShaderId
  .finalRenderBilinearProbe` was still part of `ShaderLibrary.warmUp()`'s
  eager load, so every app depending on `glass_forge` compiled and loaded a
  fourth shader at startup regardless of whether the flag was ever touched,
  and a load failure for that shader on some backend would have broken
  `ShaderLibrary.isReady` for every consumer (`_loadAll` propagates any
  core shader's failure). Fixed: `GlassShaderId` now carries a `core` flag;
  `warmUp()` only loads shaders where it is true, and
  `finalRenderBilinearProbe` is `core: false`. It loads on demand via
  `ShaderLibrary.ensureLoaded()` / the new
  `debugWarmUpBilinearBackdropSampling()`, called from the probe's own
  `SamplingProbeCubit.setMode()` only when switching *to* bilinear. Nothing
  outside the probe ever calls it.

## What could not be measured, and why

**The glass shape's refraction was not visible in any capture I took**, on
either shader. Three independent pieces of evidence:

1. A synthetic display-side check: temporarily instrumented
   `RenderGlassLayer._refreshMatte` to log `scene.revision` and the baked
   matte's bounds. It fired exactly once, ever, over several seconds of a
   continuously-running 7-second sweep animation — `scene.revision` never
   incremented past 1. (This instrumentation was removed before committing;
   it is not part of the shipped diff.)
2. A byte-level diff between full-resolution screenshots taken in shipped
   and bilinear mode, restricted to the probe canvas region, found **zero
   differing pixels** — not "small," zero. Since the checkerboard/stripe
   backdrop is a pure function of screen position with no time dependence,
   any actual refraction effect at any position would show up as a
   non-matching pixel somewhere in that region.
3. Area-averaged crops of the canvas (to rule out the pattern's own Nyquist
   aliasing hiding a subtle tint/rim effect) show a perfectly flat
   checkerboard-tone / stripe-tone split with no shape-shaped anomaly
   anywhere, in either mode.

**Update, later in this task: confirmed, and fixed twice.** `RenderGlassShape`
(`packages/glass_forge/lib/src/rendering/render_glass_shape.dart`) only
registered its geometry from `attach()`/`performLayout()`. For a `Positioned`
child inside `Stack`, `RenderStack.performLayout` assigns
`childParentData.offset` for the current pass *after* calling
`child.layout(...)` — so the transform read from inside the child's own
`performLayout` is stale, missing that pass's offset entirely (confirmed via
instrumentation: the very first registration read `origin = (0, 0)`,
missing the widget's own position outright). A first fix added a paint-time
check but special-cased the first post-layout paint to record a baseline
without re-registering, to avoid breaking a retained-clip-chain test — which
left the *first*, offset-less registration as the one that stuck for any
shape that did not move a second time, worse than not checking at all for
the general case. Corrected to always register the paint-time-authoritative
transform, and use the "just laid out" flag only to decide whether to
schedule an extra deferred repaint, not whether to register. See
`RenderGlassShape._syncGeometryIfTransformChanged` and its doc comment.
Regression test: `test/src/widgets/glass_widgets_test.dart`, the
`Positioned`-inside-`Stack` test, now asserts the *absolute* registered
origin after the very first paint, not just that it changes after a second
one — verified red against the original bug, and again red against the
first, incomplete fix, before landing green.

**A second, independent bug surfaced while chasing why the shape still
wasn't visually correct after that fix**: `ShapeGeometry.resolve`
(`packages/glass_forge/lib/src/shapes/shape_geometry.dart`) computed
`origin` from this `RenderBox`'s own top-left corner
(`MatrixUtils.transformPoint(toLayer, Offset.zero)`), but
`shaders/common/sdf.glsl` evaluates every shape as `abs(local) -
GF_EXTENT(i)` — a centred-box SDF that requires `local` to be zero at the
shape's *centre* — and `GlassScene._boundsOf` independently computes a
shape's corners as `origin ± halfExtent`, the same centre convention.
`ShapeGeometry.resolve` disagreed with both, by exactly half the shape's own
size. Fixed by transforming the shape's centre instead of `Offset.zero`.
**This fix was not re-verified against a device screenshot before this task
was told to stop** — `flutter analyze` and the bare + a targeted impeller
subset (retained-clip-chain, glass widgets, glass composition — 19 tests,
including pixel-exact positioning assertions) all pass, but the full
`--tags impeller --run-skipped --enable-impeller` suite was still running
at handover, and no fresh capture confirms the shape now renders vertically
centred on device. See `.superpowers/sdd/2026-09-10-renderer-core/
task-19-report.md`'s "Fix round" section for the full handover.

Also not obtained:

- **1x and 2x DPR captures.** No 1x device or simulator was available in
  this environment. A macOS desktop run launched successfully (confirmed via
  the Accessibility API) but its window lived in a macOS Space the available
  screenshot tooling (`screencapture`, `osascript`/System Events) could not
  bring forward — `screencapture -R` and a full-screen capture both only
  ever showed whatever was on the active Space. No PyObjC/Quartz was
  available to capture by window ID instead, which would have sidestepped
  this.
- **A physical device pass.** A real iPhone was available wirelessly
  (`flutter devices` listed it), but was not attempted — between the Space
  issue above and the SkSL bug, the time budget went to fixing what was
  actually reachable rather than adding a slower, less certain channel.
- **`flutter build web`, as a second SkSL validation channel.** Once the
  probe screen became the first real `GlassLayer` consumer in either app
  (grep confirmed neither app used `GlassLayer`/`Glass` before this task),
  `flutter build web` for `glass_forge_workbench` started failing — not on
  shaders, but on `package:flutter_gpu`'s `external` JS-interop-style
  members, which dart2js rejects outright
  (`Error: Only JS interop members may be 'external'`). Confirmed
  pre-existing and unrelated to this task by reverting to a clean stash and
  reproducing the same failure once the stash *also* had a real `GlassLayer`
  consumer — `flutter_gpu` (added in Task 18, for the accelerated geometry
  producer) has apparently never been exercised through a web build before,
  because nothing used `GlassLayer` in an app until now. Left unfixed:
  it is a real defect, but it is Task 18's/the GPU producer's surface, not
  backdrop sampling, and fixing it means a conditional import with a web
  stub — a bigger, separate change. The second app of the time,
  `apps/glass_forge_benchmark`, had no web platform at all and, once added
  for this check, failed build for an unrelated pre-existing reason
  (`gen_localizations`, missing `flutter: generate: true`) before ever
  reaching shader compilation. That app has since been deleted as dead. Shader
  SkSL-legality was instead confirmed the way described above: directly, via
  `ShaderLibrary.warmUp()` in the package's own test suite, which loads
  `ui.FragmentProgram.fromAsset` for every `GlassShaderId` and is what
  caught the sampler-parameter bug in the first place.

## The decision

**Reconstruct in-shader — shipped as tested, opt-in infrastructure, not yet
wired to any default path.**

This is not a clean fit for any of the three outcomes the brief names, and
that mismatch is itself the honest answer: I could not confirm the shimmer
is visible (outcome 1's premise), and I could not confirm it isn't (outcome
3's premise, "no change" because it's invisible). What I *can* stand behind:

- The shader-level case that nearest-neighbour sampling produces quantized
  output across a wide, continuously-varying displacement range is not
  speculative — it is read directly from the shipped shader and the actual
  `edgeRefraction` values `GlassMaterial.regular()` ships with.
- The fix costs a bounded, known amount — 4 texture taps instead of 1 (12
  instead of 3 under chromatic aberration) — and is small enough that
  "affordable" is very likely true for any tier that would enable refraction
  at all; the risk of shipping it is what needed to be near zero given the
  measurement gap, and it is: `debugBilinearBackdropSampling` defaults
  `false`, is never set anywhere outside the probe and its own test, and
  `finalRenderBilinearProbe` is a separate compiled asset that the default
  `finalRender` path never touches. Nothing about this change alters
  existing behaviour for any current consumer.
- Declining to preserve it would have meant re-discovering the SkSL
  sampler-parameter bug from scratch on the next attempt at this — a
  concrete, wasted cost against a hedge that costs nothing at rest.

**What would settle the open part:** a physical-device (or Space-reachable
desktop) capture, in both modes, once `RenderGlassShape`'s
position-tracking gap (or its absence as the actual cause) is resolved
enough that the shape is visibly refracting at all. At that point, wiring
`debugBilinearBackdropSampling` — or its eventual replacement, once the tier
engine exists — behind a real tier check and re-running this exact probe
would close the loop this task could not.

**Update, 2026-09-11 — the dome profile now reads bilinearly by default.**
`GlassProfile.dome` displaces the whole surface by a continuously varying
amount and magnifies what is behind it, which is exactly the case this doc
predicted would show. On the iOS Simulator, over the workbench's
checkerboard, every edge seen through the dome came out stair-stepped by a
pixel or two, and over the Photographic backdrop the magnified 1-pixel
gradient dither turned into moiré arcs. `final_render.frag` now takes the
backdrop through `gfSampleBilinear` when the pass is a dome
(`uSurface.x`), and keeps the single nearest tap for the edge band, whose
flat interior never needed it. Cost: 4 taps instead of 1 (12 instead of 3
under chromatic aberration), on dome surfaces only.

## flutter#186945 and the upstream issue

flutter#186945: `ImageFilter.shader`'s backdrop sampler is nearest-neighbour
by default. A `filterQuality` parameter merged to Flutter master 2026-07-30
but still defaults to `none`. If/when that lands and defaults usefully, it
would replace this hand-rolled reconstruction outright — cheaper (an engine
flag, not 3 extra taps) and correct for every consumer, not just this one
shader. Re-check that issue before wiring anything here into a real tier.
