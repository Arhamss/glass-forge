# glass_forge

Liquid glass for Flutter that is honest about the GPU it is running on.

Real refraction where the device can afford it, a graceful climb-down
everywhere else, and a benchmark harness that refuses to pass off a debug
build as a measurement.

> **Status: built, not released.** The renderer, tier engine, motion, design
> system, benchmark harness and a workbench app all exist and are tested.
> Nothing is published — the package is `publish_to: none`, so
> `flutter pub add glass_forge` will not find it; depend on it by path.
>
> **Nothing has been measured on real hardware.** Every performance number in
> this repo, including the budgets the benchmark gate enforces, is a seed
> value rather than a capture. Verifying [flutter#187820] (glass over glass
> washing out) also needs a physical device, and has not been done.

[flutter#187820]: https://github.com/flutter/flutter/issues/187820

## Layout

One package. Add it and everything works — rendering, tiering, motion, the
design system and the native accessibility signals. There is no companion
package to remember, and no configuration required to get correct behaviour.
The package's own [README](packages/glass_forge/README.md) is the API guide,
and every snippet in it is compiled by a test.

| Path | What it is |
|---|---|
| [`packages/glass_forge`](packages/glass_forge) | The package. Shapes, SDF, both geometry producers, composition, tier engine, motion, tokens, native signals. |
| [`apps/glass_forge_workbench`](apps/glass_forge_workbench) | Visual workbench — test surfaces, tier forcing, material knobs. |
| [`packages/glass_forge/benchmark`](packages/glass_forge/benchmark) | The benchmark runner — 16 single-axis scenes, real percentiles, and budgets in a checked-in file. |

## Why

Flutter's glass packages render one way and hope for the best. `BackdropFilter`
forces a `saveLayer` and a framebuffer read-back, which defeats the tile-based
rendering mobile GPUs depend on — so a design language built on glass gets
expensive fast, and gets expensive worst on the cheapest phones.

`glass_forge` keeps one widget API and varies the strategy underneath:

| Tier | Renders |
|---|---|
| **full** | Everything: refraction, dispersion, specular, blending, and the dome lens |
| **balanced** | The dome without dispersion — 12 backdrop reads per fragment down to 4 |
| **reduced** | The lens flattens to Apple's edge band, keeping tint, saturation, frost and light |
| **flat** | No refraction: the frost, the tint and a contrasting border |
| **off** | Nothing is rendered at all |

The engine resolves a tier from four inputs — GPU capability, thermal state,
observed frame health, and accessibility settings. Capability, heat and
accessibility set absolute ceilings; frame health steps down relatively from
wherever those left it, so the same frame rate lands lower on a hot device
than a cool one. Flattening holds until the device is fully healthy again, so
it cannot oscillate. `ResolvedTier.describe()` reports *why* the current tier
was chosen, not just which one it is.

`flat` doubles as the accessibility path for Reduce Transparency and Increase
Contrast — which almost no Flutter glass package honours today. It applies
automatically only inside a `GlassTierScope`.

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
