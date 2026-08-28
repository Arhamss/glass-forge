# glass_forge

Liquid glass for Flutter that is honest about the GPU it is running on.

Real refraction where the device can afford it, a graceful climb-down
everywhere else, and the frame timings published so the claim is checkable.

> **Status: scaffold.** Nothing is implemented yet. Start with
> [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) — the thesis, the research and the
> plan. This README describes where it is going, not where it is.

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

| Document | Contents |
|---|---|
| [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) | Thesis, tier design, licensing duties, first-weekend plan |
| [`docs/reference/liquid_glass_renderer_teardown.md`](docs/reference/liquid_glass_renderer_teardown.md) | Upstream architecture, the batching design, the SkSL defect and its fix |
| [`docs/reference/kibu_glass_inventory.md`](docs/reference/kibu_glass_inventory.md) | The 63 real surfaces driving the design |
| [`THIRD_PARTY.md`](THIRD_PARTY.md) | MIT attribution — fill in before vendoring |

## Credit

Built on [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass)
by Tim Lehmann / whynotmake.it (MIT), whose shader corpus and 16-shape batching
design are the foundation here. Spring motion comes from
[`motor`](https://github.com/whynotmake-it/rivership/tree/main/packages/motor)
by the same author.

## License

MIT — see [`LICENSE`](LICENSE) and [`THIRD_PARTY.md`](THIRD_PARTY.md).
