import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

void main() {
  final sdf = File('shaders/common/sdf.glsl').readAsStringSync();

  test('reads the uniform array as a global, never as a parameter', () {
    // The exact defect behind upstream #150: a by-value array parameter makes
    // spirv-cross emit an array copy-initializer that SkSL rejects.
    expect(
      RegExp(r'\(\s*[^)]*float\s+\w+\s*\[').hasMatch(sdf),
      isFalse,
      reason: 'an array parameter would break SkSL compilation',
    );
  });

  test('uses no derivative functions', () {
    // Rejected on web, and undefined after a non-uniform early return.
    for (final banned in const ['dFdx', 'dFdy', 'fwidth']) {
      expect(sdf.contains(banned), isFalse, reason: '$banned is not portable');
    }
  });

  test('takes no sampler parameters', () {
    expect(RegExp(r'\(\s*[^)]*sampler2D').hasMatch(sdf), isFalse);
  });

  test('every loop has constant bounds', () {
    for (final match in RegExp(r'for\s*\(([^)]*)\)').allMatches(sdf)) {
      final header = match.group(1)!;
      expect(
        RegExp(r'<\s*\d+').hasMatch(header),
        isTrue,
        reason: 'non-constant loop bound in "$header" breaks SkSL',
      );
    }
  });

  test('dispatches on every shape type the Dart side can emit', () {
    // If a new ShapeType is added without a shader branch it silently renders
    // as whatever the final else happens to be.
    expect(ShapeType.values.length, 4);
    expect(sdf.contains('sdRoundedBox'), isTrue);
    expect(sdf.contains('sdEllipse'), isTrue);
    expect(sdf.contains('sdSuperellipse'), isTrue);
  });

  test('documents the stride the Dart packing must match', () {
    expect(sdf.contains('* 3 + 0'), isTrue);
    expect(sdf.contains('* 3 + 1'), isTrue);
    expect(sdf.contains('* 3 + 2'), isTrue);
    expect(kMaxShapes, greaterThan(0));
  });
}
