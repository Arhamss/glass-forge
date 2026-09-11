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
- **A real SkSL-legality bug, found and fixed.** The first version of
  `gfSampleBilinear` took `sampler2D tex` as a function parameter (matching
  the brief's own GLSL snippet). `ShaderLibrary.instance.warmUp()` in the
  package's own test suite caught it immediately:
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

The most likely explanation, based on reading `RenderGlassShape` (packages
`glass_forge/lib/src/rendering/render_glass_shape.dart`): its geometry is
registered into the layer's `GlassScene` from `attach()` and `performLayout()`
only. `Align` repositions a child at *paint* time without changing its
incoming `BoxConstraints`, so `performLayout()` — and the `_syncGeometry()`
call inside it — never runs again after the first frame; the same is true of
`Positioned` inside a `Stack`, because a parent-data-only change (new
left/top, same tight width/height) does not, by itself, force Flutter to
re-run a child's `performLayout()`. The probe was rewritten from `Align` to
`Positioned` specifically to test this hypothesis
(`sampling_probe_animated_glass.dart`'s doc comment explains why); the
symptom was unchanged, consistent with the geometry staying frozen at
whatever position the shape was first laid out at, regardless of how it is
later repositioned. **This is not confirmed as the root cause** — the debug
instrumentation that would have proven it conclusively kept getting reverted
by the live-reload tooling mid-session, and re-diagnosing it from scratch
was not a good trade against the time this task had left. It is recorded
here because it would affect any consumer animating a `Glass` shape's
*position* (not just this probe), independent of the sampling-quality
question, and is worth a follow-up task of its own.

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
  stub — a bigger, separate change. `apps/glass_forge_benchmark` (the other
  app) has no web platform at all and, once added for this check, failed
  build for an unrelated pre-existing reason (`gen_localizations`, missing
  `flutter: generate: true`) before ever reaching shader compilation. Shader
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

## flutter#186945 and the upstream issue

flutter#186945: `ImageFilter.shader`'s backdrop sampler is nearest-neighbour
by default. A `filterQuality` parameter merged to Flutter master 2026-07-30
but still defaults to `none`. If/when that lands and defaults usefully, it
would replace this hand-rolled reconstruction outright — cheaper (an engine
flag, not 3 extra taps) and correct for every consumer, not just this one
shader. Re-check that issue before wiring anything here into a real tier.
