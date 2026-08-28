# Reference: liquid_glass_renderer 0.2.0-dev.4 teardown

Captured 2026-08-28 from `~/.pub-cache/hosted/pub.dev/liquid_glass_renderer-0.2.0-dev.4`.
Upstream: https://github.com/whynotmake-it/flutter_liquid_glass
License: MIT, Copyright 2025 Tim Lehmann for whynotmake.it

## Provenance

| Fact | Value |
|---|---|
| Latest version | `0.2.0-dev.4` |
| Published | ~9–10 months before 2026-08-28 |
| Total versions | 31, **every one a prerelease** |
| Stable release | never |
| Package size | 4.4 MB |
| Dart files | 21 |
| Shader files | 8 |

Same author ships `motor`, which reached **1.1.0 stable**. One graduated,
this one did not — read that as "the shader work is hard", not "abandoned".

## Public API surface

`LiquidGlassSettings` — ten knobs, and a sensible starting point for our own:

```
visibility            glassColor            thickness
blur                  chromaticAberration   lightAngle
lightIntensity        ambientStrength       refractiveIndex
saturation
```

Entry widgets: `LiquidGlass`, `LiquidGlass.withOwnLayer`, `LiquidGlassLayer`,
`LiquidGlassBlendGroup`, `Glassify`, `GlassGlow`, `FakeGlass`.

## The batching design — the part worth keeping

```
sdf.glsl:3     #define MAX_SHAPES 16
               uniform float uShapeData[MAX_SHAPES * 6]   // 96 floats
               uniform float uNumShapes
```

Six floats per shape: `type, centerX, centerY, sizeX, sizeY, cornerRadius`.

A `LiquidGlassLayer` packs up to **16 shapes into one shader pass**, and
`uBlend` smooth-blends their SDFs so nearby shapes merge — that merging is what
reads as "liquid" rather than "frosted". `sceneSDF` unrolls for 1–4 shapes and
loops beyond.

This is the correct architecture and we should keep it. The complaint is
ergonomic: batching is something the caller has to know to reach for
(`LiquidGlassLayer` + children) instead of the default.

## Shader corpus

```
sdf.glsl                        shape SDFs + scene composition
shared.glsl                     common helpers
displacement_encoding.glsl      refraction displacement encode/decode
render.glsl                     shading
liquid_glass_filter.frag        main filter pass      <-- fails SkSL
liquid_glass_final_render.frag  final composite
liquid_glass_arbitrary.frag     arbitrary shapes (236 lines, largest)
liquid_glass_geometry_blended.frag  geometry path     <-- same array pattern
```

## The SkSL defect

`sdf.glsl` passes arrays into functions by value:

```glsl
float getShapeSDFFromArray(int index, vec2 p, float shapeData[MAX_SHAPES * 6]) {
    int baseIndex = index * 6;
    float type = shapeData[baseIndex];
    ...
}

float sceneSDF(vec2 p, int numShapes, float shapeData[MAX_SHAPES * 6], float blend) {
    float result = getShapeSDFFromArray(0, p, shapeData);
    ...
}
```

`spirv-cross` lowers the by-value parameter to a local copy —
`float param_2[96] = shapeData;` — which SkSL rejects outright:

```
error: initializers are not permitted on arrays (or structs containing arrays)
error: unknown identifier 'param_2'
```

**Fix:** `uShapeData` is a uniform and already globally visible. Remove the
array parameter from both signatures, index the uniform directly. ~10 lines
across `sdf.glsl`, `liquid_glass_filter.frag`,
`liquid_glass_geometry_blended.frag`.

**Blast radius today: none on mobile.** Since Flutter 3.29 non-Vulkan Android
falls back to Impeller/GLES rather than Skia, and Skia is removed from iOS.
SkSL is the web/CanvasKit path. This gates web support, not KiBU.

## What to vendor

Vendor: the shader corpus and the layer/render-object plumbing
(`rendering/`, `internal/multi_shader_builder.dart`,
`internal/render_liquid_glass_geometry.dart`).

Do not vendor `motor` — depend on it. It is stable and maintained.
