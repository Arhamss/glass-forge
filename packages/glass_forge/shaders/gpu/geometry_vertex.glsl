// Fullscreen-quad vertex stage for the Flutter GPU geometry render pass.
//
// Two triangles covering clip space entirely. There is nothing to
// interpolate besides gl_Position: shaders/gpu/geometry_fragment.glsl reads
// gl_FragCoord directly rather than a varying, matching FlutterFragCoord()
// in the runtime-effect path (shaders/geometry.frag) -- both follow the same
// top-left, pixel-centre convention, so the two stay interchangeable.

in vec2 position;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
}
