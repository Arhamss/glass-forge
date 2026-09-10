# Reference: motor 1.1.0 teardown

Captured 2026-09-10 from a full source read of
`~/.pub-cache/hosted/pub.dev/motor-1.1.0`.
Upstream: https://github.com/whynotmake-it/rivership/tree/main/packages/motor
License: MIT, Copyright 2025 Tim Lehmann for whynotmake.it

**Verdict: depend, do not vendor.** But the useful surface is ~400 lines, and
about six things glass_forge needs do not exist in it. Those become a
`glass_forge/motion` layer on top, not a thin passthrough.

4,697 lines of Dart, no native code, no shaders. Deps: `equatable`, `meta`.
Requires Flutter >= 3.32.

## The finding that matters most

**`MotionController<T>` extends `Animation<T>`**, and Flutter's `Animation<T>`
implements `ValueListenable<T>`. So a motor value can drive a `FragmentShader`
uniform with **no widget rebuilds at all**:

```dart
// in a State with SingleTickerProviderStateMixin
final c = SingleMotionController(motion: CupertinoMotion.interactive(), vsync: this);

// then either:
CustomPaint(painter: GlassPainter(repaint: c))       // repaint-only
// or, in a RenderBox:
c.addListener(markNeedsPaint);
```

Notifications come from `notifyListeners()` inside the ticker callback. No
`setState`, no element rebuild, no layout. Every motor *widget* is a thin layer
over this controller — we do not need any of them.

## Spring model

Pure delegation to Flutter's own `SpringSimulation` — a linear damped harmonic
oscillator, solution branch chosen from the discriminant. motor adds no physics
of its own.

**iOS-style `duration + bounce` is supported** via `CupertinoMotion`, which maps
to `SpringDescription.withDurationAndBounce`:

```
mass = 1
k    = 4*pi^2 / duration^2
zeta = bounce > 0 ? 1 - bounce : 1 / (bounce + 1)
c    = 2 * zeta * sqrt(m*k)
```

`duration` here is the perceptual oscillation period, not the settle time.
Negative bounce gives an overdamped spring. This matters for Apple parity —
Apple's motion is specified this way, not in stiffness/damping.

Named presets: `CupertinoMotion.bouncy` (500ms, bounce .3), `.snappy`
(500ms, .15), `.smooth` (500ms, 0), `.interactive` (150ms, .14). Also
`MaterialSpringMotion` with 12 named constructors covering the Material 3
spatial/effects x fast/default/slow matrix.

**Interruption and redirection are correct.** `animateTo` samples the live
`dx` of each running simulation, stops the ticker, builds new simulations
seeded with that position *and* velocity, and restarts. Position and velocity
are both continuous (C1) across a retarget. A spring redirected mid-flight
does not jump. The `motion` setter redirects the same way.

## Multi-dimensional motion

`MotionConverter<T>` flattens `T` to `List<double>`; the controller runs **one
independent `Simulation` per index**, and finishes only when all dimensions
report done. Per-axis motions via `.motionPerDimension`.

Built-in converters: `double`, `Offset`, `Size`, `Rect`, `Alignment`, `Color`
(RGBA floats), `EdgeInsets`, `EdgeInsetsDirectional`. Arbitrary N-dimensional
via `MotionConverter.custom`.

**Not covered:** `Matrix4`, `Radius`, `BorderRadius`, `Path`, and any
perceptual colour space (no HSL/Oklab). Dimension count is fixed at
construction.

Because the ODE is linear, equal-parameter per-axis springs are equivalent to
a vector spring — there is no magnitude artefact from animating axes
independently.

## Lifecycle

- Ticker is created in the constructor from the supplied `TickerProvider`.
- **Settled controllers idle at genuinely zero cost** — when every simulation
  reports done the ticker is stopped and unscheduled. No frame callbacks
  remain, and `velocities` short-circuits to zeros without touching the
  simulations.
- `TickerMode` is handled by Flutter's own `TickerProviderStateMixin`, so
  offscreen routes stop ticking. Note `isAnimating` still reports `true` while
  muted, and on unmute the spring jumps to wherever wall-clock says it should
  be. That is standard Flutter behaviour, not a motor bug.
- Disposal is clean; `resync(vsync)` is provided.

## Defects and gaps we inherit

| Issue | Impact on glass_forge |
|---|---|
| **`CurveSimulation.dx` returns `2*(x2-x1)/delta`** instead of the correct central difference `(x2-x1)/(2*delta)` — **4x too high**. Dart operator precedence bug. | Any curve -> spring handoff injects 4x velocity. Upstream PR candidate. Avoid mixing curves and springs until fixed. |
| **No decay / fling simulation.** Only spring, curve, none, trimmed. `createSimulation` is target-based. | Fling-reactive glass needs a custom `Motion` wrapping `FrictionSimulation`. The `Motion` base class is abstract with the right hooks, but `_getStatusWhenDone` and `_redirectSimulation` assume a target. |
| **No scroll coupling.** No `ScrollPosition` / listenable-target input anywhere. | Scroll-parallax glass is entirely ours. |
| **No follow-the-pointer primitive.** Tracking a finger means calling `animateTo` per pointer event, which reallocates N simulations and restarts the ticker each time. | Needs a cheaper "follow" primitive for drag-reactive glass. |
| **No rubber-band / overdrag resistance**, despite a changelog entry claiming it. Grep finds no such code. | Ours to write. Upstream's `stretch.dart` `withResistance` is a better starting point. |
| **`AnimationBehavior` is stored but never consulted.** | **Zero reduce-motion handling.** We must implement it ourselves — and it is a headline accessibility claim. |
| **Spring `tolerance` is not tunable** — `SpringMotion` never forwards it. Default is 1e-3 for distance and velocity. | Pixel-scale springs tick at sub-pixel amplitude before settling. Wasted frames on a shader-driving controller. |
| `SequenceMotionBuilder` calls `setState` every tick. | Use `SequenceMotionController` directly; never the builder. |
| `BoundedMotionController.value=` does not stop the ticker (the base setter does). | Setting `value` mid-flight on a bounded controller is silently overwritten next tick. |
| Base `value=` completes rather than cancels the pending `TickerFuture`. | `.then` callbacks fire as if the animation finished. |

## Per-frame cost

Per tick, per controller: one `List<double>` allocation, one closure for the
`every(isDone)` check (which re-evaluates each simulation on top of `x`), and
one `T` allocation per `value` read. A redirect additionally allocates N
`Simulation` objects and two lists.

Fine at gesture rate. Noticeable if driven per-frame from a scroll listener —
which is exactly what a scroll-coupled glass surface would do, so our follow
primitive must avoid `animateTo` churn.

`CupertinoMotion.description` recomputes `sqrt`/`pow` and allocates a
`SpringDescription` on **every access**, and `SpringMotion.==` calls it six
times — per build, not per frame.
