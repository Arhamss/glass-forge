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
float gfSceneDistance(vec2 p) {
    float result = 1e9;
    float groupResult = 1e9;
    float groupBlend = 0.0;
    int count = int(uNumShapes);

    for (int i = 0; i < MAX_SHAPES; i++) {
        if (i >= count) { break; }

        float marker = GF_MARKER(i);
        bool startsGroup = marker < 0.0;
        float blend = startsGroup ? -marker - 1.0 : marker;

        // Conservative bound first. Skipping the real SDF here is worth
        // 14-23% GPU on shape-heavy scenes.
        float bound = gfBoundLowerBound(i, p);
        float best = min(result, groupResult);
        if (bound >= best + blend && !startsGroup) {
            continue;
        }

        float d = gfShapeDistance(i, p);

        if (startsGroup) {
            result = min(result, groupResult);
            groupResult = d;
            groupBlend = blend;
        } else {
            groupResult = smoothUnion(groupResult, d, groupBlend);
        }
    }
    return min(result, groupResult);
}
