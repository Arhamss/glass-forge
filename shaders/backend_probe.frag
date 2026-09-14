#version 460 core

// Reports which Impeller backend compiled this shader.
//
// `impellerc` injects IMPELLER_TARGET_OPENGLES into the GLES stage of every
// FragmentProgram asset, and nothing else in Dart or on any platform channel
// says whether Android fell back from Vulkan to GLES — the engine only logs
// it. So the one-bit answer has to come back out through a pixel: render
// this 1x1 offscreen, read the red channel, and a 1 means GLES.
//
// IMPELLER_TARGET_METAL and IMPELLER_TARGET_VULKAN are *not* injected for
// runtime-stage shaders (only for .shaderbundle/flutter_gpu), which is why
// this is one bit rather than three: Metal-versus-Vulkan comes from
// defaultTargetPlatform instead, which is exact, since iOS and macOS have
// been Metal-only since Skia was removed in 3.29.
//
// SkSL-legal by construction (invariant 8): no loops, no array indices, no
// samplers. Under the Skia backend the define is absent and this answers
// "not GLES", which is the right answer there for a different reason —
// ImageFilter.isShaderFilterSupported has already told the probe it is not
// on Impeller at all.
#include <flutter/runtime_effect.glsl>

precision highp float;

out vec4 fragColor;

void main() {
#ifdef IMPELLER_TARGET_OPENGLES
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
#else
    fragColor = vec4(0.0, 1.0, 0.0, 1.0);
#endif
}
