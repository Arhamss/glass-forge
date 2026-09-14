// Candidate mitigation for flutter#186945: `ImageFilter.shader`'s backdrop
// sampler is nearest-neighbour by default, so every displaced lookup snaps
// between texels instead of interpolating. This reconstructs bilinear
// filtering manually against `uBackdrop`.
//
// Not parameterised over which sampler to read: SkSL's runtime-effect
// target does not support `sampler2D` as a function parameter (spirv-cross
// silently drops the SkSL stage for a shader that tries -- confirmed by
// `ShaderLibrary`'s own warm-up throwing "does not contain appropriate
// runtime stage data for current backend (SkSL)" when this file took one).
// Every caller here only ever samples the backdrop, so hard-coding it costs
// nothing.
//
// Four taps instead of one, so it is only worth binding where the measured
// shimmer justifies the cost — see docs/reference/backdrop_sampling.md for
// the decision and the numbers behind it.
vec3 gfSampleBilinear(vec2 uv, vec2 texSize) {
    vec2 texel = uv * texSize - 0.5;
    vec2 base = floor(texel);
    vec2 f = texel - base;
    vec2 uv00 = (base + 0.5) / texSize;
    vec2 uv10 = (base + vec2(1.0, 0.0) + 0.5) / texSize;
    vec2 uv01 = (base + vec2(0.0, 1.0) + 0.5) / texSize;
    vec2 uv11 = (base + vec2(1.0, 1.0) + 0.5) / texSize;
    vec3 a = mix(texture(uBackdrop, uv00).rgb, texture(uBackdrop, uv10).rgb, f.x);
    vec3 b = mix(texture(uBackdrop, uv01).rgb, texture(uBackdrop, uv11).rgb, f.x);
    return mix(a, b, f.y);
}
