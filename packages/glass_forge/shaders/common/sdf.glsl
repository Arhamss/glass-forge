// Shape distance functions and scene composition.
//
// SkSL LEGALITY — do not "simplify" any of this:
//
//   * uShapeData is read as a GLOBAL, never passed as a parameter. A by-value
//     array parameter makes spirv-cross emit `float param[96] = uShapeData;`,
//     which SkSL rejects outright. This is upstream issue #150.
//   * Array indices are compile-time constants, expanded by macro. SkSL
//     requires uniform-array indices to be constant.
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
    return length(nearest - q) * sign(q.y - nearest.y);
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

vec2 gfToLocal(int i, vec2 p) {
    vec2 d = p - GF_ORIGIN(i);
    vec4 m = GF_BASIS(i);
    return vec2(m.x * d.x + m.y * d.y, m.z * d.x + m.w * d.y);
}

float gfShapeDistance(int i, vec2 p) {
    float type = GF_TYPE(i);
    if (type < 0.5) {
        return 1e9;
    }
    vec2 local = gfToLocal(i, p);
    vec2 extent = GF_EXTENT(i);
    float radius = GF_RADIUS(i);
    float d;
    if (type < 1.5) {
        d = sdRoundedBox(local, extent, radius);
    } else if (type < 2.5) {
        d = sdEllipse(local, extent);
    } else {
        d = sdSuperellipse(local, extent, radius);
    }
    return d * GF_DISTSCALE(i);
}

// A conservative lower bound on this shape's distance, cheap enough to be
// worth evaluating before the real SDF. Upstream measured 14-23% GPU savings
// from culling on this bound; an L-infinity bound culled less and ran slower.
float gfBoundLowerBound(int i, vec2 p) {
    if (GF_TYPE(i) < 0.5) {
        return 1e9;
    }
    vec2 local = gfToLocal(i, p);
    vec2 d = abs(local) - GF_EXTENT(i);
    return length(max(d, vec2(0.0))) * GF_DISTSCALE(i);
}
