// RGBA8 matte codec. This is the shader half of lib/src/geometry/matte_codec.dart.
// The two MUST agree; matte_codec_test.dart pins the Dart side and
// geometry_contract_test.dart pins the constants here.

// 0..254 of 0..255, so -1, 0 and +1 are all exactly representable. A symmetric
// code cannot hit all three, and a flat surface then acquires a permanent
// sub-pixel tilt from its own encoding.
float gfEncodeSigned(float v) {
    return floor((clamp(v, -1.0, 1.0) * 0.5 + 0.5) * 254.0 + 0.5) / 255.0;
}

float gfDecodeSigned(float e) {
    return (e * 255.0 / 254.0) * 2.0 - 1.0;
}

// Concentrates precision near the MAXIMUM of the 0..1 range: this is
// steepest (largest derivative) as `linear` approaches 1. Used for
// displacement magnitude, whose edge profile goes flat near the shape edge
// -- the maximum -- which is exactly where banding needs to be fought.
//
// Dart's mirror is MatteCodec._encodeTowardMax / _decodeTowardMax.
float gfEncodeCompandedMax(float linear) {
    return 1.0 - sqrt(1.0 - clamp(linear, 0.0, 1.0));
}

float gfDecodeCompandedMax(float e) {
    float inv = 1.0 - e;
    return 1.0 - inv * inv;
}

// Concentrates precision near ZERO: this is steepest as `linear` approaches
// 0. Used for signed edge distance, since coverage, the contour and the
// bevel are all computed near distance zero -- the shape edge itself.
//
// Dart's mirror is MatteCodec._encodeTowardZero / _decodeTowardZero. Do not
// unify this with gfEncodeCompandedMax above: they concentrate precision in
// opposite places on purpose, matching where each channel's own precision
// needs to live.
float gfEncodeCompandedZero(float linear) {
    return sqrt(clamp(linear, 0.0, 1.0));
}

float gfDecodeCompandedZero(float e) {
    return e * e;
}

vec4 gfEncodeMatte(vec2 normal, float signedDistance, float magnitude,
                   float maxDisplacement) {
    float len = length(normal);
    vec2 unit = len < 1e-6 ? vec2(0.0) : normal / len;

    // Signed distance is companded toward zero -- see gfEncodeCompandedZero.
    float nd = clamp(signedDistance / maxDisplacement, -1.0, 1.0);
    float ndMag = gfEncodeCompandedZero(abs(nd));
    float b = nd < 0.0 ? 0.5 - ndMag * 0.5 : 0.5 + ndMag * 0.5;

    // Displacement magnitude is companded toward the maximum -- see
    // gfEncodeCompandedMax.
    return vec4(
        gfEncodeSigned(unit.x),
        gfEncodeSigned(unit.y),
        b,
        gfEncodeCompandedMax(clamp(magnitude / maxDisplacement, 0.0, 1.0))
    );
}
