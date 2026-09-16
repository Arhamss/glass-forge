# Where glass_forge stands — 2026-09-17

Resume file. Updated at the end of a working session; read it first.

## State

Branch `main`, clean, **not pushed** (`origin` is a local `.bundle`, and
there is no GitHub repository yet). Last five commits:

| Commit | What |
|---|---|
| `040d769` | The glass widgets design spec, awaiting sign-off |
| `a522eb4` | Package moved to the repository root, countrify-style |
| `b2398c0` | Workbench deleted (573 files) |
| `9feb819` | pub.dev publishing blockers cleared |
| `cd25945` | The example app pub.dev will show |

The repository is now one package at its root: `lib/ shaders/ test/
benchmark/ hook/ android/ ios/ macos/ example/ docs/` with `pubspec.yaml`,
`README.md`, `CHANGELOG.md`, `LICENSE` beside them. No pub workspace;
`example/` resolves on its own through `path: ../`. `.pubignore` keeps
`CLAUDE.md`, `PROJECT_BRIEF.md` and `docs/` out of the published archive.

## Verified on a clean checkout of `a522eb4`

- `flutter analyze` — clean.
- `flutter test` — **480 passed, 23 skipped, 0 failed**.
- `flutter test --tags impeller --run-skipped --enable-impeller` —
  79 passed, 2 skipped, **1 failed** (see below).
- The example's web build (CI's SkSL gate) succeeds.
- The example runs on the iPhone 17e simulator
  (`2473CC29-B74E-43FC-B4C5-7162629E0DFC`) and renders correctly.

## Waiting on Arham — four decisions

From `docs/superpowers/specs/2026-09-14-glass-widgets-design.md`. No code is
written until these are answered; then each sub-project gets its own
implementation plan (A → B → C → D).

1. **The widget list.** Four controls (button, switch, slider, segmented
   control), four pieces of chrome (tab bar, app bar, sheet, scaffold). Text
   fields, menus/morph, toasts, minimize-on-scroll are deferred. Add or drop
   anything?
2. **Touch glow: shader or painted?** Recommended: shader — only that version
   spreads to neighbouring glass the way Apple's does, and costs one uniform.
3. **Glass-over-glass overlap check: debug warning or assert?** Recommended:
   warning, because an assert would throw mid-transition.
4. **Names.** `GlassButton` etc. also exist in `liquid_glass_widgets`.
   Recommended: keep the plain names.

## Known problems, none of them fixed

- **Not publish-clean.** On a fresh checkout `flutter pub publish --dry-run`
  reports one warning: `pubspec.yaml` declares
  `build/shaderbundles/geometry.shaderbundle` as an asset, but `build/` is
  gitignored, so the file only exists after something has built. Fixing it
  touches `hook/build.dart` and `lib/`, so it was left alone. It also means
  CI must build before it analyzes — `shaders.yaml` is ordered that way
  deliberately.
- **`repository` and `issue_tracker` are unset** in `pubspec.yaml`, because
  pub.dev checks that the URLs resolve and no public repo exists yet.
  `publish_to: none` is still set.
- **One Impeller test fails**, before and after the move: the fail-soft test
  in `test/src/rendering/render_glass_layer_test.dart` expects
  `GpuGeometryProducer` but the lane runs without `--enable-flutter-gpu`.
  Pre-existing; CI fails on it too.
- **The other session (`glass-forge-b7`) was never told about the move.** The
  permission classifier blocked the message. It should pull before working.
- The edge band shows **stair-stepped contours** when refracting a smooth
  photographic gradient — consistent with the RGBA8 matte quantising
  displacement. Visible at 2× zoom, not at phone scale.

## The finding the widget spec is built on

`RenderGlassLayer` keys its render passes by material *value*
(`Map<GlassMaterial, _GlassPass>`). Changing a material re-registers the
shapes into a new pass, retires the old one, bakes a fresh matte and rebuilds
the filter — every frame, if animated. The example's refraction slider
already does this. So fading glass in or out cannot animate a material; the
spec adds a `presence` value on the pass instead. Scaling the displacement
uniform alone does not work either, because `final_render.frag` uses the same
`uOptical.x` to decode edge distance, which drives coverage.

## Working notes

- Hot restart without a TTY: run with `--pid-file <path>`, then
  `kill -USR2 $(cat <path>)`. Wait for a *new* `Restarted application` line
  before screenshotting; the count-based wait races.
- A changed asset manifest hangs hot restart — relaunch instead.
- Screenshot then measure, do not trust impressions:
  `xcrun simctl io <id> screenshot x.png`, `sips -Z 1400` before reading, and
  compare pixels inside the glass against a control region outside it.
- `flutter analyze` from the root covers `example/` too, but only after
  `flutter pub get` has run inside `example/`.
