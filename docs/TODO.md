# Where glass_forge stands — 2026-09-30

Resume file. Read it first; update it at the end of a session. It holds the
current state only; the history is in `git log` and in the ledgers under
`.superpowers/sdd/` (gitignored).

## Branch state

`origin/main` has everything up to `300b8ee` (pushed 2026-09-29). On top of
it, **local and not pushed**: the fixes from the iOS 27 simulator round on
2026-09-30. The switch and segmented control are sized to iOS
(`84efef0`). Glass pages and sheets set a real text style, so there are no
yellow debug underlines without a Material ancestor (`b4555ae`). Control
labels name their own size (`f342555`). Pushing and publishing are Arham's call.

Last full verification (2026-09-29, before the simulator fixes):

- `flutter test`: 965 passed, 31 skipped.
- Impeller lane
  (`flutter test --tags impeller --run-skipped --enable-impeller --enable-flutter-gpu -j 1`):
  114 passed.
- Example: 16 passed.
- `flutter analyze` (root and `example/`) and `dart format`: clean.
- `flutter pub publish --dry-run`: no warnings.

## Closed on the iOS 27 simulator, 2026-09-30

- **Switch and segmented control dimensions.** Measured against a native
  SwiftUI build on the simulator: `Toggle` 63 x 28, knob 37 x 24, inset 2,
  on-colour #30D158 (the `appleDark` accent already matched); segmented
  control 32 tall, pill 28, inset 2. Both controls now match (`84efef0`).
- **The scaffold bars' hard edge.** No line at a bar's inner edge at full
  resolution. The rim samples inward, so clipping at the bar's bounds never
  cuts it off.

## Deferred by Arham, 2026-09-30 (needs a real iPhone)

The simulator cannot answer these, and Arham chose to leave them for now.

- **flutter#187820, physically.** Glass-on-glass whitewash only shows on a
  device; the simulator hides it.
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
- On the simulator, run `flutter build ios --simulator --debug` before
  `flutter test integration_test -d <sim>` on a clean checkout, or asset
  bundling fails before the shader-bundle hook has run. A worktree must sit
  in a folder named `glass_forge`: Swift Package Manager takes the package
  identity from the directory name.
- A native reference to measure against: a one-file SwiftUI app compiles
  with `xcrun swiftc -parse-as-library -target
  arm64-apple-ios27.0-simulator -sdk "$(xcrun --sdk iphonesimulator
  --show-sdk-path)"`, plus an `Info.plist` and `codesign -s -`, then
  `xcrun simctl install` / `launch`.
