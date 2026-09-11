// The matte bake, shared by both geometry producers.
//
// Include after common/scene.glsl, common/profile.glsl and common/codec.glsl.
// The two producers differ only in how they arrive at a layer-local `p` --
// FlutterFragCoord() in the runtime-effect path, gl_FragCoord plus an origin
// uniform in the Flutter GPU one -- so that is all their main() should
// contain. Everything downstream of `p` is identical and lives here, where it
// cannot drift.

// The dome's bake: direction, signed distance and magnitude, exactly the
// channels the edge band fills below, computed from the dome instead. See
// common/profile.glsl for the surface itself.
vec4 gfBakeDome(vec2 p, float maxDisplacement, float edgeRefraction,
                float thickness) {
    vec3 scene = gfSceneSample(p, vec2(-1.0));
    float sd = scene.x;
    if (sd > maxDisplacement) {
        return vec4(0.5, 0.5, 1.0, 0.0);
    }

    float depth = max(0.0, -sd);

    // How deep the dome is here: the depth of the scene itself at the core
    // point, not a property of any one shape. For a single shape that is its
    // inradius -- or, along an oval's major axis, the shallower depth the
    // axis really has, which is what keeps the axis from creasing. Where two
    // shapes merge, the core passes through the neck, and the neck is far
    // shallower than either shape: taking either shape's depth left the
    // whole neck reading as rim, pushed hard from both sides, pinched.
    //
    // The core itself comes from the steering fold, whose merges are wide
    // enough that it slides smoothly from one shape to the next even where
    // the caller's blend is tight or zero. Between them, these are the
    // dome's neck fade: at the saddle the core sits under the point itself,
    // the depth there is the neck's own, the surface lies flat and nothing
    // is displaced -- so the dome needs no separate fade, and the edge
    // band's (gfNeckFade) changed none of these numbers when tried here.
    vec3 steering = gfSceneSample(p, vec2(edgeRefraction, kDomeDepthLimit));
    vec2 core = steering.yz;
    float coreDepth = max(-gfSceneDistance(core), 1.0);

    // The profile reads the true depth at the rim and the steering proxy's
    // inside. The true depth of a rounded box is a hip roof -- its ridges run
    // along the diagonals from each corner arc's centre -- and a magnitude
    // read straight off it creases there: every straight line seen through
    // the dome broke where it crossed a diagonal. The proxy has its corners
    // rounded past the displacement, so its ridges start far deeper or not
    // at all. The handover finishes 30% of the way in, before a corner's
    // ridge begins on any reasonably rounded shape, and its own input is
    // the true depth only where that depth is still smooth.
    //
    // The proxy may only make a point shallower, never deeper. A rounded
    // box's proxy sits inside it everywhere, so this changes nothing there;
    // an oval's is the capsule around it, deeper than the oval toward its
    // ends, and handing over to that pulled the displacement down so fast
    // just inside the rim that the image folded. An oval has no hip roof to
    // smooth, so it keeps its own depth.
    float xTrue = clamp(depth / coreDepth, 0.0, 1.0);
    float xProxy = clamp(-steering.x / coreDepth, 0.0, 1.0);
    float x = mix(xTrue, min(xProxy, xTrue), smoothstep(0.0, 0.3, xTrue));
    vec2 direction = gfDomeDirection(p, core, depth, x, edgeRefraction);
    float magnitude = sd > 0.0
        ? 0.0
        : gfDomeDisplacement(x, coreDepth, edgeRefraction, thickness);

    return gfEncodeMatte(direction, sd, magnitude, maxDisplacement);
}

// `profile` is the uProfile uniform: x selects the surface (0 edge band,
// 1 dome), y is the dome's slab thickness in pixels. Both surfaces fill the
// same channels with the same meanings, so nothing downstream -- the codec,
// the final pass -- can tell which one baked a matte, and neither needs to.
vec4 gfBakeMatte(vec2 p, float maxDisplacement, float edgeRefraction,
                 float spread, vec4 profile) {
    if (profile.x > 0.5) {
        return gfBakeDome(p, maxDisplacement, edgeRefraction, profile.y);
    }

    vec3 scene = gfSceneSample(p, vec2(-1.0));
    float sd = scene.x;

    // Far outside every shape: encode a saturated *positive* distance rather
    // than a zeroed texel. The final pass derives coverage from channel B
    // (see gfDecodeMatteDistance), and a zeroed texel decodes as
    // -maxDisplacement -- the deep interior -- which would make the padding
    // around each shape read as solid glass.
    if (sd > maxDisplacement) {
        return vec4(0.5, 0.5, 1.0, 0.0);
    }

    // The same four samples give the normal and the neck fade.
    vec2 difference = gfSceneDifference(p, 1.0, vec2(-1.0));
    vec2 normal = gfUnitOrZero(difference);
    float band = mix(edgeRefraction, edgeRefraction * 4.0,
                     clamp(spread, 0.0, 1.0));

    // Only the band and the fringe outside it displace anything, so only
    // they pay for the second fold that finds how deep the shape is at its
    // core (see gfEdgeBandFit). A single shape's core depth is its
    // inradius; where blended shapes merge, the core runs through the neck
    // and the depth is the neck's own.
    float magnitude = 0.0;
    if (-sd < band) {
        float depth = max(-gfSceneDistance(scene.yz), 1.0);
        float fit = gfEdgeBandFit(depth, band, edgeRefraction);
        magnitude = gfDisplacementMagnitude(min(sd, 0.0), band * fit,
                                            edgeRefraction * fit)
                  * gfNeckFade(difference, 1.0);
    }

    // The real signed distance, on both sides of the boundary, and NOT
    // premultiplied by coverage. Both matter now that the final pass reads
    // this channel: clamping it to the interior leaves it unable to say how
    // far outside a texel is, and premultiplying scales it toward zero --
    // which decodes as "deep inside" -- at exactly the fringe where coverage
    // is being resolved. Antialiasing is the final pass's job; the caller's
    // antialias width still sizes the matte's padding on the Dart side.
    return gfEncodeMatte(normal, sd, magnitude, maxDisplacement);
}
