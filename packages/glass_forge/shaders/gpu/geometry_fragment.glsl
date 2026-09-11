#version 460 core

// GPU render-pass counterpart to shaders/geometry.frag. Same SDF, edge
// profile and matte codec -- see shaders/common/ -- so the accelerated and
// runtime-effect producers stay interchangeable (Task 18 acceptance
// criterion 8 checks their output matches).
//
// Differences from the runtime-effect version are mechanical, not
// mathematical:
//
//   * Uniforms arrive through a named uniform block (FragInfo) rather than
//     loose globals -- Flutter GPU shader bundles reflect uniforms as named
//     structs (see Shader.getUniformSlot), unlike the SkSL runtime-effect
//     frontend that geometry.frag targets. The #define aliases below let
//     the shared common/ files see the same bare identifiers either way,
//     satisfying common/sdf.glsl's "read uShapeData as a global" rule --
//     these aliases still expand to a global (frag_info is file-scope), not
//     a function parameter.
//   * uOrigin carries (allocation.left, allocation.top) rather than an
//     engine-written uSize placeholder as in geometry.frag. gl_FragCoord is
//     the render target's own raw pixel coordinates (0..width, 0..height),
//     but FlutterFragCoord() in the runtime-effect path -- which
//     RuntimeGeometryProducer feeds through a Canvas translated by
//     (-allocation.left, -allocation.top) before drawing -- reports
//     coordinates in that *local*, pre-translation space instead (matching
//     the rect argument passed to drawRect, not the rasterized device
//     pixel). uOrigin reproduces the same local space here so both
//     producers evaluate the shared SDF at the same layer-local coordinate.
//     Confirmed empirically, byte-for-byte, in the cross-producer golden
//     test in gpu_geometry_producer_test.dart -- neither Flutter GPU's docs
//     nor the runtime-effect frontend's docs spell this out.

precision highp float;

#define MAX_SHAPES 8

uniform FragInfo {
    // (allocation.left, allocation.top) -- see the file header for why this
    // is needed to match FlutterFragCoord()'s local coordinate space.
    vec2 uOrigin;
    // maxDisplacement, edgeRefraction, refractionSpread, antialiasWidth.
    vec4 uOptical;
    vec4 uShapeDataBlock[MAX_SHAPES * 3];
    float uNumShapes;
} frag_info;

#define uOptical frag_info.uOptical
#define uShapeData frag_info.uShapeDataBlock
#define uNumShapes frag_info.uNumShapes

out vec4 fragColor;

#include "common/sdf.glsl"

// Identical to geometry.frag's gfSceneDistance -- see there for the fold
// order and culling rationale. Kept in sync by hand; drift here silently
// diverges the two producers, which is exactly what the cross-producer
// golden suite in gpu_geometry_producer_test.dart exists to catch.
float gfSceneDistance(vec2 p) {
    float result = 1e9;
    float groupResult = 1e9;
    float groupBlend = 0.0;
    int count = int(uNumShapes);

    for (int i = 0; i < MAX_SHAPES; i++) {
        if (i >= count) { break; }

        float marker = GF_MARKER(i);
        bool startsGroup = marker < 0.0;
        float blend = startsGroup ? -marker - 1.0 : marker;

        // Conservative bound first, matching geometry.frag.
        float bound = gfBoundLowerBound(i, p);
        float best = min(result, groupResult);
        if (bound >= best + blend && !startsGroup) {
            continue;
        }

        float d = gfShapeDistance(i, p);

        if (startsGroup) {
            result = min(result, groupResult);
            groupResult = d;
            groupBlend = blend;
        } else {
            groupResult = smoothUnion(groupResult, d, groupBlend);
        }
    }
    return min(result, groupResult);
}

#include "common/profile.glsl"
#include "common/codec.glsl"

void main() {
    vec2 p = gl_FragCoord.xy + frag_info.uOrigin;

    float maxDisplacement = uOptical.x;
    float edgeRefraction  = uOptical.y;
    float spread          = uOptical.z;
    float aaWidth         = uOptical.w;

    float sd = gfSceneDistance(p);

    // Centred half-pixel coverage, matching geometry.frag.
    float alpha = 1.0 - smoothstep(-aaWidth, aaWidth, sd);
    if (alpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 normal = gfSceneNormal(p, 1.0);
    float band = mix(edgeRefraction, edgeRefraction * 4.0, clamp(spread, 0.0, 1.0));
    float magnitude = gfDisplacementMagnitude(min(sd, 0.0), band, edgeRefraction);

    vec4 encoded = gfEncodeMatte(normal, min(sd, 0.0), magnitude, maxDisplacement);
    fragColor = encoded * alpha;   // premultiplied output
}
