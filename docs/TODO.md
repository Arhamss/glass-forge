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
  in the example**, on the iPhone 17e simulator. Mechanism confirmed by
  direct instrumentation (fix round 1 — a temporary dump of every
  `RenderGlassLayer._records` entry's geometry, per paint, reverted before
  commit; see task-5-report.md). Two distinct things, found together:
  - **The overlap is a one-frame, self-correcting fresh-mount artifact —
    not old/new scenes coexisting, and not a persistent settled overlap.**
    Switching Blend → Motion was traced end to end:
    - At the exact paint that warns, `_records` holds **three** entries —
      the tab bar, Motion's own sheet, Motion's own specimen — never four
      or five, so none of Blend's two ovals are still registered. Old and
      new scenes do **not** coexist; `Element.deactivateChild` really does
      detach (and `RenderGlassShape.detach()` really does
      `unregisterShape`) the outgoing subtree synchronously, before this
      frame's layout or paint, exactly as a straightforward reading of
      the framework predicts.
    - Motion's sheet registers at `origin=(195, 121.5)` and its specimen
      at `origin=(104, 141)` on that one paint — both wrong. On every
      subsequent repaint (confirmed both by the transition's own
      settle-animation frames and by forced no-op repaints seconds later,
      scene unchanged) they read `(195, 671.5)` and `(195, 386)` — their
      real, final, **non-overlapping** positions — and stay there. The
      warning never recurs once settled, including under repeated forced
      repaints long after the transition. This rules out a persistent
      design-level overlap: the settled layout is fine.
    - The wrong-then-corrected values match a mechanism
      `RenderGlassShape` already documents and defends against, just one
      step too late for this check: `RenderGlassShape.performLayout` calls
      `_syncGeometry()` (registers via `getTransformTo`), but — per the
      doc comment on `_syncGeometryIfTransformChanged` —
      `getTransformTo` read from inside a shape's own `performLayout` can
      be missing an ancestor's contribution entirely, because some
      ancestors (the doc's own example is `Positioned` inside `Stack`;
      the same ordering applies to a `Column` positioning a
      freshly-mounted child) assign the child's offset only *after*
      laying it out. `RenderGlassShape.paint` calls
      `_syncGeometryIfTransformChanged()`, which *does* always register
      the fresh, correct transform — but that runs during the subtree's
      paint, which is *after* `_debugWarnOnCrossPassOverlap()` (per this
      task's decision 1, deliberately placed before the subtree paints).
      So the check is, by construction, reading exactly the one value
      `RenderGlassShape` itself calls "the stale one," one paint before
      the shape's own paint-time call corrects it. This is not a new bug
      introduced by this task; it is the same documented staleness
      window the brief already named ("every shape's geometry is from
      last frame's registration ... good enough for a diagnostic"),
      just observed on a *fresh mount* rather than only on frame one of
      the whole app.
    - The app's very-first-frame case (finding recorded here originally)
      is almost certainly the same mechanism at its most severe: on that
      frame *every* ancestor in the chain is still on its pre-layout
      default, not just the freshly-mounted subtree's own immediate
      parent, so the registered geometry degenerates all the way to
      `origin == halfExtent` (as if the shape's own top-left sat at the
      layer's literal `(0, 0)`) rather than merely landing at a
      wrong-but-plausible offset. Not re-verified with the same
      per-record dump as the tab-switch case, so held to a slightly lower
      confidence than the tab-switch finding above, but the values fit
      exactly and no other explanation was found.
    - **A `GlassPresence` crossfade between scenes would not fix this.**
      That was the original guess in this entry and it is wrong: nothing
      here is two scenes' content coexisting, so there is nothing for a
      crossfade to sequence. The actual fix, if this is worth fixing at
      the package level rather than accepted as inherent to a debug-only
      diagnostic, is in the check's own timing or in
      `RenderGlassShape`'s registration path — not in the example.
  - **A related, louder, and separately-confirmed bug in the Blend
    scene's teardown**, surfaced by the same interaction: switching away
    from Blend throws (caught and reported, not fatal)
    `RenderGlassLayer#... NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE and
    RenderGlassShape#... are not in the same render tree`.
    `RenderGlassShape.detach()` unregisters itself from the layer first,
    which is correct, but then calls `_leaveGroup()`, whose
    `BlendGroupLink.remove()` synchronously `notifyListeners()`s —
    reaching the *other* circle still mid-teardown, whose
    `_onGroupChanged` re-syncs geometry via `getTransformTo(_layer)`
    against an ancestor chain that is disturbed by the same detach
    cascade. `ChangeNotifier.notifyListeners()` catches and reports this
    per listener rather than rethrowing, so the frame survives, but it is
    a real ordering bug in `RenderGlassShape`/`BlendGroupLink`, not an
    example bug. This finding is unaffected by the mechanism correction
    above — it was confirmed independently, from its own stack trace.
  - Not fixed here: task 5 was "add the diagnostic," and the check is
    correctly refusing to stay quiet about a real, reproducible artifact
    rather than being softened to hide it (see task-5-report.md, "Fix
    round 1"). Follow-up, if wanted: decide whether the check should read
    geometry *after* the subtree paints instead of before (trading "never
    misses a frame that pushed backdrop layers" for "never warns on a
    fresh mount's stale layout-time geometry" — a real design tradeoff,
    not an obvious win either way), or accept the one-frame fresh-mount
    false-positive-shaped print as inherent to a diagnostic that is
    explicitly documented as reading possibly-stale geometry; and,
    separately, fix `RenderGlassShape.detach()`/`BlendGroupLink` to
    finish this shape's own teardown before notifying group siblings.

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
