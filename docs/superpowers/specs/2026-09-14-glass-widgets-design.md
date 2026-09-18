# Glass widgets and motion effects — design

Written 2026-09-14, for sign-off before any code. Once the widget list and
the open decisions at the bottom are agreed, each sub-project below gets its
own implementation plan.

## Why

glass_forge has the renderer, the tier engine, the motion physics and five
surface roles. It has no ready-made controls. The evidence is our own example
app, which had to hand-build a segmented control and a slider out of paint
because the package offers neither.

`liquid_glass_widgets` (1.5.0, 63k weekly downloads) ships about forty
widgets on a fork of the same upstream renderer. Its breadth is the thing to
learn from. Its foundations are not: it approximates Reduce Transparency from
Increase Contrast, and its own README says a user with only Reduce
Transparency on still gets the full shader. We read it from the OS, and every
widget here inherits that.

The rules in this document come from three places: Apple's behaviour as
recorded in `docs/reference/apple_liquid_glass_spec.md`, the composition bugs
this repo has already shipped and fixed, and a source read of the renderer
done while writing this.

## Constraints every widget obeys

- **One `GlassLayer` per screen.** A layer captures once per distinct
  material among its shapes.
- **At most one glass surface at any point on screen.** On a physical iPhone
  a backdrop filter stacked over another reads a stale frame and washes out
  white (flutter#187820). The simulator hides it. Apple says the same thing
  for its own reasons: "Always avoid glass on glass."
- **A control drawn on a glass surface is paint.** A switch on a glass
  toolbar paints its knob; the same switch on content can make its knob
  glass. No widget ever builds a `Glass` inside another `Glass`.
- **What glass refracts is painted behind the layer, never inside it.**
- **Degradation is inherited, not reimplemented.** Widgets render through
  `Glass`, `GlassSurface` and `GlassLayer`, so the tier engine, Reduce
  Transparency and Increase Contrast apply without widget code.
- **Reduce Motion removes elasticity.** Apple: it "disables any elastic
  properties for the material." Stretch, bounce and glow spread go; state
  changes still happen, instantly.
- **Widgets depend on `package:flutter/widgets.dart` only.** No Material
  ancestor is required, so there is no yellow-underline workaround to
  document.
- **Every interactive widget has semantics, keyboard focus and activation,
  and a hit target of at least 44 × 44 logical pixels.** Nothing in the
  widget layer does this today, so each control does it itself.
- Repo rules: `very_good_analysis`, 80-character lines, no `// ignore:`,
  README snippets compiled by `test/readme_examples_test.dart`.

## What exists, and what is missing

| Need | Today |
|---|---|
| Glass behind any widget | `Glass(shape:, child:)` — done |
| A semantic surface | `GlassSurface.navigationBar/.sheet/.card/.control/.scrim` — done |
| Press, drag, fling, spring home | `InteractiveGlass` — done |
| Stretch toward a held finger | Missing. Press only scales; stretch only comes from velocity |
| Touch-origin glow | Missing |
| Glass appearing and disappearing | Missing, and not possible cheaply today (see A1) |
| Knowing you are drawn on glass | Missing. No scope tells a descendant it is inside a `Glass` |
| Buttons, switch, slider, segmented control | Missing |
| Tab bar, app bar, sheet, scaffold | Missing |

## Sub-project A — foundations

These are renderer and motion changes. The controls are thin once they exist,
and every control in B and C needs at least two of them.

### A1. Presence: glass that can fade in without re-keying its pass

**The problem, from the source.** `RenderGlassLayer` keeps its passes in a
`Map<GlassMaterial, _GlassPass>` keyed by material *value*. Any change to a
material re-registers every affected shape into a new `_GlassPass`, retires
the old one (releasing its matte and disposing its composition), and the new
pass has no matte, so `_refreshMatte` produces one. `FilterSnapshot` also
carries `materialRevision`, so the filter is rebuilt too. Animating a
material therefore costs a pass, a matte bake and a filter on every frame.
The example's refraction slider already does this on every drag frame; it is
fine for a demo and wrong for a transition that every sheet plays.

Scaling the displacement uniform alone is not a way round it either.
`final_render.frag` multiplies both the displacement magnitude *and* the
decoded signed distance by `uOptical.x`, and the signed distance drives
coverage and antialiasing. Scaling it would move the edge, not fade the
refraction.

**The design.** A `presence` value from 0 to 1, set on the pass rather than
folded into the material, so it never changes the pass key or the matte
request:

- **Displacement** is scaled in the shader by `uSurface.z`, which
  `_writeUniforms` currently writes as a constant 0. The shader multiplies
  the displacement magnitude by it and leaves the signed distance alone. The
  uniform layout does not change. This is the only shader edit in A1.
- **Tint, highlight, contour and dispersion** are scaled on the CPU in
  `_writeUniforms`. **Saturation** lerps from its neutral 1.0. **Frost**
  scales the blur sigma, which rebuilds only the composed `ImageFilter`
  object, not the pass or the matte.
- **Presence 0 pushes no backdrop filter at all**, exactly like a material
  whose `rendersAnything` is false. That matters for handoffs (see C3): a
  surface at presence 0 must not still be a stacked filter.

This is what Apple does. Materialize "ramps refraction, not alpha", and
setting opacity to 0 on a glass view makes the effect stop rendering
entirely.

Public API:

```dart
/// Fades a glass subtree in or out by ramping its refraction, frost, tint
/// and light together, then drops the backdrop pass entirely at zero.
class GlassPresence extends StatelessWidget {
  const GlassPresence({required this.presence, required this.child});

  /// 0 is no glass at all; 1 is the material as declared.
  final Animation<double> presence;
  final Widget child;
}
```

Presence is per pass, so it applies to every shape that shares a material. A
surface that fades on its own — a sheet over a screen whose bars stay put —
already has its own material through its `GlassSurface` role.

**Tests.** `GlassRenderCounters` matte-produce count stays flat while presence
animates from 0 to 1 over twenty frames. Presence 0 pushes no
`BackdropFilterLayer`. On the Impeller lane, the uniform written at
`uSurface.z` equals the presence value, and at presence 1 the output is
pixel-identical to today's.

### A2. Anchored press-stretch

Apple's buttons elongate toward a held finger and pull back when it lifts,
while barely moving. Ours only scale on press, and stretch only while
travelling fast.

```dart
@immutable
class GlassPressStretch {
  const GlassPressStretch({
    this.intensity = 0.5,
    this.squash = 0.3,
    this.travel = 0.15,
  });

  const GlassPressStretch.none();

  /// How far the surface elongates along the finger's offset, as a fraction
  /// of that offset relative to the surface's own size.
  final double intensity;

  /// How much of that elongation is conserved as squash across it. 1 keeps
  /// area exactly; lower keeps labels on the surface from distorting.
  final double squash;

  /// The fraction of the finger's offset the surface actually translates.
  final double travel;
}
```

`InteractiveGlass` gains `pressStretch`. While a pointer is down, the follow
spring already tracks the raw finger offset; `glassSurfaceTransform`
translates by `travel × offset` and stretches along the offset using the same
area-conserving similarity transform the velocity jiggle already uses. Release
springs everything home on the settle spring, so the snap-back bounces for
free. Under Reduce Motion it resolves to `GlassPressStretch.none()`.

The defaults above match what `liquid_glass_widgets` settled on (its
`AnchorStretchSettings`). They are a starting point, and get checked against
a screen recording of an iOS 27 button before they ship.

**Tests.** Pure transform tests beside `glass_jiggle_test.dart`: zero offset
is identity; the determinant equals 1 when `squash` is 1; translation is
exactly `travel × offset`; `none()` is identity for any offset.
`interactive_glass_test.dart`: a held pointer stretches, release returns to
rest, and Reduce Motion yields identity.

### A3. Touch glow

Apple: "Starting right under your fingertips, the glow spreads throughout the
element and onto any Liquid Glass elements nearby." A glow that spills onto
neighbours cannot belong to one shape. It belongs to the shared container.

Two ways to build it:

- **In the shader (recommended).** One new uniform, `uGlow` =
  (x, y, radius, strength), added to `final_render.frag` and brightening the
  refracted colour by a smooth radial falloff before the coverage multiply.
  It is masked by coverage for free, so it lights every shape in the pass —
  the neighbours Apple describes — and nothing between them. It costs one
  distance and one smoothstep per fragment. It changes the uniform layout, so
  it must pass the SkSL web-build gate.
- **Painted.** A radial gradient drawn inside each `Glass`. No shader change,
  but it is clipped to one shape, so it can never spread to a neighbour.

API either way: `GlassLayer` gains a `GlassGlow` channel that `InteractiveGlass`
drives from the pointer position — radius and strength spring out on press
and decay on release, on the theme's `press` motion. Reduce Motion keeps a
static highlight under the finger and drops the spreading animation.

### A4. The on-glass scope and an overlap check

`Glass` puts a `GlassHostScope` above its child. Controls read
`GlassHostScope.maybeOf(context)`: present means they are drawn on glass and
must render entirely in paint; absent means one part of them may be glass.
This is how a single `GlassSwitch` class is correct both on a toolbar and on
content, with no mode for a developer to remember.

In debug builds, `RenderGlassLayer` also checks, after registration, whether
any two shapes belonging to *different* passes overlap. It already holds
every shape's bounds. When they do, it prints which widgets they were and
names flutter#187820 — the rule that has shipped broken in this repo by
accident, turned into a warning. A `Glass` built directly inside another
`Glass` asserts.

## Sub-project B — controls

Every control resolves `GlassSurfaceRole.control` for its material and
motion, takes an optional `backdrop` for adaptation like `GlassSurface`, and
reads its label colour from the surface rather than naming one.

What each control makes glass, depending on where it is drawn:

| Control | On content | On a glass surface |
|---|---|---|
| `GlassButton` | the button body | paint |
| `GlassSwitch` | the knob — Apple's one lens-profile element — over a painted track | knob and track painted |
| `GlassSlider` | the thumb, over a painted track and fill | all paint |
| `GlassSegmentedControl` | the travelling selection pill | all paint |
| `GlassTextField` | the field body | paint |

### B1. `GlassButton`

```dart
const GlassButton({
  required VoidCallback? onPressed, // null renders disabled
  required Widget child,
  GlassShape? shape,                // defaults to a capsule
  Color? backdrop,
  GlassPressStretch pressStretch = const GlassPressStretch(),
  bool glow = true,
  String? semanticLabel,
  FocusNode? focusNode,
  bool autofocus = false,
});

const GlassButton.icon({
  required VoidCallback? onPressed,
  required Widget icon,
  required String semanticLabel,    // required: an icon has no label
  Color? backdrop,
  ...
});
```

Semantics: button, enabled state, label. Enter and Space activate. Minimum
44 × 44 even for a smaller icon, which grows the hit area rather than the
glass.

### B2. `GlassSwitch`

```dart
const GlassSwitch({
  required bool value,
  required ValueChanged<bool>? onChanged,
  Color? activeTrackColor,
  Color? backdrop,
  String? semanticLabel,
});
```

The knob can be dragged across and flicked; it settles to whichever side it
is past, on the `settle` spring. Semantics: toggle, `toggled` state. Track
and knob dimensions are taken from an iOS 27 capture during the plan for
this task, not guessed here.

### B3. `GlassSlider`

```dart
const GlassSlider({
  required double value,
  required ValueChanged<double>? onChanged,
  double min = 0,
  double max = 1,
  int? divisions,
  ValueChanged<double>? onChangeStart,
  ValueChanged<double>? onChangeEnd,
  Color? backdrop,
  String? semanticLabel,
  String Function(double value)? semanticValue,
});
```

The thumb stretches with the drag velocity, which `GlassJiggle` already
computes. Semantics: slider, with increase and decrease actions that step by
one division, or by 10% without divisions.

### B4. `GlassSegmentedControl<T>`

```dart
const GlassSegmentedControl<T>({
  required List<GlassSegment<T>> segments,
  required T selected,
  required ValueChanged<T> onChanged,
  Color? backdrop,
});

const GlassSegment<T>({required T value, required Widget label});
```

The pill travels between segments on the `settle` spring, and can be dragged
directly under a finger, snapping to the nearest segment. Semantics: each
segment is a selectable button in a group.

**Tests, for every control.** Widget tests cover: the callback fires; disabled
never fires; semantics flags and actions; keyboard activation; the 44-point
minimum; exactly one `Glass` when built on content and none when built under
a `GlassHostScope`; Reduce Motion makes every transition instant; README
snippet compiles.

### B5. `GlassTextField`

```dart
const GlassTextField({
  TextEditingController? controller,
  String? placeholder,
  Widget? leading,
  Widget? trailing,
  GlassShape? shape,                // defaults to a capsule
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  Color? backdrop,
});
```

Added on 2026-09-18, against the spec's own recommendation to defer it. The
reason it was deferred stands and is now work to be done rather than work to
be avoided:

- **Focus.** Focus is a state change on glass, not a painted ring bolted on
  top. The field's material resolves brighter on focus and animates there on
  the `settle` spring, so focus reads as the glass lighting up. A painted
  ring would be a second edge fighting the lens profile.
- **The caret and the selection.** Both are painted *inside* the glass, above
  the refraction, never refracted by it — a refracted caret smears and reads
  as a rendering bug. Their colour comes from the surface, as every other
  control's label colour does.
- **The keyboard inset.** The field scrolls clear of the keyboard through
  `MediaQuery.viewInsets`, and when it sits in a `GlassScaffold` bottom bar
  the bar rides the inset with it. The bar is still the only glass in that
  region while it moves.
- **IME and composing text** are `EditableText`'s job. `GlassTextField` wraps
  it rather than reimplementing it, so composing underlines, autocorrect and
  the system selection toolbar all keep working.

On a glass surface the field body is painted, like every other control under
a `GlassHostScope` (A4).

**Tests, additionally.** Focus changes the material and restores it on blur;
Reduce Motion makes that change instant; the caret is not inside the glass
subtree; `viewInsets` moves the field clear of the keyboard; semantics
expose a text field with its placeholder as the label.

## Sub-project C — chrome

### C1. `GlassTabBar`

```dart
const GlassTabBar({
  required List<GlassTab> tabs,
  required int currentIndex,
  required ValueChanged<int> onTap,
  Color? backdrop,
});

const GlassTab({required Widget icon, Widget? activeIcon, required String label});
```

A `GlassSurface.navigationBar` with a painted selection pill — it sits on
glass — that travels on the `settle` spring. Bottom safe-area inset built in.
Minimize-on-scroll is deferred.

### C2. `GlassAppBar`

```dart
const GlassAppBar({
  Widget? leading,
  Widget? title,
  List<Widget> actions = const [],
  Color? backdrop,
});
```

Top safe-area inset built in, because anything pinned to the top of an
edge-to-edge surface otherwise prints through the clock. Actions built from
`GlassButton.icon` render in paint automatically, through `GlassHostScope`.

### C3. `showGlassSheet`

```dart
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
});
```

The sheet is a `GlassSurface.sheet` that materializes through A1 as its route
animates. Content behind it dims with a painted scrim, so the sheet stays the
only glass over that region.

Where the sheet covers glass chrome on the page beneath, the two must never
both render. Partial presence is still a stacked backdrop filter, and a
stacked filter is the bug, however faint it looks. So the presentation is a
handoff, not a cross-fade: the covered chrome's presence reaches 0 in the
first part of the route animation, and only then does the sheet's rise from 0.
`GlassScaffold` wires the chrome side to `ModalRoute.secondaryAnimation`.

### C4. `GlassScaffold`

```dart
const GlassScaffold({
  required Widget body,
  Widget? background,
  Widget? topBar,
  Widget? bottomBar,
  GlassMaterial? material,
});
```

One widget that makes the composition rules the default rather than something
to know:

- `background` and `body` are painted **behind** one `GlassLayer`, so the bars
  refract the content scrolling under them.
- `topBar` and `bottomBar` are the only glass, inside that layer.
- Bars get their safe-area insets; the body gets padding to scroll clear of
  them.
- Bar presence follows the route's secondary animation, for C3.

### C5. `GlassDetentSheet` — the Apple Maps sheet

C3 presents a sheet and takes it away. This is the other kind: a sheet that
is always on screen, that the user drags between fixed heights, and that
changes shape as it rises. Apple Maps, Find My and Apple's own
`UISheetPresentationController` detents are the reference. Added on
2026-09-18 from an Expo write-up of the same behaviour; that article is React
Native (`formSheet`, TrueSheet) and none of its API ports, but it documents
the behaviour precisely and its detent fractions are quoted below as a
starting point to tune, not as measured Apple values.

```dart
const GlassDetentSheet({
  required List<GlassDetent> detents,   // ascending; at least two
  required Widget child,
  int initialDetent = 0,
  ValueChanged<int>? onDetentChanged,
  GlassDetentSheetController? controller,
  Color? backdrop,
});

const GlassDetent.fraction(double amount); // of the available height
const GlassDetent.height(double logical);
const GlassDetent.content();               // measured from the child
```

**Floating, then flush.** Below the top detent the sheet floats: inset from
the screen's side and bottom edges by a gap, with a large radius on all four
corners. As it rises the gap closes toward 0 and the radius interpolates
toward the display's own corner radius, so at the top detent the sheet is
flush and its corners match the screen's. The Expo article's example detents
are 0.1, 0.5 and 1.0, and it describes exactly this: floating with a visible
gap at the low detent, still floating but tighter at the middle, gap gone at
the top.

**The interpolation is driven by offset, not by detent index.** The gap and
the radius are functions of the sheet's current top, continuous under a
finger, so the morph tracks the drag rather than playing when a detent is
reached. Only the *snap* is discrete.

**Scroll handoff.** One gesture, two consumers, resolved by position and
direction:

- Below the top detent, a vertical drag moves the sheet and the inner
  scrollable does not scroll.
- At the top detent, the inner scrollable scrolls.
- Scrolled back to its own zero and still dragging down, the sheet takes the
  gesture back and descends.

This is `NestedScrollView`'s problem shape but not its API; it needs a
`ScrollPhysics` that reports its overscroll to the sheet's controller, so the
handoff happens within one gesture without a lifted finger.

**Release** snaps to the nearest detent on the `settle` spring, with fling
velocity projected forward so a flick carries past the nearest detent to the
next one. Reduce Motion makes the snap instant and the morph a step.

**The glass, which is the part that is ours.** The sheet is a
`GlassSurface.sheet`, and everything A1 and A4 exist for shows up here at
once:

- Where the sheet floats above a `GlassScaffold` bottom bar, both want to be
  glass over the same region. They must not both render — stacked backdrop
  filters are the bug. The bar's presence ramps to 0 as the sheet's bottom
  edge reaches it, and the sheet's ramps up behind that, a handoff driven by
  the same offset that drives the morph.
- At the top detent the sheet covers the page entirely, so the page's chrome
  is at presence 0 and costs nothing.
- The A4 overlap check must stay quiet through the whole drag. If it warns
  mid-drag, the handoff is wrong, and that is the test.

**Tests.** Detent snapping from a drag and from a fling; the gap and radius
at three sampled offsets; the scroll handoff in both directions within one
gesture; `GlassRenderCounters` shows one matte produce for the whole drag,
not one per frame; never two backdrop filters over the same region at any
offset; Reduce Motion; semantics expose the sheet as a draggable with
increase and decrease actions.

## Sub-project D — rebuild the example on the widgets

Replace the example's hand-built `SegmentedControl` and `ValueSlider` with
`GlassSegmentedControl` and `GlassSlider`, the tab bar with `GlassTabBar`, and
the System scene's buttons with `GlassButton`. Keep the five scenes. Add
anchored stretch and the touch glow to the Lens and Motion specimens. Replace
the scrim's one-frame swap with a real presence handoff. Re-verify with the
same simulator screenshots and pixel measurements used when the example was
first built.

Add one scene the example does not have today: a `GlassDetentSheet` over the
System scene's content, with the tab bar beneath it, so the C5 handoff is
something a reader can drag rather than read about. That scene is also the
best demonstration the package has of why presence exists at all.

## Deferred

Not in this round, each for a stated reason:

- **The search bar** — a text field that is also chrome, with its own
  expand-on-focus behaviour. B5 ships the field; the bar that hosts it waits
  until C1 and C2 have settled how chrome resolves its material.
- **Menus and morph** — Apple's teardrop morph needs shapes that change
  topology mid-animation; that deserves its own design once presence and
  blending are proven together.
- **Toasts** — a presented surface; it follows C3's pattern once C3 exists.
- **Minimize-on-scroll tab bar**, **gyroscope-driven lighting**, **progressive
  blur**, and **automatic backdrop sampling** for adaptation.

## Order and plans

A1 → A4 → A2 → A3 → B1 → B2 → B3 → B4 → B5 → C4 → C1 → C2 → C3 → C5 → D.

A1 comes first because C3, C5 and D cannot be correct without it. A4 comes
next because every control's glass-or-paint decision depends on it. C4 comes
before the bars it hosts. C5 comes last of the chrome because it needs C4's
bar presence to hand off to and C3's handoff pattern already proven on a
simpler case. One implementation plan per sub-project: A, B, C, D.

## Decisions made — 2026-09-18

Answered by Arham. The spec above is amended to match; these are recorded so
the reasoning is not lost.

1. **The widget list: the eight, plus a text field.** Five controls (button,
   switch, slider, segmented control, text field) and four pieces of chrome
   (tab bar, app bar, sheet, scaffold). B5 was added for the field. Menus and
   morph, toasts, the search bar and minimize-on-scroll stay deferred.
2. **Touch glow in the shader.** As recommended: only the shader version
   spreads to neighbouring glass the way Apple's does, and it costs one
   uniform.
3. **The overlap check warns in debug, it does not assert.** As recommended.
   An assert would throw mid-transition, where overlap is legitimately
   transient — and C5's handoff drags through exactly that window.
4. **Plain names.** `GlassButton` and the rest, colliding with
   `liquid_glass_widgets`. An app depending on both uses an import prefix.

## Added after sign-off

**C5, `GlassDetentSheet`** — the Apple Maps sheet: persistent, dragged
between detents, morphing from floating to flush as it rises. Requested
2026-09-18. It is the hardest thing in the document, because it is where
presence (A1), the overlap rule (A4) and a two-consumer gesture all land in
one widget.
