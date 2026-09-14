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
//
// `steer` picks the field, as in gfSceneSample: negative for the shapes
// themselves, which is all the edge band ever asks for.
//
// The difference itself, unnormalised: its length over 2 * epsilon is the
// field's slope, which gfNeckFade reads.
vec2 gfSceneDifference(vec2 p, float epsilon, vec2 steer) {
    float dx = gfSceneSample(p + vec2(epsilon, 0.0), steer).x
             - gfSceneSample(p - vec2(epsilon, 0.0), steer).x;
    float dy = gfSceneSample(p + vec2(0.0, epsilon), steer).x
             - gfSceneSample(p - vec2(0.0, epsilon), steer).x;
    return vec2(dx, dy);
}

vec2 gfUnitOrZero(vec2 g) {
    float len = length(g);
    return len < 1e-6 ? vec2(0.0) : g / len;
}

vec2 gfSceneGradient(vec2 p, float epsilon, vec2 steer) {
    return gfUnitOrZero(gfSceneDifference(p, epsilon, steer));
}

vec2 gfSceneNormal(vec2 p, float epsilon) {
    return gfSceneGradient(p, epsilon, vec2(-1.0));
}

// How much refraction a point may keep, given how well its surface knows
// which way it faces. `difference` is gfSceneDifference at `epsilon`.
//
// Where blended shapes merge, the two sides of the neck face each other, the
// smooth-min's gradient averages them, and along the neck's centreline it
// collapses to nothing before turning round -- so the direction the lens
// pushes flips from one texel to the next and the bridge tears down the
// middle (docs/reference/shader_techniques.md s3, "union necks"). Fading the
// refraction where the slope collapses leaves the saddle flat, as a saddle
// is. An SDF's slope is 1; across a single shape's own seams, where the
// stencil straddles two faces at right angles, about 0.7 -- so the fade
// starts below that, and no single shape is touched by it.
float gfNeckFade(vec2 difference, float epsilon) {
    return smoothstep(0.1, 0.6, length(difference) / (2.0 * epsilon));
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

// How deep into a shape the band's samples reach, in pixels.
//
// A texel `s` pixels in samples the backdrop `s + gfDisplacementMagnitude`
// in. In units of the band, x + r * (1 - x^4)^(1/4) with r = amount/height,
// which peaks at (1 + r^(4/3))^(3/4) -- 1.68 bands at Apple's spread of 0,
// so the deepest sample lands well inside the band's own inner edge.
float gfEdgeBandReach(float height, float amount) {
    float r = amount / max(height, 1e-3);
    return height * pow(1.0 + pow(r, 4.0 / 3.0), 0.75);
}

// How much of the band a shape `depth` pixels deep at its core has room
// for: 1 when every sample stays on its own side of the medial axis, less
// when the band has to shrink -- height and amount together -- to keep them
// there.
//
// The SDF normal turns right round across a shape's medial axis. A band
// that reaches past it -- every 44 pt control and 52 pt bar, at Apple's
// 27.42 pt -- has each half refracting from the far side of the axis, so
// the two halves of the image trade places and the surface tears along
// its centreline, where the normal flips from one texel to the next. The
// union-neck fade (gfNeckFade) cannot see that seam until the stencil
// straddles it, a pixel from the axis, long after the band is pushing at
// full strength. Shrinking the band until its deepest sample reaches the
// axis and no further keeps the halves apart and leaves the axis
// undisplaced, which is what a thin pane's centre does. A shape with room
// for the whole band is left exactly as it was.
float gfEdgeBandFit(float depth, float height, float amount) {
    return min(1.0, depth / gfEdgeBandReach(height, amount));
}

// Dome profile.
//
// The other model: a sphere cap spanning the shape's whole interior depth,
// refracted as a single slab -- the displacement liquid_glass_renderer gives,
// re-derived from the formulas in docs/reference/shader_techniques.md s3
// rather than from its source.
//
// `x` is how far into the dome a point sits, 0 at the rim and 1 where the
// interior is deepest; `coreDepth` is how deep that is, in pixels.
//
// A true cap, not a hemisphere: it meets the base at 40 degrees rather than
// standing vertical. At the rim of a hemisphere the tilt races to 90
// degrees, the displacement climbs faster than the rim moves outward, and
// the lens folds its own image back on itself -- a caustic ring that, at
// interface scale and with the backdrop sampled nearest-neighbour, reads as
// radial streaks through every speck of the backdrop. A 40-degree cap does
// not fold anywhere across edge refractions of 5 to 80 pixels, slabs of 1
// to 40 and depths of 8 to 400 (the numbers are in the dome tests).
//
// The slab: the view ray (0,0,-1) refracts through the tilted surface --
// index n = sqrt(1 + (E / 8t)^2), derived exactly as GlassMaterial derives
// it -- and travels `8 * thickness` plus the local height to the backdrop.
// That fixes the displacement's shape. Its size is then set by what the
// caller asked for: edgeRefraction at the rim, so the knob means under a
// dome what it means under the edge band -- but never more than 0.35 of the
// depth, because a small shape given a large rim displacement folds just
// the same, whatever the cap. Past that a pill is simply a thinner lens.
const float kDomeCapSin = 0.6427876097;   // sin(40 degrees)
const float kDomeCapCos = 0.7660444431;   // cos(40 degrees)
const float kDomeDepthLimit = 0.35;

// The in-plane displacement, in pixels, of a ray through a cap tilted to
// `sinTilt`, before scaling.
float gfDomeRefraction(float sinTilt, float eta, float thickness) {
    float cosTilt = sqrt(max(0.0, 1.0 - sinTilt * sinTilt));
    float height = (cosTilt - kDomeCapCos) / (1.0 - kDomeCapCos);
    // Solved in the plane of the tilt: which way the surface leans is the
    // matte's direction channel, so only the in-plane component matters.
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), vec3(sinTilt, 0.0, cosTilt), eta);
    float travel = thickness * (8.0 + height);
    return max(0.0, -ray.x) * travel / max(abs(ray.z), 1e-3);
}

float gfDomeDisplacement(float x, float coreDepth, float edgeRefraction,
                         float thickness) {
    float t = max(thickness, 1e-3);
    float ratio = edgeRefraction / (8.0 * t);
    float eta = inversesqrt(1.0 + ratio * ratio);
    float rim = gfDomeRefraction(kDomeCapSin, eta, t);
    if (rim < 1e-6) {
        return 0.0;
    }
    float here = gfDomeRefraction(kDomeCapSin * (1.0 - clamp(x, 0.0, 1.0)),
                                  eta, t);
    float amplitude = min(edgeRefraction, kDomeDepthLimit * coreDepth);
    return amplitude * here / rim;
}

// Which way the dome leans at p, as a unit vector pointing out of it.
//
// Kyant0's dome term, `normalize(gradSd + depth * radial)`: the shape's own
// normal at the rim handing over to the direction away from its core
// (gfShapeCore) toward the middle. Here the handover is a smoothstep that
// completes 40% of the way in, and on its own it is not enough -- the
// numbers are in dome_matte_test.dart. Three things together are:
//
//   * the gradient comes from the steering proxy (gfShapeSteeringDistance),
//     whose corners are rounded past the displacement, so no corner's
//     normals converge anywhere a sample is pushed to;
//   * it is taken across a stencil that widens with depth -- exact at the
//     rim, where the silhouette is honoured, averaging over three quarters
//     of the point's depth further in. Across a seam of a rounded box's SDF
//     the gradient turns a full right angle between one texel and the next,
//     and with only the radial term to soften it that tore the backdrop
//     apart along both diagonals by about 50 pixels;
//   * the radial term, which owns the direction where the other two run out
//     -- at the core, where a symmetric stencil sees no slope at all.
vec2 gfDomeDirection(vec2 p, vec2 core, float depth, float x,
                     float edgeRefraction) {
    vec2 grad = gfSceneGradient(p, max(1.0, depth * 0.75),
                                vec2(edgeRefraction, kDomeDepthLimit));
    vec2 toCore = p - core;
    float reach = length(toCore);
    vec2 radial = reach > 1e-3 ? toCore / reach : grad;
    vec2 dir = mix(grad, radial, smoothstep(0.0, 0.4, x));
    float len = length(dir);
    return len < 1e-6 ? vec2(0.0) : dir / len;
}
