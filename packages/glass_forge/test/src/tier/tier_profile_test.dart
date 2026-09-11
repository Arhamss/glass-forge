import 'dart:ui' show Brightness, Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';

GlassMaterial get _regular =>
    GlassMaterial.regular(brightness: Brightness.dark);

GlassMaterial _onRung(GlassTier tier, GlassMaterial material) =>
    tier.profile.applyTo(material, brightness: Brightness.dark);

void main() {
  group('applyTo', () {
    test('the full tier leaves a material untouched', () {
      final material = _regular;

      expect(
        GlassTier.full.profile.applyTo(material, brightness: Brightness.dark),
        material,
      );
    });

    test('the reduced tier halves the lensing rather than removing it', () {
      final material = _regular;

      final reduced = GlassTier.reduced.profile.applyTo(
        material,
        brightness: Brightness.dark,
      );

      expect(reduced.edgeRefraction, material.edgeRefraction * 0.5);
      expect(reduced.frost, lessThan(material.frost));
      expect(reduced.chromaticAberration, 0);
    });

    test('the flat tier removes lensing but still draws a surface', () {
      final flat = GlassTier.flat.profile.applyTo(
        _regular,
        brightness: Brightness.dark,
      );

      expect(flat.edgeRefraction, 0);
      expect(flat.refractionSpread, 0);
      expect(flat.tintOpacity, greaterThanOrEqualTo(0.55));
      expect(flat.contour, greaterThanOrEqualTo(0.3));
      // The point of the rung. A bottom tier whose material rendered nothing
      // would make a glass navigation bar vanish rather than simplify, and
      // the content behind it unreadable.
      expect(flat.rendersAnything, isTrue);
    });

    test('the flat tier still bakes a matte, because shape needs one', () {
      // Without a matte the composite pass has no coverage and degrades to
      // blurring the layer's whole rectangle — wrong-looking, and not
      // cheaper. What this rung drops is the optics, not the silhouette.
      expect(GlassTier.flat.profile.geometry, GeometryTier.portable);
    });

    test('the off tier produces a material that renders nothing at all', () {
      final off = GlassTier.off.profile.applyTo(
        _regular,
        brightness: Brightness.dark,
      );

      // This is what keeps `ui.ImageFilter.shader` from ever being
      // constructed on a Skia backend, where it throws: the layer checks
      // `rendersAnything` first and pushes no backdrop pass.
      expect(off.rendersAnything, isFalse);
      expect(off.saturation, 1, reason: 'saturation is neutral at 1, not 0');
    });

    test('a floor raises a thin material without capping a thick one', () {
      const profile = TierProfile(
        geometry: GeometryTier.portable,
        minimumTintOpacity: 0.8,
      );

      final thin = profile.applyTo(
        const GlassMaterial(tintOpacity: 0.1),
        brightness: Brightness.light,
      );
      final thick = profile.applyTo(
        const GlassMaterial(tintOpacity: 0.95),
        brightness: Brightness.light,
      );

      expect(thin.tintOpacity, 0.8);
      expect(thick.tintOpacity, 0.95);
    });

    test('a monochrome tint follows the platform brightness', () {
      const profile = TierProfile(
        geometry: GeometryTier.portable,
        monochromeTint: true,
      );

      expect(
        profile.applyTo(_regular, brightness: Brightness.dark).tint,
        const Color(0xFF000000),
      );
      expect(
        profile.applyTo(_regular, brightness: Brightness.light).tint,
        const Color(0xFFFFFFFF),
      );
    });

    test('refraction spread is dropped along with the band it describes', () {
      const profile = TierProfile(
        geometry: GeometryTier.portable,
        refractionScale: 0,
      );

      final applied = profile.applyTo(
        const GlassMaterial(refractionSpread: 4),
        brightness: Brightness.light,
      );

      // Spread is how far inward a band reaches. With no band it is not
      // merely unused, it is meaningless — and leaving it set would make an
      // otherwise-identical matte re-bake for no visible reason.
      expect(applied.refractionSpread, 0);
    });
  });

  group('domes', () {
    test('full keeps a dome exactly as it was written', () {
      final dome = GlassMaterial.dome();

      expect(_onRung(GlassTier.full, dome), dome);
    });

    test('balanced keeps the lens and takes only its dispersion', () {
      final dome = GlassMaterial.dome();
      // The preset's dispersion is the thing this rung exists to cut; a
      // preset without any would make the assertion below vacuous.
      expect(dome.chromaticAberration, greaterThan(0));

      final balanced = _onRung(GlassTier.balanced, dome);

      expect(balanced.profile, GlassProfile.dome);
      expect(balanced.chromaticAberration, 0);
      expect(balanced, dome.copyWith(chromaticAberration: 0));
    });

    test('reduced, flat and off flatten a dome to the edge band', () {
      final dome = GlassMaterial.dome();

      for (final tier in [GlassTier.reduced, GlassTier.flat, GlassTier.off]) {
        expect(
          _onRung(tier, dome).profile,
          GlassProfile.edgeBand,
          reason: '${tier.name} must not keep a dome',
        );
      }
    });

    test("a flattened dome is the same glass on a flat pane, not Apple's", () {
      final dome = GlassMaterial.dome();

      for (final tier in GlassTier.values) {
        if (tier.profile.dome) {
          continue;
        }
        final flattened = _onRung(tier, dome);
        final pane = _onRung(
          tier,
          dome.copyWith(profile: GlassProfile.edgeBand),
        );
        // The rim is the one field flattening touches for itself, so put it
        // aside and the rest must be identical: a flattened dome is the
        // developer's own glass on a flat pane. Resetting a field to a
        // default, or reaching for a preset on the way down, fails here.
        expect(
          flattened.copyWith(edgeRefraction: 0),
          pane.copyWith(edgeRefraction: 0),
          reason: tier.name,
        );
      }

      final reduced = _onRung(GlassTier.reduced, dome);
      // Concretely, at the first rung that flattens: the dome's vivid,
      // unfrosted, upper-left-lit glass on a flat pane.
      expect(reduced.saturation, dome.saturation);
      expect(reduced.frost, 0);
      expect(reduced.lightDirection, dome.lightDirection);
      expect(reduced.tint, dome.tint);
    });

    test('a flattened rim never outreaches the edge the dome lit', () {
      // The cap applies after the rung's scale, not before: it is a limit
      // on what is drawn, not another scale.
      final deep = GlassMaterial.dome().copyWith(thickness: 100);
      final thin = GlassMaterial.dome().copyWith(thickness: 2);

      expect(
        _onRung(GlassTier.reduced, deep).edgeRefraction,
        deep.edgeRefraction * 0.5,
        reason: 'a thick dome has room for the whole scaled rim',
      );
      expect(_onRung(GlassTier.reduced, thin).edgeRefraction, 2);
      // The preset: 40 halved to 20, held to its 8 of thickness.
      expect(
        _onRung(GlassTier.reduced, GlassMaterial.dome()).edgeRefraction,
        8,
      );
    });

    test('flattening does not switch on a spread the dome never showed', () {
      final spread = GlassMaterial.dome().copyWith(refractionSpread: 1);

      // Spread shapes only the edge band, so on a dome it did nothing and
      // the developer never saw it. Flattening must not make it visible —
      // it would widen the band far past the rim the cap above allows.
      expect(_onRung(GlassTier.reduced, spread).refractionSpread, 0);
      // An edge band that asked for one still gets it.
      expect(
        _onRung(
          GlassTier.reduced,
          spread.copyWith(profile: GlassProfile.edgeBand),
        ).refractionSpread,
        1,
      );
    });

    test('a dome degraded to nothing does not still claim to be one', () {
      final off = _onRung(GlassTier.off, GlassMaterial.dome());

      expect(off.rendersAnything, isFalse);
      expect(off.profile, GlassProfile.edgeBand);
    });

    test('the dome axis never touches an edge band', () {
      // Every surface that is not a dome must come out of every rung
      // exactly as it did before domes were an axis at all.
      final materials = <GlassMaterial>[
        _regular,
        GlassMaterial.clear(),
        const GlassMaterial(refractionSpread: 0.5, chromaticAberration: 2),
      ];
      for (final tier in GlassTier.values) {
        for (final material in materials) {
          expect(
            tier.profile
                .copyWith(dome: false)
                .applyTo(
                  material,
                  brightness: Brightness.dark,
                ),
            tier.profile
                .copyWith(dome: true)
                .applyTo(
                  material,
                  brightness: Brightness.dark,
                ),
            reason: tier.name,
          );
        }
      }
    });

    test('a profile that differs only in domes is a different profile', () {
      // GlassTierScope rebuilds glass layers when the resolved profile
      // changes. If equality ignored this axis, domes held flat by the
      // hysteresis would never be redrawn when the hold ended.
      final keeps = GlassTier.balanced.profile;
      final flattens = keeps.copyWith(dome: false);

      expect(flattens, isNot(keeps));
      expect(flattens.dome, isFalse);
      expect(flattens.copyWith(), flattens);
      expect(flattens.copyWith(dome: true), keeps);
    });
  });

  group('the ladder', () {
    test('is ordered from richest to poorest', () {
      expect(GlassTier.full.index, lessThan(GlassTier.balanced.index));
      expect(GlassTier.balanced.index, lessThan(GlassTier.reduced.index));
      expect(GlassTier.reduced.index, lessThan(GlassTier.flat.index));
      expect(GlassTier.flat.index, lessThan(GlassTier.off.index));
    });

    test('clampedTo picks the poorer of the two', () {
      expect(GlassTier.full.clampedTo(GlassTier.reduced), GlassTier.reduced);
      expect(GlassTier.flat.clampedTo(GlassTier.reduced), GlassTier.flat);
    });

    test('lowered steps down and stops at flat, never reaching off', () {
      expect(GlassTier.full.lowered(1), GlassTier.balanced);
      expect(GlassTier.full.lowered(2), GlassTier.reduced);

      // No amount of heat or dropped frames means the renderer *cannot*
      // draw glass. A device that quietly stopped drawing it would read as
      // broken rather than degraded.
      expect(GlassTier.full.lowered(10), GlassTier.flat);
      expect(GlassTier.reduced.lowered(5), GlassTier.flat);
    });

    test('once a rung flattens domes, every poorer rung does too', () {
      // A ladder that flattened at one rung and restored domes further
      // down would give a hotter device a costlier surface.
      var flattened = false;
      for (final tier in GlassTier.values) {
        if (flattened) {
          expect(tier.profile.dome, isFalse, reason: tier.name);
        }
        flattened = flattened || !tier.profile.dome;
      }
      expect(flattened, isTrue);
    });

    test('lowered by zero steps is the identity, and never climbs', () {
      expect(GlassTier.reduced.lowered(0), GlassTier.reduced);
      expect(GlassTier.off.lowered(3), GlassTier.off);
    });
  });
}
