import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

void main() {
  final geometry = File('shaders/geometry.frag').readAsStringSync();
  final profile = File('shaders/common/profile.glsl').readAsStringSync();
  final codec = File('shaders/common/codec.glsl').readAsStringSync();

  test('MAX_SHAPES matches the Dart constant', () {
    // Drift here silently truncates the shape list, and the missing shapes
    // just stop rendering.
    expect(geometry.contains('#define MAX_SHAPES $kMaxShapes'), isTrue);
  });

  test('the first uniform is the engine-written vec2', () {
    final firstUniform =
        RegExp(r'uniform\s+(\w+)\s+(\w+)').firstMatch(geometry);
    expect(firstUniform?.group(1), 'vec2');
    expect(firstUniform?.group(2), 'uSize');
  });

  test('runs at high precision', () {
    // mediump shimmers on large layers; upstream #57.
    expect(geometry.contains('precision highp float'), isTrue);
  });

  test('normals are analytic, not screen-space derivatives', () {
    for (final banned in const ['dFdx', 'dFdy', 'fwidth']) {
      expect(profile.contains(banned), isFalse);
      expect(geometry.contains(banned), isFalse);
    }
  });

  test('the interior is left undistorted', () {
    // Apple displaces only an edge band. Losing this makes the effect both
    // more expensive and less faithful.
    expect(profile.contains('gfDisplacementMagnitude'), isTrue);
    expect(profile.contains('-sd >= height'), isTrue);
  });

  test('the codec uses the same 254 code and sqrt companding as Dart', () {
    expect(codec.contains('254.0'), isTrue);
    expect(codec.contains('1.0 - sqrt(1.0 - clamp'), isTrue);
  });

  test('the matte carries a real signed distance on both sides of the edge',
      () {
    // Not `min(sd, 0.0)`, and not scaled by coverage. The final pass derives
    // coverage, the contour and the rim falloff from this channel, so an
    // interior-clamped value cannot say how far outside a texel is, and a
    // premultiplied one decays toward the code for "deep inside" at exactly
    // the fringe where coverage is being resolved.
    expect(geometry.contains('gfEncodeMatte(normal, sd, magnitude'), isTrue);
    expect(geometry.contains('encoded * alpha'), isFalse);
  });

  test('texels past the band encode as outside, never as a zeroed texel', () {
    // A zeroed texel decodes to -maxDisplacement -- the deep interior --
    // which would make the padding around every shape read as solid glass.
    expect(geometry.contains('vec4(0.5, 0.5, 1.0, 0.0)'), isTrue);
  });
}
