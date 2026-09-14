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
