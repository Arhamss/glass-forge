# glass_forge

Liquid glass for Flutter that is honest about the GPU it is running on.

Real refraction where the device can afford it, a graceful climb-down
everywhere else, and the frame timings published so the claim is checkable.

> **Status: scaffold.** No rendering is implemented yet. The research and the
> design are done and written down; start with the
> [architecture design](docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md).
> This README describes where it is going, not where it is.

## Layout

One package. `flutter pub add glass_forge` and everything works — rendering,
tiering, motion, and the native accessibility signals. There is no companion
package to remember, and no configuration required to get correct behaviour.

| Path | What it is |
|---|---|
| [`packages/glass_forge`](packages/glass_forge) | The package. Shapes, SDF, both geometry producers, composition, tier engine, motion, tokens, native signals. |
| [`apps/glass_forge_workbench`](apps/glass_forge_workbench) | Visual workbench — test surfaces, tier forcing, material knobs. |
| [`apps/glass_forge_benchmark`](apps/glass_forge_benchmark) | Device benchmark harness. Deliberately minimal, so it measures the renderer rather than itself. |

## Why

Flutter's glass packages render one way and hope for the best. `BackdropFilter`
forces a `saveLayer` and a framebuffer read-back, which defeats the tile-based
rendering mobile GPUs depend on — so a design language built on glass gets
expensive fast, and gets expensive worst on the cheapest phones.

`glass_forge` keeps one widget API and varies the strategy underneath:

| Tier | Condition | Renders |
|---|---|---|
| **T3 Full** | Impeller + Vulkan | Refraction, chromatic aberration, specular, shape blending |
| **T2 Reduced** | Impeller + OpenGL ES | Refraction at lower samples, clamped blur |
| **T1 Cheap** | Low-end / throttled | `BackdropFilter` + gradient border + baked sheen |
| **T0 Static** | Weakest devices, and *reduce transparency* | Solid translucent fill |

T0 doubles as the accessibility path — which almost no Flutter glass package
honours today.

## Documentation

**Design**

| Document | Contents |
|---|---|
| [Architecture design](docs/superpowers/specs/2026-09-10-glass-forge-architecture-design.md) | Locked decisions, the ten invariants, the render graph, decomposition |
| [Renderer core design](docs/superpowers/specs/2026-09-10-renderer-core-design.md) | Sub-project 1: API, shaders, invalidation, acceptance criteria |
| [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) | The original thesis. Several assumptions in it have since been falsified — see the architecture design §1 |

**Research**

| Document | Contents |
|---|---|
| [Upstream teardown](docs/reference/liquid_glass_renderer_teardown.md) | `liquid_glass_renderer` 0.2.0-dev.4 by source read: pipeline, batching, ~25 defects |
| [Upstream rewrite](docs/reference/upstream_rewrite.md) | The unreleased Flutter GPU rewrite: what to take, what it drops, repo health |
| [`motor` teardown](docs/reference/motor_teardown.md) | Spring physics: what it gives us, and the six gaps we fill ourselves |
| [Flutter rendering capabilities](docs/reference/flutter_rendering_capabilities.md) | What Flutter 3.47 actually exposes — backend detection, thermal, accessibility, engine bugs |
| [Apple Liquid Glass spec](docs/reference/apple_liquid_glass_spec.md) | The material as an implementable contract |
| [Shader techniques](docs/reference/shader_techniques.md) | Techniques with licence provenance |
| [Competitive landscape](docs/reference/competitive_landscape.md) | What others shipped, and what they document as broken |
| [KiBU inventory](docs/reference/kibu_glass_inventory.md) | The 63 surfaces that motivated the design |
| [`THIRD_PARTY.md`](THIRD_PARTY.md) | Attribution — upstream is under three licences, not one |

## Credit

Built on [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass)
by Tim Lehmann / whynotmake.it (MIT), whose shader corpus and 16-shape batching
design are the foundation here. Spring motion comes from
[`motor`](https://github.com/whynotmake-it/rivership/tree/main/packages/motor)
by the same author.

## License

MIT — see [`LICENSE`](LICENSE) and [`THIRD_PARTY.md`](THIRD_PARTY.md).
