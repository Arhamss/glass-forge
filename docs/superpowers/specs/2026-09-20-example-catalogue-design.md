# The example app as a named catalogue — design

## Why

The example is five scenes over five photographs — Lens, Edge, Blend, Motion,
System — each a specimen with a slider panel under it. It is a good lab
bench: it proves the renderer's optics to someone deciding whether the
refraction is real.

It is the wrong artefact for the question most people arrive with. A
developer opening the example wants to know *what can I build, what is it
called, and how do I write it*. The bench answers none of those. It
demonstrates refraction, not interfaces.

That gap is why sub-project A's widgets have nowhere to live in it.
`GlassPresence`, `GlassHostScope`, anchored press-stretch and the touch glow
are all about assembling real UI — a sheet materialising, a control knowing
it sits on a toolbar, a button reaching for a finger, light crossing between
neighbouring surfaces. A specimen-and-sliders bench has no toolbar, no sheet,
and no neighbours.

So: replace the bench with a **catalogue**. Every capability the package
offers, shown live, named with the API that produces it, with the code beside
it.

## What it is

An index of named entries, grouped, each opening to a page that shows one
capability working and tells you how to write it.

The index answers "what looks like what" — each row carries a live thumbnail,
so the answer is visible before you tap. An entry answers "how do I build
this" — the running widget, its knobs, and the exact Dart.

## Inventory

Thirty-three entries in seven groups. This is the contract for "all the
functionality": if a capability is not here, the catalogue does not claim to
cover it. Per-group counts are given so the total is checkable rather than
asserted.

**Surfaces (6)** — `Glass`, `GlassLayer`, `GlassMaterial` (regular, clear,
dome), `GlassVariant`, `GlassProfile`, and one **Material knobs** entry
carrying all eight parameters together — refraction, frost, tint,
saturation, highlight, contour, thickness, dispersion. One entry, not
eight: they are parameters of a single `GlassMaterial`, and splitting them
would imply eight APIs where there is one.

**Shapes (4)** — `GlassRoundedRectangle`, `GlassOval`, `GlassSuperellipse`,
`GlassBlendGroup`.

**Motion (7)** — `InteractiveGlass`, `GlassJiggle`, `GlassPressStretch`,
`GlassOverdrag`, `GlassDecay`, `GlassMotion`, and Reduce Motion behaviour.

**Composition (4)** — `GlassPresence`, `GlassHostScope`, `GlassGlow`, and
the cross-pass overlap warning.

**Design system (5)** — `GlassTheme`, `GlassSurface` with `GlassSurfaces`
as one entry, `GlassTokens`, `GlassTint`, `GlassLegibility`.

**Chrome (4)** — `GlassDetentSheet`, `GlassDetent`,
`GlassDetentSheetController`, `GlassSheetScrollPhysics`. Added after the
detent-sheet work landed on `main`; the example already carries a sixth
scene for it (`example/lib/src/scenes/sheet_scene.dart`), which is this
group's starting point. The sheet is also the clearest demonstration the
package has of `GlassPresence`: its own doc comment calls it "the reason
`GlassPresence` exists", because the tab row behind it must reach presence
zero before the sheet's glass arrives, or the two stack.

**Adaptation (3)** — `GlassTierScope` with tier degradation as one entry,
the thermal / frame-rate / accessibility signals as one, and
`GeometryTier`.

**Deliberately excluded:** `GlassForgePlatform` and `FrameWatchdog`. Both
are exported, but they exist so the package can be tested and extended, not
so UI can be assembled from them.

`ProducerRegistry` and `RenderCapabilityProbe` need no exclusion — the barrel
exports only `GeometryTier` and `GraphicsBackend`/`RenderCapabilities` from
their files, so they are not public surface at all.

A catalogue padded to all 36 export lines would be less honest, not more
complete.

## Information architecture

**Index → detail.** A grouped index; tapping a row opens a full page for that
entry.

Chosen over a single long scroll because code snippets make entries tall, and
over section tabs because twenty-four entries across six tabs leaves each tab
either crowded or arbitrary. Index → detail also gives each capability room
to actually be demonstrated rather than glimpsed.

The navigation is not incidental to the demo — see "The app demonstrates
itself" below.

## Anatomy of an entry

Top to bottom:

1. **The live thing, large**, over the photographic backdrop.
2. **Its API name** as the title, in code type — the string you would search
   for.
3. **One line** on what it is for.
4. **Live knobs** for that entry's parameters only.
5. **The snippet**, copyable.
6. **See also** — links to related entries.

## Snippets that cannot drift

The failure mode this design must prevent: a snippet that compiles but no
longer describes the thing rendered above it. That is worse than no snippet,
because the reader trusts it.

**The constraint: the declaration is the source, not a description of it.**
Each entry declares its parameters once, as data. The live widget and the
rendered code are both derived from that single declaration. Moving a knob
mutates the data, so the widget and the text move together by construction —
there is nothing to keep in sync, because there is only one thing.

This rules out hand-written snippet strings. That is the tempting shortcut
and it is exactly what rots.

On top of that, `test/readme_examples_test.dart`'s technique extends to
compile every catalogue snippet, so a renamed constructor fails CI instead of
shipping a lie. That guard has already proved itself once: reintroducing
`GlassShape.capsule()` — a constructor that never existed, yet sat in shipped
doc comments long enough to propagate into an implementation plan — made it
fail to compile.

## The app demonstrates itself

The four new pieces are shown working by the catalogue's own structure,
before the reader reaches their entries. A capability demonstrated only in
its own entry is a capability the reader has to take on trust.

- **`GlassPresence`** drives index → detail. The detail surface materialises
  by ramping refraction rather than opacity — the whole point of it — and the
  index chrome hands off instead of cross-fading, which would stack two
  backdrop filters and reproduce flutter#187820.
- **`GlassHostScope`** is what lets one control widget sit both on the
  photographic content and inside the glass toolbar, painting in one and
  refracting in the other. Both contexts exist on every screen, so it is
  demonstrated continuously rather than staged.
- **`GlassGlow`** lights the index rows: pressing one brightens its
  neighbours, which is the behaviour that justified putting it in the shader
  instead of painting it.
- **The overlap warning** gets an entry that deliberately triggers it and
  shows the debug output on screen. A diagnostic you can watch fire is worth
  more than one you read about.

## What happens to the five scenes

The specimens survive; the container does not.

Lens, Edge, Blend and Motion become entries under Surfaces, Shapes and
Motion. System becomes the Adaptation group. The five photographs and the
Geist type stay — that aesthetic is already right and matches the direction
below.

Deleted: the `_SceneTabs` bottom tab bar in `main.dart`, and the per-scene
control panel, replaced by the index/detail model and per-entry knobs.

`chrome.dart` mostly **survives**. Its `SegmentedControl`, `ValueSlider` and
`GlassCaption` are painted controls — not package widgets — and they are
already the knob toolkit an entry page needs. Rebuilding them would be
inventing a second set of the same thing.

`SceneInfo` survives too, renamed to carry a backdrop rather than a scene:
its `panelBackdrop` and `barBackdrop` are colours *measured off the
photograph*, and they exist because nothing in the package samples the
backdrop for you — `GlassSurface` can only keep labels readable if it is
told what is behind them. Any entry placed over imagery inherits that
obligation, so the catalogue reuses the five measured backdrops rather than
introducing unmeasured ones.

## Visual direction

**Apple-native, editorial.** Anchors, and the specific thing taken from each:

- **iOS 26 Settings and Control Centre** — the glass language itself. The
  package implements Apple's material; the demo should look like it belongs
  on the platform it emulates.
- **Things 3** — spacing rhythm and restraint. One accent, generous
  whitespace, hierarchy carried by type rather than by boxes.
- **The Apple Developer documentation app** — the index → detail catalogue
  pattern, and how a named API entry reads.

Taken as principles, never as identity or assets.

Reference comps for the index and one detail page are generated and agreed
**before** any UI code is written. "Improved a lot" is the brief, and it is
judged against those comps rather than argued about afterwards.

## Testing

- A widget test per group: the entry builds, and its knobs change what is
  rendered.
- The snippet compile-check described above, extended to every entry.
- Simulator verification for the `GlassGlow` and `GlassPresence` entries,
  **measured** the way the glow's neighbour reach was measured — screenshot,
  compare pixels against an unpressed baseline — not eyeballed.

## Out of scope

- Rewriting the renderer, the shaders, or any package API. This is example
  work; if the catalogue exposes a gap in the API, that is a finding to
  record, not to fix here.
- Publishing the example as a web demo.
- Localisation.
