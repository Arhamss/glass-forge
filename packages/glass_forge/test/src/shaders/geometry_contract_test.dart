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

  test('output is premultiplied', () {
    expect(geometry.contains('encoded * alpha'), isTrue);
  });
}
