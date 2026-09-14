# Documentation

Design records and research behind glass_forge. None of it ships with the
package; `.pubignore` keeps this directory out of the published archive.

The records are dated and describe the repository as it was when they were
written. Until 2026-09-14 the package lived at `packages/glass_forge/`, beside
a workbench app at `apps/glass_forge_workbench/`. The workbench has since been
deleted and the package moved to the repository root, so paths in the older
documents are historical. They were left as written rather than rewritten
after the fact.

## Design

| Document | Contents |
|---|---|
| [Architecture design](superpowers/specs/2026-09-10-glass-forge-architecture-design.md) | Locked decisions, the ten invariants, the render graph, decomposition |
| [Renderer core design](superpowers/specs/2026-09-10-renderer-core-design.md) | Sub-project 1: API, shaders, invalidation, acceptance criteria |
| [`PROJECT_BRIEF.md`](../PROJECT_BRIEF.md) | The original thesis. Several assumptions in it have since been falsified — see the architecture design §1 |

## Research

| Document | Contents |
|---|---|
| [Upstream teardown](reference/liquid_glass_renderer_teardown.md) | `liquid_glass_renderer` 0.2.0-dev.4 by source read: pipeline, batching, ~25 defects |
| [Upstream rewrite](reference/upstream_rewrite.md) | The unreleased Flutter GPU rewrite: what to take, what it drops, repo health |
| [`motor` teardown](reference/motor_teardown.md) | Spring physics: what it gives us, and the six gaps we fill ourselves |
| [Flutter rendering capabilities](reference/flutter_rendering_capabilities.md) | What Flutter 3.47 actually exposes — backend detection, thermal, accessibility, engine bugs |
| [Apple Liquid Glass spec](reference/apple_liquid_glass_spec.md) | The material as an implementable contract |
| [Shader techniques](reference/shader_techniques.md) | Techniques with licence provenance |
| [Backdrop sampling](reference/backdrop_sampling.md) | Whether the nearest-neighbour backdrop sampler shows, and the bilinear reconstruction |
| [Competitive landscape](reference/competitive_landscape.md) | What others shipped, and what they document as broken |
| [KiBU inventory](reference/kibu_glass_inventory.md) | The 63 surfaces that motivated the design |
| [`THIRD_PARTY.md`](../THIRD_PARTY.md) | Attribution — upstream is under three licences, not one |
