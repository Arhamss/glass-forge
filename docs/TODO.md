# Where glass_forge stands — 2026-09-29

Resume file. Read it first; update it at the end of a session. It holds the
current state only; the history is in `git log` and in the ledgers under
`.superpowers/sdd/` (gitignored).

## Branch state

`main` is **22 commits ahead of `origin/main`, not pushed.** They are the
work since Arham's "resolve all apart from real iphone stuff": the tab bar
(always-glass selection after Kibu, painted body at the legible step,
squash inside the bar, `maxWidth` 480), the retuned touch response (drag
stretch, 6 pt press growth, softer glow), the scaffold bars clipped to
their own layers and laid out first, `Glass.containsChild` removed, the
readback rebake fix, themed control and chrome colours
(`GlassTokens.controls`, `GlassTokens.chrome`) and automatic backdrop
sampling (`GlassBackdropSampler`). `CHANGELOG.md` "Unreleased" lists all
of it. Pushing and publishing are Arham's call.

Verified on the final commits (2026-09-29):

- `flutter test`: 965 passed, 31 skipped.
- Impeller lane
  (`flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu -j 1`):
  114 passed.
- Example: 16 passed.
- `flutter analyze` (root and `example/`) and `dart format`: clean.
- `flutter pub publish --dry-run`: no warnings.

## Needs a real iPhone

- **flutter#187820, physically.** Nothing here has been looked at on a
  device since the chrome was reworked.
- **The scaffold bars' hard edge.** Each bar's glass is now clipped at the
  bar's own bounds. A full-bleed bar may show a visible line at its inner
  edge.
- **Switch and segmented control dimensions** against an iOS capture.
- **Press, stretch and glow magnitudes.** They rest on one third-party
  measurement (`liquid_glass_widgets`' 120 fps capture) and Arham's
  feedback. A 120 fps recording of iOS would pin them.
- **Raising `kMaxShapes`.** Needs the uniform probe re-run on the weakest
  backend (`kMaxShapesProvenance`).

## Dropped by Arham, 2026-09-29 ("not needed")

- **Task 14, Apple preset refit.** `GlassMaterial.regular` and `.clear()`
  do not match iOS side by side. No refit, no rename.
- **Task 15, device benchmark budgets.** `benchmark/budgets.json` stays
  seed values.

## Decided and kept

- **The rim fold.** The edge band maps backwards for a few pixels just
  inside the rim, then stalls, before it reads 1:1: x 21–24 at
  `edgeRefraction` 24, 21–28 at 40, 21–32 at 60; 1:1 by about x 36, 45
  and 55.
- **Tab bar labels are not dimmed when unselected.** The body's legible
  step keeps every label at 3:1, and a dimmed label would drop below it.

## Known limits

- `kMaxShapes` is 8 **per cluster** (shapes whose mattes could meet, and
  every shape in one blend group). Past eight the extras are not drawn,
  with a debug warning.
- The backdrop sampler misses a repaint behind a repaint boundary inside
  the source until `GlassBackdropSampler.markNeedsSample`, and a surface
  that moves while nothing repaints or scrolls keeps its last reading.

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
- A focus change applies in a microtask, and the test binding's `pump`
  draws no frame unless one was scheduled. Call
  `FocusManager.instance.applyFocusChangesIfNeeded()` before a single pump.
- Compare commits in pinned `git worktree`s, never in the main checkout.
- Prove a guard fails by breaking what it guards.
