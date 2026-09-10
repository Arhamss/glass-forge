#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// The engine overwrites uSize with the input texture size and binds
// uBackdrop as sampler 0. Both are required by ImageFilter.shader.
uniform vec2 uSize;
uniform vec4 uMatteRect;      // origin.xy, size.xy in filter space
uniform vec4 uOptical;        // maxDisplacement, chromaticAberration, tintA, saturation
uniform vec4 uTint;           // rgb, variant (0 regular, 1 clear)
uniform vec4 uLighting;       // highlight, angleX, angleY, contour
uniform vec4 uMapBasis;       // a, b, c, d
uniform vec2 uMapOffset;      // tx, ty
uniform sampler2D uBackdrop;
uniform sampler2D uMatte;

out vec4 fragColor;

#include "common/codec.glsl"

// Only mirror samples that leave the texture. Clamping everywhere washes out
// Metal; leaving it alone gives GLES a black decal border.
vec2 gfMirrorUV(vec2 uv) {
    vec2 m = mod(abs(uv), 2.0);
    return mix(m, 2.0 - m, step(1.0, m));
}

void main() {
    vec2 frag = FlutterFragCoord().xy;

    // Ancestor motion is compositor-only: this affine maps the filter's
    // coordinate space into the layer-local matte rather than re-baking it.
    vec2 matteSpace = vec2(
        uMapBasis.x * frag.x + uMapBasis.y * frag.y,
        uMapBasis.z * frag.x + uMapBasis.w * frag.y
    ) + uMapOffset;

    vec2 matteUV = (matteSpace - uMatteRect.xy) / max(uMatteRect.zw, vec2(1.0));
    vec4 encoded = texture(uMatte, matteUV);

    float coverage = encoded.a > 0.0 ? 1.0 : 0.0;
    if (matteUV.x < 0.0 || matteUV.x > 1.0 ||
        matteUV.y < 0.0 || matteUV.y > 1.0 || coverage == 0.0) {
        fragColor = texture(uBackdrop, frag / uSize);
        return;
    }

    vec2 normal = vec2(gfDecodeSigned(encoded.r), gfDecodeSigned(encoded.g));
    // Displacement magnitude was encoded toward the maximum
    // (gfEncodeCompandedMax) -- see codec.glsl -- so it decodes with the
    // matching decoder, not the toward-zero one signed distance uses.
    float magnitude = gfDecodeCompandedMax(encoded.a) * uOptical.x;
    vec2 displacement = normal * -magnitude;

    vec2 offsetUV = (frag + displacement) / uSize;

    vec3 refracted;
    // Threshold in PIXELS, not in unit-free aberration. Upstream compares the
    // raw setting against 0.01 while defaulting to exactly 0.01, so every
    // default install pays three taps for an invisible half-percent effect.
    if (abs(uOptical.y) * uOptical.x > 0.25) {
        float spread = uOptical.y * 0.5;
        vec2 rUV = (frag + displacement * (1.0 + spread)) / uSize;
        vec2 bUV = (frag + displacement * (1.0 - spread)) / uSize;
        refracted = vec3(
            texture(uBackdrop, gfMirrorUV(rUV)).r,
            texture(uBackdrop, gfMirrorUV(offsetUV)).g,
            texture(uBackdrop, gfMirrorUV(bUV)).b
        );
    } else {
        refracted = texture(uBackdrop, gfMirrorUV(offsetUV)).rgb;
    }

    // Saturation, on Rec.709 luma.
    float luma = dot(refracted, vec3(0.2126, 0.7152, 0.0722));
    refracted = mix(vec3(luma), refracted, uOptical.w);

    // Tint. A clear variant takes a dark scrim on bright backdrops instead of
    // adapting, which is what Apple specifies.
    if (uTint.w > 0.5) {
        refracted = mix(refracted, vec3(0.0), 0.35 * step(0.5, luma));
    } else {
        refracted = mix(refracted, uTint.rgb, uOptical.z);
    }

    // Two opposing rim highlights. The colour is incident white rather than
    // the refracted backdrop: deriving it from the backdrop is what gives
    // upstream its cyan/green fringing.
    vec2 lightDir = normalize(vec2(uLighting.y, uLighting.z));
    float facing = dot(normal, lightDir);
    float rim = max(0.0, facing) + 0.8 * max(0.0, -facing);

    // Guard on luminance so a truly black surface does not flicker at the rim.
    float guard = pow(max(luma, 0.0), 0.25);
    refracted += vec3(rim * uLighting.x * guard * 0.35);

    fragColor = vec4(refracted, 1.0);
}
