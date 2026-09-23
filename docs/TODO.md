# Where glass_forge stands — 2026-09-23

Resume file. Updated at the end of a working session; read it first.

## State

Branch `main`, **not pushed** (`origin` is a local `.bundle`, and there is
no GitHub repository yet). The six dirty iOS files that used to sit here
uncommitted are gone. The clean-checkout iOS build is fixed at source, so
the CocoaPods integration that had been standing in for it was discarded
rather than committed — see "The iOS build" under Verified.

**Sub-project A (foundations) shipped**, and the example app has been rebuilt
as a **catalogue of 33 named entries across 7 groups** — index → detail, each
entry a live specimen with knobs and a copyable snippet. Spec at
`docs/superpowers/specs/2026-09-20-example-catalogue-design.md`, plan at
`docs/superpowers/plans/2026-09-20-example-catalogue.md`. All 12 plan tasks
are complete; the execution ledger, with every ruling made along the way,
is at `.superpowers/sdd/2026-09-20-example-catalogue/progress.md`
(gitignored).

Entry counts, which `example/test/index_page_test.dart` now pins: Surfaces 6,
Shapes 4, Motion 7, Composition 4, Chrome 4, Design system 5, Adaptation 3.

The repository is now one package at its root: `lib/ shaders/ test/
benchmark/ hook/ android/ ios/ macos/ example/ docs/` with `pubspec.yaml`,
`README.md`, `CHANGELOG.md`, `LICENSE` beside them. No pub workspace;
`example/` resolves on its own through `path: ../`. `.pubignore` keeps
`CLAUDE.md`, `PROJECT_BRIEF.md` and `docs/` out of the published archive.

## Verified

All re-run on 2026-09-23 against current `main`, and independently
re-run by a second agent, which got the same numbers:

- `flutter analyze` — clean, at the root and in `example/`.
- `flutter test` — **613 passed, 24 skipped, 0 failed**. The old 527 figure
  predates the catalogue; +73 is the catalogue's own tests, and nothing
  regressed.
- `flutter test --tags impeller --run-skipped --enable-impeller` —
  **82 passed, 2 skipped, 1 failed**: the pre-existing `GpuGeometryProducer`
  fail-soft in `test/src/rendering/render_glass_layer_test.dart`. Any other
  failure is new.
- `cd example && flutter test` — **157 passed, 0 skipped**, about 6m30s. Note
  `example/test/snippet_compiles_test.dart` alone takes about six minutes: it
  mounts a real mirror of all 33 snippets, and the heavy entries pump a real
  backdrop pass at roughly 17s each. **Tell CI.**
- `dart format --set-exit-if-changed --output=none .` — exit 0, but only
  after `48aded3`. It was **already failing** on
  `test/src/composition/glow_gating_test.dart` before this session's last
  task touched anything — a `dart_style` splitting rule, not line length.
- **The iOS build — fixed on 2026-09-23.** `cd example && flutter build ios
  --simulator` and `flutter run -d <iPhone 17e>` both succeed from a clean
  checkout, verified in a throwaway `git worktree` before the fix went on
  `main` and again on `main` afterwards. The app launches and serves
  DevTools. No shim, no manual step.

  The cause was two stray `PBXFileReference` wrappers in the pbxproj's
  Flutter group — `glass_forge` at `../../ios/glass_forge` and
  `FlutterFramework` at `Flutter/ephemeral/Packages/.packages/`. Neither
  carried a build role; they were navigator entries. Xcode still resolved
  the first as a local Swift package, and its manifest asks for a sibling
  `../FlutterFramework` that only exists next to the *symlinked* copy under
  `Flutter/ephemeral/Packages/.packages/`, never next to the real source
  directory. Deleting the four lines fixes it under both dependency
  managers. **A consumer cloning the repo does nothing:** Swift Package
  Manager is `enabledByDefault: true` on Flutter stable, so the default path
  needs no CocoaPods at all and builds in about 18s.
- The example's web build (CI's SkSL gate) — *not re-verified this session.*
  Carried over from the `a522eb4` checkout and possibly stale.

**Ten tests written during this work read as correct while asserting
nothing**, across five distinct causes. The lesson is recorded in full in the
ledger; the short version is that the best single tell is **an expected value
sourced from the thing under test**, and that a guard's ability to fail is
established by breaking the code it guards, never by reading it.

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

## C5 landed — `GlassDetentSheet`, out of order

**C5, `GlassDetentSheet`** — the Apple Maps sheet, requested the same day
from an Expo write-up of the behaviour and specced as the hardest widget in
the document. It has landed: `lib/src/chrome/` (`GlassDetent`,
`detent_geometry.dart`, `GlassDetentSheetController`,
`GlassSheetScrollPhysics`, `GlassDetentSheet` itself), a scene in the
example (`example/lib/src/scenes/sheet_scene.dart`), a
`test/readme_examples_test.dart` guard on its class-doc example, and a
`CHANGELOG.md` entry. Plan:
`docs/superpowers/plans/2026-09-20-glass-detent-sheet.md`.

**It landed ahead of C4, C1, C2 and C3, deliberately.** The documented order
below is A → B → C4 → C1 → C2 → C3 → C5 → D; C5 jumped the queue to land
first among the chrome sub-project's five widgets. `GlassScaffold` (C4),
the tab bar (C1), the app bar (C2) and the sheet-presentation controller
(C3) are all still unwritten — nothing in this section describes work done
on them. One consequence: the presence handoff C5 needs a bottom bar for is
wired by the example app itself, not by any scaffold, because there is no
scaffold yet. See "Known gaps" below.

**A correction to the spec, worth knowing before trusting
`GlassRenderCounters` here.** C5's test list asks for "one matte produce for
the whole drag, not one per frame" — that is not achievable.
`RenderGlassLayer._refreshMatte` rebakes whenever a registered shape's
geometry changes, and this sheet resizes and morphs its radius every frame
of a drag by design, so a per-frame rebake while a finger is down is the
honest cost. What is tested instead: one backdrop pass for the sheet across
the whole drag, never two; and a settled sheet — resting at a detent,
registering unchanged geometry — bakes nothing per frame.

**Off Impeller, this geometry producer is slow enough to stall a session.**
Outside Impeller, the runtime geometry producer runs the SDF over a shape's
bounds on the CPU, measured at 2–6 seconds per bake and rising with the
shape's size, once per frame for every frame it moves. A widget test that
animates a large glass surface — this sheet included — must build its
`GlassLayer` with `tier: GeometryTier.none`, or the file takes tens of
minutes and reads as a hang. This stalled one implementer during this plan;
see `test/src/chrome/glass_detent_sheet_test.dart`'s `_layer` helper for the
pattern that avoids it.

**Known gaps, left deliberately.** Each is its own task and none blocks the
sheet being useful:

1. `GlassDetent.content()` is not measured — nothing measures the child yet,
   so a content detent resolves to the available height (the documented
   fallback in `GlassDetentContent.resolve`).
2. The bottom-bar presence handoff is wired by the app, not by the sheet.
   `presenceUnder` exists and is tested; `GlassScaffold` (C4) is what will
   call it automatically once it exists. Until then the example does it by
   hand, and that hand-wiring is also the honest documentation of what C4
   will be doing. The *arrangement* is no longer untested, though: the
   sheet's gap clearing the bar and the ramp reaching zero before their
   glass meets is pinned by
   `test/src/chrome/sheet_presence_handoff_test.dart`, built against the
   package alone, because the first hand-wiring of it in the example was
   wrong at every detent and nothing caught it.
3. There is no overdrag past the top detent. `dragBy` clamps.
   `GlassOverdrag` is the right tool the day a rubber band past the top, or
   a drag-to-dismiss below the bottom, becomes a wanted gesture.
4. ~~`GlassDetentSheet.gap` is one number for all three edges.~~
   **Fixed 2026-09-21.** `gap` now means the side edges and a new
   `bottomGap` means the bottom, defaulting to `gap` so a sheet floating
   over nothing is unaffected. Both still close to 0 together, so a flush
   sheet is flush on every edge however far apart they started. The sheet
   scene now leaves the sides at the widget's default and raises only the
   bottom to clear its 52 pt tab row, recovering the 104 pt of width the
   shared number was costing it. Pinned by
   `test/src/chrome/detent_geometry_test.dart` (the two insets ramp on
   their own scales) and `sheet_presence_handoff_test.dart` (the clearance
   still comes from the bottom edge alone, with a 16 pt side inset).
5. `GlassDetentSheetController.settleMotion` carries the **`present`** role's
   spring, not `GlassMotionRole.settle`'s. That is deliberate and correct —
   `GlassSurfaces.sheet` names `present`, and `settle` defaults to
   `bouncy()`, which would spring the sheet past its detent — but the field's
   name says otherwise and its own doc never mentions `present`. The clash is
   explained only on the private `_syncSettleMotion`. One sentence on the
   public field closes it.
6. `_GlassDetentSheetState._releaseSettleMotion` compares springs **by
   value**, so on dispose it clears a caller's pinned spring whenever that
   pin happens to equal what the widget pushed. Under a retuned theme such a
   caller's controller then falls back to the untuned default rather than to
   what they asked for. Contrived and self-inflicted; the alternative is a
   second ownership flag on a public class, which was judged the worse
   trade.

## Order, and where the plans are

A1 → A4 → A2 → A3 → B1 → B2 → B3 → B4 → B5 → C4 → C1 → C2 → C3 → C5 → D —
the documented order. **Not the order taken**: C5 landed before C4, C1, C2
and C3, see above.

- **Sub-project A** — plan written:
  `docs/superpowers/plans/2026-09-18-glass-widgets-a-foundations.md`.
  Nine tasks: presence through `uSurface.z` (1–3), `GlassHostScope` and the
  overlap warning (4–5), anchored press-stretch (6–7), the touch glow
  uniform and its driver (8–9). **Essentially complete — all nine tasks
  have landed in `lib/`** (`GlassPresence`/`GlassPresenceScope`,
  `GlassHostScope`, the debug-only cross-pass overlap warning,
  `GlassPressStretch`/`GlassMotionState.pressAnchor` wired through
  `InteractiveGlass`, and `GlassGlow`).
- **Sub-projects B, C, D** — no plans yet. Write each one when the one
  before it lands.

## Known problems, struck through as they are fixed

- **Overscrolling the catalogue index emits 14 glass-over-glass overlap
  warnings.** Found when the overscroll workarounds were removed (`fca850e`).
  They are absent without the stretch, and the pairs named sit in *different*
  backdrop passes even though the rows declare no material of their own —
  which is not what the warning is supposed to fire on. Either the warning is
  over-reporting under a stretch transform, or the stretch is genuinely
  putting two passes over the same pixels. Nobody has established which.

- ~~**The retained clip chain was collected from one arbitrary shape, and
  cropped whole pages.**~~ Fixed by `f85863c`; `collect` now takes every
  shape in the pass and keeps only clips they all sit under.

  Worth keeping because of how it was found and what it says about the tests.
  The catalogue index rendered as the bare photograph plus a single 44x44
  glass square — no bar, no rows, no text — while **all 613 package tests and
  154 example tests passed.** Every existing test of that mechanism asserts on
  the mechanism (chain length, an entry's rrect, where one square landed);
  none asserted that anything *else* on screen survived. **The missing class
  is negative space: "this clip did not eat the rest of the frame."** The new
  test closes it for the multi-shape case, not in general.

  `62bb1d6` **exposed** this rather than introducing it: before it, the
  layout-time walk threw against the unsized `FittedBox`, so rows never
  registered and the chain was empty *because the shapes were missing*, not
  because it was right. For an index-shaped tree, `472dc44` gives 13 framework
  errors, 10 shapes, 0 retained clips; `63857f7` gives 0 errors, 14 shapes, 2.

  **Two residuals, documented rather than quietly fixed.** A clip that every
  shape *does* sit under is still re-pushed around the subtree, so non-glass
  siblings under the same `GlassLayer` can still be cropped — the subtree
  needs no retained clip at all, but moving it also moves the layer's bounds
  clip, which is a behaviour change with its own test surface. And a clip
  private to one shape is now dropped rather than honoured, so that shape's
  backdrop can bleed past its box — strictly better than cropping the page,
  and the real answer is the per-pass clipping `_pushBackdropPasses` flags.

- ~~**Swapping a `GlassBlendGroup` for an `InteractiveGlass` in one slot
  threw "are not in the same render tree".**~~ Fixed by `62bb1d6`, and
  recorded here only because it was never written down as a bug before it
  was fixed — it was found while confirming a different one, and without
  this note the fix's value is invisible.

  Verified as a **package** bug rather than a catalogue symptom, with a bare
  repro carrying no catalogue code: one `GlassLayer`, a `GlassBlendGroup` of
  two ovals swapped in place for an `InteractiveGlass`, no key. At `472dc44`
  it raised `RenderGlassLayer#… NEEDS-PAINT and RenderGlassShape#… are not
  in the same render tree.`; at `0afb36f` it is clean, and `62bb1d6` is the
  only non-docs commit between those runs. So any consumer swapping a blend
  group for an interactive surface in one slot could hit it.

  It was **one-directional**: the reverse swap was clean even at `472dc44`.
  Worth knowing, because a symmetric-looking API with an asymmetric failure
  is the kind of thing a test written in one direction will miss.

- **A `Glass` in a scrolled lazy list keeps stale geometry.** Found while
  fixing the paint-time transform walk (`62bb1d6`), and **not caused by it** —
  the same probe gives the same numbers with that fix reverted. The
  exceptions it removed were hiding this.

  `ListView` wraps each row in a `RepaintBoundary`, and scrolling re-lays out
  nothing, so a scrolled row neither paints nor lays out. It therefore never
  re-registers its transform. Measured after a fling: rows that should sit at
  y = 2.6, 102.6 and 202.6 register at **467.5, 518.8 and 567.5** — the
  positions they held when they were last painted.

  What a user sees is refraction sampling the wrong part of the backdrop for
  any glass row that has been scrolled without repainting. It wants its own
  task; the fix is presumably to re-register on scroll, or to make the layer
  re-read transforms it has not seen painted this frame.

- **The `FittedBox` bug has two exception shapes, and the guards only know
  one.** Instrumenting the index test caught **14** errors: **9** are
  `_AssertionError … 'hasSize'` with no sliver frame, and **5** are
  `_TypeError: Null check operator used on a null value` with
  `RenderSliverMultiBoxAdaptor` in the stack and no `hasSize` in the message.

  The three per-group guards in `example/test/catalogue_test.dart`
  (`:1063`, `:1995`, `:2543`) match on the literal string
  `"Failed assertion: line 2251 pos 12: 'hasSize'"`. So they would
  **mis-classify the sliver form as a regression** — the one thing those
  guards exist to distinguish. They also pin a Flutter SDK line number, which
  will drift on any SDK bump. The newer index test matches the stack
  (`_syncGeometry` + `getTransformTo`) instead, which is the better shape.

  Two follow-ups: widen the three guards to the stack-based match, and record
  the null-check form alongside the `hasSize` one in this file's description
  of the bug above.

- **`_hex` is written out three times verbatim** — `entries/adaptation.dart:107`,
  `entries/chrome.dart:127`, `entries/design_system.dart:40`. Its home is
  `example/lib/src/backdrop_info.dart`, which already owns `BackdropInfo` and
  `backdrops` and is the sole source of every colour in the example. Recorded
  here rather than left in a review report, because the fourth copy is what
  happens otherwise.

- **The line-length rule is 80, not 79, and nothing enforces it.**
  `docs/superpowers/specs/2026-09-14-glass-widgets-design.md:50` is the only
  statement of it: "`very_good_analysis`, 80-character lines, no `// ignore:`".
  **79 appears nowhere in any spec or plan — it was my own error, propagated
  through every dispatch this session.** The practical damage is small, since
  79 is stricter than 80 and all the work is compliant either way, but commit
  `610d14b` reflowed five lines that were exactly 80 characters and therefore
  already correct.

  `dart format`'s default width is 80, so `analyze` and `format` both pass
  lines at 80 and neither catches 81+. **37 lines of exactly 80 characters
  live under root `lib/` and `test/`** — all legal under the real rule.
  If the intent is to make the limit enforced rather than aspirational, the
  change is `formatter: page_width: <n>` in `analysis_options.yaml`; applied
  at 79 in a throwaway worktree it reformats **24 files, +245/−161**, all
  under root `lib/`/`test/` and none under `example/`. Mechanical re-splitting
  with no semantic risk, but big enough to want its own commit — and worth
  confirming the number with Arham first, since the documented rule is 80.

- **An iOS run still dirties four tracked files on this machine.** The build
  itself is fixed; this is what is left of it, and it needs one decision
  from Arham.

  `~/.config/flutter/settings` here carries
  `"enable-swift-package-manager": false` — a global, per-user opt-out, set
  at some point on this machine. Swift Package Manager is on by default on
  Flutter stable, so every consumer takes the SPM path and generates
  nothing. This machine takes the CocoaPods fallback instead, and `pod
  install` writes the Pods include into `Flutter/Debug.xcconfig` and
  `Flutter/Release.xcconfig`, a `Pods.xcodeproj` reference into
  `Runner.xcworkspace`, and about 110 lines of Pods integration into the
  pbxproj. `Podfile` and `Podfile.lock` are now gitignored, so they stay
  quiet, but those four tracked files reappear as modified. Two of them —
  the xcconfigs — come back on a bare `flutter pub get` in `example/`, not
  just on a build, so `flutter analyze` there is enough to dirty the tree.

  Flutter itself says not to live this way. On an SPM-enabled build against
  the CocoaPods-integrated project it prints: *"All plugins found for ios
  are Swift Packages, but your project still has CocoaPods integration …
  Removing CocoaPods integration will improve the project's build time."*
  That is why the CocoaPods artifacts were discarded rather than committed
  — committing them would force the CocoaPods gem on every consumer and
  pin a `Podfile.lock` that fails the `[CP] Check Pods Manifest.lock` phase
  on the next Flutter bump.

  **The one-line fix, which needs Arham's nod because it is outside the
  brief's allowed paths:** a `config: enable-swift-package-manager: true`
  entry under `flutter:` in `example/pubspec.yaml`. Project-level config
  outranks both the global setting and the `FLUTTER_SWIFT_PACKAGE_MANAGER`
  environment variable, so it pins every machine to the same path the
  default consumer already takes. Measured in a worktree: build drops from
  ~45s to ~18s, no `pod install`, and the tree is clean after a run.
  Alternatively, `flutter config --enable-swift-package-manager` on this
  machine has the same effect without a repository change — but only here,
  which is why the pubspec entry is the better of the two.

- ~~**A hard-edged grey smear on the first `GlassSurface.control` of an
  entry page.**~~ **Not a defect — it is the photograph.** Investigated on a
  booted simulator with `xcrun simctl io` screenshots and pixel reads, not
  from source.

  The catalogue backdrop has a dark rocky shoreline crossing exactly the band
  of screen the first control occupies on every entry page; the second control
  sits 50pt lower over the bright aurora, which is why it "never" showed it.
  The hard edge is the opaque painted pill abutting it. Decisive evidence: a
  scan-line comparison of the photograph alone against the same rows seen
  through a control — the control's luminance minimum falls on exactly the
  photograph's minimum, with no displacement. Falsified twice over: remove the
  pill and the region is soft-edged on both sides; declare the *lower* control
  first, making it `firstShapeOwner`, and the band stays on the upper one.

  flutter#187820 was ruled out directly — eight synthetic arrangements over a
  striped backdrop (1/2/3 passes, with and without viewport clip, with and
  without a painted fill) were all clean, and a debug shader painting red on
  out-of-range backdrop samples showed none on the real page. **This file
  previously called that issue "the obvious suspect". It was not.**

- **~~`_events`'s `handleError` cannot catch what it documents~~ — fixed
  2026-09-23.** The mechanism the entry recorded was right, and confirmed
  against the SDK this repo builds on (Flutter 3.47.2,
  `packages/flutter/lib/src/services/platform_channel.dart:693-740`):
  `receiveBroadcastStream`'s `onListen` activates the stream by invoking
  `listen` on a method channel of the same name and hands a failure to
  `FlutterError.reportError`, never to the stream. So neither a `try` around
  `receiveBroadcastStream()` nor a `handleError` on its result could ever
  have seen the `MissingPluginException`. `onCancel` does the same thing
  with `cancel`, so the count was four errors per open-and-close of the two
  channels, not two.

  There is no seam to catch it from outside, so `_events` no longer calls
  `receiveBroadcastStream`. `_openQuietly` owns the broadcast controller and
  does the `listen`/`cancel` invocations itself through `_activate`, which
  swallows a `MissingPluginException` and reports anything else exactly as
  Flutter would. The rest of it mirrors the SDK deliberately, including the
  one-listen/one-cancel shape the host's stream handler expects; that is the
  drift to watch.

  `test/src/platform/event_channel_quiet_test.dart` pins all three claims: a
  plugin-less host reports nothing and adds nothing to the stream, a host
  that fails *inside* its handler is still reported, and an event the host
  sends still arrives through the open-coded decode path. Still not run on
  Windows or Linux — the plugin-less host is reproduced in
  `flutter_test` by registering no mock handler, which is the same
  `MissingPluginException` from the same call.

  The catalogue's snippet guard (`example/test/snippet_compiles_test.dart`)
  answers both event channels with null. That mock existed because of this
  bug and is no longer needed for it, though it is harmless and the mirror
  may want it for other reasons.

- **~~A `sizeAccessAllowed` assertion fires when one catalogue entry page
  replaces another in place~~ — cause found and fixed 2026-09-23.** The
  culprit was `InteractiveGlass`: its `build` wrapped the child in a
  `GestureDetector` only when `drag.enabled || onTap != null`, so its
  subtree had a different *number of elements* depending on its own
  parameters. Replacing one Motion entry page with another in the same
  slot, unkeyed, left Flutter updating an element against a widget of a
  different type. Its own entry above has the fix — the `GestureDetector`
  is now unconditional — and the reasoning for why that costs nothing.

  The entry's warning about the message was right and worth keeping:
  `RenderGlassMotion` is the *victim*, the box whose `size` was read, and
  the trailing `.performLayout` is template text from `box.dart:2274`.
  Nobody should chase `RenderGlassMotion` itself over this message.

  **How it was confirmed**, since the recorded reproduction did more than
  the entry realised. A throwaway test pumped
  `MaterialApp(home: GlassLayer(child: CatalogueEntryPage(entry: entry)))`
  for every entry with a knob, unkeyed, `pumpAndSettle()` between, and —
  unlike the original — cleared and re-read `FlutterError.onError` after
  *each* pump instead of stopping at the first, so one error could not hide
  the rest. Run in a throwaway `git worktree` pinned to a commit, because
  the main checkout had another agent's uncommitted work in
  `lib/src/rendering/render_glass_shape.dart` and that silently made an
  earlier attempt read clean on both sides.

  At `472dc44^`, five transitions reported something: **four**
  `sizeAccessAllowed`, all inside the Motion group — `InteractiveGlass →
  GlassJiggle`, `GlassJiggle → GlassPressStretch`, `GlassPressStretch →
  GlassOverdrag`, and the `GlassMotion → GlassReduceMotion` one this entry
  named. At `472dc44` all four are gone. So this was never one transition;
  it was every adjacent pair of Motion entries whose `InteractiveGlass`
  drag configuration differed.

  **One report at that repro survives, and it is a different bug.**
  `Shapes | GlassBlendGroup → Motion | InteractiveGlass` still raises
  `RenderGlassLayer#… and RenderGlassShape#… are not in the same render
  tree`. Different message, different assertion, unrelated to tree shape —
  recorded here so nobody reads the surviving failure as this one coming
  back. It did not reproduce against the main checkout's working tree,
  which suggests the `render_glass_shape.dart` work in flight on
  2026-09-23 addresses it; worth re-checking once that lands.

- **~~`GlassDetentSheet` notifies its controller from inside its own
  build~~ — fixed 2026-09-23.** The chain the entry recorded was exact:
  `_syncDetents(available)` inside `LayoutBuilder.builder` →
  `_controller.setDetents(...)` → `_publish()` → `notifyListeners()`, and a
  sibling already built and subscribed is not a descendant of the element
  being built, so `markNeedsBuild` on it throws.

  The detents are still resolved where they were, because the available
  height is the one number only layout supplies and the
  `contentHeight: double.infinity` fallback depends on that placement. What
  changed is that `GlassDetentSheetController._publish` holds a
  notification raised during `SchedulerPhase.persistentCallbacks` to the end
  of the frame, and notifies normally in every other phase — drags run in
  the idle phase and ticks in `transientCallbacks`, so neither is deferred.
  Only the notification waits: the heights, the index and the position are
  all in place synchronously, so the sheet's own subtree, built moments
  later inside the same layout pass, still shows the resolved height on the
  very first frame. The frame the siblings lose is the frame before the
  sheet had a height at all.

  `test/src/chrome/glass_detent_sheet_test.dart` — "a sibling listening to
  the controller survives the mount" — mounts an `AnimatedBuilder` on the
  controller beside the sheet, collects `FlutterError.onError` one
  `FlutterErrorDetails` at a time rather than through `takeException`, and
  asserts both that nothing was reported and that the sibling was handed the
  60px the sheet resolved.

  This is the deferral `GlassScaffold` needs, now in the package. The
  catalogue's example-side workaround in
  `example/lib/src/catalogue/entries/chrome.dart` is redundant and can go.

- **~~`InteractiveGlass` changes its widget-tree *shape* with its
  parameters~~ — fixed 2026-09-23.** The entry's diagnosis held exactly:
  `build` wrapped its child in a `GestureDetector` only when
  `widget.drag.enabled || widget.onTap != null`, so two `InteractiveGlass`es
  differing only in that produced differently-shaped subtrees, and an
  in-place element update across the two failed
  `RenderGlassMotion.performLayout`'s `sizeAccessAllowed` assertion.

  The `GestureDetector` is now unconditional, with the per-callback nulling
  it already had left alone. The alternative — keeping the gate and reaching
  for a key — only moves the sharp edge to the consumer, who has no way to
  know it is there.

  **The cost of always emitting it was checked, not assumed.** It is
  nothing on either axis the gate might have been buying:

  - *The arena.* `GestureDetector.build` registers a recognizer only when at
    least one callback of that family is non-null, so a surface with no drag
    and no `onTap` builds an empty `gestures` map,
    `RawGestureDetectorState._handlePointerDown` iterates nothing, and no
    member is added to the arena. It cannot take a gesture an ancestor would
    otherwise win.
  - *Hit testing.* The `Listener` that carries the press was already
    unconditional and already applied `behavior` to this very box, so the
    surface was opaque (or translucent, or deferring) in every configuration
    before this change. The extra proxies repeat a decision already made:
    `RenderProxyBoxWithHitTestBehavior.hitTest` returns whatever its child
    returned for `deferToChild` and `translucent`, and the same `true` for
    `opaque`, so nesting two of identical behaviour and size lengthens the
    hit-test path and changes no outcome.

  Four tests in `test/src/motion/interactive_glass_test.dart`, under
  `_treeShapeTests`: both swap directions in one keyless slot, each
  asserting that no `FlutterErrorDetails` was reported *and* that the
  `State` instance survived (a swap that inflated a fresh element would
  never have exercised the in-place update); plus the two hit-testing
  guards the fix risks — that a plain surface still swallows a tap a
  full-bleed widget behind it would otherwise get, and that a parent
  `onPanStart` still wins over it. Both swap tests fail on the old code with
  the recorded `sizeAccessAllowed` assertion; both guards were shown to bite
  by mutation (unconditional pan callbacks, and a translucent `Listener`).

  A parent *vertical* or *horizontal* drag was tried first as the arena
  guard and proved nothing: it declares victory at `kTouchSlop` while a pan
  is still waiting for `kPanSlop`, so it beats a child pan either way. A
  scrollable ancestor was never at risk; a parent pan is.

  The catalogue's workaround is test-side, not in the entries: the
  `KeyedSubtree` wrappers in `example/test/catalogue_test.dart`'s two
  "every entry mounts and paints" loops (motion and composition). The crash
  those keys were guarding against is gone. Their comments give a second,
  independent reason to keep them — one catalogue page never turns into
  another without a route push, so an unkeyed in-place swap is not what the
  real app does — so they are no longer load-bearing, but whether they go is
  the example's call, not the package's.


- ~~*A `Glass` under a transform-bearing ancestor that has not been laid out
  yet throws on first layout.** Two symptoms found so far, one cause.** Found while building the catalogue example. It is a
  package bug, not an example one, and it hits the headline use case — glass
  chrome over scrolling content.

  ```
  RenderBox was not laid out: RenderTransform NEEDS-LAYOUT NEEDS-PAINT
    RenderTransform._effectiveTransform  (proxy_box.dart:2700)
    RenderTransform.applyPaintTransform   (proxy_box.dart:2783)
  ```

  **Cause.** Material's default scroll behaviour wraps scrollable content in
  a stretch overscroll indicator, which is a `Transform`.
  `RenderGlassShape._syncGeometry` calls `getTransformTo(layer)`, and that
  walk reaches the `RenderTransform` before it has been laid out;
  `applyPaintTransform` then asserts on its own unlaid-out box.

  **Reproduction** — a bare widget test, no example code involved:

  ```dart
  await tester.pumpWidget(
    MaterialApp(
      home: GlassLayer(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverList.list(children: <Widget>[
              Glass(shape: const GlassOval(),
                    child: const SizedBox(width: 200, height: 80)),
            ]),
          ],
        ),
      ),
    ),
  );
  ```

  **Fixed by `62bb1d6`** — the walk moved to paint, which is the one phase
  where it is both permitted and correct. The approach it rules out is
  worth recording: tolerate-and-skip cannot be written release-safely,
  because a third exception shape, `sizeAccessAllowed`, has only debug-only
  predicates (`debugDoingThisLayout`, `debugActiveLayout`), so such a walk
  would register different geometry in debug than in release.

  All three example workarounds are gone (`fca850e`), each proved dead
  first: the override removed, the stretch actually engaged, errors read
  through `FlutterError.onError`, zero in all three. **This entry said
  "Not fixed" for some hours after it was fixed, and on that basis I told
  an agent to keep workarounds it should have removed.** The old text
  described the example working around it with
  `ScrollConfiguration(...copyWith(overscroll: false))` around its scroll
  views, and the same default app-wide in `main.dart`. That is the right move
  for the example and the wrong thing to ask of a consumer: anyone putting
  glass in a scroll view hits this, and the workaround is undiscoverable from
  the error. The real fix belongs in `RenderGlassShape` — either tolerate an
  unlaid-out ancestor during the walk, or defer registration until layout has
  settled. `_scheduleLayerRepaint` in that same file is the nearest prior art.

  **Second symptom, same cause, found later.** `_EntryRow` in the catalogue
  example puts each row's thumbnail in a `FittedBox`, which is also
  transform-bearing. Pumping a populated `CatalogueIndexPage` throws on the
  first frame when a fresh `Glass` specimen beneath it registers geometry
  before the `FittedBox` has laid out — and it is unstable run to run,
  sometimes one self-correcting exception, sometimes several across many
  frames. That instability is why a widget test covering the real index had
  to stand in a simpler widget instead.

  So this is not "handle Material's overscroll indicator". It is: **the
  `getTransformTo` walk in `RenderGlassShape._syncGeometry` must tolerate an
  ancestor that has not been laid out**, whatever put it there — a stretch
  overscroll `Transform`, a `FittedBox`, or a plain `Transform` a consumer
  wrote. Fixing only the overscroll case would leave the other two.

  **How often it actually fires, measured.** Not once on first launch, which
  is what a casual look suggests. It fires on the **first layout of each
  row**, and the catalogue index is a lazy `SliverList`, so ordinary scrolling
  re-triggers it indefinitely. Counting the framework's exception tally in a
  widget test at 393x852: **17** after the first frame, **81** after flinging
  down, **144** after flinging back up, **160** after unmount and remount. The
  thumbnails self-correct visually, which is why it reads as a first-launch
  glitch and why it went unnoticed this long.

  **Third symptom, and the one that raises the priority.** The `FittedBox`
  also imposes unbounded width on whatever it holds. A catalogue entry whose
  specimen is a `Stack` of only `Positioned` children then takes
  `constraints.biggest`, gets infinite width, and never lays out at all —
  found in the Composition group's cross-pass overlap entry, which throws
  permanently under that parent (eight exceptions, `size: MISSING`) where its
  three siblings recover after the first-frame geometry exception. Each entry
  can be written to survive it, and that one will be. But an API whose
  specimens have to be authored around an unbounded-width thumbnail slot is
  an API with a sharp edge, and this is the third distinct way the same
  missing tolerance has drawn blood.

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
- **A4's cross-pass overlap warning (Task 5) briefly false-positived on
  every fresh mount of a glass subtree — cold launch and every tab
  switch — because of where it read geometry from, not because of a bug
  in the example.** Fixed in fix round 2; kept here because the
  investigation is worth knowing about the next time this check surprises
  someone. One real, independent bug was found alongside it and is not
  fixed — see below.
  - **What was wrong.** The check originally ran before the layer's
    subtree painted (task 5's decision 1). `RenderGlassShape.performLayout`
    registers a shape's geometry via `getTransformTo`, but — per the doc
    comment on `RenderGlassShape._syncGeometryIfTransformChanged` —
    that read can miss an ancestor's just-assigned offset, because some
    ancestors (a `Column` positioning a freshly-mounted child, among
    others) assign a child's offset only *after* laying it out.
    `RenderGlassShape.paint`'s own `_syncGeometryIfTransformChanged()`
    always corrects this — but it runs during the subtree's paint, which
    is after where the check used to read. So on any fresh mount the
    check was reading exactly the value `RenderGlassShape` itself
    documents as stale, one paint before that shape's own paint-time call
    fixes it — and the mattes and filters were never built from that
    stale value in the first place: `_pushBackdropPasses` builds them
    only after the subtree has painted, from the corrected geometry. The
    shapes the check warned about never actually rendered overlapping.
  - **Fix: moved the check to after the subtree paints**, at both points
    in `paint()` where that becomes true — the `passes.isEmpty` early
    return (right after its own `_paintSubtree` call) and the tail of
    `_pushBackdropPasses` (right after the filter-build loop, alongside
    the comment that already said "the subtree has painted ... only now
    does the scene describe this frame"). Confirmed empirically, twice:
    - Fix round 1 traced one transition (Blend → Motion) end to end with
      a temporary per-paint dump of `_records`. At the exact paint that
      used to warn, `_records` held exactly the *new* scene's own shapes
      (never the outgoing scene's), which registered wrong-then-corrected
      geometry — `(195, 121.5)`/`(104, 141)` on the first paint,
      `(195, 671.5)`/`(195, 386)` (their real, non-overlapping settled
      positions) on every paint after. This ruled out both "old and new
      scene coexist" and "the shapes really do overlap when settled."
    - Fix round 2, after moving the check, re-ran the same dump against
      the fix: **two full cycles through all five scenes (Lens → Edge →
      Blend → Motion → System → Lens ...), cold launch included — zero
      overlap warnings.** The very first paint after cold launch now
      reads correct, sane, non-overlapping geometry directly (e.g. Lens's
      specimen at `origin=(195, 378.5) size=(260x260)`, its tab bar and
      sheet each in their own real place) — the cold-launch false
      positive is gone too, not just the tab-switch one, because the
      check no longer runs before that shape's own paint-time correction
      has happened even on frame one.
  - **A `GlassPresence` crossfade between scenes would not have fixed
    this** (an earlier version of this entry suggested one). Nothing here
    was ever two scenes' content actually coexisting, so there was
    nothing for a crossfade to sequence.
  - **A related, separately-confirmed, and still-unfixed bug in the
    Blend scene's teardown**, found via the same investigation and
    unaffected by the fix above (still reproduces after it, once per
    cycle through Blend, exactly as before): switching away from Blend
    throws (caught and reported, not fatal) `RenderGlassLayer#...
    NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE and RenderGlassShape#...
    are not in the same render tree`. `RenderGlassShape.detach()`
    unregisters itself from the layer first, which is correct, but then
    calls `_leaveGroup()`, whose `BlendGroupLink.remove()` synchronously
    `notifyListeners()`s — reaching the *other* circle still
    mid-teardown, whose `_onGroupChanged` re-syncs geometry via
    `getTransformTo(_layer)` against an ancestor chain disturbed by the
    same detach cascade. `ChangeNotifier.notifyListeners()` catches and
    reports this per listener rather than rethrowing, so the frame
    survives, but it is a real ordering bug in
    `RenderGlassShape`/`BlendGroupLink`. Follow-up: finish a shape's own
    teardown in `detach()` before notifying its group siblings.

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
