# Reference: the Flutter glass landscape

Captured 2026-09-10 from pub.dev and GitHub APIs.

> **Scope note.** Publishing is deferred (decision 2026-09-10), so positioning
> and differentiation are not live questions. This file is kept for the
> *technical* intelligence: what others tried, what they measured, and
> — especially — what they publicly document as broken. Those are free
> negative results.

## 1. Only three implementations do real refraction

| Package | Version / date | dl/30d | Licence | What it is |
|---|---|---|---|---|
| **liquid_glass_renderer** | 0.2.0-dev.4 / 2025-11-13 | 25,239 | MIT (rewrite: Apache-2.0) | The origin. 886 likes, 440 stars. Stalled on pub, mid-rewrite on GitHub. See `upstream_rewrite.md`. |
| **liquid_glass_widgets** | 1.4.3 / **2026-09-10** | **60,278** | MIT | A **vendored fork** of the above, "extended with bug fixes, performance improvements, and shader optimisations", plus an original `lightweight_glass.frag` for Skia/web/desktop. 165 releases in 9 months. |
| **liquid_glass_easy** | 4.2.0 / 2026-08-25 | 11,055 | MIT | The only independent shader implementation with real adoption. |
| *fluid_glass* | 0.1.13 / 2026-09-07 | 634 | Apache-2.0 | A clean **port of Kyant0/AndroidLiquidGlass** to Flutter. Two weeks old, ~zero adoption, but technically the cleanest analytic-gradient implementation in the ecosystem. |
| *oc_liquid_glass* | 0.3.0 / 2026-06-25 | 774 | MIT | 4 shapes max; **12-tap in-shader radial blur** with no downsample. |

Everything else on pub.dev with "glass" in the name is a `BackdropFilter`
wrapper. The most-downloaded of those (`blurrycontainer`, 59k/30d;
`blur`, 42k/30d) do nothing but wrap `ImageFilter.blur`.

Two notable non-renderers: `flutter_acrylic` (600 likes) drives **OS window
compositors** — Windows DWM mica/acrylic, macOS `NSVisualEffectView` — so it is
whole-window and desktop-only. `inspire_blur` does **progressive
variable-strength blur**, which is real prior art for scroll-edge effects and
the cheap tier.

There is also a family of native platform-view wrappers (`real_liquid_glass`,
`cupertino_native`, `adaptive_platform_ui`) that host the genuine
`UIGlassEffect`/`NSGlassEffectView` on iOS 26+. `real_liquid_glass` notably
**follows the iOS 27 transparency slider and Reduce Transparency
automatically** — because the OS does it. Nothing equivalent exists on Android.

## 2. What the competition documents as broken

This is the useful part.

**`liquid_glass_widgets`**, from its own README:

- *"Use Premium only for static, non-scrolling surfaces… may not render
  correctly inside ListView on Impeller."* — its best tier does not work in a
  scroll view.
- *"A user with Reduce Transparency on and Increase Contrast off will still
  receive the full shader."* — accessibility is approximated through
  `MediaQuery.highContrast`, because Flutter exposes nothing better.
- Adaptive quality is `@experimental` with **uncalibrated thresholds**.
- GLES/ANGLE gets an 8-shape layout "to prevent JIT compiler stalls."

**`liquid_glass_easy`** documents a platform constraint worth recording:
*"iOS 26 Impeller binds each runtime-effect uniform to its own Metal buffer and
caps at ~30"* — they had to pack scalars into `vec4`s. Single source,
unverified against engine code, but consistent with upstream hitting a uniform
buffer limit at 96 floats.

**Everyone** either uses `ImageFilter.blur` or an in-shader tap loop. **Nobody
ships a downsampled cheap-tier blur.** Nobody handles Reduce Transparency
correctly. Every Impeller-only package broke on Flutter 3.44 or 3.47 at least
once.

## 3. Upstream's open issues, as a defect checklist

34 open. The ones that describe defects we would inherit by vendoring, and
which our design must therefore answer:

| # | Defect | Our answer |
|---|---|---|
| **153** | Upside-down on Flutter 3.47 — GLES double Y-flip | Gate the flip on `IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED`, or drop it entirely on our floor |
| **150 / 147** | All shaders fail SkSL compile since 3.44 — array-copy initialiser **and** non-constant loop initialiser | Constant loop bounds, global uniform reads, constant array indices. See `upstream_rewrite.md` §5 |
| **149 / 131** | `toImageSync` crash / `Infinity or NaN toInt` on zero-size or non-finite bounds | Guard `!size.isFinite \|\| w <= 0 \|\| h <= 0` |
| **124 / 136 / 101 / 33** | Glass disappears, flickers or tears at scroll bounds and on overscroll | Retained ancestor clips outside the moving offset layer |
| **118 / 24** | Ancestor `Opacity` breaks rendering; white flash during fade | **Still unsolved upstream.** Open design question for us |
| **64** | Glass over a platform view (camera/video) bends the child, blur leaks as a square halo | Engine-level (flutter#175048). Document, cannot fix |
| **85** | Text and corners aliased app-wide on Pixel 3/4 after dev.10 | Analytic normals; fix the derivative-after-early-return bug |
| **57** | Edge artifacts with `mediump` | `highp` in the final pass |
| **135** | Aggressive rim reflection, green/cyan fringe | Incident-white highlight colour, not backdrop-derived |
| **130 / 129** | `outlineIntensity` documented but missing; high `lightIntensity` artifacts | Docs discipline + the RGBA8 codec fix |
| **117** | Per-shape colour inside a blend group | Contributor-map approach |
| **125 / 35** | Per-corner radii; arbitrary shapes | Open feature gaps |
| **15** | Callback for light/dark backdrop adaptation | Apple parity requires this |

Closed issues worth knowing: **#36** (overheating, 26 comments) ended with the
maintainer writing *"I don't have a background in graphics programming at
all… not comfortable recommending this for production anytime soon."* **#39**
was fixed by adding the `IMPELLER_TARGET_OPENGLES` Y-flips — **which is exactly
the code that now double-flips on 3.47 and causes #153.**

## 4. Forks worth reading

- **`vespr-wallet/flutter_liquid_glass_plus`** — 31 commits ahead, published as
  `liquid_glass_plus`. Has its own SkSL/web fix and a FakeGlass-with-fake-
  refraction approach. Removed blend groups entirely in favour of per-shape
  geometry — a design choice we would not copy.
- **`KevinVan720`** — arbitrary-shape SDF from quadratic Béziers packed into a
  texture. Stale, but the technique addresses upstream #35.
- **`DDefiebre`** — the zero-size/non-finite guard for #149 and #131.

## 5. Cross-ecosystem

The technique converges everywhere, which is reassuring:

- **Android**: `Kyant0/AndroidLiquidGlass` (Apache-2.0, 3,733 stars) is the
  reference — analytic gradient, interior early-out, dome term.
  `Kashif-E/KMPLiquidGlass` runs the same shader as AGSL on Android and
  **SkSL elsewhere**, proving the technique survives SkSL.
- **Web**: `backdrop-filter: url(#f)` with `feDisplacementMap`. Chrome only;
  WebKit bug 245510 open since 2022. `rdev/liquid-glass-react` has 6,101 stars.
- **React Native**: `expo-glass-effect` wraps the real `UIVisualEffectView`.
- **Figma** shipped a native Glass effect with Light angle/intensity,
  Refraction, **Depth** ("how far the curved edge extends inward"), Dispersion
  and Frost — the same edge-band parameter model, arrived at independently.
