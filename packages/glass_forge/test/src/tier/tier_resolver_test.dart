import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
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
}) {
  return resolveTier(
    capabilities: capabilities,
    thermal: thermal,
    frameHealth: frameHealth,
    accessibility: accessibility,
    requested: requested,
  );
}

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
