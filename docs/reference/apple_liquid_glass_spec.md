# Reference: Apple's Liquid Glass, as an implementable spec

Captured 2026-09-10. Sources: WWDC25 sessions 219 ("Meet Liquid Glass"), 323,
284, 356; the HIG Materials page; SwiftUI/UIKit API docs; WWDC26 SOTU for iOS
27 changes; plus two independent runtime teardowns of the shipping
implementation.

We committed to **faithful parity**, so this is the target. Everything below is
attributed; claims that are observed-but-unconfirmed are flagged.

## 1. Variants — there are only two

| Variant | Behaviour |
|---|---|
| **Regular** | "the most versatile… gives you all the visual and adaptive effects… works in any size, over any content and anything can be placed on top of it." HIG: "Blurs and adjusts luminosity of background content to maintain legibility." |
| **Clear** | "does not have adaptive behaviors… permanently more transparent… needs a dimming layer to darken the underlying content." Use only when **all** of: over media-rich content, a dimming layer won't hurt that content, and the foreground is bold and bright. |
| *Identity* | SwiftUI only, a no-op. |

**"They should never be mixed."** (219)

HIG gives the dimming number outright:
**bright background -> add a 35% opacity dark dimming layer; dark background ->
no dimming layer needed.**

There is no separate "tinted" or "interactive" material — `Glass.tint(_:)` and
`Glass.interactive(_:)` are modifiers on either variant, and
`UIGlassEffect.Style` has exactly `.regular` and `.clear`. Tint "uses a vibrant
color that adapts to the content behind it."

**Size is a material input**, not just a layout fact: "larger size is more
opaque; smaller size is clearer," and larger elements get "more pronounced
lensing and refraction… deeper, richer shadows… softer scattering of light."

## 2. Containers — one shared sampling region

The single most important architectural sentence in the whole WWDC corpus:

> "**Glass cannot sample other glass**, so having nearby glass elements in
> different containers results in inconsistent behavior. Using a glass
> container allows these elements to share their sampling region." (323)

And: the material samples "an area larger than itself."

Concretely — **one padded backdrop capture per container**, shared by every
shape in it. API evidence: `GlassEffectContainer(spacing:)`,
`UIGlassContainerEffect(spacing)`, `NSGlassEffectContainerView`,
`glassEffectUnion(id:namespace:)`, `glassEffectID(_:in:)`, and
`cornerConfiguration = .containerRelative()`.

This maps exactly onto a batched-SDF layer, and it is why upstream's
`nested-glass-workbench` example wraps a whole app in one layer.

## 3. Lensing — an edge band, not a whole-surface distortion

Apple's framing: "Whereas previous materials scattered light, this new set of
materials dynamically bends, shapes, and concentrates light in real time."
(De)materialisation animates "the light bending and lensing" — **refraction
amount is the animated parameter, not alpha.**

### What the runtime actually does

From a teardown of the iOS implementation (Lrdcq): glass replaces the view's
layer with `_UIMultiLayer`, configured by `_UIViewGlass` (`smoothness`,
`tintColor`, `contentLensing`, `highlightsDisplayAngle`). Three GPU stages:

```
CASDFElementLayer   shape mask, synced to the view
CASDFGenerator      GPU SDF   (jump-flood is the author's guess - speculative)
CABackdropLayer     "glassBackground" CAFilter
                      inputInnerRefractionHeight  <- band width, inward from edge
                      inputInnerRefractionAmount  <- displacement magnitude
                      + blur radius, exposure, tint, highlight params
```

The SDF texture: **R = edge distance (0..1 mapping 50px..0), G/B = normalised
direction to the nearest edge.**

> **Conclusion: Apple's lensing is a 2D edge-band displacement along the SDF
> normal. The interior is undistorted.**

That is a materially different model from upstream `liquid_glass_renderer`,
which refracts across the whole shape via a physical `refract()` through a
hemisphere. Apple's is cheaper *and* is what actually matches.

Cost is approximately a blur when static; regenerating the SDF during shape
animation is the expensive part (author's inference).

A macOS teardown (ShatteredGlass) agrees on structure: `CABackdropLayer`
carrying "refraction, blur, vibrancy, and tone mapping" in one pass, plus **two
`CASDFGlassHighlightEffect` layers at opposing light angles** through a
`vibrantColorMatrix`.

### Edge profile

A careful CSS/SVG reconstruction (kube.io) ray-traced Snell's law at n=1.5 over
four candidate height profiles and found the **convex squircle**
`y = fourth-root(1 - (1-x)^4)` matches Apple best — "Apple's Liquid Glass
appears to favor convex profiles." Apple is all-convex except the Switch knob,
which avoids sampling beyond the object's bounds.

A Metal rebuild (Sorrell) used superellipse n=4 with
`bend = slope * (1 - 1/n) * r * bevel * 0.5` and three IORs for aberration.

### Chromatic aberration — unverified on Apple's side

Reviewers describe visible colour fringing (MacStories), but **neither teardown
lists a dispersion parameter**. A third source (1ar.io) describes a
luminance-based displacement map, which contradicts the SDF+direction teardown;
treat that source as simplified. Flagging this as genuinely unresolved.

### Content-aware shadow and colour bleed

Shadow opacity "increases… when it is over text… lowers… over a solid light
background." And "light from colorful content nearby can subtly spill onto its
surface."

## 4. Specular highlights and device motion

Apple's own wording is hedged: "**In some cases**, the lighting responds to
device motion, making it feel like Liquid Glass is aware of its position in the
real world." The Newsroom copy is stronger: "dynamically reacts to movement
with specular highlights." Highlights also travel on interaction — on unlock
"these lights move in space, causing light to travel around the material."

Hands-on confirmation (MacStories): "responds to a device's movement via the
gyroscope and accelerometer; it also responds to the user's touches" — visible
on tab bars, the loupe, and notifications. Another reviewer observed the same
but "couldn't find any official documentation." The private
`highlightsDisplayAngle` property is consistent with a runtime light-angle
input.

**macOS has no IMU**, and the fluid/stretchy behaviours are "notably absent on
macOS."

**Implementable spec:** two opposing directional rim highlights driven by
`SDF normal · lightDir`; light angle is a uniform; feed it from the
accelerometer on phones, and keep it fixed (with interaction sweeps) elsewhere.
Exactly which iOS components subscribe to motion is undocumented.

## 5. Adaptation and legibility

- **Size gates the light/dark flip.** "Small elements like navbars and tabbars…
  flip from light to dark based on the background. Larger elements like menus
  and sidebars adapt based on context, but they don't flip."
- "The amount of tint and the dynamic range shift to always ensure buttons
  remain legible, while letting as much of the content through as possible."
- **Labels flip via vibrancy, not hard-coded colour.** "SwiftUI automatically
  uses a vibrant text color that adapts"; "Labels added to glass content view
  automatically become vibrant." HIG: "Always use vibrant colors on top of
  Liquid Glass," and calls out `systemGray3` as unreadable.
- **The legibility fallback is the scroll-edge effect.** "As content begins to
  scroll underneath a glass element, the effect gently dissolves the content
  into the background… When darker content scrolls under, triggering the glass
  itself to transition to its dark style, the effect intelligently switches to
  apply a subtle dimming." `ScrollEdgeEffectStyle.soft` (iOS default) vs
  `.hard` (macOS default). "Apply one scroll edge effect per view."

Worth recording that this is also Apple's most-criticised behaviour: the
legibility gradients "appear, disappear, and change colour with seemingly
little relevance to what is underneath them."

**iOS 27 (June 2026):** the material is "tuned to more effectively diffuse
complex content behind it" and gains "a darkened edge along with brighter
specular highlights."

## 6. Motion

| Behaviour | Description |
|---|---|
| **Press / gel** | "inherent gel-like flexibility… the material illuminates from within as a form of feedback. **Starting right under your fingertips, the glow spreads throughout the element and onto any Liquid Glass elements nearby.**" Interactive glass "reacts to user interaction by scaling, bouncing, and shimmering." |
| **Morph** | "dynamically morphs between the controls in each context… a singular floating plane… the bubble simply pops open to reveal the content." `glassEffectID` + `.matchedGeometry`. UIKit: "When overlapping frames are animated, glass views combine into single shape." |
| **Merge / separate** | Container `spacing` sets the proximity at which shapes "merge like water droplets." `glassEffectUnion` forces a union. Mechanism per both teardowns: smooth-min on a shared SDF. |
| **Materialize** | Ramps **refraction**, not alpha. UIKit says set/unset `effect` rather than animating alpha. Expo confirms the consequence: "Setting opacity to 0 on GlassView… causes the glass effect to not render at all." |
| **Tab bar** | `.tabBarMinimizeBehavior(.onScrollDown)`, re-expands on reverse scroll, `UITabAccessory` rides along. iOS 27 adds `.toolbarMinimizeBehavior`. `backgroundExtensionEffect()` mirrors and blurs content under sidebars. |

Note the press behaviour spreads **to neighbouring glass elements** — that
requires the glow to be a property of the shared container, not the shape.

## 7. Accessibility — the exact contract

Apple's own definitions (219):

| Setting | Behaviour |
|---|---|
| **Reduce Transparency** | "makes Liquid Glass frostier and obscures more of the content behind it" |
| **Increase Contrast** | "makes elements predominantly black or white and highlights them with a contrasting border" |
| **Reduce Motion** | "decreases the intensity of some effects and disables any elastic properties for the material" |

Claims elsewhere that Reduce Motion "eliminates lensing" go beyond Apple's
wording — **unverified**.

Observed behaviour: Reduce Transparency "simply makes translucent areas more
opaque while maintaining the overall iOS 26 aesthetic"; Increase Contrast
"keeps the translucency, but… removes Liquid Glass' softness, giving icons a
more visible border." On macOS Tahoe, Increase Contrast forces Reduce
Transparency on.

**User preference, distinct from accessibility:** iOS 26.1 added a
**Clear / Tinted** toggle (Settings > Display & Brightness > Liquid Glass) —
"Tinted increases the opacity of Liquid Glass and adds more contrast." It
stacks with Reduce Transparency and **no public API exposes it**. iOS 26.2 added
a lock-screen-clock slider. **iOS 27 turns it into a slider "from ultra clear
to fully tinted" and removes the opt-out for apps built with Xcode 27.**

**The Flutter gap:** `AccessibilityFeatures` has `reduceMotion` and
`highContrast` but **no `reduceTransparency`**. See
`flutter_rendering_capabilities.md` §4 — parity requires our own platform
channel. Every competing Flutter package approximates it with `highContrast`
and documents the resulting hole.

## 8. When Apple says not to use it

- **Navigation layer only.** "best reserved for the navigation layer that
  floats above the content"; a glass table view "would make it compete with
  other elements and muddy the hierarchy." HIG: "exclusively for the functional
  layer… Exception: transient interactive elements like sliders and toggles."
- **"Always avoid glass on glass"** — use fills, transparency and vibrancy for
  elements on top.
- Avoid steady-state intersections of content and glass.
- **Tint sparingly**: "When every element is tinted, nothing stands out."
- Never mix Regular and Clear. Clear only over rich media.
- Group all custom glass in one container, for correctness *and* performance.
  Concentric corners. One scroll-edge effect per view.

The beta history is the empirical evidence for the legibility risk: beta 3
replaced nav bars with frosted glass, beta 4 partially reverted.

## 9. Distilled shader spec

1. **One padded backdrop capture per container.** Shared smooth-min SDF giving
   distance **and** direction. Uniforms: light angle, variant, tint, size.
2. **Displace UVs only within an inner band** along the SDF normal, magnitude
   `innerRefractionAmount` scaled by a convex-squircle profile. **Interior
   undistorted.** Animate the amount toward 0 to dematerialize.
3. Blur + luminosity/tone + vibrancy in one pass. Scale blur, opacity and
   shadow with element size.
4. **Two opposing rim highlights** from `n·L`. Light angle from the IMU on
   phones.
5. Sample backdrop luminance; flip the scheme and use vibrant labels **only for
   small shapes**; raise shadow opacity over text.
6. **Clear**: no adaptivity, plus a 35% dark scrim on bright backdrops.
7. **Press**: scale/bounce plus a touch-origin inner glow that spills to
   neighbours in the same container. Reduce Motion -> no elasticity.
   Reduce Transparency -> frostier. Increase Contrast -> near-opaque black or
   white plus a border.
8. **iOS 27 look**: stronger diffusion, a darkened edge ring, brighter
   speculars.
