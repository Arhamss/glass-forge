// Everything the final pass does to a refracted sample once it has one:
// the contour, the rim light, and the dome's lighting. Shared by
// final_render.frag and its bilinear measurement twin, which differ only in
// how they sample the backdrop -- when this lived in both, the twin quietly
// lost the contour and the rim falloff, and measured a different image.
//
// Include after common/codec.glsl.

// How much added light a surface this bright may take.
//
// Exactly zero on a truly black surface, so the rim cannot flicker there
// (upstream #112), and full strength by 4% luminance. The previous guard,
// pow(luma, 0.25), also reached zero at black, but on the way it held the
// rim at half strength over the workbench's stage ground (luma ~0.05) and
// under two thirds over anything short of mid-grey -- on a dark stage, where
// the rim is often the only thing saying "glass", it dimmed the one cue left.
float gfBlackGuard(float luma) {
    return smoothstep(0.0, 0.04, luma);
}

// Apple's edge band: a darkened contour ring and a two-lobe rim, both
// confined to thin strips at the boundary.
//
// `depth` is how far inside the surface the fragment sits, in matte pixels;
// `lighting` is uLighting (highlight, light x, light y, contour).
vec3 gfShadeEdgeBand(vec3 color, vec2 normal, float depth,
                     float maxDisplacement, vec4 lighting, float guard) {
    // Contour: the darkened ring that reads as the edge of a solid object.
    // A boundary line, so a quarter of the refraction band rather than a
    // wash over the whole surface.
    float contourBand = max(1.0, maxDisplacement * 0.12);
    float contourT = clamp(1.0 - depth / contourBand, 0.0, 1.0);
    color *= 1.0 - lighting.w * contourT * contourT;

    // Two opposing rim highlights. The colour is incident white rather than
    // the refracted backdrop: deriving it from the backdrop is what gives
    // upstream its cyan/green fringing.
    vec2 lightDir = normalize(lighting.yz);
    float facing = dot(normal, lightDir);
    float rim = max(0.0, facing) + 0.8 * max(0.0, -facing);

    // Confined to a thin strip at the boundary. Without any falloff the term
    // ran at full strength across the entire interior, and since an SDF
    // gradient is piecewise constant inside a rounded box it painted flat
    // wedges of brightness meeting at the centre rather than a lit edge.
    //
    // A *thin* strip specifically: at the full width of the refraction band
    // the wedges are still what you see, just with a gradient on them --
    // the shape reads as a bevelled plastic button rather than a lit glass
    // edge. A rim is a highlight on a boundary, not a shading of the body.
    float rimBand = max(1.0, maxDisplacement * 0.18);
    float rimT = clamp(1.0 - depth / rimBand, 0.0, 1.0);
    float rimFalloff = rimT * rimT * rimT;

    return color + vec3(rim * lighting.x * guard * 0.35 * rimFalloff);
}

// The dome: lit from a real 3D surface normal rather than a flat rim term.
//
// The matte carries the dome's direction but not its tilt, so the tilt the
// light sees comes from how deep the fragment sits: a quarter-circle bevel
// `band` pixels wide, standing vertical at the rim and flat past it. That
// keeps the light on the edge, where glass catches it, instead of washing a
// highlight across the body -- which is what made earlier attempts read as a
// plastic button. The direction is the dome's own, which is continuous
// across a rounded box (see gfDomeDirection), so no wedge can form.
//
// From docs/reference/shader_techniques.md s6: a key light and an opposing
// fill at +/-(light, 0.5), specular powers 14 and 20, Schlick Fresnel, a
// two-colour hemisphere reflected at the rim, Beer-Lambert darkening along
// the longer path through the edge, and incident white throughout.
//
// The specular lobe is Phong's, reflect-based, not Blinn's half-vector: at
// these powers Blinn lights a surface facing the viewer at about 10%, which
// is a white veil over the whole flat interior -- frosting, the thing this
// profile exists to get rid of. Phong puts that same surface at 1e-5.
vec3 gfShadeDome(vec3 color, vec2 normal, float depth, float band,
                 vec4 lighting, float guard) {
    float sinTilt = clamp(1.0 - depth / max(band, 1.0), 0.0, 1.0);
    float cosTilt = sqrt(max(0.0, 1.0 - sinTilt * sinTilt));
    vec3 n = vec3(normal * sinTilt, cosTilt);
    vec3 view = vec3(0.0, 0.0, 1.0);

    vec2 light = lighting.yz;
    float lightLen = length(light);
    light = lightLen < 1e-6 ? vec2(0.0, 1.0) : light / lightLen;
    vec3 key = normalize(vec3(light, 0.5));
    vec3 fill = normalize(vec3(-light, 0.5));

    float specular =
        pow(max(dot(reflect(-key, n), view), 0.0), 14.0) +
        0.8 * pow(max(dot(reflect(-fill, n), view), 0.0), 20.0);

    // Only the part of the Fresnel reflectance that rises toward the rim.
    // Glass reflects 4% head-on, but adding that everywhere is a uniform
    // veil, and the eye reads a veil as frost.
    float edge = 1.0 - cosTilt;
    float fresnel = 0.96 * edge * edge * edge * edge * edge;

    // The sky over the key side, the ground under the fill side.
    float sky = 0.5 + 0.5 * dot(normal * sinTilt, light);
    float reflection = fresnel * mix(0.3, 1.0, sky);

    // Beer-Lambert. Head-on the path is the slab; toward the rim it grows as
    // 1 / cos(tilt), and the extra length darkens what comes through. The
    // contour setting is the absorbance. Capped where the tilt passes about
    // 78 degrees, or the outermost texel goes to black.
    float extraPath = 1.0 / max(cosTilt, 0.2) - 1.0;
    color *= exp(-lighting.w * extraPath);

    return color + vec3((specular * 0.8 + reflection * 0.9) * lighting.x *
                        guard);
}

// The whole of the shading, for either profile. `surface` is uSurface
// (profile, thickness in matte pixels); `lighting` is uLighting.
vec3 gfShade(vec3 color, vec2 normal, float depth, float luma,
             float maxDisplacement, vec4 lighting, vec4 surface) {
    float guard = gfBlackGuard(luma);
    if (surface.x > 0.5) {
        // The lit band tracks the slab: thicker glass has a wider rounded
        // edge to catch the light on.
        return gfShadeDome(color, normal, depth, surface.y, lighting, guard);
    }
    return gfShadeEdgeBand(color, normal, depth, maxDisplacement, lighting,
                           guard);
}
