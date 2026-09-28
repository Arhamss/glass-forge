## Unreleased

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
- A debug warning when more shapes share one material in a `GlassLayer`
  than a pass can carry (`kMaxShapes`, 8). The extras were silently not
  drawn.
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

### Chrome

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

### Motion

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
