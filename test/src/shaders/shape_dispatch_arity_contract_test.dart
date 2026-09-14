import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// Counts the `X(n)` invocations inside `GF_SHAPE_CASES(X) X(0) X(1) ...`.
///
/// This is the arity of the macro-expanded dispatch: how many literal shape
/// indices `shaders/common/sdf.glsl` actually branches on. Nothing enforces
/// that this number agrees with `MAX_SHAPES` or `kMaxShapes` — the three are
/// independent literals that happen to match today.
int _shapeCaseArity(String sdf) {
  final define = RegExp(
    r'#define\s+GF_SHAPE_CASES\(X\)\s*((?:X\(\d+\)\s*)+)',
  ).firstMatch(sdf);
  expect(
    define,
    isNotNull,
    reason: 'GF_SHAPE_CASES macro not found in sdf.glsl',
  );
  return RegExp(r'X\(\d+\)').allMatches(define!.group(1)!).length;
}

void main() {
  // This test's working directory must be the package root, matching every
  // other shader contract test.
  final geometry = File('shaders/geometry.frag').readAsStringSync();
  final sdf = File('shaders/common/sdf.glsl').readAsStringSync();

  test(
    'raising kMaxShapes without touching the shader silently drops shapes',
    () {
      // Controller ruling R18: shaders/common/sdf.glsl hardcodes its
      // GF_SHAPE_CASES dispatch to exactly 8 literal indices,
      // shaders/geometry.frag hardcodes MAX_SHAPES to 8, and
      // lib/src/shapes/shape_limits.dart hardcodes kMaxShapes to 8. They
      // agree today only by coincidence — kMaxShapesProvenance explicitly
      // invites raising kMaxShapes after device confirmation, and nothing
      // ties the three together. If someone raises kMaxShapes alone, the
      // shader keeps dispatching on only the old number of indices and every
      // shape past that index silently stops rendering, with no test
      // failing. This test is that tie.
      final maxShapesMatch =
          RegExp(r'#define\s+MAX_SHAPES\s+(\d+)').firstMatch(geometry);
      expect(
        maxShapesMatch,
        isNotNull,
        reason: 'MAX_SHAPES not found in geometry.frag',
      );
      final shaderMaxShapes = int.parse(maxShapesMatch!.group(1)!);
      final shapeCaseArity = _shapeCaseArity(sdf);

      expect(
        shaderMaxShapes,
        kMaxShapes,
        reason: 'geometry.frag MAX_SHAPES has drifted from kMaxShapes',
      );
      expect(
        shapeCaseArity,
        kMaxShapes,
        reason:
            'sdf.glsl GF_SHAPE_CASES dispatches on $shapeCaseArity indices, '
            'not kMaxShapes ($kMaxShapes) — shapes past index $shapeCaseArity '
            'would render as nothing',
      );
    },
  );
}
