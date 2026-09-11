// The matte bake, shared by both geometry producers.
//
// Include after common/scene.glsl, common/profile.glsl and common/codec.glsl.
// The two producers differ only in how they arrive at a layer-local `p` --
// FlutterFragCoord() in the runtime-effect path, gl_FragCoord plus an origin
// uniform in the Flutter GPU one -- so that is all their main() should
// contain. Everything downstream of `p` is identical and lives here, where it
// cannot drift.
vec4 gfBakeMatte(vec2 p, float maxDisplacement, float edgeRefraction,
                 float spread) {
    float sd = gfSceneDistance(p);

    // Far outside every shape: encode a saturated *positive* distance rather
    // than a zeroed texel. The final pass derives coverage from channel B
    // (see gfDecodeMatteDistance), and a zeroed texel decodes as
    // -maxDisplacement -- the deep interior -- which would make the padding
    // around each shape read as solid glass.
    if (sd > maxDisplacement) {
        return vec4(0.5, 0.5, 1.0, 0.0);
    }

    vec2 normal = gfSceneNormal(p, 1.0);
    float band = mix(edgeRefraction, edgeRefraction * 4.0,
                     clamp(spread, 0.0, 1.0));
    float magnitude = gfDisplacementMagnitude(min(sd, 0.0), band,
                                              edgeRefraction);

    // The real signed distance, on both sides of the boundary, and NOT
    // premultiplied by coverage. Both matter now that the final pass reads
    // this channel: clamping it to the interior leaves it unable to say how
    // far outside a texel is, and premultiplying scales it toward zero --
    // which decodes as "deep inside" -- at exactly the fringe where coverage
    // is being resolved. Antialiasing is the final pass's job; the caller's
    // antialias width still sizes the matte's padding on the Dart side.
    return gfEncodeMatte(normal, sd, magnitude, maxDisplacement);
}
