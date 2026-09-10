#version 460 core
#include <flutter/runtime_effect.glsl>

// highp, not mediump. Coordinates here are physical pixels in the thousands,
// and mediump turns the coordinate subtraction into visible shimmer on large
// layers — upstream issue #57.
precision highp float;

#define MAX_SHAPES 8

// The engine overwrites the first declared vec2 below with the input size.
uniform vec2 uSize;
uniform vec4 uOptical;   // maxDisplacement, edgeRefraction, spread, aaWidth
uniform vec4 uShapeData[MAX_SHAPES * 3];
uniform float uNumShapes;

out vec4 fragColor;

#include "common/sdf.glsl"

// Folds the scene deterministically: shapes are walked in registration order,
// a negative marker opens a group, and groups combine by plain min. The
// quadratic smooth-min is not associative, so order is load-bearing.
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

        // Conservative bound first. Skipping the real SDF here is worth
        // 14-23% GPU on shape-heavy scenes.
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
    vec2 p = FlutterFragCoord().xy;

    float maxDisplacement = uOptical.x;
    float edgeRefraction  = uOptical.y;
    float spread          = uOptical.z;
    float aaWidth         = uOptical.w;

    float sd = gfSceneDistance(p);

    // Centred half-pixel coverage. Screen-space derivative functions are
    // unavailable in runtime effects even on Impeller, so the width comes
    // from the caller, computed from the transform basis. The matte reserves
    // half a pixel of padding for this.
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
