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

    float sd = gfSceneDistance(p);

    // Far outside every shape: encode a saturated *positive* distance rather
    // than a zeroed texel. The final pass derives coverage from channel B
    // (see gfDecodeMatteDistance), and a zeroed texel decodes as
    // -maxDisplacement -- the deep interior -- which would make the padding
    // around each shape read as solid glass.
    if (sd > maxDisplacement) {
        fragColor = vec4(0.5, 0.5, 1.0, 0.0);
        return;
    }

    vec2 normal = gfSceneNormal(p, 1.0);
    float band = mix(edgeRefraction, edgeRefraction * 4.0, clamp(spread, 0.0, 1.0));
    float magnitude = gfDisplacementMagnitude(min(sd, 0.0), band, edgeRefraction);

    // The real signed distance, on both sides of the boundary, and NOT
    // premultiplied by coverage. Both matter now that the final pass reads
    // this channel: clamping it to the interior leaves it unable to say how
    // far outside a texel is, and premultiplying scales it toward zero --
    // which decodes as "deep inside" -- at exactly the fringe where coverage
    // is being resolved. Antialiasing is the final pass's job; uOptical.w
    // (aaWidth) still sizes the matte's padding on the Dart side.
    fragColor = gfEncodeMatte(normal, sd, magnitude, maxDisplacement);
}
