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
// profile (0 edge band, 1 dome), dome thickness, unused, unused. Declared
// last so every uniform before it keeps the index it always had.
uniform vec4 uProfile;

out vec4 fragColor;

#include "common/sdf.glsl"

#include "common/scene.glsl"
#include "common/profile.glsl"
#include "common/codec.glsl"
#include "common/matte_pass.glsl"

void main() {
    // FlutterFragCoord() reports the local, pre-translation space the
    // RuntimeGeometryProducer's translated Canvas draws into -- already
    // layer-local, so it needs no origin fixup. Everything downstream lives
    // in common/matte_pass.glsl, shared with the Flutter GPU producer.
    fragColor = gfBakeMatte(FlutterFragCoord().xy, uOptical.x, uOptical.y,
                            uOptical.z, uProfile);
}
