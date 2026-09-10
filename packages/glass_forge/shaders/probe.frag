#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

#define MAX_SHAPES 16

// The engine overwrites the first vec2 uniform with the input size.
uniform vec2 uSize;
uniform vec4 uShapeData[MAX_SHAPES * 3];
uniform sampler2D uInput;

out vec4 fragColor;

void main() {
    // Touch every declared slot so the compiler cannot strip the array.
    // The loop runs to completion (no break) so every slot is read; the
    // bound is a compile-time constant, which keeps this SkSL-legal.
    float acc = 0.0;
    for (int i = 0; i < MAX_SHAPES * 3; i++) {
        acc += uShapeData[i].x;
    }
    // Sample the input so the engine's sampler requirement is satisfied.
    vec4 probe = texture(uInput, vec2(0.0));
    fragColor = vec4(acc * 0.0 + 1.0, probe.g * 0.0, 0.0, 1.0);
}
