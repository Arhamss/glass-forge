import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

/// Strips `//` line comments and `/* */` block comments from GLSL source.
///
/// The header comment's entire job is to name the banned tokens (`dFdx`,
/// a by-value array parameter, `sampler2D`, a non-constant loop bound) so the
/// next person who edits this file knows what not to reintroduce. A token
/// scan meant to catch those things in *code* must not also fire on prose
/// that is explaining the ban, so every scan below runs against comment-
/// stripped source rather than the raw file.
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      if (end == -1) break;
      i = end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      if (end == -1) break;
      i = end + 2;
      continue;
    }
    buffer.write(source[i]);
    i++;
  }
  return buffer.toString();
}

void main() {
  final sdf = File('shaders/common/sdf.glsl').readAsStringSync();
  final code = _stripComments(sdf);

  test('reads the uniform array as a global, never as a parameter', () {
    // The exact defect behind upstream #150: a by-value array parameter makes
    // spirv-cross emit an array copy-initializer that SkSL rejects.
    expect(
      RegExp(r'\(\s*[^)]*float\s+\w+\s*\[').hasMatch(code),
      isFalse,
      reason: 'an array parameter would break SkSL compilation',
    );
  });

  test('uses no derivative functions', () {
    // Rejected on web, and undefined after a non-uniform early return.
    for (final banned in const ['dFdx', 'dFdy', 'fwidth']) {
      expect(
        code.contains(banned),
        isFalse,
        reason: '$banned is not portable',
      );
    }
  });

  test('takes no sampler parameters', () {
    expect(RegExp(r'\(\s*[^)]*sampler2D').hasMatch(code), isFalse);
  });

  test('every loop has constant bounds', () {
    for (final match in RegExp(r'for\s*\(([^)]*)\)').allMatches(code)) {
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
