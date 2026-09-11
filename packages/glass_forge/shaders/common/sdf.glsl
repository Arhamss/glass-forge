// Shape distance functions and scene composition.
//
// SkSL LEGALITY — do not "simplify" any of this:
//
//   * uShapeData is read as a GLOBAL, never passed as a parameter. A by-value
//     array parameter makes spirv-cross emit `float param[96] = uShapeData;`,
//     which SkSL rejects outright. This is upstream issue #150.
//   * SkSL requires uniform-array indices to be constant, and a plain `int`
//     parameter does NOT qualify even when every call site happens to pass a
//     loop index. RESOLVED by Task 9's build — the first thing to compile
//     this file through a real SkSL target, via geometry.frag, which is its
//     first includer. impellerc rejected the naive version (gfToLocal,
//     gfShapeDistance and gfBoundLowerBound indexing uShapeData with a plain
//     `int i` parameter) with:
//       error: 19: index expression must be constant
//           vec2 d = p - uShapeData[(i * 3) + 0].xy;
//     The fix below — the known-good remedy, matching what upstream's own
//     web-compatibility branch did for the identical problem — keeps each
//     function's `(int i, vec2 p)` signature for callers, but dispatches
//     internally on a runtime if-chain over the literal indices
//     0..MAX_SHAPES-1: every array access inside a branch uses that
//     branch's own literal, never `i` itself.
//   * Loops have constant bounds and exit with `break`. A non-constant loop
//     initialiser is the second half of #150.
//   * No sampler2D parameters anywhere. SkSL rejects those too.
//   * No dFdx/dFdy/fwidth. Rejected on web (flutter#180959), and undefined
//     after a non-uniform early return. Normals here are analytic.
//
// The includer must declare, BEFORE including this file:
//   #define MAX_SHAPES <n>
//   uniform vec4 uShapeData[MAX_SHAPES * 3];
//
// Layout, per shape i:
//   uShapeData[i*3 + 0].xy  origin
//   uShapeData[i*3 + 0].zw  half extent
//   uShapeData[i*3 + 1].xyzw inverse basis, row-major
//   uShapeData[i*3 + 2].x   sdf type code
//   uShapeData[i*3 + 2].y   corner radius
//   uShapeData[i*3 + 2].z   distance scale (min singular value)
//   uShapeData[i*3 + 2].w   blend marker

// Rounded box. Inigo Quilez's formulation, re-derived; see
// docs/reference/shader_techniques.md for provenance.
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Ellipse, by Newton iteration on the parametric normal.
//
// The cheap closed form divides by |p| near the centre, which produces a
// direction-dependent pinhole and a gradient whose magnitude is not 1 — so
// heights and normals come out distorted for anything but a circle.
float sdEllipse(vec2 p, vec2 ab) {
    vec2 q = abs(p);
    vec2 e = max(ab, vec2(1e-4));
    float t = 0.7853981634; // pi/4
    for (int i = 0; i < 4; i++) {
        vec2 cs = vec2(cos(t), sin(t));
        vec2 xy = e * cs;
        vec2 ex = (e.x * e.x - e.y * e.y) * vec2(cs.x * cs.x * cs.x,
                                                 -cs.y * cs.y * cs.y) / e;
        vec2 r = xy - ex;
        vec2 qx = q - ex;
        float rl = length(r);
        float ql = length(qx);
        t += rl * asin(clamp((r.x * qx.y - r.y * qx.x) / (rl * ql), -1.0, 1.0))
             / max(1e-6, sqrt(max(0.0, e.x * e.x + e.y * e.y - dot(xy, xy))));
        t = clamp(t, 0.0, 1.5707963268);
    }
    vec2 nearest = e * vec2(cos(t), sin(t));
    // The sign comes from the ellipse's own implicit equation, not from
    // comparing q.y against the nearest point's y. That comparison is zero
    // on the whole horizontal axis: q.y is 0 there, and whenever the Newton
    // step overshoots to t <= 0 the clamp above snaps it to exactly 0, so
    // nearest.y is exactly 0 too and sign(0) wipes out the distance — inside
    // or outside. It drew a hairline through every oval and a little way
    // past its edges. Whether the step overshoots depends on the GPU's
    // sin/asin precision: Skia's CPU raster lands a hair above zero and gets
    // lucky, Metal does not, which is why no test in the untagged lane could
    // see it. The implicit test has no such dependence.
    vec2 n = q / e;
    return length(nearest - q) * sign(dot(n, n) - 1.0);
}

// Rounded superellipse, matching Flutter's own RoundedSuperellipse so the
// refraction silhouette and the child clip agree at the corners. Upstream's
// "squircle" is term-for-term identical to its rounded box while its clip is
// a real superellipse, and they disagree at every corner.
float sdSuperellipse(vec2 p, vec2 b, float r) {
    vec2 q = abs(p);
    vec2 inner = max(b - vec2(r), vec2(1e-4));
    vec2 d = max(q - inner, vec2(0.0));
    if (d.x <= 0.0 && d.y <= 0.0) {
        return max(q.x - b.x, q.y - b.y);
    }
    // Exponent 4 is the distance-like metric Flutter uses for its corners.
    vec2 n = d / max(r, 1e-4);
    float m = pow(pow(n.x, 4.0) + pow(n.y, 4.0), 0.25);
    return (m - 1.0) * r;
}

// Quadratic smooth-min. NOT associative — fold order changes the surface, so
// the caller must fold deterministically.
float smoothUnion(float a, float b, float k) {
    if (k <= 0.0) {
        return min(a, b);
    }
    float e = max(k - abs(a - b), 0.0);
    return min(a, b) - e * e * 0.25 / k;
}

#define GF_ORIGIN(i)     uShapeData[(i) * 3 + 0].xy
#define GF_EXTENT(i)     uShapeData[(i) * 3 + 0].zw
#define GF_BASIS(i)      uShapeData[(i) * 3 + 1]
#define GF_TYPE(i)       uShapeData[(i) * 3 + 2].x
#define GF_RADIUS(i)     uShapeData[(i) * 3 + 2].y
#define GF_DISTSCALE(i)  uShapeData[(i) * 3 + 2].z
#define GF_MARKER(i)     uShapeData[(i) * 3 + 2].w

// Every literal shape index 0..MAX_SHAPES-1 (MAX_SHAPES is always 8; see
// shape_limits.dart). X is applied to each, once, to build the if-chains
// below.
#define GF_SHAPE_CASES(X) X(0) X(1) X(2) X(3) X(4) X(5) X(6) X(7)

vec2 gfToLocal(int i, vec2 p) {
#define GF_CASE_TOLOCAL(I) \
    if (i == (I)) { \
        vec2 d = p - GF_ORIGIN(I); \
        vec4 m = GF_BASIS(I); \
        return vec2(m.x * d.x + m.y * d.y, m.z * d.x + m.w * d.y); \
    }
    GF_SHAPE_CASES(GF_CASE_TOLOCAL)
#undef GF_CASE_TOLOCAL
    return p;
}

// One shape's distance in its own local space, by type code. Takes values,
// not an index, so it is free of the literal-index rule above and both
// dispatchers below can share it rather than each carrying the type switch.
float gfLocalDistance(float type, vec2 local, vec2 extent, float radius) {
    if (type < 1.5) {
        return sdRoundedBox(local, extent, radius);
    } else if (type < 2.5) {
        return sdEllipse(local, extent);
    }
    return sdSuperellipse(local, extent, radius);
}

float gfShapeDistance(int i, vec2 p) {
#define GF_CASE_SHAPE_DISTANCE(I) \
    if (i == (I)) { \
        float type = GF_TYPE(I); \
        if (type < 0.5) { \
            return 1e9; \
        } \
        vec2 local = gfToLocal(I, p); \
        float d = gfLocalDistance(type, local, GF_EXTENT(I), GF_RADIUS(I)); \
        return d * GF_DISTSCALE(I); \
    }
    GF_SHAPE_CASES(GF_CASE_SHAPE_DISTANCE)
#undef GF_CASE_SHAPE_DISTANCE
    return 1e9;
}

// The same shape with its corners rounded further, for steering a dome.
//
// Only the dome reads this, and only for which way to push -- never for
// where the shape is. Near a rounded corner the SDF's normals all point at
// the corner arc's centre, one corner radius in; a dome displacing inward by
// more than that carries samples across that point, and the image there
// turns inside out -- a star of streaks on each diagonal. Steering by a
// shape whose corners are rounded to 3x the displacement keeps every
// convergence point well beyond anything pushed toward it. Kyant0 does the
// same with 1.5x the corner radius; this sizes it to the displacement, which
// is what the fold depends on. 1.5x the displacement stopped the fold but
// still stretched the backdrop tenfold beside each corner; 3x holds the
// worst local stretch anywhere on the dome to about 2x.
//
// `edgeRefraction` and `depthLimit` are the dome's own (see
// gfDomeDisplacement): the displacement never exceeds either. An oval is
// steered as the capsule it inscribes, for the same reason at its ends,
// where an elongated ellipse curves tighter than the displacement.
float gfShapeSteeringDistance(int i, vec2 p, float edgeRefraction,
                              float depthLimit) {
#define GF_CASE_STEER(I) \
    if (i == (I)) { \
        float type = GF_TYPE(I); \
        if (type < 0.5) { \
            return 1e9; \
        } \
        vec2 extent = GF_EXTENT(I); \
        float inradius = min(extent.x, extent.y); \
        float scale = max(GF_DISTSCALE(I), 1e-6); \
        float reach = 3.0 * min(edgeRefraction / scale, \
                                depthLimit * inradius); \
        float radius = type > 1.5 && type < 2.5 \
            ? inradius \
            : min(max(GF_RADIUS(I), reach), inradius); \
        return sdRoundedBox(gfToLocal(I, p), extent, radius) * scale; \
    }
    GF_SHAPE_CASES(GF_CASE_STEER)
#undef GF_CASE_STEER
    return 1e9;
}

// A conservative lower bound on this shape's distance, cheap enough to be
// worth evaluating before the real SDF. Upstream measured 14-23% GPU savings
// from culling on this bound; an L-infinity bound culled less and ran slower.
float gfBoundLowerBound(int i, vec2 p) {
#define GF_CASE_BOUND(I) \
    if (i == (I)) { \
        if (GF_TYPE(I) < 0.5) { \
            return 1e9; \
        } \
        vec2 local = gfToLocal(I, p); \
        vec2 d = abs(local) - GF_EXTENT(I); \
        return length(max(d, vec2(0.0))) * GF_DISTSCALE(I); \
    }
    GF_SHAPE_CASES(GF_CASE_BOUND)
#undef GF_CASE_BOUND
    return 1e9;
}

// Where the shape's interior is deepest, nearest to p.
//
// A dome needs to know which way is "toward the middle" at every point, and
// the SDF gradient cannot say: inside a rounded box it is piecewise constant,
// and every seam between two of its pieces runs from a corner to the centre.
// Displacement or light driven by it alone paints flat wedges meeting in an
// X. The direction from p to the shape's core is the continuous alternative.
//
// The core is the shape shrunk by its own inradius, which is a point for a
// square or circle and a segment for anything longer than it is wide -- so a
// pill domes across its short axis along its whole straight run, as a real
// capsule does, rather than everything leaning toward the pill's centre.
//
// Returns the core point nearest p, in layer space.
vec2 gfShapeCore(int i, vec2 p) {
#define GF_CASE_CORE(I) \
    if (i == (I)) { \
        vec2 extent = GF_EXTENT(I); \
        float inradius = min(extent.x, extent.y); \
        vec2 coreHalf = extent - vec2(inradius); \
        vec2 nearest = clamp(gfToLocal(I, p), -coreHalf, coreHalf); \
        vec4 m = GF_BASIS(I); \
        float det = m.x * m.w - m.y * m.z; \
        float invertible = step(1e-12, abs(det)); \
        vec2 layer = vec2(m.w * nearest.x - m.y * nearest.y, \
                          -m.z * nearest.x + m.x * nearest.y) \
            * invertible / mix(1.0, det, invertible); \
        return GF_ORIGIN(I) + layer; \
    }
    GF_SHAPE_CASES(GF_CASE_CORE)
#undef GF_CASE_CORE
    return p;
}
