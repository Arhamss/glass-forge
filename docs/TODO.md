# Where glass_forge stands — 2026-09-23

Resume file. Updated at the end of a working session; read it first.

## State

Branch `main`, **not pushed** (`origin` is a local `.bundle`, and there is
no GitHub repository yet). Six iOS files are dirty in the working tree and
are deliberately uncommitted — see "The example cannot build for iOS" below;
they are a workaround, not a preference, and what to do about them is
Arham's call.

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
- `flutter test` — **600 passed, 24 skipped, 0 failed**. The old 527 figure
  predates the catalogue; +73 is the catalogue's own tests, and nothing
  regressed.
- `flutter test --tags impeller --run-skipped --enable-impeller` —
  **82 passed, 2 skipped, 1 failed**: the pre-existing `GpuGeometryProducer`
  fail-soft in `test/src/rendering/render_glass_layer_test.dart`. Any other
  failure is new.
- `cd example && flutter test` — **150 passed, 0 skipped**. Note
  `example/test/snippet_compiles_test.dart` alone takes about six minutes: it
  mounts a real mirror of all 33 snippets, and the heavy entries pump a real
  backdrop pass at roughly 17s each. **Tell CI.**
- `dart format --set-exit-if-changed --output=none .` — exit 0, but only
  after `48aded3`. It was **already failing** on
  `test/src/composition/glow_gating_test.dart` before this session's last
  task touched anything — a `dart_style` splitting rule, not line length.
- **The example does NOT build for iOS from a clean checkout.** See below.
  A simulator run was only achieved with a throwaway shim. The old note that
  it "runs on the iPhone 17e simulator and renders correctly" is withdrawn.
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

## Known problems, none of them fixed

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

- **The example does not build for iOS from a clean checkout.** Found during
  Task 12's simulator run, and verified at source afterwards — this is not
  the 60-second cold-resolution timeout that looks similar.

  `example/ios/Runner.xcodeproj/project.pbxproj:58` holds a folder reference
  with `path = ../../ios/glass_forge`. Xcode resolves that as a local Swift
  package, and its manifest — `ios/glass_forge/Package.swift:15` — declares
  `.package(name: "FlutterFramework", path: "../FlutterFramework")`. That
  sibling directory only exists when Swift Package Manager generates it, and
  `flutter config` has `enable-swift-package-manager: false`. So `xcodebuild`
  fails resolving `<repo>/ios/FlutterFramework`, which does not and will not
  exist.

  **This is why the example flipped to CocoaPods**, and it explains the
  untracked `example/ios/Podfile` and modified xcconfigs that reappear after
  every iOS run. Those files are not a stylistic question about whether to
  track CocoaPods artifacts — they are the workaround keeping an otherwise
  unbuildable iOS target alive.

  Task 12 got a simulator run only by creating a throwaway `ios/FlutterFramework`
  shim and deleting it afterwards. **The clean-checkout build is still
  broken.** Two coherent fixes: enable SPM and let it generate the sibling, or
  drop the local-package folder reference from the pbxproj and let CocoaPods
  own the plugin properly, tracking the `Podfile` that follows from it.

- **A hard-edged grey smear on the first `GlassSurface.control` of an entry
  page.** Seen on the simulator across three different entries, roughly
  150x40pt, always the **first** control and never the second, present before
  any knob is touched.

  It reads as a stale backdrop region, which makes flutter#187820 — stacked
  backdrop filters sampling the previous frame's backdrop, already recorded
  below — the obvious suspect. **It is not confirmed as that.** Evidence both
  ways, gathered during Task 12's review and checked at source here:

  *For.* **The precondition is present, and the README's own rule does not
  prevent it.** `_pushBackdropPasses` (`lib/src/rendering/render_glass_layer.dart:932-946`)
  pushes one `BackdropFilterLayer` **per material pass**, as siblings over the
  whole layer rect. An entry page has at least two materials — the specimen
  and its `GlassSurface.control` — so two backdrop filters really are stacked
  over the same region *even though no two shapes overlap*. The README's rule
  about overlap governs **shapes**, not **passes**. Worth stating plainly,
  because the invariant everyone has been reasoning from does not cover this.

  *Against.* The smear is hard-edged, static, and present from the first
  frame. flutter#187820 is a progressive white wash that builds over
  successive frames.

  *The pattern is positional, not control-type.* The obvious benign
  explanation was falsified: `GlassDetentSheet`'s first knob is a `double`
  slider while `GlassMaterial`'s and `GlassTierEngine`'s are segmented
  controls, and the smear lands on the first either way. That points instead
  at `_clipChain.collect(firstShape, this)`
  (`render_glass_layer.dart:737-741`), where the **entire pass's retained clip
  chain is collected from `scene.firstShapeOwner` alone**. Look there before
  filing this under #187820.

- **`_events`'s `handleError` cannot catch what it documents, and its doc
  comment says the opposite.** `lib/src/platform/glass_forge_method_channel.dart:102`
  explains the choice of `handleError` over a `try` by saying "the failure
  arrives as the first event, after the stream is already open". It does not.
  `EventChannel.receiveBroadcastStream`'s `onListen` reports a failed
  activation through `FlutterError.reportError`, not by adding an error to the
  stream — so the `handleError(..., test: (e) => e is MissingPluginException)`
  one line below never sees it.

  The intent is right and stated in the comment above it: "a platform with no
  implementation must look like a platform with nothing to say, not like an
  error a consumer has to catch." On a host with no plugin — Windows and
  Linux, per that file's own comment — it currently looks like two red errors
  instead.

  Found while building the catalogue's snippet guard, whose
  `GlassTierEngine` mirror has to answer both event channels with null or the
  test reads two `MissingPluginException`s instead of the snippet. That mock
  is a real necessity for the test, but it also hides this.

  **Verified to the extent of the comment and the mechanism, not on a
  plugin-less host.** Whoever fixes it should confirm on Windows or Linux
  first, then either catch it where Flutter actually raises it or correct the
  comment to say the failure is unreachable from here.

- **A `sizeAccessAllowed` assertion fires when one catalogue entry page
  replaces another in place — culprit unidentified.** Recorded because it
  reproduces, not because it is understood. Latent, not live: no route in the
  example replaces an entry page without a key, and it has only ever been
  seen under `flutter test`, never on a device.

  Verbatim:

  ```
  'package:flutter/src/rendering/box.dart': Failed assertion: line 2268
  pos 11: 'sizeAccessAllowed': RenderBox.size accessed beyond the scope of
  resize, layout, or permitted parent access. ... If you hit this assert
  trying to access a child's size, pass "parentUsesSize: true" to that
  child's layout() in RenderGlassMotion.performLayout.
  ```

  **`RenderGlassMotion` is the victim, not the culprit, and the trailing
  `.performLayout` is template text.** `box.dart:2274` builds that sentence
  with `objectRuntimeType(this, 'RenderBox')`, where `this` is the box whose
  `size` getter was *read*. So the message names `RenderGlassMotion` because
  `RenderGlassMotion.size` was accessed, and then phrases the remedy as
  though the reader were the victim's parent. `RenderGlassMotion` has no
  `performLayout` override at all — it is a `RenderProxyBox`, and
  `RenderProxyBoxMixin.performLayout` already passes `parentUsesSize: true`.
  Anyone chasing this must ignore the class name in the message and find what
  `RenderObject.debugActiveLayout` actually was.

  **Reproduction.** A throwaway widget test looping every catalogue entry
  that has an option knob, pumping `MaterialApp(home: GlassLayer(child:
  CatalogueEntryPage(entry: entry)))` then `pumpAndSettle()`, **with no key**,
  so elements are reused between pumps. It fires on the pump replacing the
  `GlassMotion` page with the `GlassReduceMotion` one. Pumped alone,
  `GlassReduceMotion` is clean; wrapping each page in a `KeyedSubtree` reaches
  the same transition and is also clean. So it needs element reuse across
  that specific transition.

  **What is missing is the stack.** The only capture so far used
  `tester.takeException()` and kept the message alone. To locate it, install
  `FlutterError.onError` and read `details.stack` — which will name the object
  actually laying out.

- **`GlassDetentSheet` notifies its controller from inside its own build,
  so a sibling that listens to that controller throws "setState called
  during build" on mount.** Found while writing the catalogue's Chrome
  entries, and verified in source rather than taken on report.

  `build` calls `_syncDetents(available)` inside `LayoutBuilder.builder`
  (`glass_detent_sheet.dart:354-357`), which calls
  `_controller.setDetents(...)` (`:311`), which reaches `_publish()` and so
  `notifyListeners()` (`glass_detent_sheet_controller.dart:137-151`). Any
  sibling already built and subscribed — an `AnimatedBuilder` or a
  `FadeTransition` driven by the same controller, which is exactly how a
  caller fades a tab row out as the sheet rises — is asked to rebuild in the
  middle of the build that is still running.

  The deleted `SheetScene` had precisely that shape; `af7556b` added the
  `FadeTransition`, and nothing tested it, so it went unnoticed until the
  catalogue rebuilt the same handoff. The catalogue works around it
  example-side with a listener that defers only that phase.

  The workaround does not generalise. **`GlassScaffold` will hit this the
  moment it automates the covered-surface presence handoff**, which is the
  whole reason that widget is planned — and at that point the deferral has
  to live in the package, not in each caller. The fix belongs in
  `GlassDetentSheet`: resolve detents somewhere that is allowed to notify,
  or defer the publish by a frame.

- **`InteractiveGlass` changes its widget-tree *shape* with its parameters,
  so swapping one for another in the same slot can crash.** Found while
  writing the catalogue's Motion entries.

  `build` wraps its child in a `GestureDetector` only when
  `widget.drag.enabled || widget.onTap != null`:

  ```dart
  if (widget.drag.enabled || widget.onTap != null) {
    result = GestureDetector(
      onPanStart: widget.drag.enabled ? _onPanStart : null,
      ...
    );
  }
  ```

  Two `InteractiveGlass`es that differ only in whether drag is enabled
  therefore produce differently-shaped subtrees. Flutter's element diffing
  tries to update the old element in place, and the mismatch surfaces as
  `RenderGlassMotion.performLayout` failing `sizeAccessAllowed`.

  **The outer `if` buys nothing** — every callback inside is already
  individually nulled when drag is off, so always building the
  `GestureDetector` is behaviourally identical and keeps the tree shape
  stable. That is the fix.

  Reachable by any consumer who swaps a draggable surface for a
  non-draggable one at the same position. The catalogue does not hit it,
  because entries are reached through a `Navigator` push rather than a
  direct widget swap, and the task that found it worked around it test-side
  with a `KeyedSubtree`.


- **A `Glass` under a transform-bearing ancestor that has not been laid out
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

  **Not fixed.** The catalogue example works around it with
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
