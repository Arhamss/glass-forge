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

#include "common/scene.glsl"
#include "common/profile.glsl"
#include "common/codec.glsl"
#include "common/matte_pass.glsl"

void main() {
    // gl_FragCoord is the render target's own raw pixel coordinates, so the
    // allocation origin is added back to reach the same layer-local space
    // FlutterFragCoord() reports in geometry.frag -- see the file header.
    // Everything downstream lives in common/matte_pass.glsl, shared with the
    // runtime-effect producer.
    fragColor = gfBakeMatte(gl_FragCoord.xy + frag_info.uOrigin, uOptical.x,
                            uOptical.y, uOptical.z);
}
