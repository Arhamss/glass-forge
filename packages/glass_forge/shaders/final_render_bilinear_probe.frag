#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Measurement-only variant of final_render.frag for Task 19 (see
// docs/reference/backdrop_sampling.md). Identical in every respect except
// that every displaced backdrop lookup goes through gfSampleBilinear instead
// of a raw nearest-neighbour `texture()` call. Never bound outside the
// sampling probe — see GlassShaderId.finalRenderBilinearProbe and
// debugBilinearBackdropSampling in package:glass_forge/src/debug.dart. Keep
// this file's uniform block byte-for-byte identical to final_render.frag's:
// GlassComposition writes uniforms once, by position, for whichever of the
// two is bound.

// The engine overwrites uSize with the input texture size and binds
// uBackdrop as sampler 0. Both are required by ImageFilter.shader.
uniform vec2 uSize;
uniform vec4 uMatteRect;      // origin.xy, size.xy in filter space
uniform vec4 uOptical;        // maxDisplacement, chromaticAberration, tintA, saturation
uniform vec4 uTint;           // rgb, variant (0 regular, 1 clear)
uniform vec4 uLighting;       // highlight, angleX, angleY, contour
uniform vec4 uMapBasis;       // a, b, c, d
uniform vec2 uMapOffset;      // tx, ty
uniform vec4 uSurface;        // profile (0 edge band, 1 dome), thickness, 0, 0
uniform sampler2D uBackdrop;
uniform sampler2D uMatte;

out vec4 fragColor;

#include "common/codec.glsl"
#include "common/shading.glsl"
#include "common/sampling.glsl"

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

    // Coverage is derived exactly as final_render.frag derives it -- from the
    // signed distance in channel B, not the displacement magnitude in A. A
    // probe that covers a different set of fragments than the shader it is
    // measuring is measuring a different image.
    if (matteUV.x < 0.0 || matteUV.x > 1.0 ||
        matteUV.y < 0.0 || matteUV.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 encoded = texture(uMatte, matteUV);
    float signedDistance = gfDecodeMatteDistance(encoded.b) * uOptical.x;
    float mapScale = sqrt(abs(uMapBasis.x * uMapBasis.w
                            - uMapBasis.y * uMapBasis.z));
    float coverage = clamp(0.5 - signedDistance / max(mapScale, 1e-3),
                           0.0, 1.0);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
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
            gfSampleBilinear(gfMirrorUV(rUV), uSize).r,
            gfSampleBilinear(gfMirrorUV(offsetUV), uSize).g,
            gfSampleBilinear(gfMirrorUV(bUV), uSize).b
        );
    } else {
        refracted = gfSampleBilinear(gfMirrorUV(offsetUV), uSize);
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

    // Shaded exactly as final_render.frag shades it -- common/shading.glsl.
    refracted = gfShade(refracted, normal, max(0.0, -signedDistance), luma,
                        uOptical.x, uLighting, uSurface);

    fragColor = vec4(refracted * coverage, coverage);
}
