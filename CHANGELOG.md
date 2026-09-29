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

### Changed

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
  is capped at the edge.
- `InteractiveGlass`'s touch glow is sized to the pressed surface (its
  longest side, 48 to 320) instead of a fixed 320. The glow is one light
  per layer, so a fixed 320 washed a whole screen of tiles white for a
  press on any one of them.
- The debug warning for glass shapes overlapping across backdrop passes
  prints once per pair of passes instead of on every frame. An overlap that
  lasted printed about sixty times a second and buried the rest of the log.
- A debug warning when more shapes sit in one cluster than a single draw
  can carry (`kMaxShapes`, 8). The limit is per cluster of nearby or
  blended shapes now, not per material; see Rendering below.
- `GlassDetentSheet.material` replaces the sheet role's material for an app
  with a look of its own. Null keeps the role's, so nothing changes by
  default; label colour, shadows and motion still come from the role.
- Fixed: dragging an `InteractiveGlass` stretched it into a needle toward
  the finger. Pointer moves arrive in the coordinate space of the
  pointer-down, so the press anchor grew with the drag distance and the
  press-stretch with it. The anchor is now measured against where the
  surface is, recomputed as it springs after the finger, and clamped to the
  surface's own extent.

- `GlassDetentSheet.bottomGap` separates the floating sheet's bottom inset
  from its side ones. A sheet that floats over other glass has to clear
  that chrome's full height before their backdrop passes would overlap, and
  driving every edge from one number charged twice that clearance in width.
  Defaults to `gap`, so a sheet floating over nothing is unchanged.

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
  settles to the side it ends up past. `activeTrackColor` defaults to an
  approximate system green.
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

- `GlassScaffold` puts the composition rules in place for you. The bars
  sit in a layer of their own. The body gets one layer, which draws glass
  only between the bars. The body is padded to clear the bars, and its
  `viewInsets.bottom` is 0 under a bottom bar that rides the keyboard. Each
  bar fades out over the first 40% of any route that covers the page, so
  the bar and the covering glass are never two backdrop filters over the
  same pixels. `material` is what a bare `Glass` in either layer inherits.
- `GlassTabBar` and `GlassTab`, a floating capsule with a painted selection
  pill. A glass lens rises out of the pill only while the selection
  travels (a tap, or a drag it chases under the finger), then sinks back.
  A resting finger swells the pill and raises no lens. `material` takes a
  look of the bar's own. `GlassTabBar.height` and `GlassTabBar.margin` are
  public for laying out around it. `GlassTab.semanticLabel` names icon-only
  tabs. Labels stop growing at 1.5x text size. In debug it reports a bar
  too narrow for 44-point tabs.
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
  reported once. The tab-bar lens is exempt against its own bar, and
  against nothing else.

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

- `Glass.containsChild` is accepted but not wired yet.
- Benchmark budgets are seed values, not measurements from real hardware.
