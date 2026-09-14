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

/// A GLSL scalar, vector, or matrix type name — everything a by-value array
/// parameter could plausibly be typed as (`uShapeData` itself is `vec4[]`,
/// not `float[]`, so the type list has to cover more than the one type the
/// upstream defect happened to use).
const _glslTypePattern =
    '(?:bool|u?int|float|double|[iubd]?vec[234]|mat[234](?:x[234])?)';

/// Finds each `for (...)` loop header in [source], tracking paren depth so a
/// nested call in the bound (e.g. `i < min(4, n)`) cannot truncate the
/// header early the way a plain `[^)]*` capture would.
List<String> _forHeaders(String source) {
  final headers = <String>[];
  for (final match in RegExp(r'\bfor\s*\(').allMatches(source)) {
    var depth = 1;
    var i = match.end;
    final start = i;
    while (i < source.length && depth > 0) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') depth--;
      if (depth > 0) i++;
    }
    headers.add(source.substring(start, i));
  }
  return headers;
}

void main() {
  final sdf = File('shaders/common/sdf.glsl').readAsStringSync();
  final code = _stripComments(sdf);

  test('reads the uniform array as a global, never as a parameter', () {
    // The exact defect behind upstream #150: a by-value array parameter makes
    // spirv-cross emit an array copy-initializer that SkSL rejects. Checked
    // against every GLSL type, not just `float` — uShapeData itself is
    // `vec4[]`, so a parameter typed `vec4 shapeData[24]` is exactly the
    // defect this test exists to catch, and a float-only pattern would miss it.
    expect(
      RegExp(r'\(\s*[^)]*' '$_glslTypePattern' r'\s+\w+\s*\[').hasMatch(code),
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
    for (final header in _forHeaders(code)) {
      expect(
        RegExp(r'<=?\s*\d+').hasMatch(header),
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
