# Where glass_forge stands — 2026-09-18

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

## The four decisions — answered 2026-09-18

Arham signed off the widget spec. Recorded in full in
`docs/superpowers/specs/2026-09-14-glass-widgets-design.md` under
"Decisions made — 2026-09-18":

1. **The widget list:** the eight, **plus a text field**. Five controls
   (button, switch, slider, segmented control, text field) and four pieces
   of chrome (tab bar, app bar, sheet, scaffold). B5 was added to the spec
   for the field.
2. **Touch glow in the shader**, not painted — only that version spreads to
   neighbouring glass.
3. **The overlap check warns in debug**, it does not assert.
4. **Plain names** — `GlassButton` and the rest, colliding with
   `liquid_glass_widgets`.

## Added after sign-off

**C5, `GlassDetentSheet`** — the Apple Maps sheet, requested the same day
from an Expo write-up of the behaviour. Persistent rather than presented,
dragged between detents, morphing from floating (inset, big radius) to flush
(no gap, screen corners) as it rises, with a scroll handoff at the top detent
and a presence handoff with the bottom bar it covers. Specced as C5; it is
the hardest widget in the document.

## Order, and where the plans are

A1 → A4 → A2 → A3 → B1 → B2 → B3 → B4 → B5 → C4 → C1 → C2 → C3 → C5 → D.

- **Sub-project A** — plan written:
  `docs/superpowers/plans/2026-09-18-glass-widgets-a-foundations.md`.
  Nine tasks: presence through `uSurface.z` (1–3), `GlassHostScope` and the
  overlap warning (4–5), anchored press-stretch (6–7), the touch glow
  uniform and its driver (8–9). **Not started — no code written yet.**
- **Sub-projects B, C, D** — no plans yet. Write each one when the one
  before it lands.

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
- **A4's new cross-pass overlap warning (Task 5) fires on every tab switch
  in the example**, on the iPhone 17e simulator. Two distinct things, found
  together:
  - **The transient overlap itself.** `Stage._sceneFor` swaps to a whole
    new scene widget on `setState(() => _index = i)` — exactly what
    `_SceneTabs`'s `onChanged` calls on a real tap — and for one frame the
    outgoing scene's glass and the incoming scene's glass both show up in
    `RenderGlassLayer._records` with real, non-degenerate bounds (not the
    zero-size placeholder a genuinely unmounted shape would leave). This is
    the legitimately-transient case the warning was designed not to assert
    on, but it is worth fixing properly rather than living with the
    print, since nothing here is a deliberate `GlassPresence` handoff —
    it is every ordinary tab switch. The very first frame of the app (any
    scene, before any tap) also warns once, for the same reason: the
    control-panel sheet and the bottom tab bar both register with
    `origin.y == 0` on that first frame, before the Column has assigned
    their real offsets — `Rect.fromLTRB(0.0, 0.0, 1050.0, 156.0)` and
    `Rect.fromLTRB(0.0, 0.0, 1050.0, 432.0)` at 3x, reproduced on every
    cold launch and every hot restart.
  - **A related, louder bug in the Blend scene's teardown**, surfaced by
    the same interaction: switching away from Blend throws (caught and
    reported, not fatal) `RenderGlassLayer#... NEEDS-PAINT
    NEEDS-COMPOSITING-BITS-UPDATE and RenderGlassShape#... are not in the
    same render tree`. `RenderGlassShape.detach()` unregisters itself from
    the layer first, which is correct, but then calls `_leaveGroup()`,
    whose `BlendGroupLink.remove()` synchronously `notifyListeners()`s —
    reaching the *other* circle still mid-teardown, whose
    `_onGroupChanged` re-syncs geometry via `getTransformTo(_layer)` against
    an ancestor chain that is disturbed by the same detach cascade.
    `ChangeNotifier.notifyListeners()` catches and reports this per
    listener rather than rethrowing, so the frame survives, but it is a
    real ordering bug in `RenderGlassShape`/`BlendGroupLink`, not an
    example bug, and it is exactly the kind of thing that could leave a
    blend-group shape's geometry stale.
  - Not fixed here: task 5 was "add the diagnostic," and the check is
    correctly refusing to stay quiet about a real, reproducible cross-pass
    overlap rather than being softened to hide it (see task-5-report.md).
    Fixing the transition order — most likely giving `Stage` a real
    crossfade between scenes via `GlassPresence`, and fixing
    `RenderGlassShape.detach()`/`BlendGroupLink` to finish this shape's
    own teardown before notifying group siblings — is follow-up work.

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
