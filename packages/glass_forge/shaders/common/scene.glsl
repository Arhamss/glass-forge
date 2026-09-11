// The scene fold, shared by both geometry producers.
//
// This lived as two hand-copied bodies -- one in geometry.frag, one in
// gpu/geometry_fragment.glsl -- each carrying a comment warning that drift
// between them silently diverges the producers. It does not have to be that
// way: the Flutter GPU file aliases its uniform-block members to the same
// bare identifiers the runtime-effect file declares as globals
// (`#define uShapeData frag_info.uShapeDataBlock` and friends), which is the
// same trick common/sdf.glsl already relies on. So the bodies were identical
// by construction, and keeping them in one file makes the divergence the
// comments warned about impossible rather than merely tested for.
//
// Include after common/sdf.glsl and after MAX_SHAPES is defined.

// Folds the scene deterministically: shapes are walked in registration order,
// a negative marker opens a group, and groups combine by plain min. The
// quadratic smooth-min is not associative, so order is load-bearing.
//
// `steer` selects the field: a negative x folds the shapes' true distances;
// otherwise every shape is folded as its steering proxy (see
// gfShapeSteeringDistance), with steer = (edgeRefraction, depthLimit). One
// fold either way, so the proxy blends and groups exactly as the shapes do.
//
// Returns (distance, core.x, core.y). The distance is the only thing the
// edge band reads; the dome also needs to know where the interior is deepest
// (see gfShapeCore). The core rides through the same fold as the distance,
// weighted the way the distance itself blends, so two merging shapes dome
// over their union rather than each over itself -- and, across a neck, the
// core slides from one shape to the other through the neck's own middle.
// It cannot be a second fold: two folds is the drift this file exists to
// prevent.
vec3 gfSceneSample(vec2 p, vec2 steer) {
    float result = 1e9;
    float groupResult = 1e9;
    float groupBlend = 0.0;
    vec2 resultCore = p;
    vec2 groupCore = p;
    int count = int(uNumShapes);

    for (int i = 0; i < MAX_SHAPES; i++) {
        if (i >= count) { break; }

        float marker = GF_MARKER(i);
        bool startsGroup = marker < 0.0;
        float blend = startsGroup ? -marker - 1.0 : marker;
        // The steering proxy merges at least three displacements wide, for
        // the reason it rounds corners that far (gfShapeSteeringDistance):
        // where two shapes cross at a tight blend, each side of the crease
        // points at its own core, and a dome pushing hard toward both folds
        // the image there. Only the steering field is widened; the shapes'
        // own fold keeps the width the caller asked for.
        if (steer.x >= 0.0) {
            blend = max(blend, 3.0 * steer.x);
        }

        // Conservative bound first. Skipping the real SDF here is worth
        // 14-23% GPU on shape-heavy scenes.
        float bound = gfBoundLowerBound(i, p);
        float best = min(result, groupResult);
        if (bound >= best + blend && !startsGroup) {
            continue;
        }

        float d = steer.x < 0.0
            ? gfShapeDistance(i, p)
            : gfShapeSteeringDistance(i, p, steer.x, steer.y);
        vec2 core = gfShapeCore(i, p);

        if (startsGroup) {
            resultCore = groupResult < result ? groupCore : resultCore;
            result = min(result, groupResult);
            groupResult = d;
            groupBlend = blend;
            groupCore = core;
        } else {
            // How much of the group so far survives the union: 1 where it is
            // clearly nearer, 0 where the new shape is, and a ramp across the
            // blend width between -- the smooth-min's own mix factor.
            float keep = groupBlend > 0.0
                ? clamp(0.5 + 0.5 * (d - groupResult) / groupBlend, 0.0, 1.0)
                : step(groupResult, d);
            groupCore = mix(core, groupCore, keep);
            groupResult = smoothUnion(groupResult, d, groupBlend);
        }
    }
    return groupResult < result ? vec3(groupResult, groupCore)
                                : vec3(result, resultCore);
}

// The scene distance alone, for everything that needs nothing else.
float gfSceneDistance(vec2 p) {
    return gfSceneSample(p, vec2(-1.0)).x;
}
