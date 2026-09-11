import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:glass_forge/src/tier/frame_watchdog.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';
import 'package:glass_forge/src/tier/tier_resolver.dart';

/// Impeller with a working Flutter GPU context: nothing is ruled out.
const _capable = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.metal,
  acceleratedGeometry: true,
  complete: true,
);

/// Impeller without Flutter GPU — a shader bundle that did not build, or a
/// Flutter release that moved the API.
const _noAcceleratedGeometry = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.openGLES,
  acceleratedGeometry: false,
  complete: true,
);

/// The synchronously-knowable subset, before the async probe lands.
const _stillProbing = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.unknown,
  acceleratedGeometry: false,
  complete: false,
);

/// Skia. `ui.ImageFilter.shader` throws here rather than running slowly.
const _skia = RenderCapabilities(
  shaderFilters: false,
  backend: GraphicsBackend.skia,
  acceleratedGeometry: false,
  complete: true,
);

const _noAccessibilitySettings = AccessibilitySignals();

ResolvedTier _resolve({
  RenderCapabilities capabilities = _capable,
  ThermalState? thermal,
  FrameHealth frameHealth = FrameHealth.healthy,
  AccessibilitySignals accessibility = _noAccessibilitySettings,
  GlassTier? requested,
  bool domeWasFlattened = false,
}) {
  return resolveTier(
    capabilities: capabilities,
    thermal: thermal,
    frameHealth: frameHealth,
    accessibility: accessibility,
    requested: requested,
    domeWasFlattened: domeWasFlattened,
  );
}

/// What [resolved] does to the dome preset.
GlassMaterial _dome(ResolvedTier resolved) =>
    resolved.materialFor(GlassMaterial.dome(), brightness: Brightness.dark);

void main() {
  group('capability', () {
    test('a capable device with nothing wrong resolves to full', () {
      expect(_resolve().tier, GlassTier.full);
      expect(_resolve().geometry, GeometryTier.accelerated);
    });

    test('a missing accelerated producer caps the tier at balanced', () {
      final resolved = _resolve(capabilities: _noAcceleratedGeometry);

      expect(resolved.tier, GlassTier.balanced);
      expect(resolved.geometry, GeometryTier.portable);
    });

    test('an unfinished probe does not cap anything', () {
      // `acceleratedGeometry` is pessimistically false until the probe runs.
      // Clamping on it would start every app a rung low and then visibly
      // climb — and nothing breaks by waiting, because producer selection
      // falls through to the runtime producer on its own.
      expect(_resolve(capabilities: _stillProbing).tier, GlassTier.full);
    });

    test('a Skia backend resolves to off and renders nothing', () {
      final resolved = _resolve(capabilities: _skia);

      expect(resolved.tier, GlassTier.off);
      expect(
        resolved
            .materialFor(
              GlassMaterial.regular(brightness: Brightness.dark),
              brightness: Brightness.dark,
            )
            .rendersAnything,
        isFalse,
      );
    });
  });

  group('thermal', () {
    test('an unknown reading imposes no ceiling', () {
      // Windows, Linux, web and Android below API 29 have no thermal API.
      // Degrading them for the platform's silence would make glass worse on
      // machines that are perfectly cool.
      expect(_resolve().tier, GlassTier.full);
      expect(_resolve().thermalCeiling, GlassTier.full);
    });

    test('an unknown reading is reported as unknown, not as nominal', () {
      final unknown = _resolve();
      final nominal = _resolve(thermal: ThermalState.nominal);

      expect(unknown.tier, nominal.tier);
      // Same verdict, different evidence. A caller that wants to say "this
      // device is running cool" has to be able to tell them apart.
      expect(unknown.thermalIsKnown, isFalse);
      expect(nominal.thermalIsKnown, isTrue);
      expect(unknown.describe(), contains('thermal: unknown'));
    });

    test('a fair reading does not degrade anything', () {
      // Fair is common, transient and reached by ordinary use. Degrading on
      // it would make the tier flicker on a phone that is merely awake.
      expect(_resolve(thermal: ThermalState.fair).tier, GlassTier.full);
    });

    test('a serious reading caps the tier', () {
      expect(_resolve(thermal: ThermalState.serious).tier, GlassTier.reduced);
    });

    test('a critical reading caps it harder', () {
      expect(_resolve(thermal: ThermalState.critical).tier, GlassTier.flat);
    });
  });

  group('frame health', () {
    test('healthy frames take nothing away', () {
      expect(_resolve().frameSteps, 0);
      expect(_resolve().tier, GlassTier.full);
    });

    test('strained frames step down one rung', () {
      expect(
        _resolve(frameHealth: FrameHealth.strained).tier,
        GlassTier.balanced,
      );
    });

    test('saturated frames step down two', () {
      expect(
        _resolve(frameHealth: FrameHealth.saturated).tier,
        GlassTier.reduced,
      );
    });

    test('the step is relative to where the ceilings already left it', () {
      // Frame health is not a statement about the device, it is a statement
      // about the current workload: whatever you are doing is too much. So
      // it moves down from wherever the ceilings put us rather than naming a
      // floor of its own — which is why the same verdict lands on different
      // rungs here.
      expect(
        _resolve(frameHealth: FrameHealth.strained).tier,
        GlassTier.balanced,
      );
      expect(
        _resolve(
          thermal: ThermalState.serious,
          frameHealth: FrameHealth.strained,
        ).tier,
        GlassTier.flat,
      );
    });

    test('never steps past flat, however bad it gets', () {
      expect(
        _resolve(
          thermal: ThermalState.critical,
          frameHealth: FrameHealth.saturated,
        ).tier,
        GlassTier.flat,
      );
    });
  });

  group('accessibility', () {
    test('Reduce Transparency makes the surface frostier and more opaque', () {
      final material = GlassMaterial.regular(brightness: Brightness.dark);
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceTransparency: true),
      );

      final degraded = resolved.materialFor(
        material,
        brightness: Brightness.dark,
      );

      // Apple: "makes Liquid Glass frostier and obscures more of the content
      // behind it".
      expect(degraded.frost, greaterThan(material.frost));
      expect(degraded.tintOpacity, greaterThan(material.tintOpacity));
      expect(degraded.edgeRefraction, 0);
    });

    test('Reduce Transparency gives up the accelerated geometry pass', () {
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceTransparency: true),
      );

      // The accelerated pass exists to bake a refraction band. With no band
      // to bake it is a whole render pass producing a coverage mask the
      // portable producer makes just as well.
      expect(resolved.geometry, GeometryTier.portable);
    });

    test('Increase Contrast goes near-opaque with a border', () {
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(increaseContrast: true),
      );

      final degraded = resolved.materialFor(
        GlassMaterial.regular(brightness: Brightness.light),
        brightness: Brightness.light,
      );

      // Apple: "makes elements predominantly black or white and highlights
      // them with a contrasting border".
      expect(degraded.tintOpacity, greaterThanOrEqualTo(0.95));
      expect(degraded.contour, greaterThanOrEqualTo(0.6));
      expect(degraded.tint.r, 1.0);
      expect(degraded.edgeRefraction, 0);
      expect(degraded.highlight, 0);
    });

    test('Reduce Motion disables elasticity and touches nothing else', () {
      final material = GlassMaterial.regular(brightness: Brightness.dark);
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceMotion: true),
      );

      expect(resolved.elasticMotion, isFalse);
      // Claims that Reduce Motion also eliminates lensing go beyond Apple's
      // own wording, which is about elastic properties and effect intensity.
      expect(
        resolved.materialFor(material, brightness: Brightness.dark),
        material,
      );
      expect(resolved.tier, GlassTier.full);
    });

    test('elasticity is on by default', () {
      expect(_resolve().elasticMotion, isTrue);
    });
  });

  group('an explicit request', () {
    test('beats heat and dropped frames together', () {
      final resolved = _resolve(
        thermal: ThermalState.critical,
        frameHealth: FrameHealth.saturated,
        requested: GlassTier.full,
      );

      expect(resolved.tier, GlassTier.full);
      expect(resolved.geometry, GeometryTier.accelerated);
      // The signals are still reported, so the override is visible as an
      // override rather than as a device that never got hot.
      expect(resolved.thermalCeiling, GlassTier.flat);
      expect(resolved.frameSteps, 2);
    });

    test('beats a missing accelerated producer', () {
      expect(
        _resolve(
          capabilities: _noAcceleratedGeometry,
          requested: GlassTier.full,
        ).tier,
        GlassTier.full,
      );
    });

    test('can also pin a tier lower than the signals would', () {
      expect(_resolve(requested: GlassTier.flat).tier, GlassTier.flat);
    });

    test('does not lift Reduce Transparency', () {
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceTransparency: true),
        requested: GlassTier.full,
      );

      // Deliberately asymmetric with heat and frames. Accessibility settings
      // are correctness requirements, so a developer pinning a tier would be
      // opting out on their users' behalf.
      expect(resolved.tier, GlassTier.flat);
      expect(
        resolved
            .materialFor(
              GlassMaterial.regular(brightness: Brightness.dark),
              brightness: Brightness.dark,
            )
            .edgeRefraction,
        0,
      );
    });

    test('does not lift a backend that cannot run the shader', () {
      // Not a preference either: honouring the request on Skia would not
      // produce worse glass, it would produce an exception during paint.
      expect(
        _resolve(capabilities: _skia, requested: GlassTier.full).tier,
        GlassTier.off,
      );
    });
  });

  group('domes', () {
    test('a capable, healthy device draws a dome as written', () {
      final resolved = _resolve();

      expect(resolved.dome, isTrue);
      expect(_dome(resolved), GlassMaterial.dome());
    });

    test('strained frames keep the lens and drop its dispersion', () {
      final resolved = _resolve(frameHealth: FrameHealth.strained);

      expect(resolved.tier, GlassTier.balanced);
      expect(_dome(resolved).profile, GlassProfile.dome);
      expect(_dome(resolved).chromaticAberration, 0);
    });

    test('saturated frames flatten it', () {
      final resolved = _resolve(frameHealth: FrameHealth.saturated);

      expect(resolved.tier, GlassTier.reduced);
      expect(resolved.dome, isFalse);
      expect(_dome(resolved).profile, GlassProfile.edgeBand);
    });

    test('serious heat flattens it, and fair heat does not', () {
      expect(
        _dome(_resolve(thermal: ThermalState.fair)).profile,
        GlassProfile.dome,
      );
      expect(
        _dome(_resolve(thermal: ThermalState.serious)).profile,
        GlassProfile.edgeBand,
      );
    });

    test('a device capped at balanced keeps it until frames strain', () {
      expect(_resolve(capabilities: _noAcceleratedGeometry).dome, isTrue);

      final strained = _resolve(
        capabilities: _noAcceleratedGeometry,
        frameHealth: FrameHealth.strained,
      );
      expect(strained.tier, GlassTier.reduced);
      expect(strained.dome, isFalse);
    });
  });

  group('dome hysteresis', () {
    test('the same signals keep or hold a dome depending on history', () {
      // The band itself. Strained frames on a full-ceiling device mean
      // balanced, where a dome that was never flattened survives; one that
      // was flattened stays flat, because the watchdog has climbed only one
      // of the two steps back to healthy.
      final never = _resolve(frameHealth: FrameHealth.strained);
      final after = _resolve(
        frameHealth: FrameHealth.strained,
        domeWasFlattened: true,
      );

      expect(never.tier, GlassTier.balanced);
      expect(after.tier, GlassTier.balanced);
      expect(never.dome, isTrue);
      expect(after.dome, isFalse);
      expect(_dome(after).profile, GlassProfile.edgeBand);
    });

    test('a saturated episode keeps domes flat until frames are healthy', () {
      // One verdict feeding the next, as the engine does it.
      var dome = true;
      final seen = <(GlassTier, bool)>[];
      for (final health in [
        FrameHealth.healthy,
        FrameHealth.saturated,
        FrameHealth.strained,
        FrameHealth.healthy,
      ]) {
        final resolved = _resolve(
          frameHealth: health,
          domeWasFlattened: !dome,
        );
        dome = resolved.dome;
        seen.add((resolved.tier, dome));
      }

      expect(seen, [
        (GlassTier.full, true),
        (GlassTier.reduced, false),
        (GlassTier.balanced, false),
        (GlassTier.full, true),
      ]);
    });

    test('the hold is reported as a hold', () {
      final held = _resolve(
        frameHealth: FrameHealth.strained,
        domeWasFlattened: true,
      );

      expect(held.domeHeld, isTrue);
      expect(held.describe(), contains('held flat'));
      // Flat because the rung says so is not a hold.
      final flattened = _resolve(frameHealth: FrameHealth.saturated);
      expect(flattened.domeHeld, isFalse);
      expect(flattened.describe(), isNot(contains('held')));
    });

    test('on a device capped at balanced the hold ends at the ceiling', () {
      // Such a device can never reach full. A hold that waited for full
      // would take its domes away for the rest of the session after one
      // strained moment.
      final recovered = _resolve(
        capabilities: _noAcceleratedGeometry,
        domeWasFlattened: true,
      );

      expect(recovered.tier, GlassTier.balanced);
      expect(recovered.dome, isTrue);
    });

    test('heat that has passed brings domes straight back', () {
      final hot = _resolve(thermal: ThermalState.serious);
      final cooled = _resolve(
        thermal: ThermalState.fair,
        domeWasFlattened: !hot.dome,
      );

      expect(hot.dome, isFalse);
      expect(cooled.tier, GlassTier.full);
      expect(cooled.dome, isTrue);
    });

    test('history cannot keep a dome on a rung that flattens it', () {
      expect(
        _resolve(frameHealth: FrameHealth.saturated).dome,
        isFalse,
      );
      expect(_resolve(requested: GlassTier.flat).dome, isFalse);
    });
  });

  group('domes and an explicit request', () {
    test('a pinned full keeps domes whatever the heat, frames or history', () {
      final resolved = _resolve(
        thermal: ThermalState.critical,
        frameHealth: FrameHealth.saturated,
        requested: GlassTier.full,
        domeWasFlattened: true,
      );

      expect(resolved.tier, GlassTier.full);
      expect(_dome(resolved), GlassMaterial.dome());
    });

    test('a pinned balanced keeps domes even inside the hold band', () {
      final resolved = _resolve(
        frameHealth: FrameHealth.strained,
        requested: GlassTier.balanced,
        domeWasFlattened: true,
      );

      expect(resolved.dome, isTrue);
      expect(resolved.domeHeld, isFalse);
    });

    test('a pinned reduced flattens domes on a healthy device', () {
      expect(
        _dome(_resolve(requested: GlassTier.reduced)).profile,
        GlassProfile.edgeBand,
      );
    });

    test('does not lift Reduce Transparency or Increase Contrast off one', () {
      for (final settings in const [
        AccessibilitySignals(reduceTransparency: true),
        AccessibilitySignals(increaseContrast: true),
      ]) {
        final resolved = _resolve(
          accessibility: settings,
          requested: GlassTier.full,
        );

        expect(resolved.dome, isFalse);
        expect(_dome(resolved).profile, GlassProfile.edgeBand);
      }
    });

    test('does not lift a backend that cannot run the shader', () {
      final resolved = _resolve(capabilities: _skia, requested: GlassTier.full);

      expect(_dome(resolved).rendersAnything, isFalse);
      expect(_dome(resolved).profile, GlassProfile.edgeBand);
    });
  });

  group('domes and accessibility', () {
    test('Reduce Transparency flattens a dome and frosts it as it would a '
        'pane', () {
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceTransparency: true),
      );
      final degraded = _dome(resolved);

      expect(degraded.profile, GlassProfile.edgeBand);
      // The dome preset has no frost and almost no tint, so both floors
      // have to do all the work here.
      expect(degraded.frost, greaterThanOrEqualTo(24));
      expect(degraded.tintOpacity, greaterThanOrEqualTo(0.85));
      expect(degraded.edgeRefraction, 0);
      expect(resolved.geometry, GeometryTier.portable);
    });

    test('Increase Contrast flattens a dome, and the border survives', () {
      final degraded = _resolve(
        accessibility: const AccessibilitySignals(increaseContrast: true),
      ).materialFor(GlassMaterial.dome(), brightness: Brightness.light);

      expect(degraded.profile, GlassProfile.edgeBand);
      expect(degraded.tintOpacity, greaterThanOrEqualTo(0.95));
      expect(degraded.tint.r, 1.0);
      expect(degraded.contour, greaterThanOrEqualTo(0.6));
      expect(degraded.highlight, 0);
      expect(degraded.edgeRefraction, 0);
    });

    test('Reduce Motion keeps a dome a dome', () {
      final resolved = _resolve(
        accessibility: const AccessibilitySignals(reduceMotion: true),
      );

      expect(resolved.elasticMotion, isFalse);
      expect(_dome(resolved), GlassMaterial.dome());
    });
  });

  test('describe names every input, not just the verdict', () {
    final description = _resolve(
      thermal: ThermalState.serious,
      frameHealth: FrameHealth.strained,
    ).describe();

    expect(description, contains('flat'));
    expect(description, contains('serious'));
    expect(description, contains('strained'));
  });
}
