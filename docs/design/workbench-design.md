# Glass Forge Workbench — design direction

Resolved via `ui-ux-pro-max` (Flutter stack) with the design dials at
variance 7 / motion 8 / density 4, then art-directed against real references.

> **Comps not generated.** The flow calls for reference comps before code.
> No image-generation capability is connected in this session, so this
> document stands in for them. It is written to be buildable without one.

## 1. Anchors, and what each one gets right

| Reference | What to take |
|---|---|
| **Apple iOS 26 Control Center** | Glass only over content-rich backdrops; reserved for the navigation layer; speculars restrained, never decorative. |
| **Rive editor** | Canvas is the hero, chrome recedes. Property panels dense but quiet — the artifact gets the light. |
| **shadcn/ui gallery** | How to show variants systematically: one live specimen, controls beside it, code beneath. Never a spec sheet. |
| **Spline / Shadertoy** | The backdrop *is* the product. |

Take the principles. Copy no identity, no proprietary asset.

## 2. The one idea

**Instrument, not brochure.**

And the counterintuitive call that keeps this out of slop territory:
**a demo app for a glass package should mostly not be made of glass.**

Two reasons, both real:

1. Apple's own guidance is "always avoid glass on glass." A workbench whose
   chrome is also glass violates the thing it is demonstrating.
2. Practically: if the controls are glass, they shift and re-tint every time
   you change the specimen. You cannot read the slider you are dragging.

So: **one glass specimen on a living stage, and a solid, quiet instrument
panel.** The glass is the exhibit. Everything else gets out of its way.

## 3. Design bible — hold this across every screen

| Axis | Decision |
|---|---|
| Platform mode | Cross-platform premium neutral, dark |
| Theme | Deep dark (OLED). Ground `#0A0E17`, raised `#131A28` |
| Accent | One functional green `#22C55E`, used **only** for active/running state |
| Type | IBM Plex Sans for prose; **JetBrains Mono for every number, unit and token name** |
| Structure | Specimen-led: stage over instrument, on every screen |
| Imagery | Tactile abstract + photographic — the backdrops are refraction targets, not decoration |
| Texture | Low-opacity technical grid on the instrument; real content on the stage |
| Radius | 20 stage, 14 cells, 999 pills. Three values, no others |
| Icons | Single stroke weight, one family, 24pt token. No emoji |
| Motion | Sheet-rise for panels; tab-transition calm for section changes |

## 4. Screen architecture

Every screen is the same two zones. Learn it once, it holds everywhere.

```
┌─────────────────────────────┐
│  STAGE            ~55%      │   live glass over a swappable backdrop
│                             │   edge-to-edge, no chrome on top of it
│      ┌───────────┐          │   backdrop picker is a thin rail at the
│      │  specimen │          │   very bottom edge of the stage
│      └───────────┘          │
│  ▓▒░ backdrop rail ░▒▓      │
├─────────────────────────────┤
│  INSTRUMENT       ~45%      │   SOLID. never glass.
│  ── Material ───────────    │   grouped cells, hairline dividers
│  Thickness        12.0 px   │   value right-aligned, mono, always united
│  ────●──────────────────    │
│  Edge refraction  27.4 px   │
│  ──────────●────────────    │
└─────────────────────────────┘
```

**Backdrops are the product surface**, not styling. The rail offers exactly
the five that prove something:

- **Photographic** — the realistic case
- **1px checkerboard** — worst case for texel snapping
- **Fine diagonals** — worst case for edge shimmer
- **Gradient mesh** — shows tint and saturation behaviour
- **Pure black** — the rim-flicker test that upstream issue #112 was about

## 5. The screens

1. **Gallery** — entry. A vertical shelf of specimen cards, each a *live*
   miniature over its own backdrop. No text hero, no feature grid. The work
   is the pitch.
2. **Specimen** — the workbench. Stage + instrument, full material controls.
3. **Blend playground** — two or three draggable shapes that merge as they
   approach. Stage goes full-bleed; instrument collapses to one blend slider.
4. **Tiers** — the same scene at each tier, side by side, with a frame-timing
   strip in mono. This is the package's actual claim, so it gets a screen.
5. **Sampling probe** — Task 19's screen, folded into the same two-zone system
   rather than bolted on.

## 6. States that actually exist here

Shaders take a beat to warm. That is a real state, not an edge case, and it
gets a designed treatment rather than a spinner:

- **Warming** — the stage shows the backdrop alone with a thin mono line:
  `compiling shaders…`. The specimen fades in when ready. No layout shift.
- **Unsupported** — on a backend without `ImageFilter.shader`, the stage
  states plainly which tier it fell back to and why. The package's whole
  thesis is honesty about the GPU; the demo should model that.
- **Reduced transparency on** — the stage says so, and shows the tier it
  pinned to. Do not silently render full glass.

## 7. Anti-slop commitments

- No purple-on-white, no default-blue. One green, used functionally.
- No ambient blobs. Backdrops are real content with real frequency.
- No cards-inside-cards: the stage is edge-to-edge, the instrument is one
  sheet with dividers.
- Every number is monospaced and carries its unit.
- No feature-grid landing screen. A gallery of live specimens instead.

## 8. Accessibility floor

- Body text ≥ 4.5:1 on the dark ground; the muted grey must be measured, not
  eyeballed.
- Touch targets ≥ 44pt; slider thumbs get an expanded hit area.
- Reduced motion disables the idle drift and the gel press, keeping state
  changes instant rather than animated.
- The backdrop rail is a segmented control with labels, not colour-only swatches.
