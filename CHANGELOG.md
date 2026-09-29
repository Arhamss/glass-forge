## Unreleased

### Breaking

- `GlassShapeClipper` is no longer exported. It was marked
  `@visibleForTesting` but public, and every shape clip in the package now
  goes through one internal clipper. Clip to a shape with `ClipPath` and
  your own `CustomClipper` over `GlassShape`'s geometry instead.
- `GlassSlider.semanticValue` is now `semanticValueFormatter`. It is a
  `String Function(double)`, and the old name read as a string.
  `GlassSlider` is new in this release, so this only affects code written
  against this branch before release.
- `GlassSurface` no longer builds a `Glass` when it is placed on glass
  (under `GlassHostScope`). It paints its material's tint instead, as the
  controls do. Before, it tripped the nested-glass assert.
- A `GlassSurface` inside a `GlassPresence` now fades its content with the
  glass, not only the glass.
- `GlassTabBar`'s bar is painted, not glass: its `material` and
  `minimumTintOpacity` are gone, replaced by `backgroundColor` (null is the
  navigationBar role's tint at its legible step). Pass a tuned material as
  `selectionMaterial` to drive the lens instead. `GlassTabBar` is new in
  this release, so this only affects code written against this branch.

- `InteractiveGlass.pressScale` is now `double?` and defaults to null, which
  grows the surface by the new `pressGrowth` (6 pt). Passing a ratio still
  works as before and wins over `pressGrowth`; code that reads the field as
  a `double` needs a null check.
- `GlassMotionState.pressAnchor` is now `pressDrag` and
  `GlassMotionController.setPressAnchor` is now `setPressDrag`. The value
  is the finger's movement since pointer-down, no longer its offset from
  the surface's centre.
- `Glass.containsChild` is removed. It was accepted and never did
  anything. What glass refracts is whatever paints behind its
  `GlassLayer`; a child of `Glass` paints over the glass, never into what
  it bends. Put content you want refracted behind the layer, as
  `GlassScaffold` does with its body.

### Backdrop sampling

- `GlassBackdropSampler`, `GlassBackdropSource` and `GlassBackdropBuilder`
  measure what is behind a surface, so adaptation no longer needs a
  caller-supplied `backdrop`. The source is snapshotted at low resolution
  (1/8 scale, at most 96 px on its long side), asynchronously, at most
  every 200 ms and only after it repainted; each surface takes the mean
  colour under its own rect, with a luminance band so it does not flicker
  between schemes. `GlassSurface`, `GlassAppBar`, `GlassTabBar`,
  `GlassDetentSheet` and every control use it when no `backdrop` is given.
  An explicit `backdrop` still wins. Nothing is sampled where the tier
  renders no glass, under Reduce Transparency, or on glass.

### Changed

- The controls' own colours come from the theme: `GlassTokens.controls`,
  a `GlassControlPalette` of light and dark `GlassControlColors` — `accent`
  (the switch's on-track), `knob` (the knob, thumb and pill painted on
  glass), and `fill` and `focus` (the slider's fill and the focus ring,
  null for the label colour). The defaults are the old green and white, so
  nothing changes until a theme sets them; `GlassSwitch.activeTrackColor`
  still wins for one switch.
- Fixed: the edge band drew a hard ring inset from every shape's edge,
  which read as a bezel. The convex squircle the band is built on is the
  glass's *height*; it was being used directly as the displacement, which
  falls to zero with infinite steepness at the band's inner edge and folds
  the image there. The displacement is now what refracting through that
  surface's slope gives: strongest at the rim, easing to zero with no seam.
  `edgeRefraction` keeps its meaning — the displacement at the edge.
- Fixed: press-stretch on a non-square surface sheared it. The reach was
  normalised per axis and that normalised vector used as the stretch
  direction, so a finger at the corner of a wide card stretched it along a
  45-degree diagonal. The direction is now the finger's own, and the reach
  is capped.
- `InteractiveGlass`'s touch response is retuned to Apple's Liquid Glass,
  from `liquid_glass_widgets`' 120 fps measurements of iOS 26 and the
  springs read out of UIKit:
  - Press-stretch comes from how far the finger has **moved** since it went
    down, not from where it rests. A tap or a still press, even at the very
    edge, no longer deforms the glass. The first 3 pt of movement are
    ignored and the rest is rubber-banded, so it saturates.
  - `GlassPressStretch` defaults are now intensity 0.05, squash 1 (area
    kept) and travel 0.05 of the drag, capped at 4 pt: at most 5 % of
    elongation, where the old 0.5 / 0.3 / 0.15 reached 1.5×.
  - A press **grows** the surface by 6 pt on its longest side
    (`pressGrowth`), held to a ratio of 1.02 to 1.10, instead of shrinking
    it to 0.96.
  - The press runs on snappy 250 ms / bounce 0.25 and lets go on its own
    spring, bouncy 280 ms / bounce 0.45 (`pressReleaseMotion`, new).
    `GlassMotionDefaults.press` follows. `settleMotion` and the tab bar's
    spring are unchanged.
  - The touch glow is a soft lift, not a flash: 0.10 at the finger (0.05 in
    dark mode) instead of 0.55, over a radius of one and a half times the
    surface's longest side (48 to 640) instead of a fixed 320, so it covers
    the pressed surface and only fringes its neighbours.
  - Dragging a surface no longer stretches it into a needle: the stretch
    saturates however far the finger carries it.
  - `GlassJiggle` defaults to a 1.08 ceiling at a 2000 px/s half-speed
    (was 1.18 at 1600), which quiets the slider thumb's stretch too.
- Controls' settle springs land exactly on their target. They used to stop
  wherever they were once within half a pixel, which left a slider thumb
  visibly stretched after the jiggle ceiling came down.
- The debug warning for glass shapes overlapping across backdrop passes
  prints once per pair of passes instead of on every frame. An overlap that
  lasted printed about sixty times a second and buried the rest of the log.
- A debug warning when more shapes sit in one cluster than a single draw
  can carry (`kMaxShapes`, 8). The limit is per cluster of nearby or
  blended shapes now, not per material; see Rendering below.
- `GlassDetentSheet.material` replaces the sheet role's material for an app
  with a look of its own. Null keeps the role's, so nothing changes by
  default; label colour, shadows and motion still come from the role.

- `GlassDetentSheet.bottomGap` separates the floating sheet's bottom inset
  from its side ones. A sheet that floats over other glass has to clear
  that chrome's full height before their backdrop passes would overlap, and
  driving every edge from one number charged twice that clearance in width.
  Defaults to `gap`, so a sheet floating over nothing is unchanged.
- Fixed: every layer baked its mattes a second time a few frames after it
  mounted, when its producer's warm-up settled, although the mattes it held
  were already the ones a ready producer bakes. The settling now only
  re-asks a pass that got no matte.

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

The controls:

- `GlassButton` and `GlassButton.icon`, with `toggled` for a button that
  reports an on/off state, `pressStretch`, `glow` and `semanticLabel`.
- `GlassSwitch`: a painted track and a glass knob that drags, flicks and
  settles to the side it ends up past. `activeTrackColor` defaults to the
  theme's accent, an approximate system green.
- `GlassSlider`, with `min`, `max`, `divisions`, `onChangeStart`,
  `onChangeEnd` and `semanticValueFormatter`. It can be dragged from
  anywhere in its hit area, a tap sets it (in a scroll view too), and it
  reports only real changes. Arrow keys step it, onto the division grid
  when it has one.
- `GlassSegmentedControl` and `GlassSegment`, a travelling pill you can
  drag. The control is a named semantics group, each segment a selectable
  button with its own `semanticLabel`. Left and right arrows move the
  selection; up and down are left to the page.
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
- `GlassTabBar` and `GlassTab`, a floating capsule whose selection is
  always a clear glass lens, after the Kibu app's bar. Only the selection
  is glass: the bar is painted, a translucent capsule in the role's tint at
  its legible step (about 54% in dark mode, 35% in light, or
  `backgroundColor`) with a hairline rim (white in dark mode, black in
  light) and the role's shadow, and no blur, so the lens is never glass
  over glass. The fill is light so the content behind shows through for
  the lens to bend, and still keeps every label at 3:1 over any backdrop,
  so unselected labels are no longer dimmed. The default lens is brighter
  and bends further (highlight 2.8, edge refraction 26, a 14% white tint,
  chromatic aberration 0.3), and a faint `selectionMaterial` is raised to
  `minimumSelectionHighlight` (2), `minimumSelectionTintOpacity` (0.12)
  and `minimumSelectionEdgeRefraction` (14), so a clear preset never hides
  the selection. A bouncy spring moves the lens and it squashes along its
  travel with its speed, to at most 116% of its height, so it stays inside
  the bar and a `GlassScaffold`'s clip of it. A drag carries it under the finger, clicks once per tab crossed,
  and commits the tab under the finger on release; a cancelled drag sends
  it back. Reduce Motion moves it at once, still glass.
  `selectionMaterial` replaces `GlassTabBar.defaultSelectionMaterial`.
  `GlassTabBar.height` and `GlassTabBar.margin` are
  public for laying out around it. `GlassTab.semanticLabel` names icon-only
  tabs. Labels stop growing at 1.5x text size. In debug it reports a bar
  too narrow for 44-point tabs. `maxWidth` caps the bar, centred, at
  `GlassTabBar.defaultMaxWidth` (480 points) unless you pass another, so on
  a tablet it stays a capsule rather than a strip across the screen.
- `GlassAppBar`: `leading`, a title centred iOS style and marked as a
  header, `actions`, the top safe area, and `material`.
- `showGlassSheet` presents a modal glass sheet from the bottom edge. It
  takes `isDismissible`, `material`, `barrierLabel`, `useRootNavigator` and
  `routeSettings`, and completes with what it is popped with. The sheet
  rises over the keyboard, and Reduce Motion presents it instantly, even
  mid-presentation.
- `GlassSurface` takes a `material` on every constructor. Chrome placed on
  glass paints its tint instead of drawing glass.

- `GlassDetentSheet` — a persistent bottom sheet dragged between fixed
  heights, à la Apple Maps: floating with an inset, large-radius corner
  below its top detent, flush with the display's own corners at it, with a
  scroll handoff to the content it carries and no gap between detents to
  step across. Detents are `GlassDetent.fraction`, `.height` or `.content`.
  `GlassDetentSheetController` drives it from outside — including
  `presenceUnder`, which hands a covered surface's `GlassPresence` off
  before the sheet's own glass reaches it, over a ramp the caller states in
  their own geometry: the sheet's floating `gap` has to clear the covered
  bar in the first place, or the two are stacked before any drag begins —
  and `GlassSheetScrollPhysics`
  is what lets one drag cross from the sheet to its list and back without a
  lifted finger.

### Presence

- `GlassPresence` and `GlassPresenceScope` fade a `Glass` in and out —
  driven by a controller, an `Animation<double>`, or a route transition —
  without rebaking its matte on every frame.

### Host awareness

- `GlassHostScope` lets a control ask `GlassHostScope.isOnGlass(context)` so
  it can adapt when it is drawn on top of glass instead of a plain
  background.

### Rendering

- Any number of shapes per material. A pass's shapes are sorted into
  clusters, groups of shapes whose mattes could meet plus any blend group,
  and each cluster is a draw of its own. `kMaxShapes` (8) is now a limit
  per cluster, not per material. A grid of separate tiles no longer loses
  its ninth.
- The edge band reads the backdrop bilinearly wherever it bends it.
  Nearest-neighbour reads stepped the refraction by whole texels, so every
  edge seen through the band was stair-stepped. The flat interior keeps its
  single tap.
- A shape that is laid out but not drawn stays out of the matte, its
  clusters and the diagnostics until it is. This covers shapes under an
  `Opacity` at zero, in an `Offstage` or in a lazy list's cache region. It
  used to sit at the layer's origin as a phantom.
- A pass whose material changes only in shading (tint, frost, highlight) is
  carried over to its new material and keeps its matte. A focused
  `GlassTextField` used to rebake seventeen times.
- `GlassTextField`'s focus is now a uniform on its pass, driven the way
  `GlassPresence` drives a fade. The focus animation re-sorts no pass.
- A shape painted straight into its layer no longer walks up the tree on
  every paint to look for a repaint boundary.
- The cross-pass overlap warning reports every overlapping pair of passes
  in the same paint, not only the first. An overlap that animates is
  reported once. Nothing is exempt from it.

### Motion

- `InteractiveGlass.glow` turns the touch glow off for one surface, where a
  glow would light glass it should not.
- Anchored press-stretch: `InteractiveGlass` elongates a surface toward the
  finger that is holding it, via the new `GlassPressStretch` and
  `GlassMotionState.pressAnchor`.
- Touch glow: `GlassGlow` drives a per-pass shader uniform from the pointer,
  reaching neighbouring shapes so a touch's glow is not clipped to the
  surface under the finger.
- Fixed a surface with no area (zero width or height) transforming to NaN
  instead of resolving to a safe default.

### Debug tooling

- A debug-only warning fires when shapes in different render passes overlap
  on screen, surfacing the artifact behind
  [flutter/flutter#187820](https://github.com/flutter/flutter/issues/187820)
  before it reaches a release build.

## 0.1.0

First release.

### Rendering

- `GlassLayer` captures the backdrop once per material, and every `Glass`
  under it registers into one shared signed-distance matte.
- Two refraction models. `GlassMaterial.regular(brightness:)` and
  `GlassMaterial.clear()` bend only inside a band at the rim, fitted against
  iOS 27 captures. `GlassMaterial.dome()` refracts across the whole surface.
- Shapes: `GlassRoundedRectangle`, `GlassOval` and `GlassSuperellipse`.
  `GlassBlendGroup` smooth-mins shapes into one another.

### Motion

- `InteractiveGlass` handles press, drag, fling and spring-home. Squash and
  stretch are read off the spring's own velocity.
- Springs take a duration and a bounce, the way SwiftUI specifies them:
  `GlassMotion.bouncy`, `.snappy`, `.smooth` and `.interactive`.

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

### Known limits

- Benchmark budgets are seed values, not measurements from real hardware.
