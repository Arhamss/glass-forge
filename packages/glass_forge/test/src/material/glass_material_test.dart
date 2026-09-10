import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_variant.dart';

void main() {
  test('a material with nothing enabled renders nothing', () {
    // The layer then pushes no backdrop filter at all. Upstream pushes a
    // full backdrop pass even at blur 0.
    //
    // Built via copyWith rather than the constructor directly: several of
    // these values coincide with GlassMaterial's own defaults, and passing
    // them as constructor arguments would be flagged as redundant.
    final material = const GlassMaterial().copyWith(
      frost: 0,
      edgeRefraction: 0,
      tintOpacity: 0,
      highlight: 0,
    );
    expect(material.rendersAnything, isFalse);
  });

  test('frost alone is enough to render', () {
    final material = const GlassMaterial().copyWith(
      frost: 5,
      edgeRefraction: 0,
      tintOpacity: 0,
      highlight: 0,
    );
    expect(material.rendersAnything, isTrue);
  });

  test('displacement range is sized to reachable displacement', () {
    final material = const GlassMaterial().copyWith(edgeRefraction: 27.42);
    expect(material.maxDisplacement, closeTo(28.79, 0.01));
  });

  test('equal materials share a revision so the filter can be reused', () {
    expect(const GlassMaterial().revision, const GlassMaterial().revision);
  });

  test('a changed field changes the revision', () {
    expect(
      const GlassMaterial().revision,
      isNot(const GlassMaterial(frost: 12).revision),
    );
  });

  group('revision covers every field (R22)', () {
    // A cached native ImageFilter is reused while FilterSnapshot compares
    // equal, and that snapshot represents the whole material by a single
    // materialRevision int. If any field that reaches a shader uniform is
    // missing from `revision`, a change to it renders with the previous
    // frame's value and nothing catches it. Pin every field here.
    const base = GlassMaterial();

    test('variant', () {
      expect(
        base.copyWith(variant: GlassVariant.clear).revision,
        isNot(base.revision),
      );
    });

    test('thickness', () {
      expect(
        base.copyWith(thickness: base.thickness + 1).revision,
        isNot(base.revision),
      );
    });

    test('edgeRefraction', () {
      expect(
        base.copyWith(edgeRefraction: base.edgeRefraction + 1).revision,
        isNot(base.revision),
      );
    });

    test('refractionSpread', () {
      expect(
        base.copyWith(refractionSpread: base.refractionSpread + 1).revision,
        isNot(base.revision),
      );
    });

    test('frost', () {
      expect(
        base.copyWith(frost: base.frost + 1).revision,
        isNot(base.revision),
      );
    });

    test('chromaticAberration', () {
      expect(
        base
            .copyWith(chromaticAberration: base.chromaticAberration + 1)
            .revision,
        isNot(base.revision),
      );
    });

    test('tint', () {
      expect(
        base.copyWith(tint: const Color(0xFF123456)).revision,
        isNot(base.revision),
      );
    });

    test('tintOpacity', () {
      expect(
        base.copyWith(tintOpacity: base.tintOpacity + 0.1).revision,
        isNot(base.revision),
      );
    });

    test('saturation', () {
      expect(
        base.copyWith(saturation: base.saturation + 0.1).revision,
        isNot(base.revision),
      );
    });

    test('highlight', () {
      expect(
        base.copyWith(highlight: base.highlight + 0.1).revision,
        isNot(base.revision),
      );
    });

    test('lightDirection', () {
      expect(
        base.copyWith(lightDirection: const Offset(1, 0)).revision,
        isNot(base.revision),
      );
    });

    test('contour', () {
      expect(
        base.copyWith(contour: base.contour + 0.1).revision,
        isNot(base.revision),
      );
    });

    test('maxDisplacement is covered transitively through edgeRefraction',
        () {
      final changed = base.copyWith(edgeRefraction: base.edgeRefraction + 1);
      expect(changed.maxDisplacement, isNot(base.maxDisplacement));
      expect(changed.revision, isNot(base.revision));
    });
  });

  test('the regular preset uses the fitted iOS 27 geometry', () {
    // Values fitted by upstream's harness against real .buttonStyle(.glass)
    // captures, not eyeballed.
    final material = GlassMaterial.regular(brightness: Brightness.light);
    expect(material.thickness, closeTo(12, 1e-9));
    expect(material.edgeRefraction, closeTo(27.42, 1e-9));
    expect(material.variant, GlassVariant.regular);
  });

  test('the clear preset does not adapt', () {
    // Apple: clear "does not have adaptive behaviors" and takes a dimming
    // layer instead. Mixing the two variants is explicitly called out as
    // wrong, so they must stay distinguishable.
    final clear = GlassMaterial.clear(brightness: Brightness.light);
    expect(clear.variant, GlassVariant.clear);
    expect(clear.tintOpacity, 0);
  });
}
