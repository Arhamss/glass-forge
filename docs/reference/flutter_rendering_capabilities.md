# Reference: what Flutter 3.47 actually exposes

Captured 2026-09-10 against the local SDK at `~/development/flutter`
(framework `d3b14c8769`, engine source present), plus Flutter docs, engine
source and GitHub issues. Every claim here is either read from SDK/engine
source or cited to an issue.

> **This file answers `PROJECT_BRIEF.md` §9's first open question** — "Can
> render backend be read at runtime from Dart, or must the tier be inferred
> from device class? Biggest unknown; gates the design."
>
> **Answer: it can be read.** Two mechanisms, both release-safe. The tier
> system is viable.

## 1. Backend detection

### Impeller vs Skia — one public getter

`dart:ui` keeps a private `_impellerEnabled` set by the engine at isolate
start. Exactly one public API exposes it:

```dart
ui.ImageFilter.isShaderFilterSupported   // true only under Impeller
```

Landed via engine PR #53490, first stable **3.29.0**. It is a plain static, not
a service extension, so it is valid in release builds.

There is a debug-only service extension `ext.ui.window.impellerEnabled`,
registered under `if (!_kReleaseMode)`. Useless for shipping code.

No `PlatformDispatcher` or `SchedulerBinding` property reports the renderer; a
grep of `dart:ui` for `vulkan|opengl|metal|renderer` finds nothing else.

### Vulkan vs GLES vs Metal — no API, but a probe works

- **iOS/macOS: Metal, always.** Skia was removed from iOS in 3.29 and the
  `FLTEnableImpeller` opt-out no longer works. Docs: "Impeller is the only
  supported rendering engine on iOS." Desktop is Impeller-default as of 3.47.
- **Android: Vulkan, with a runtime fallback to Impeller-GLES.** The choice is
  **logged only** — `"Using the Impeller rendering backend (Vulkan|OpenGLES)"`.
  It is not plumbed to Dart or to any platform channel.
- **Manifest/plist flags are inputs, not outcomes.** Android accepts
  `EnableImpeller`, `ImpellerBackend` (`"opengles"`/`"vulkan"`, manifest-only,
  allowed in release), `ImpellerLazyShaderInitialization`, and several tracing
  flags. A plugin can read them, but they only say what was *requested* — the
  Vulkan-to-GLES fallback happens afterwards, per device.

**The probe.** `impellerc` injects `IMPELLER_TARGET_OPENGLES` into the GLES
stage of every `FragmentProgram` asset. So:

```
1x1 fragment shader:
    #ifdef IMPELLER_TARGET_OPENGLES
        write red
    #else
        write green
    #endif

PictureRecorder -> Picture.toImageSync(1, 1) -> Image.toByteData()
```

Red means GLES. Otherwise: `Platform.isIOS || Platform.isMacOS` implies Metal,
else Vulkan. Nothing touches the screen.

Caveats: `IMPELLER_TARGET_METAL`/`_VULKAN` are injected only for
`.shaderbundle`/flutter_gpu, not for runtime-stage shaders — so the probe is
one-bit, and Metal-vs-Vulkan comes from `Platform`. Behaviour under the
`kOpenGLES3` stage is expected to match (same define path in `compiler.cc`) but
**has not been executed**.

**Prior art check:** Sentry hit this exact wall and gave up —
[sentry-dart#1719](https://github.com/getsentry/sentry-dart/issues/1719),
closed 2025-03-10 with `getRenderer() => null`.

### `device_info_plus` does not help

No GPU fields on either platform. `systemFeatures` returns
`packageManager.systemAvailableFeatures` **names only, with nulls dropped** —
so `android.hardware.vulkan.version` appears as a name but its version int does
not, and `reqGlEsVersion` (a nameless `FeatureInfo`) is dropped entirely. iOS
`utsname.machine` gives a hardware identifier that could be mapped to a Metal
GPU family offline.

`gpu_info` on pub.dev is Windows-only via the Vulkan SDK. Nothing for mobile.

## 2. Thermal and power state

**Flutter core exposes nothing** — the engine never reads thermal state.
Everything is plugin territory.

| Platform | API |
|---|---|
| Android | `PowerManager.getCurrentThermalStatus()` + `addThermalStatusListener()` (API 29), `getThermalHeadroom(forecastSeconds)` (API 30, 0.0–1.0, returns NaN if polled faster than every 10s), `THERMAL_STATUS_NONE..SHUTDOWN` |
| iOS | `ProcessInfo.thermalState` (`nominal/fair/serious/critical`, iOS 11+) + `thermalStateDidChangeNotification`; `isLowPowerModeEnabled` + `NSProcessInfoPowerStateDidChangeNotification` |

Existing packages: `thermal` 1.2.2 (Android + iOS, exposes `thermalStatus`,
`onThermalStatusChanged`, `onBatteryTemperatureChanged`; its GitHub repo 404s,
so its native mapping is unverified). `battery_plus` 7.1.1 has
`isInBatterySaveMode` but no thermal.

**Verdict: live thermal response is achievable**, at the cost of ~50 lines of
Kotlin and Swift. Writing our own channel is preferable to depending on
`thermal`, because we also want `getThermalHeadroom` and low-power mode, which
it lacks.

## 3. Self-measurement

`FrameTiming` gives `buildDuration`, `rasterDuration`, `vsyncOverhead`,
`totalSpan`, `frameNumber`, `layerCacheCount/Bytes`, `pictureCacheCount/Bytes`,
plus `timestampInMicroseconds(FramePhase)`. Works in release; batched ~1s in
release, ~100ms in debug/profile; documented cost under 0.1 ms per second.
`Display.refreshRate` gives the frame budget.

### `rasterDuration` is a weak GPU proxy — this matters

`RecordRasterEnd` fires after `DrawToSurfaceUnsafe` returns — i.e. after
command-buffer **encode and submit**, not after GPU execution. On Metal the
present path does not wait for GPU completion except when threads are merged.

**So GPU cost appears only as backpressure**: drawable/swapchain acquisition
stalls inside the *next* frame's raster span, and `totalSpan` creeps past
budget. Flutter's own tracking issue
([#136493](https://github.com/flutter/flutter/issues/136493)) says exactly
this: "we cannot measure how long the GPU takes… except indirectly via any
backpressure."

GPU tracing exists only as a Dart-timeline counter (`GPUTracer / FrameTimeMS`),
gated behind engine flags on Vulkan/GLES, and never appears in `FrameTiming`.

**Usable signal:** rolling p90 of `rasterDuration` and `totalSpan` against
`1000/refreshRate`, plus a missed-vsync count. Treat it as "is the pipeline
saturated," never as "GPU milliseconds."

### A startup GPU probe is feasible and invisible

`Picture.toImageSync` renders GPU-resident without a copy back, and
`Image.toByteData()` completes on the Impeller command buffer's
`kCompleted` status — so **`toByteData` is a real GPU fence**. Timing it
brackets actual GPU execution, offscreen.

Run the probe **twice**: the first pass includes pipeline-state-object
creation, which we want to trigger but not measure.

**Prior art:** none doing runtime adaptation. `inspire_blur` gives manual sigma
advice; `flutter_performance_optimizer` just wraps `addTimingsCallback`.

## 4. Accessibility flags

The complete set on `PlatformDispatcher.accessibilityFeatures` in 3.47:

`accessibleNavigation`, `invertColors`, `disableAnimations`, `boldText`
(iOS + Android 31+), `reduceMotion` (**iOS only**), `highContrast`
(iOS + Android 34+), `onOffSwitchLabels` (iOS), `supportsAnnounce`,
`autoPlayAnimatedImages` (iOS), `autoPlayVideos` (iOS), `deterministicCursor`
(iOS).

**Two traps:**

1. `MediaQueryData` mirrors only 7 of these and has **no `reduceMotion`
   field**. Its `disableAnimations` doc explicitly states that iOS Reduce
   Motion **does not set that flag**
   ([#65874](https://github.com/flutter/flutter/issues/65874)). Read
   `reduceMotion` from `dart:ui` directly.
2. **Reduce Transparency is not surfaced at all.** The iOS bitmask builder
   reads VoiceOver, SwitchControl, invertColors, boldText, reduceMotion,
   `isDarkerSystemColorsEnabled` (which becomes `highContrast` — that is
   *Increase Contrast*, a different toggle), onOffSwitchLabels, autoplay flags
   and cursor. There is **no** reference to `isReduceTransparencyEnabled`
   anywhere under `shell/platform/darwin`.

   A plugin needs `UIAccessibility.isReduceTransparencyEnabled` plus
   `reduceTransparencyStatusDidChangeNotification` over an `EventChannel`.
   **Android has no public equivalent** — its `highContrast` bit comes from the
   accessibility bridge and `REDUCE_MOTION` is marked `// NOT SUPPORTED` in
   engine source. No pub.dev package covers this.

Every competing Flutter glass package approximates Reduce Transparency via
`MediaQuery.highContrast`. `liquid_glass_widgets` documents the resulting hole
in its own README: "A user with Reduce Transparency on and Increase Contrast
off will still receive the full shader."

## 5. Shader warm-up under Impeller

- **SkSL warm-up is gone.** `--bundle-sksl-path` / `--cache-sksl` were removed
  in flutter/flutter#162849, first stable **3.32.0**.
- Engine-internal shaders are precompiled at engine build; their pipeline state
  objects are created at context startup, skippable via
  `ImpellerLazyShaderInitialization`. The Vulkan pipeline cache persists to
  disk after ~50 frames.
- **Custom `FragmentProgram`s still compile at runtime on every Impeller
  backend.** `fromAsset` posts a raster-thread task that registers the shader
  and creates a pipeline for the default colour format, asynchronously. On
  Metal the stage is MSL *source* compiled by `newLibraryWithSource`; on Vulkan
  it is SPIR-V plus a driver PSO build.
- **The residual jank is pipeline *variants*.** A different blend mode, sample
  count, or attachment format builds its pipeline on first draw
  **synchronously**.

**Mitigation that follows directly:** call `fromAsset` at startup, then draw
each shader once offscreen with the *exact* `Paint`, blend mode and saveLayer
configuration it will use in production, so the variant PSOs already exist.
This composes with the GPU probe in §3.

## 6. `ImageFilter.shader`, `BackdropGroup`, and the bug list

### `ui.ImageFilter.shader` — stable since 3.29

Impeller-only; throws `UnsupportedError` elsewhere. Constraints:

- The **first float uniform must be a `vec2`** — the engine overwrites it with
  the input texture size.
- At least one `sampler2D`; index 0 is the filter input.
- Engine requires `texture_inputs >= 1 && uniforms >= 8 bytes`.

### Backdrop sharing — stable since 3.29

`SceneBuilder.pushBackdropFilter(..., int? backdropId)` (engine #55701) plus
framework `BackdropKey`, `BackdropGroup`, `BackdropFilter.grouped`
(flutter #157278).

**Exact semantics**, from Impeller source: the display list is pre-scanned per
frame into `{backdrop_count, all_filters_equal, texture_slot,
shared_filter_snapshot}`. Sharing engages only when `backdrop_count > 1` for
that id in the frame. The backdrop texture is captured once, **at the first
filter's position**, and reused. If every filter with that id is equal, the
filter itself **runs once** and the snapshot is re-composited per consumer; if
they differ, each filter re-runs over the cached texture — saving the captures,
not the filter passes.

**Two constraints:** overlapping surfaces must not share a key (they would see
the backdrop before their siblings drew — documented in framework source); and
on Skia the id is silently **ignored**, not an error.

Impeller also flips directly to the onscreen texture for the *last* backdrop
filter when framebuffer fetch is supported — so the count of backdrop filters
per frame matters even with grouping.

### Newer primitives

`ImageFilterConfig.blur(sigmaX, sigmaY, tileMode, bounded)` and
`BackdropFilter(filterConfig:)` landed in flutter#175473 ("iOS style blurring"),
first stable **3.41.0**.

### Open bugs to design around

| Issue | Effect |
|---|---|
| [#187820](https://github.com/flutter/flutter/issues/187820) | **On physical iPhones, a shader `BackdropFilter` above another `BackdropFilter` reads a stale previous-frame backdrop including its own output** — progressive white-wash. Workaround: `RepaintBoundary.toImageSync()` self-capture. **This breaks the two-stacked-filter architecture.** |
| [#186945](https://github.com/flutter/flutter/issues/186945) | **The backdrop sampler is nearest-neighbour by default** — warped lookups snap between texels instead of interpolating. A `filterQuality` parameter merged to master 2026-07-30 but still defaults to `none`. |
| [#180959](https://github.com/flutter/flutter/issues/180959) | **`dFdx`/`dFdy`/`fwidth` are rejected on web** ("no match for dFdx(float)"), open. Analytic normals are mandatory for a web-capable shader. |
| [#148577](https://github.com/flutter/flutter/issues/148577) | Runtime-int indexing into a uniform array reported failing ("RuntimeEffect error"), P2 — yet upstream ships it on Impeller. Likely SkSL-only. **Verify per backend.** |
| [#138627](https://github.com/flutter/flutter/issues/138627) | `toImageSync` retains its display list; textures cannot be released immediately. Animation means transient texture churn. |
| [#175048](https://github.com/flutter/flutter/issues/175048) | Blur leaks as a square halo over platform views (camera, video). Engine-level. |
| [#174984](https://github.com/flutter/flutter/issues/174984) | Android Impeller backdrop slower than Skia. Open P2. |
| [#149368](https://github.com/flutter/flutter/issues/149368) | `BackdropFilter` processes the whole screen for a small region. |

**Already fixed** (do not design workarounds for these): #170820
(blur ∘ shader composition, fixed by #177687), #163302 (uniform change not
repainting), #179918 (rotation), #170973 (compose).

### Measured `BackdropFilter` cost — the empirical case for tiering

| Scenario | Numbers |
|---|---|
| Multiple blurred `BackdropFilter`s in a `ListView` ([#126353](https://github.com/flutter/flutter/issues/126353)) | Impeller raster **avg 16 ms / max 24 ms** vs Skia 6/5 |
| Blurred bottom nav, iPhone X ([#138615](https://github.com/flutter/flutter/issues/138615)) | **30–40 ms** raster |
| Full-screen sigma 30 on iOS ([#132735](https://github.com/flutter/flutter/issues/132735)) | **~25 ms** |

### How Impeller blurs, for comparison

No downsampling for sigma <= 4; above that it scales by `4/sigma` rounded to a
power of two, floored at 1/16. `kMaxSigma = 500`. **Three passes in separate
command buffers, specifically to prevent device crashes on older Adreno GPUs.**
Bilinear tap-merging halves the kernel. Backdrop filters get coverage aligned
to the downsample divisor to avoid shimmer.

## 7. Fragment shader language limits

- GLSL 460 down to 100. **No UBOs or SSBOs.**
- `sampler2D` only. **Only the two-argument `texture(sampler, uv)`** — no
  `textureLod`, no `texelFetch`, no `textureSize`. Texture size arrives as the
  engine-written `vec2` uniform.
- No additional varying inputs. No unsigned ints, no bools.
- Float uniforms via `setFloat`, samplers via `setImageSampler`, indexed in
  declaration order.
- Use `FlutterFragCoord()`, not `gl_FragCoord`.
- Tile mode is always clamp — anything else must be emulated in-shader.
- Output is premultiplied alpha.
- **Precision hints are ignored when targeting Skia.**
- **SkSL additionally rejects**: non-constant loop initialisers, array-copy
  initialisers, `sampler2D` function parameters, and non-constant uniform-array
  indices.
- **`fwidth` is unavailable in runtime effects even on Impeller** (measured by
  upstream; they fall back to a fixed feather).
- Impeller's own optimisation guidance: uniform-condition branches are fine;
  complex varying branches and early `return`s are the ones to watch.

**Uniform capacity**: no documented numeric cap in the engine; treat as
device-dependent. Two data points — upstream hit an Impeller uniform-buffer
limit at 96 floats of shape data (which is why `MAX_SHAPES` went 64 -> 16), and
`liquid_glass_easy` reports "iOS 26 Impeller binds each runtime-effect uniform
to its own Metal buffer and caps at ~30" (single source, unverified).

## 8. Web specifically

`FragmentProgram` works for `Paint.shader` on CanvasKit and Skwasm.
**`ImageFilter.shader` does not.** Derivatives are rejected. Skwasm is the
default with a CanvasKit fallback; iOS browsers always fall back.

So on web, "real glass" via backdrop refraction is **not available at all** —
not merely slow. Web gets a fake/cheap path regardless of how good our shader
is. This is a hard ceiling, not a tuning problem.
