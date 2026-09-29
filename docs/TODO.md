# Where glass_forge stands — 2026-09-29

Resume file. Read it first; update it at the end of a session. It holds the
current state only. The history it used to carry is in `git log` and in the
ledgers under `.superpowers/sdd/` (gitignored).

## Branch state

All of this work is on **`feat/open-items`**, in the worktree
`glass_forge-open-items`, branched from `main` at `2a62763`. It is **not
merged**. It waits on Arham's go. `main` has nothing newer than `2a62763`.

The ledger for the branch, with every decision made along the way
(Arham's included), is
`.superpowers/sdd/2026-09-28-open-items/progress.md`. The review and audit
reports and each fix batch's report are beside it.

## What shipped on the branch

The nine widgets from the widget spec are in: `GlassButton`, `GlassSwitch`,
`GlassSlider`, `GlassSegmentedControl`, `GlassTextField`, `GlassScaffold`,
`GlassTabBar`, `GlassAppBar` and `showGlassSheet`. Controls share one frame
for semantics, keys, focus and the 44-point target, and support
right-to-left layouts, Reduce Motion, large text, disabled glass and an
owner that declines a change. The renderer draws any number of shapes per
material in clusters. `kMaxShapes` now applies per cluster. The edge band
reads its backdrop bilinearly. Unpainted shapes stay out of the matte. A
pass whose material only reshades keeps its matte, and a focused text field
brightens through a uniform. The overlap warning reports every pair, once.
The example is rebuilt on the package's own widgets, with a settings page
on `GlassScaffold`. `CHANGELOG.md` "Unreleased" lists all of it, with a
**Breaking** section (`GlassShapeClipper` unexported,
`GlassSlider.semanticValue` renamed `semanticValueFormatter`).

## Verified

- **Full suite at `54afa37`** (before the review fixes): package 761
  passed; Impeller lane 95 passed; example 13 passed; analyze and format
  clean.
- **Fix batch D, at `3ec3ff4`**, on the paths it touched:
  - Plain `rendering widgets controls chrome composition`: 393 passed,
    21 skipped. Two back-to-back runs at the default parallelism, no
    flake.
  - Impeller lane with `--enable-flutter-gpu -j 1`, on
    `rendering composition controls chrome widgets diagnostics`: 62
    passed.
  - Example: 16 passed.
  - README snippets, `flutter analyze` (root and `example/`) and
    `dart format`: clean.
- The controller runs the full suite after batch D. Put its numbers here
  when it lands.

The Impeller lane is
`flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu -j 1`.
`-j 1` is also in CI now. The old intermittent `setUpAll` failure came from
`test/flutter_test_config.dart`: every test process re-copied the shader
mirror, truncating each file first, while other processes read it. The copy
is atomic now.

## Open

### Dropped by Arham, 2026-09-29 ("not needed")

- **Task 14, Apple preset refit.** `GlassMaterial.regular` and `.clear()`
  do not look like iOS side by side (Arham, 2026-09-28), and frost bites
  harder than its number suggests. No refit, no rename.
- **Task 15, device benchmark budgets.** `benchmark/budgets.json` is still
  seed values, not measurements.

### Arham's calls, defaults kept

- **M14, controls pick some of their own colours.** The switch's green
  track (an approximate system green) and white knob, the white slider
  thumb and segmented pill. There is no accent system yet.
- **The rim fold.** The edge band maps backwards for a few pixels just
  inside the rim, then stalls, before it reads 1:1. That is x 21–24 at
  `edgeRefraction` 24, 21–28 at 40 and 21–32 at 60, 1:1 by about x 36,
  45 and 55. Kept as is. Numbers in `task-3-report.md`.
- **Holding a tab differs from iOS.** A resting finger swells the pill and
  raises no lens. This was the conservative choice, so the lens is glass on
  glass only while it travels. iOS's timed hold is the alternative.

### Needs a device

- **Physical-iPhone check for flutter#187820.** Two things to look at:
  - The tab-bar lens in flight is glass over the bar's glass, a bounded,
    declared overlap.
  - The I1 residual, still true. The bars' layer has one pass and no clip
    of its own, so its filter reads the body under it, including body
    glass output, where the bars draw nothing. Also, the bar heights are
    measured a frame late, so on the scaffold's first frame the body's
    glass band spans the whole screen.
- **Switch and segmented control dimensions** are not measured against an
  iOS capture.

### Known limits, documented

- `kMaxShapes` is 8 **per cluster**: shapes whose mattes could meet, and
  every shape in one blend group, share a cluster. Past eight in one
  cluster the extras are not drawn, and a debug warning says so. Raising it
  needs the uniform probe re-run on the weakest backend
  (`kMaxShapesProvenance`).
- `Glass.containsChild` is accepted and not wired.
- Backdrop luminance for surface adaptation is caller-supplied.
- The tab bar has no maximum width.
- `GlassDetentSheetController.settleMotion` carries the `present` role's
  spring, which is right, but its public doc does not say so. The reason
  is only on the private `_syncSettleMotion`.

### Not done by batch C, and why

- **Optional duplication the audit said to keep:** the painted stand-ins,
  hole rects and semantics.
- **`toImage` readback:** a readback of a boundary holding a glass layer is
  followed by one matte bake on the next frame. Observed, not
  investigated. The carry-over tests settle after a readback before they
  count.

### Publishing

`flutter pub publish --dry-run` passed on `main` (2026-09-28). Publishing
is Arham's call, after this branch merges.

## Working notes

- Hot restart without a TTY: run with `--pid-file <path>`, then
  `kill -USR2 $(cat <path>)`. Wait for a *new* `Restarted application` line
  before screenshotting.
- A changed asset manifest hangs hot restart; relaunch instead.
- Off Impeller, the runtime geometry producer bakes on the CPU in seconds.
  A widget test that animates a large glass surface builds its `GlassLayer`
  with `tier: GeometryTier.none`.
- `flutter analyze` from the root covers `example/` too, but only after
  `flutter pub get` has run inside `example/`.
- Compare commits in pinned `git worktree`s, never in the main checkout.
- Prove a guard fails by breaking what it guards.
