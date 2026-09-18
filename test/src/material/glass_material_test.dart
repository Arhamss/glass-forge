import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
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

  test('contour alone is enough to render', () {
    // The darkened edge ring is independently visible and needs none of
    // frost/edgeRefraction/tintOpacity/highlight to be nonzero.
    final material = const GlassMaterial().copyWith(
      frost: 0,
      edgeRefraction: 0,
      tintOpacity: 0,
      highlight: 0,
      contour: 0.5,
    );
    expect(material.rendersAnything, isTrue);
  });

  test('a non-default saturation alone is enough to render', () {
    // saturation is a multiplier neutral at 1.0, not at 0 — a saturation
    // shift is visible on its own and must not require ">  0" to register.
    final material = const GlassMaterial().copyWith(
      frost: 0,
      edgeRefraction: 0,
      tintOpacity: 0,
      highlight: 0,
      saturation: 0.5,
    );
    expect(material.rendersAnything, isTrue);
  });

  test(
    'a material with everything neutral, including saturation, renders '
    'nothing',
    () {
      final material = const GlassMaterial().copyWith(
        frost: 0,
        edgeRefraction: 0,
        tintOpacity: 0,
        highlight: 0,
        contour: 0,
        saturation: 1,
      );
      expect(material.rendersAnything, isFalse);
    },
  );

  test('displacement range is sized to reachable displacement', () {
    final material = const GlassMaterial().copyWith(edgeRefraction: 27.42);
    expect(material.maxDisplacement, closeTo(28.79, 0.01));
  });

  test('equal materials share a revision so the filter can be reused', () {
    // Two independently constructed materials with equal fields is what a
    // widget rebuild produces every frame. Comparing `const GlassMaterial()`
    // on both sides would canonicalise to one instance and compare its
    // `revision` with itself, passing even if `hashCode` -- which
    // `revision` reuses -- were broken. Building through a helper whose
    // argument is a parameter, not a literal, keeps the analyzer from
    // const-folding the call back into one canonical instance, so
    // `identical` being false here is what proves this test actually
    // exercises the cache-reuse case rather than object identity.
    GlassMaterial materialWith({double frost = 5.0}) =>
        GlassMaterial(frost: frost);

    final a = materialWith();
    final b = materialWith();

    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a.revision, equals(b.revision));
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

    test('profile', () {
      // A cached filter reused across a profile switch would keep shading
      // the old surface over the new matte.
      expect(
        base.copyWith(profile: GlassProfile.dome).revision,
        isNot(base.revision),
      );
      expect(base.copyWith(profile: GlassProfile.dome), isNot(base));
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

    test('maxDisplacement is covered transitively through edgeRefraction', () {
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
    final clear = GlassMaterial.clear();
    expect(clear.variant, GlassVariant.clear);
    expect(clear.tintOpacity, 0);
  });

  test('everything that is not asked to be a dome is the edge band', () {
    // The fitted presets are fitted against the edge band; a default that
    // drifted to the dome would re-skin every existing surface.
    expect(const GlassMaterial().profile, GlassProfile.edgeBand);
    expect(
      GlassMaterial.regular(brightness: Brightness.dark).profile,
      GlassProfile.edgeBand,
    );
    expect(
      GlassMaterial.regular(brightness: Brightness.light).profile,
      GlassProfile.edgeBand,
    );
    expect(GlassMaterial.clear().profile, GlassProfile.edgeBand);
  });

  test('the dome preset is a dome, and a clear one', () {
    // Frost is what turns a lens into a frosted pane, and the Apple
    // presets carry 5 to 7. The dome exists to not be that.
    final dome = GlassMaterial.dome();
    expect(dome.profile, GlassProfile.dome);
    expect(dome.frost, lessThan(1));
    expect(dome.rendersAnything, isTrue);
    expect(dome.copyWith(profile: GlassProfile.edgeBand), isNot(dome));
  });
}
