// Edge-band displacement profile.
//
// Apple's material displaces only within a band inward from the edge and
// leaves the interior undistorted — the runtime exposes exactly two knobs,
// an inner refraction height and an inner refraction amount, over an SDF that
// stores distance and direction. Refracting the whole surface, as a physical
// slab model does, is both more expensive and less faithful.
//
// The profile is a convex squircle, which a Snell ray-trace study found to be
// the best match to Apple among circle, convex, concave and lip profiles.

// Analytic gradient of the scene distance field, by central difference on the
// SDF itself rather than screen-space derivatives. Portable everywhere,
// artifact-free at corners, and defined even after a non-uniform early return.
vec2 gfSceneNormal(vec2 p, float epsilon) {
    float dx = gfSceneDistance(p + vec2(epsilon, 0.0))
             - gfSceneDistance(p - vec2(epsilon, 0.0));
    float dy = gfSceneDistance(p + vec2(0.0, epsilon))
             - gfSceneDistance(p - vec2(0.0, epsilon));
    vec2 g = vec2(dx, dy);
    float len = length(g);
    return len < 1e-6 ? vec2(0.0) : g / len;
}

// Convex squircle: y = (1 - (1 - x)^4)^(1/4), x in 0..1 across the band.
float gfEdgeProfile(float t) {
    float u = 1.0 - clamp(t, 0.0, 1.0);
    float u2 = u * u;
    return pow(max(0.0, 1.0 - u2 * u2), 0.25);
}

// Displacement magnitude at signed distance `sd`, for a band of `height`
// pixels and a peak of `amount` pixels. Zero in the interior.
float gfDisplacementMagnitude(float sd, float height, float amount) {
    if (sd > 0.0 || -sd >= height) {
        return 0.0;   // outside the shape, or past the band: interior is flat
    }
    return gfEdgeProfile(1.0 + sd / height) * amount;
}
