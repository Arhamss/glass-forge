# Example catalogue — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the example app's scene-based lab bench with a 33-entry
named catalogue — index to detail, each entry showing one capability live with the
exact Dart that builds it.

**Architecture:** One `CatalogueEntry` value type is the single source for
both the live widget and its rendered snippet, so the two cannot drift. The
index lists entries grouped; tapping one pushes a detail page whose glass
materialises through `GlassPresence`. The four sub-project A widgets are
demonstrated by the app's own structure — the transition, the toolbar, the
index rows — before the reader reaches their entries.

**Tech Stack:** Flutter, `glass_forge` (path dependency), Geist / Geist Mono,
no state-management package — the example deliberately uses only Flutter and
this package's own API.

**Spec:** `docs/superpowers/specs/2026-09-20-example-catalogue-design.md`

## Global Constraints

- **Everything on screen is this package's own API or a painted control.**
  The existing example states this and it survives: where the example needs a
  widget of its own it is painted, and it says so. No wrapper layer between
  the reader and `GlassLayer`, `Glass`, `GlassMaterial`, `InteractiveGlass`,
  `GlassSurface`.
- **Never use a lint ignore statement.** Fix the underlying issue.
- **`dart format --set-exit-if-changed` must exit 0** on every file touched.
  CI gates on it and `flutter analyze` does not catch it.
- **`flutter analyze` must stay clean.** The example is analyzed from the
  repository root, but only after `flutter pub get` has run inside
  `example/`.
- **Label colour is never named directly.** Read it through
  `SurfaceInk` (`context.ink`, `context.inkSecondary`) from
  `lib/src/theme.dart`. Writing `Colors.white` throws away the adaptation the
  design system exists to provide.
- **Colours behind glass must be measured, not guessed.** `GlassSurface`
  cannot sample its backdrop; it can only keep labels readable if told what
  is behind them. Reuse the five measured backdrops in `scene.dart`. Do not
  introduce an unmeasured one.
- **Snippets are derived, never hand-written.** See Task 2. A hand-written
  snippet string in any entry is a plan violation.
- **33 entries, per the spec's inventory.** Surfaces 6, Shapes 4, Motion 7,
  Composition 4, Chrome 4, Design system 5, Adaptation 3.
- **The comps are directional, not literal. Three details in them are wrong
  and must NOT be copied** (recorded when Task 1 was approved):
  - **No bottom tab bar.** Both comps show one, and they do not even agree
    with each other on its labels. This design is a flat index→detail with no
    tabbed navigation, and retiring the old app's tab bar is one of the
    reasons the catalogue exists. Reinstating it would be rebuilding the
    thing being deleted.
  - **Use real symbol names.** The index comp shows `GlassGroup`, which does
    not exist; the real name is `GlassBlendGroup`. Every API name rendered in
    the app must be a symbol that actually exists — this is the same failure
    as the `GlassShape.capsule()` that sat in shipped doc comments long
    enough to be copied into a plan.
  - **Seven groups, not four.** The index comp shows Surfaces, Shapes, Motion
    and Composition only. Chrome, Design system and Adaptation exist too, and
    the index must be designed against the real density of 33 entries.
  - Type in the comps is a stand-in: image models cannot render Geist or
    Geist Mono. Carry the pairing intent and use the example's real text
    styles.

- Verification commands, used throughout:
  - `cd example && flutter analyze` then `cd .. && flutter analyze`
  - `cd example && flutter test` (example-local widget tests)
  - `flutter test` from the root for the package suite — baseline **527
    passed, 24 skipped, 0 failed**
  - One Impeller-lane failure (`GpuGeometryProducer` fail-soft in
    `test/src/rendering/render_glass_layer_test.dart`) is pre-existing and
    expected. Any other failure is yours.

---

## File Structure

**Survives unchanged:** `lib/src/theme.dart` (`Tone`, `SurfaceInk`),
`lib/src/backdrop.dart` (`Backdrop`), `lib/src/chrome.dart`
(`SegmentedControl`, `ValueSlider`, `GlassCaption` — the knob toolkit).

**Survives renamed:** `lib/src/scene.dart` → `lib/src/backdrop_info.dart`.
`SceneInfo` becomes `BackdropInfo` with the same fields minus `name`/`blurb`;
the five instances keep their measured `panelBackdrop` / `barBackdrop`.
`SceneShell` is deleted — the entry page replaces it.

**Deleted:** `_SceneTabs`, `_Stage` **and `LensScene`** in `lib/main.dart`
— `LensScene` is inline there rather than in `lib/src/scenes/`, so it is easy
to miss — plus `lib/src/scenes/*.dart`. Their specimens move into entry
declarations first.

| File | Responsibility |
|---|---|
| `lib/src/catalogue/catalogue_entry.dart` | Create: the `CatalogueEntry` and `Knob` value types — the single declaration both the widget and the snippet derive from. |
| `lib/src/catalogue/snippet.dart` | Create: renders a `CatalogueEntry`'s current knob values as Dart source. |
| `lib/src/catalogue/catalogue.dart` | Create: the six groups and their ordered entries. |
| `lib/src/catalogue/entries/surfaces.dart` | Create: the 6 Surfaces entries. |
| `lib/src/catalogue/entries/shapes.dart` | Create: the 4 Shapes entries. |
| `lib/src/catalogue/entries/motion.dart` | Create: the 7 Motion entries. |
| `lib/src/catalogue/entries/composition.dart` | Create: the 4 Composition entries. |
| `lib/src/catalogue/entries/chrome.dart` | Create: the 4 Chrome entries. |
| `lib/src/catalogue/entries/design_system.dart` | Create: the 5 Design system entries. |
| `lib/src/catalogue/entries/adaptation.dart` | Create: the 3 Adaptation entries. |
| `lib/src/catalogue/index_page.dart` | Create: the grouped index, with live thumbnails and the glow on press. |
| `lib/src/catalogue/entry_page.dart` | Create: the detail page — live demo, knobs, snippet. |
| `lib/src/catalogue/snippet_view.dart` | Create: the painted code block, with copy. |
| `lib/main.dart` | Modify: root tier scope kept; stage/tabs replaced by index → detail navigation. |
| `example/test/catalogue_test.dart` | Create: entry/knob/snippet tests. |
| `example/test/snippet_compiles_test.dart` | Create: every entry's snippet compiled. |

---

## Task 1: Reference comps, agreed before any UI code

**Files:**
- Create: `docs/design/2026-09-20-catalogue-index.png`
- Create: `docs/design/2026-09-20-catalogue-entry.png`

**Interfaces:**
- Consumes: nothing.
- Produces: two agreed comps that Tasks 3 and 4 implement against.

This task writes no Dart. "Improved a lot" is the brief, and it is judged
against a comp rather than argued about after the fact.

- [ ] **Step 1: Invoke the mobile comp skill**

Use the `imagegen-frontend-mobile` skill to generate two phone-framed
concepts. Direction, from the spec: **Apple-native, editorial.** Anchors —
iOS 26 Settings and Control Centre for the glass language, Things 3 for
spacing rhythm and restraint, the Apple Developer documentation app for the
index→detail catalogue pattern. Principles only, never identity or assets.

Fixed constraints the comps must respect, because they are already true of
this app:
- Dark, over a full-bleed photograph. The palette is **achromatic** — the
  photograph is the only thing carrying colour (see `Tone` in
  `lib/src/theme.dart` for why an accent hue loses against five different
  photographs).
- Geist for prose, Geist Mono for API names and code.
- Glass chrome at top and bottom; content scrolls behind it.

- [ ] **Step 2: Generate the index comp**

Must show: grouped sections (Surfaces, Shapes, Motion, Composition, Design
system, Adaptation); rows carrying an API name in mono, a one-line purpose in
prose, and a small **live-looking glass thumbnail**; a glass top bar; the
photograph behind.

- [ ] **Step 3: Generate the entry comp**

Must show, top to bottom: the live specimen large over the photograph; the
API name as title in mono; one line of purpose; a knob row (a slider and a
segmented control, per `chrome.dart`); the code block with a copy affordance;
a "see also" row.

- [ ] **Step 4: Present both comps and get agreement**

Stop here. Do not proceed to Task 2 until the comps are approved. If they are
rejected, regenerate against the feedback rather than proceeding and fixing
in code — a comp is cheap and a built screen is not.

- [ ] **Step 5: Commit**

```bash
git add docs/design/
git commit -m "docs(design): reference comps for the catalogue index and entry"
```

---

## Task 2: The entry model and the snippet that cannot drift

**Files:**
- Create: `example/lib/src/catalogue/catalogue_entry.dart`
- Create: `example/lib/src/catalogue/snippet.dart`
- Test: `example/test/catalogue_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class Knob<T>` with `final String name; final T value; final List<T> options; final double? min; final double? max;` and `Knob<T> withValue(T next)`
  - `class CatalogueEntry` with `final String api; final String purpose; final String group; final List<Knob<Object?>> knobs; final Widget Function(List<Knob<Object?>>) build; final String Function(List<Knob<Object?>>) code; final List<String> seeAlso;`
  - `CatalogueEntry withKnob(int index, Object? value)`
  - `String renderSnippet(CatalogueEntry entry)`

**The constraint this task exists to enforce.** A snippet that compiles but no
longer describes the thing rendered beside it is worse than no snippet,
because the reader trusts it. So the entry declares its knobs **once**, and
both the live widget and the code text are functions of that one list. Moving
a knob produces a new entry value; the widget and the snippet are rebuilt
from it together. There is nothing to keep in sync because there is only one
thing.

This rules out a hand-written snippet string per entry. That is the tempting
shortcut and it is exactly what rots.

- [ ] **Step 1: Write the failing test**

Create `example/test/catalogue_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/snippet.dart';

void main() {
  CatalogueEntry entryWithFrost(double frost) {
    return CatalogueEntry(
      api: 'Glass',
      purpose: 'One glass surface.',
      group: 'Surfaces',
      knobs: <Knob<Object?>>[
        Knob<double>(name: 'frost', value: frost, min: 0, max: 24),
      ],
      build: (knobs) => SizedBox(width: knobs.first.value! as double),
      code: (knobs) => 'Glass(material: GlassMaterial(frost: '
          '${knobs.first.value}))',
      seeAlso: const <String>['GlassMaterial'],
    );
  }

  test('the widget and the snippet read the same knob', () {
    final entry = entryWithFrost(8).withKnob(0, 12.0);
    final built = entry.build(entry.knobs) as SizedBox;

    expect(built.width, 12.0, reason: 'the widget reads the new value');
    expect(
      renderSnippet(entry),
      contains('frost: 12.0'),
      reason: 'and so does the snippet, from the same list',
    );
  });

  test('changing a knob cannot move one without the other', () {
    // The drift this design exists to prevent: assert both derive from the
    // same source by checking they agree across several values, not just one.
    for (final value in <double>[0, 4, 16, 24]) {
      final entry = entryWithFrost(0).withKnob(0, value);
      expect((entry.build(entry.knobs) as SizedBox).width, value);
      expect(renderSnippet(entry), contains('frost: $value'));
    }
  });

  test('withKnob leaves the original entry untouched', () {
    final original = entryWithFrost(8);
    original.withKnob(0, 20.0);
    expect(original.knobs.first.value, 8.0);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd example && flutter test test/catalogue_test.dart`
Expected: FAIL — `CatalogueEntry` is undefined.

- [ ] **Step 3: Write `catalogue_entry.dart`**

```dart
import 'package:flutter/widgets.dart';

/// One tunable parameter of a [CatalogueEntry].
///
/// Carries its own range or options so the entry page can render a control
/// for it without the entry describing one — the declaration says what the
/// parameter *is*, not what widget adjusts it.
@immutable
class Knob<T> {
  /// Creates a knob.
  const Knob({
    required this.name,
    required this.value,
    this.options = const <Never>[],
    this.min,
    this.max,
  });

  /// The parameter's name, as it appears in the API.
  final String name;

  /// Its current value.
  final T value;

  /// The choices, for a knob adjusted by a segmented control.
  final List<T> options;

  /// The low end, for a knob adjusted by a slider.
  final double? min;

  /// The high end, for a knob adjusted by a slider.
  final double? max;

  /// This knob with [next] in place of [value].
  Knob<T> withValue(T next) => Knob<T>(
    name: name,
    value: next,
    options: options,
    min: min,
    max: max,
  );
}

/// One capability, shown live with the code that produces it.
///
/// [build] and [code] are both functions of [knobs], which is the whole
/// point: a snippet that says something other than what is rendered beside
/// it is worse than no snippet, because the reader trusts it. Deriving both
/// from one list means there is nothing to keep in sync.
@immutable
class CatalogueEntry {
  /// Creates an entry.
  const CatalogueEntry({
    required this.api,
    required this.purpose,
    required this.group,
    required this.knobs,
    required this.build,
    required this.code,
    this.seeAlso = const <String>[],
  });

  /// The API name. This is the string a reader would search for.
  final String api;

  /// One line on what it is for.
  final String purpose;

  /// Which of the six groups this belongs to.
  final String group;

  /// The parameters this entry lets the reader move.
  final List<Knob<Object?>> knobs;

  /// Builds the live thing from [knobs].
  final Widget Function(List<Knob<Object?>> knobs) build;

  /// Renders the Dart that produces [build]'s result, from the same [knobs].
  final String Function(List<Knob<Object?>> knobs) code;

  /// Other entries worth reading next, by [api].
  final List<String> seeAlso;

  /// This entry with knob [index] set to [value].
  CatalogueEntry withKnob(int index, Object? value) {
    return CatalogueEntry(
      api: api,
      purpose: purpose,
      group: group,
      knobs: <Knob<Object?>>[
        for (var i = 0; i < knobs.length; i++)
          if (i == index) knobs[i].withValue(value) else knobs[i],
      ],
      build: build,
      code: code,
      seeAlso: seeAlso,
    );
  }
}
```

- [ ] **Step 4: Write `snippet.dart`**

```dart
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';

/// The Dart that produces [entry]'s current live widget.
///
/// A thin wrapper over the entry's own `code` function rather than a
/// formatter: the entry owns how its source reads, because only the entry
/// knows which of its parameters are worth showing. What this adds is the
/// single call site, so every consumer renders snippets the same way.
String renderSnippet(CatalogueEntry entry) => entry.code(entry.knobs);
```

- [ ] **Step 5: Run the tests**

Run: `cd example && flutter test test/catalogue_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Verify and commit**

Run: `cd example && dart format --set-exit-if-changed --output=none lib test`
Expected: exit 0.

```bash
git add example/lib/src/catalogue/ example/test/catalogue_test.dart
git commit -m "feat(example): the catalogue entry model and its derived snippet"
```

---

## Task 3: The index page

**Files:**
- Create: `example/lib/src/catalogue/catalogue.dart`
- Create: `example/lib/src/catalogue/index_page.dart`
- Modify: `example/lib/src/scene.dart` → rename to `example/lib/src/backdrop_info.dart`
- Test: `example/test/index_page_test.dart`

**Interfaces:**
- Consumes: `CatalogueEntry`, `Knob` from Task 2.
- Produces:
  - `const List<String> catalogueGroups` — the six group names in order
  - `List<CatalogueEntry> entriesIn(String group)`
  - `class CatalogueIndexPage extends StatelessWidget`
  - `class BackdropInfo` (renamed from `SceneInfo`, `name`/`blurb` removed)

Implement against the index comp from Task 1.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_example/src/catalogue/catalogue.dart';

void main() {
  test('the six groups are present and ordered', () {
    expect(catalogueGroups, <String>[
      'Surfaces',
      'Shapes',
      'Motion',
      'Composition',
      'Chrome',
      'Design system',
      'Adaptation',
    ]);
  });

  test('every group has the entry count the spec promises', () {
    // The spec's inventory is a contract: 29 entries, and these counts. A
    // group that quietly loses an entry is a catalogue that quietly stops
    // covering the API.
    expect(entriesIn('Surfaces'), hasLength(6));
    expect(entriesIn('Shapes'), hasLength(4));
    expect(entriesIn('Motion'), hasLength(7));
    expect(entriesIn('Composition'), hasLength(4));
    expect(entriesIn('Chrome'), hasLength(4));
    expect(entriesIn('Design system'), hasLength(5));
    expect(entriesIn('Adaptation'), hasLength(3));
    expect(
      catalogueGroups.fold<int>(0, (n, g) => n + entriesIn(g).length),
      33,
    );
  });

  test('every entry names a group that exists', () {
    for (final group in catalogueGroups) {
      for (final entry in entriesIn(group)) {
        expect(entry.group, group);
        expect(entry.api, isNotEmpty);
        expect(entry.purpose, isNotEmpty);
      }
    }
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd example && flutter test test/index_page_test.dart`
Expected: FAIL — `catalogue.dart` does not exist.

- [ ] **Step 3: Write `catalogue.dart` as the registry**

It imports the six entry files (created empty-but-valid in this task,
populated in Tasks 5–10) and exposes:

```dart
const List<String> catalogueGroups = <String>[
  'Surfaces',
  'Shapes',
  'Motion',
  'Composition',
  'Chrome',
  'Design system',
  'Adaptation',
];

List<CatalogueEntry> entriesIn(String group) => switch (group) {
  'Surfaces' => surfacesEntries,
  'Shapes' => shapesEntries,
  'Motion' => motionEntries,
  'Composition' => compositionEntries,
  'Chrome' => chromeEntries,
  'Design system' => designSystemEntries,
  'Adaptation' => adaptationEntries,
  _ => const <CatalogueEntry>[],
};
```

Create the seven entry files each exporting an empty
`final List<CatalogueEntry> xEntries = <CatalogueEntry>[];` for now.

**`final`, not `const`, and this is not a style choice.** Every entry carries
`build` and `code` as closure literals, and a closure literal is not a
constant expression in Dart — `const CatalogueEntry(build: (knobs) => ...)`
does not compile. An earlier draft of this plan said `const` throughout; it
was wrong from the start, independently of `CatalogueEntry`'s constructor
also being non-const since its lists became unmodifiable. **The
count test will fail until Tasks 5–10 land** — that is expected and correct;
it is the contract holding the later tasks to the inventory. Mark it
`skip: 'populated by Tasks 5-10'` with exactly that reason, and remove the
skip in Task 10.

- [ ] **Step 4: Write the index page**

Structure, implementing the Task 1 comp: a `Backdrop` photograph; one
`GlassLayer`; a `CustomScrollView` whose slivers are a group header then its
rows; a glass top bar. Each row is an `InteractiveGlass` wrapping a painted
row (API name in Geist Mono via `context.ink`, purpose in
`context.inkSecondary`, a small thumbnail built by `entry.build`).

The rows are `InteractiveGlass` specifically so pressing one lights its
neighbours — `GlassGlow` is per-pass, so rows sharing the layer's material
share the glow. That is the behaviour that justified putting the glow in the
shader, demonstrated by the index itself.

- [ ] **Step 5: Rename `scene.dart`**

```bash
git mv example/lib/src/scene.dart example/lib/src/backdrop_info.dart
```

Rename `SceneInfo` to `BackdropInfo`, delete its `name` and `blurb` fields
and `SceneShell`, keep the five instances and their measured
`panelBackdrop` / `barBackdrop`. Update importers.

- [ ] **Step 6: Run the tests**

Run: `cd example && flutter test`
Expected: PASS, with the counts test skipped for the stated reason.

- [ ] **Step 7: Verify and commit**

Run: `cd example && flutter analyze && dart format --set-exit-if-changed --output=none lib test`

```bash
git add example/
git commit -m "feat(example): the catalogue index"
```

---

## Task 4: The entry page, and `GlassPresence` driving the transition

**Files:**
- Create: `example/lib/src/catalogue/entry_page.dart`
- Create: `example/lib/src/catalogue/snippet_view.dart`
- Modify: `example/lib/main.dart`
- Test: `example/test/entry_page_test.dart`

**Interfaces:**
- Consumes: `CatalogueEntry`, `renderSnippet`, `CatalogueIndexPage`.
- Produces: `class CatalogueEntryPage extends StatefulWidget` taking a
  `CatalogueEntry`; `class SnippetView extends StatelessWidget`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/catalogue/catalogue_entry.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';

void main() {
  final entry = CatalogueEntry(
    api: 'Glass',
    purpose: 'One glass surface.',
    group: 'Surfaces',
    knobs: <Knob<Object?>>[
      const Knob<double>(name: 'frost', value: 8, min: 0, max: 24),
    ],
    build: (knobs) => Text('frost ${knobs.first.value}'),
    code: (knobs) => 'GlassMaterial(frost: ${knobs.first.value})',
    seeAlso: const <String>['GlassMaterial'],
  );

  testWidgets('the page shows the api name, the live thing and the code',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GlassLayer(child: CatalogueEntryPage(entry: entry))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glass'), findsOneWidget);
    expect(find.text('frost 8.0'), findsOneWidget);
    expect(find.textContaining('GlassMaterial(frost: 8.0)'), findsOneWidget);
  });

  testWidgets('moving a knob moves the widget and the snippet together',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: GlassLayer(child: CatalogueEntryPage(entry: entry))),
    );
    await tester.pumpAndSettle();

    final state = tester.state<CatalogueEntryPageState>(
      find.byType(CatalogueEntryPage),
    );
    state.setKnob(0, 20.0);
    await tester.pumpAndSettle();

    expect(find.text('frost 20.0'), findsOneWidget);
    expect(find.textContaining('GlassMaterial(frost: 20.0)'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd example && flutter test test/entry_page_test.dart`
Expected: FAIL — `entry_page.dart` does not exist.

- [ ] **Step 3: Write the entry page**

A `StatefulWidget` holding the current `CatalogueEntry` (knob changes replace
it via `withKnob`), with a public `setKnob(int, Object?)` so the test can
drive it without synthesising gestures against a slider.

Layout, implementing the Task 1 comp: the live widget large over the
photograph; the API name in Geist Mono; the purpose; a knob row built from
`entry.knobs` (a `ValueSlider` when `min`/`max` are set, a
`SegmentedControl` when `options` is non-empty — both from `chrome.dart`);
the `SnippetView`; the see-also row.

- [ ] **Step 4: Write `snippet_view.dart`**

A painted code block — `Tone.captionScrim`, Geist Mono, `context.ink` — with
a copy button using `Clipboard.setData`. Painted, not glass: a second piece
of glass on top of the first is the one composition this renderer cannot
draw, and `theme.dart` already says so.

- [ ] **Step 5: Wire navigation through `GlassPresence`**

**`_Stage` and `_SceneTabs` are already gone** — Task 3 deleted them and
repointed `main.dart`'s `home:` at `CatalogueIndexPage`, because its own
Step 5 removed the symbols every scene depended on. So there is nothing left
to replace: what remains is adding the **route to the entry page** and the
presence handoff.

Two smaller things to fold in while you are in these files, both raised by
Task 3's review:

- `index_page.dart` selects its backdrop as `backdrops[2]`, a bare positional
  index into the list in `backdrop_info.dart`. `BackdropInfo` no longer
  carries a `name`, so there is nothing to match on. You are about to add a
  second consumer, and positional fragility compounds with consumers — add a
  named accessor (keyed off the photo asset path, which is already a unique
  string on each instance) and repoint both call sites at it.
- `catalogue_entry.dart`'s doc comment on `CatalogueEntry.group` still says
  "one of the six groups". There are seven. The entry page's glass materialises by driving
`GlassPresence` from the route animation, and the index chrome's presence
runs to 0 as the entry's rises.

This is a **handoff, not a cross-fade**. Both being partly present at once
means two backdrop filters over one region, which is flutter#187820 — the
exact bug the package exists to avoid. Getting this wrong will also trip the
cross-pass overlap warning, which is a useful signal that it is wrong.

- [ ] **Step 6: Run the tests**

Run: `cd example && flutter test`
Expected: PASS.

- [ ] **Step 7: Verify and commit**

Run: `cd example && flutter analyze && dart format --set-exit-if-changed --output=none lib test`

```bash
git add example/
git commit -m "feat(example): the entry page, with GlassPresence driving the transition"
```

---

## Tasks 5-10: the six entry groups

Each task populates one file's `final List<CatalogueEntry>` (see Task 3 for
why these cannot be `const`). Task 8b adds
`example/lib/src/catalogue/entries/chrome.dart` exporting `chromeEntries`. They share a
shape, so the steps below apply to each; what differs is the inventory, given
per task.


**Where the specimens now live.** Task 3 deleted `example/lib/src/scenes/`
and `LensScene` from `main.dart`. It had to: Task 3's own Step 5 removes
`SceneShell`, `BackdropInfo.name` and `.blurb`, and all five scenes depend on
them, so leaving the scene files in place made `flutter analyze` clean —
Task 3's hard gate — unreachable. This plan's pre-flight scan asserted the
scene widgets would survive until Task 12 and was wrong.

So read specimens out of **git history**, not the working tree:

```bash
git show acd6ee2:example/lib/src/scenes/edge_scene.dart
git show acd6ee2:example/lib/src/scenes/blend_scene.dart
git show acd6ee2:example/lib/src/scenes/motion_scene.dart
git show acd6ee2:example/lib/src/scenes/system_scene.dart
git show acd6ee2:example/lib/src/scenes/sheet_scene.dart
git show acd6ee2:example/lib/main.dart      # LensScene lives here
```

Nothing is lost; it is one command away. Port the specimen's glass
construction into the entry's `build`, and do not port `SceneShell` — the
entry page replaces it.

**Per-task steps, every one of Tasks 5-10:**

- [ ] **Step 1:** Write a test in `example/test/catalogue_test.dart` asserting
  this group's entry count and that every entry's `api`, `purpose` and at
  least one knob are populated, and that `entry.build(entry.knobs)` returns a
  widget without throwing for each entry's default knobs.
- [ ] **Step 2:** Run it; expect FAIL on the count.
- [ ] **Step 3:** Write the entries. Every `code` function must produce Dart
  that actually compiles against the real API — Task 11 will compile them, so
  a guess fails there rather than shipping.
- [ ] **Step 4:** Run the tests; expect PASS.
- [ ] **Step 5:** `cd example && flutter analyze && dart format --set-exit-if-changed --output=none lib test`
- [ ] **Step 6:** Commit, e.g. `git commit -m "feat(example): the Surfaces catalogue entries"`

### Task 5 — Surfaces (6)

`Glass` · `GlassLayer` · `GlassMaterial` (regular / clear / dome, as a
segmented knob) · `GlassVariant` · `GlassProfile` · **Material knobs** (one
entry carrying all eight: refraction, frost, tint, saturation, highlight,
contour, thickness, dispersion).

Starting points: `GlassProfile` and `GlassVariant` come from the Edge scene,
`example/lib/src/scenes/edge_scene.dart`. The whole-surface refraction demo
comes from **`LensScene`, which is declared inline in
`example/lib/main.dart:278`, not in `lib/src/scenes/`** — the only scene
without its own file.

### Task 6 — Shapes (4)

`GlassRoundedRectangle` (radius knob) · `GlassOval` · `GlassSuperellipse`
(radius knob) · `GlassBlendGroup` (separation knob — the Blend scene
specimen, `example/lib/src/scenes/blend_scene.dart`, is the starting point;
sliding two shapes together until they join through a neck is the demo).

### Task 7 — Motion (7)

`InteractiveGlass` · `GlassJiggle` (the Motion scene specimen,
`example/lib/src/scenes/motion_scene.dart`) · `GlassPressStretch` (intensity,
squash, travel knobs) · `GlassOverdrag` (limit, resistance) · `GlassDecay`
(drag) · `GlassMotion` (the spring presets as a segmented knob) · **Reduce
Motion** (a toggle showing each of the above collapsing to its instant form).

### Task 8 — Composition (4)

`GlassPresence` (a presence slider, 0 to 1 — and its entry must state that
the pass is dropped entirely below the epsilon rather than drawn faintly) ·
`GlassHostScope` (the same control rendered on content and on a toolbar, side
by side — the point being that it is one widget) · `GlassGlow` (two adjacent
surfaces; pressing one lights the other, which is the whole reason it is a
shader uniform) · **the cross-pass overlap warning** (an entry that
deliberately overlaps two differing materials and shows the captured
`debugPrint` output on screen).

For the overlap entry, capture the warning by assigning `debugPrint` in
`initState` and restoring it in `dispose`. A diagnostic the reader can watch
fire is worth more than one they read about.

### Task 8b — Chrome (4)

`GlassDetentSheet` (a detent knob — the sheet's three rest heights) ·
`GlassDetent` (fraction, height and content resolution) ·
`GlassDetentSheetController` · `GlassSheetScrollPhysics`.

Starting point: `example/lib/src/scenes/sheet_scene.dart`, added when the
detent sheet landed. Its own doc comment is the entry copy's source — it
explains that the tab row behind the sheet is the actual demonstration,
because nothing wires a covered surface's presence for a caller yet, so the
scene does by hand what `GlassScaffold` will automate.

The `GlassDetentSheet` entry must state that the presence handoff is what
keeps the tab row and the sheet from both being glass over the same pixels.

### Task 9 — Design system (5)

`GlassTheme` · `GlassSurface` with `GlassSurfaces` · `GlassTokens` ·
`GlassTint` · `GlassLegibility`. The System scene
(`example/lib/src/scenes/system_scene.dart`) is the starting point for the
named-surfaces entry.

### Task 10 — Adaptation (3)

`GlassTierScope` with tier degradation (the tier segmented control from the
System scene) · the thermal / frame-rate / accessibility signals · 
`GeometryTier`.

- [ ] **Extra step for Task 10:** remove the `skip:` from the 29-entry count
  test added in Task 3 Step 3 and confirm it passes. That test is the
  inventory contract; it must be live before this plan is done.

---

## Task 11: Compile every snippet

**Files:**
- Create: `example/test/snippet_compiles_test.dart`

**Interfaces:**
- Consumes: `catalogueGroups`, `entriesIn`, `renderSnippet`.

**Why this exists.** `test/readme_examples_test.dart` in the package root
compiles every code block in `README.md` and, since a recent change, every
` ```dart ` block in `lib/` doc comments. It exists because a phantom
constructor — `GlassShape.capsule()`, which never existed — sat in shipped
doc comments long enough to be copied into an implementation plan. Catalogue
snippets are the same hazard with a larger surface.

- [ ] **Step 1: Read the existing guard**

Read `test/readme_examples_test.dart` at the repository root and follow its
technique rather than inventing one. Its header explains the rot it prevents.

- [ ] **Step 2: Write the test**

For each of the 33 entries, a compiled expression equivalent to that entry's
`code` output. Follow the existing file's approach: the snippets are
hand-mirrored into real Dart in the test, so the compiler checks them.

- [ ] **Step 3: Prove the guard works**

Break one entry's `code` to emit a constructor that does not exist. Run the
test, confirm it fails to compile, restore it, confirm green. **Report the
result** — a guard nobody has seen fail is a guard nobody knows works.

- [ ] **Step 4: Run and commit**

Run: `cd example && flutter test`

```bash
git add example/test/snippet_compiles_test.dart
git commit -m "test(example): compile every catalogue snippet"
```

---

## Task 12: Retire the old app, and verify on a device

**Files:**
- Delete: `example/lib/src/scenes/edge_scene.dart`,
  `blend_scene.dart`, `motion_scene.dart`, `system_scene.dart`,
  `sheet_scene.dart`
- Modify: `example/lib/main.dart`, `example/README.md`
- Modify: `README.md` at the repository root, if it describes the scenes

- [ ] **Step 1: Confirm the scene files are already gone**

**Task 3 did this deletion**, including `LensScene`, which was inline in
`main.dart` rather than in `lib/src/scenes/`. It was forced: Task 3 removes
`SceneShell`, `BackdropInfo.name` and `.blurb`, which every scene depended
on, so they could not survive its `flutter analyze` gate.

So this step is now a verification, not a deletion. Confirm
`example/lib/src/scenes/` does not exist and that no `SceneShell`,
`LensScene`, `EdgeScene`, `BlendScene`, `MotionScene`, `SystemScene` or
`SheetScene` reference survives in `example/lib`, `example/test`, the example
README or the root README. A barrel export or an import is not a use.

- [ ] **Step 2: Update the example README and the root README**

Both describe a five-scene app. Rewrite for the catalogue. If the root
README's code blocks change, `test/readme_examples_test.dart` will catch a
mistake — run it.

- [ ] **Step 3: Full verification**

Run, from the repository root:
- `flutter analyze` — clean
- `flutter test` — **527 passed, 24 skipped, 0 failed**, unchanged
- `flutter test --tags impeller --run-skipped --enable-impeller` — exactly
  one failure, the pre-existing `GpuGeometryProducer` one
- `cd example && flutter test` — the example's own tests
- `dart format --set-exit-if-changed --output=none .` — exit 0

- [ ] **Step 4: Run it on the simulator and measure**

Resolve the device id at run time — `xcrun simctl list devices | grep '17e'`.
Do **not** trust a hardcoded UUID; the one that used to be in `docs/TODO.md`
no longer exists.

Verify by measurement, not impression, the way the glow's neighbour reach was
verified:
- **`GlassGlow` entry:** screenshot unpressed, screenshot held, compare the
  neighbouring surface's mean luminance against its own unpressed value. It
  must brighten. The radius is now 320 and there is a pixel test guarding it,
  so a failure here means the entry's two surfaces are not sharing a pass.
- **`GlassPresence` transition:** confirm the overlap warning does **not**
  fire during index → detail. If it does, the transition is cross-fading
  rather than handing off, and is stacking two backdrop filters.

Screenshot: `xcrun simctl io <id> screenshot /tmp/x.png`, then `sips -Z 1400`
before reading. Hot restart without a TTY is `--pid-file <path>` then
`kill -USR2 $(cat <path>)` — and wait for a **new** `Restarted application`
line, because matching a stale one silently screenshots the old build.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(example): retire the five-scene stage"
```

---

## Self-review notes

Checked against the spec:

- **Inventory (33 entries, seven groups)** — Tasks 5-10 including 8b, with the count test in
  Task 3 as the contract and Task 10 making it live.
- **Index → detail** — Tasks 3 and 4.
- **Entry anatomy** — Task 4 Step 3, against the Task 1 comp.
- **Snippets that cannot drift** — Task 2 is the mechanism, Task 11 the
  compile guard. Both of the spec's requirements are covered.
- **The app demonstrates itself** — `GlassPresence` in Task 4 Step 5,
  `GlassGlow` in Task 3 Step 4, `GlassHostScope` and the overlap warning as
  Task 8 entries. Note `GlassHostScope` is demonstrated *structurally*
  throughout by the toolbar/content split, which falls out of Tasks 3-4
  rather than needing its own step.
- **The five scenes** — specimens reused as starting points in Tasks 5-9,
  containers deleted in Task 12.
- **Visual direction** — Task 1, and Tasks 3-4 implement against it.
- **Testing** — per-group tests in Tasks 5-10, snippet compile in Task 11,
  measured simulator verification in Task 12 Step 4.
- **Out of scope** — no task touches the renderer, the shaders, or any
  package API. If a task finds an API gap, it records it rather than fixing
  it.

One thing deliberately left to the executor: the exact knob set for each
entry. The plan fixes the entry list, because that is the contract with the
reader; which two or three parameters best show a given capability is a
judgement made with the widget on screen, and prescribing it here from memory
is how the earlier `GlassShape.capsule()` error happened.
