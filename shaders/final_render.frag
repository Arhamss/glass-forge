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
uniform vec4 uSurface;        // profile (0 edge band, 1 dome), thickness, presence, 0
uniform vec4 uGlow;           // centre.xy in MATTE space, radius, strength
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

// One backdrop read, bilinear wherever the surface bends it.
//
// Read nearest-neighbour (flutter#186945), a displaced sample snaps to a
// whole texel, so a displacement that varies continuously comes out as
// steps: every edge seen through the dome was stair-stepped by a pixel or
// two. The edge band's displacement has varied continuously across its
// whole width since its profile became the refracted squircle slope, and
// under a steep ramp not one texel of it landed between two source texels
// (final_pass_shading_test.dart). So both surfaces read bilinearly where
// they displace. `displaced` is false only where the magnitude is exactly
// zero -- the edge band's flat interior, which reads its own texel and gains
// nothing from four taps -- so that interior keeps the single tap it always
// had, and the extra cost stays confined to the band.
vec3 gfBackdrop(vec2 uv, bool displaced) {
    if (displaced) {
        return gfSampleBilinear(uv, uSize);
    }
    return texture(uBackdrop, uv).rgb;
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

    // Outside the matte there is no shape here at all. Transparent, not an
    // opaque copy of the backdrop: BackdropFilterLayer composites this
    // srcOver, so alpha 0 leaves the *unfiltered* backdrop showing through.
    // Writing the blurred backdrop back at alpha 1 frosted the entire layer,
    // including the undistorted backdrop beside the shape -- which is the
    // only reference the eye has for reading a refraction as a refraction.
    if (matteUV.x < 0.0 || matteUV.x > 1.0 ||
        matteUV.y < 0.0 || matteUV.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 encoded = texture(uMatte, matteUV);

    // Signed edge distance in matte pixels, negative inside. Coverage comes
    // from here, never from the displacement magnitude in channel A: the
    // band profile drives that magnitude to exactly zero across the whole
    // interior by design, so gating on it left every shape hollow.
    float signedDistance = gfDecodeMatteDistance(encoded.b) * uOptical.x;

    // One filter pixel measured in matte pixels. The antialiasing ramp has
    // to be a pixel on screen, and uMapBasis is what relates the two spaces
    // when an ancestor has scaled this layer.
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
    // uSurface.z is presence. Scaling the magnitude here rather than
    // uOptical.x is deliberate: uOptical.x also decodes the signed distance
    // above, which drives coverage and antialiasing, so scaling it would
    // shrink the shape instead of fading its refraction.
    float magnitude = gfDecodeCompandedMax(encoded.a) * uOptical.x * uSurface.z;
    vec2 displacement = normal * -magnitude;

    vec2 offsetUV = (frag + displacement) / uSize;
    // The dome reads bilinearly everywhere, as it always has; the edge band
    // only where it moves the backdrop at all. See gfBackdrop.
    bool displaced = uSurface.x > 0.5 || magnitude > 0.0;

    vec3 refracted;
    // Threshold in PIXELS, not in unit-free aberration. Upstream compares the
    // raw setting against 0.01 while defaulting to exactly 0.01, so every
    // default install pays three taps for an invisible half-percent effect.
    if (abs(uOptical.y) * uOptical.x > 0.25) {
        float spread = uOptical.y * 0.5;
        vec2 rUV = (frag + displacement * (1.0 + spread)) / uSize;
        vec2 bUV = (frag + displacement * (1.0 - spread)) / uSize;
        refracted = vec3(
            gfBackdrop(gfMirrorUV(rUV), displaced).r,
            gfBackdrop(gfMirrorUV(offsetUV), displaced).g,
            gfBackdrop(gfMirrorUV(bUV), displaced).b
        );
    } else {
        refracted = gfBackdrop(gfMirrorUV(offsetUV), displaced);
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

    // How deep inside the surface this fragment sits. The contour, the rim
    // and the dome's lighting all key off it, which is the whole reason the
    // matte carries a signed distance companded toward zero.
    refracted = gfShade(refracted, normal, max(0.0, -signedDistance), luma,
                        uOptical.x, uLighting, uSurface);

    // The touch glow. Added after shading and before the coverage multiply,
    // so it is masked by coverage for free: it lights every shape in this
    // pass -- the neighbours Apple describes -- and none of the gaps
    // between them.
    if (uGlow.w > 0.0) {
        // Measured in MATTE space, not against `frag`. `frag` is filter
        // space; the glow centre arrives in layer-local pixels, and the
        // two coincide only when no ancestor has scrolled or scaled this
        // layer. `uMapBasis`/`uMapOffset` exist to relate them, and
        // `uMatteRect` is already compared in matte space above.
        float glowDistance = distance(matteSpace, uGlow.xy);
        float falloff = 1.0 - smoothstep(0.0, max(uGlow.z, 1.0), glowDistance);
        refracted += uGlow.w * falloff * falloff;
    }

    // Premultiplied: this layer is composited srcOver the raw backdrop, so
    // the antialiased boundary has to carry its coverage in alpha.
    fragColor = vec4(refracted * coverage, coverage);
}
