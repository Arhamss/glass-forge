import 'dart:ui' show Brightness, Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';

GlassMaterial get _regular =>
    GlassMaterial.regular(brightness: Brightness.dark);

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

    test('lowered by zero steps is the identity, and never climbs', () {
      expect(GlassTier.reduced.lowered(0), GlassTier.reduced);
      expect(GlassTier.off.lowered(3), GlassTier.off);
    });
  });
}
