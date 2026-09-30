## 0.1.0

First release.

### Rendering

- `GlassLayer` captures the backdrop once per material, and every `Glass`
  under it registers into one shared signed-distance matte.
- Two refraction models. `GlassMaterial.regular(brightness:)` and
  `GlassMaterial.clear()` bend only inside a band at the rim, fitted against
  iOS 27 captures. `GlassMaterial.dome()` refracts across the whole surface.
  The band's displacement is what refracting through its surface's slope
  gives: strongest at the rim, easing to zero with no seam. It reads the
  backdrop bilinearly wherever it bends it; the flat interior keeps a single
  tap.
- Shapes: `GlassRoundedRectangle`, `GlassOval` and `GlassSuperellipse`.
  `GlassBlendGroup` smooth-mins shapes into one another.
- Any number of shapes per material. A pass's shapes are sorted into
  clusters, groups of shapes whose mattes could meet plus any blend group,
  and each cluster is a draw of its own, up to `kMaxShapes` (8) shapes.
- A shape that is laid out but not drawn stays out of the matte, its
  clusters and the diagnostics until it is: under an `Opacity` at zero, in
  an `Offstage`, in a lazy list's cache region.
- A pass whose material changes only in shading (tint, frost, highlight)
  keeps its matte, and a `GlassTextField`'s focus is a uniform on its pass,
  so neither rebakes anything.

### Presence and host awareness

- `GlassPresence` and `GlassPresenceScope` fade a `Glass` in and out,
  driven by a controller, an `Animation<double>` or a route transition,
  without rebaking its matte on every frame.
- `GlassHostScope.isOnGlass(context)` tells a widget it is drawn on glass
  rather than on content, so it can paint instead of stacking glass on
  glass.

### Motion

- `InteractiveGlass` handles press, drag, fling and spring-home. Squash and
  stretch are read off the spring's own velocity (`GlassJiggle`, a 1.08
  ceiling at a 2000 px/s half-speed).
- Springs take a duration and a bounce, the way SwiftUI specifies them:
  `GlassMotion.bouncy`, `.snappy`, `.smooth` and `.interactive`. A press
  runs on snappy 250 ms / bounce 0.25 and lets go on its own spring,
  `pressReleaseMotion`, bouncy 280 ms / bounce 0.45.
- A press grows the surface by `pressGrowth`, 6 pt on its longest side,
  held to a ratio of 1.02 to 1.10. `pressScale` fixes a ratio instead.
- A pulled surface gives the way a native button does (`GlassPressStretch`).
  The stretch comes from how far the finger has moved since it went down,
  never from where it rests, so a tap does not deform anything. The first
  3 pt are ignored and the rest is rubber-banded. At the defaults a surface
  reaches about 1.5x along the pull with no squash across it, follows the
  finger up to 10 pt, and the label or glyph on it stretches with the glass.
  It takes on a white sheen as it stretches (`sheen`), and letting go
  bounces it softly back through rest (`rebound`).
- Touch glow (`GlassGlow`): a soft lift under the finger, 0.10 at full press
  (0.05 in dark mode), over one and a half times the pressed surface's
  longest side. It belongs to the pass, so neighbouring glass catches a
  little of it, and it stays on the pressed surface however far the finger
  pulls. `InteractiveGlass.glow` turns it off for one surface.
- Under Reduce Motion every spring settles at once and nothing stretches;
  the surface still answers the pointer.

### Controls

Five controls, each resolving `GlassSurfaceRole.control` for its shape and
label colour. On content each draws real glass: in the control role's
material, except the switch knob, which is always `GlassMaterial.dome()`.
Painted parts such as a switch track or a slider fill leave a hole where
that glass is. Under `GlassHostScope`, on a glass toolbar say, a control
paints a flat tint instead, so there is never glass on glass.

Every control but the text field shares one frame:

- One semantics node with the visible text as its label, Enter and Space
  activation, a 44 x 44 minimum hit target that grows the tap area rather
  than the glass, and a focus ring for keyboard focus.
- The owner decides. A control moves as soon as it is touched and then
  reports. If the owner does not rebuild with the new value, the control
  goes back to the value it was given.

And all five have:

- `autofocus`, and a `focusNode` on all but the segmented control, whose
  segments are each a focus stop of their own.
- A disabled state that dims the glass as well as the paint, and ignores
  touches. Disabling a control mid-drag ends the drag.
- Right-to-left layouts, mirrored the way Flutter's own controls mirror.
- A debug error naming the control when it is given an unbounded width.
- Labels that name their own size, so they never fall back to
  `WidgetsApp`'s debug text style outside a `Material`.

The controls:

- `GlassButton` and `GlassButton.icon`, with `toggled` for a button that
  reports an on/off state, `pressStretch`, `glow` and `semanticLabel`.
  Labels are iOS's 17-point button text.
- `GlassSwitch`: a painted 63 x 28 track and a 37 x 24 glass knob, sized to
  iOS 27's `Toggle`, that drags, flicks and settles to the side it ends up
  past. `activeTrackColor` defaults to the theme's accent.
- `GlassSlider`, with `min`, `max`, `divisions`, `onChangeStart`,
  `onChangeEnd` and `semanticValueFormatter`. It can be dragged from
  anywhere in its hit area, a tap sets it (in a scroll view too), and it
  reports only real changes. Arrow keys step it, onto the division grid
  when it has one.
- `GlassSegmentedControl` and `GlassSegment`, a travelling pill you can
  drag: a 32-point track under a 28-point pill inset 2, sized to iOS 27,
  centred in a hit area 44 tall. Labels are 13 points, semibold when
  selected. The control is a named semantics group, each segment a
  selectable button with its own `semanticLabel`. Left and right arrows
  move the selection; up and down are left to the page.
- `GlassTextField`, built on `EditableText`. Options: `controller`,
  `placeholder`, `leading`, `trailing`, `shape`, `enabled`, `keyboardType`,
  `textInputAction`, `obscureText`, `semanticLabel`, `onChanged` and
  `onSubmitted`. `contextMenuBuilder` defaults to the system selection menu
  (`SystemContextMenu`) where the device has one, and `selectionControls`
  takes an app's own drag handles. Focus lights the glass rather than
  drawing a ring. In a scroll view the field scrolls clear of the keyboard
  and of a bar riding it, and it grows with the reader's text size.

Large text: the fixed-height controls and bars let labels grow to 1.5x and
stop there. The text field grows instead.

### Chrome

- `GlassScaffold` puts the composition rules in place for you. Each bar
  sits in a layer of its own, the size of the bar, whose glass is clipped
  to the bar, so a bar's filter never reaches over body glass. The body
  gets one layer, which draws glass only between the bars. The bars are
  laid out before the body, so the body's padding and its glass band are
  right from the first frame. The body is padded to clear the bars, and its
  `viewInsets.bottom` is 0 under a bottom bar that rides the keyboard. Each
  bar fades out over the first 40% of any route that covers the page, so
  the bar and the covering glass are never two backdrop filters over the
  same pixels. `material` is what a bare `Glass` in either layer inherits.
- `GlassScaffold`, `showGlassSheet` and `GlassDetentSheet` give their
  content a text style and icon colour of their own, iOS's 17-point body in
  the theme's label colour, the way Material's `Scaffold` does.
- `GlassTabBar` and `GlassTab`, a floating capsule whose selection is
  always a clear glass lens. Only the selection is glass: the bar is
  painted, a translucent capsule in the role's tint at its legible step
  (about 54% in dark mode, 35% in light, or `backgroundColor`) with a
  hairline rim and the role's shadow, and no blur, so the lens is never
  glass over glass. The fill is light enough for the content behind to show
  through for the lens to bend, and still keeps every label at 3:1 over any
  backdrop. The default lens is bright and bends far (highlight 2.8, edge
  refraction 26, a 14% white tint, chromatic aberration 0.3), and a faint
  `selectionMaterial` is raised to `minimumSelectionHighlight` (2),
  `minimumSelectionTintOpacity` (0.12) and `minimumSelectionEdgeRefraction`
  (14), so a clear preset never hides the selection. A bouncy spring moves
  the lens, and it squashes along its travel with its speed, to at most 116%
  of its height. A drag carries it under the finger, clicks once per tab
  crossed, and commits the tab under the finger on release; a cancelled
  drag sends it back. Reduce Motion moves it at once, still glass.
  `GlassTabBar.height` and `GlassTabBar.margin` are public for laying out
  around it. `GlassTab.semanticLabel` names icon-only tabs. In debug it
  reports a bar too narrow for 44-point tabs. `maxWidth` caps the bar,
  centred, at `GlassTabBar.defaultMaxWidth` (480 points) unless you pass
  another, so on a tablet it stays a capsule rather than a strip.
- `GlassAppBar`: `leading`, a 17-point semibold title centred iOS style and
  marked as a header, `actions`, the top safe area, and `material`.
- `showGlassSheet` presents a modal glass sheet from the bottom edge. It
  takes `isDismissible`, `material`, `barrierLabel`, `useRootNavigator` and
  `routeSettings`, and completes with what it is popped with. The sheet
  rises over the keyboard, and Reduce Motion presents it instantly, even
  mid-presentation.
- `GlassDetentSheet`, a persistent bottom sheet dragged between fixed
  heights, à la Apple Maps: floating with an inset and a large-radius
  corner below its top detent, flush with the display's own corners at it,
  with a scroll handoff to the content it carries. Detents are
  `GlassDetent.fraction`, `.height` or `.content`. `material` replaces the
  sheet role's material, and `bottomGap` sets the floating bottom inset
  apart from the side ones, for a sheet that has to clear a bar beneath it.
  `GlassDetentSheetController` drives it from outside, including
  `presenceUnder`, which hands a covered surface's `GlassPresence` off
  before the sheet's own glass reaches it. `GlassSheetScrollPhysics` lets
  one drag cross from the sheet to its list and back without a lifted
  finger.
- `GlassSurface` takes a `material` on every constructor. Placed on glass,
  it paints its tint instead of drawing glass, and inside a `GlassPresence`
  it fades its content with the glass.

### Backdrop sampling

- `GlassBackdropSampler`, `GlassBackdropSource` and `GlassBackdropBuilder`
  measure what is behind a surface, so adaptation needs no caller-supplied
  `backdrop`. The source is snapshotted at low resolution (1/8 scale, at
  most 96 px on its long side), asynchronously, at most every 200 ms and
  only after it repainted; each surface takes the mean colour under its own
  rect, with a luminance band so it does not flicker between schemes.
  `GlassSurface`, `GlassAppBar`, `GlassTabBar`, `GlassDetentSheet` and every
  control use it when no `backdrop` is given. An explicit `backdrop` still
  wins. Nothing is sampled where the tier renders no glass, under Reduce
  Transparency, or on glass.

### Tiering and accessibility

- `GlassTierScope` picks a tier from GPU capability, thermal state, frame
  health and accessibility settings. `ResolvedTier.describe()` says why.
- Reduce Transparency is read through a native channel and reported as
  unknown where the platform has no answer. Reduce Motion honours both engine
  bits. Increase Contrast drives surfaces toward opaque with a border.
- Skia and web backends fall back to frost without refraction.

### Design system

- Tokens for blur, radius, depth and tint, five `GlassSurface` roles, and
  `GlassTheme`.
- The controls' colours come from the theme: `GlassTokens.controls`, a
  `GlassControlPalette` of light and dark `GlassControlColors` — `accent`
  (the switch's on-track), `knob` (the knob, thumb and pill painted on
  glass), and `fill` and `focus` (the slider's fill and the focus ring,
  null for the label colour). `GlassSwitch.activeTrackColor` still wins for
  one switch.
- The chrome's painted colours do too: `GlassTokens.chrome`, a
  `GlassChromeColors` with `scrim` (under `showGlassSheet`, black at 32% by
  default) and `handle` (both sheets' grab handle, null for the sheet's
  label colour).

### Debug tooling

- A warning when shapes in different render passes overlap on screen,
  surfacing the artifact behind
  [flutter/flutter#187820](https://github.com/flutter/flutter/issues/187820)
  before it reaches a release build. It reports every overlapping pair
  once, not every frame.
- A warning when more shapes sit in one cluster than a single draw can
  carry (`kMaxShapes`).

### Known limits

- `kMaxShapes` is 8 per cluster: shapes whose mattes could meet, and every
  shape in one blend group. Past eight the extras are not drawn.
- The backdrop sampler misses a repaint behind a repaint boundary inside the
  source until `GlassBackdropSampler.markNeedsSample`, and a surface that
  moves while nothing repaints or scrolls keeps its last reading.
- Benchmark budgets are seed values, not measurements from real hardware.
