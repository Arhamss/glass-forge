import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:glass_forge/src/tier/frame_watchdog.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';

/// The single answer four signals collapse into.
///
/// Every input is kept alongside the verdict rather than being thrown away
/// after it was consulted, because "why is this device at `reduced`?" is the
/// question anyone looking at a tier actually has, and reconstructing it from
/// the tier alone is impossible.
@immutable
class ResolvedTier {
  /// Creates a resolved tier.
  const ResolvedTier({
    required this.tier,
    required this.profile,
    required this.capabilities,
    required this.thermal,
    required this.frameHealth,
    required this.accessibility,
    required this.capabilityCeiling,
    required this.thermalCeiling,
    required this.accessibilityCeiling,
    required this.frameSteps,
    required this.requested,
  });

  /// The rung that won.
  final GlassTier tier;

  /// [tier]'s profile, with the accessibility overlay already applied.
  ///
  /// Not `tier.profile`: an accessibility setting moves axes that no
  /// performance rung moves — a forced monochrome tint is not a cheaper
  /// version of a tinted one — so the effective profile can sit off the
  /// ladder entirely.
  final TierProfile profile;

  /// What the renderer can do here.
  final RenderCapabilities capabilities;

  /// The last thermal reading, or null if the platform never gave one.
  final ThermalState? thermal;

  /// How the frame pipeline is doing.
  final FrameHealth frameHealth;

  /// The accessibility settings in force.
  final AccessibilitySignals accessibility;

  /// The ceiling the static capability probe imposed.
  final GlassTier capabilityCeiling;

  /// The ceiling the thermal reading imposed.
  final GlassTier thermalCeiling;

  /// The ceiling the accessibility settings imposed.
  final GlassTier accessibilityCeiling;

  /// How many rungs the frame watchdog asked for.
  final int frameSteps;

  /// The tier a caller asked for explicitly, if any.
  final GlassTier? requested;

  /// Which geometry producer a layer should use.
  GeometryTier get geometry => profile.geometry;

  /// Whether the material may have elastic properties. See
  /// [TierProfile.elasticMotion].
  bool get elasticMotion => profile.elasticMotion;

  /// Whether the thermal channel has ever answered.
  ///
  /// False means unknown, which is not the same as [ThermalState.nominal] and
  /// must not be reported as it. A caller that wants to say "the device is
  /// running cool" has to check this first.
  bool get thermalIsKnown => thermal != null;

  /// Degrades [material] to what this tier allows.
  GlassMaterial materialFor(
    GlassMaterial material, {
    required Brightness brightness,
  }) => profile.applyTo(material, brightness: brightness);

  /// A one-line explanation, for diagnostics.
  String describe() {
    final thermalText = thermal?.name ?? 'unknown';
    final accessibilityText = accessibility.reduceTransparencyIsApproximated
        ? 'reduceTransparency=${accessibility.reduceTransparency}~'
        : 'reduceTransparency=${accessibility.reduceTransparency}';
    return 'glass tier ${tier.name} '
        '(requested: ${requested?.name ?? 'auto'}, '
        'capability: ${capabilityCeiling.name}, '
        'thermal: $thermalText -> ${thermalCeiling.name}, '
        'frames: ${frameHealth.name} -> -$frameSteps, '
        'accessibility: $accessibilityText '
        'increaseContrast=${accessibility.increaseContrast} '
        'reduceMotion=${accessibility.reduceMotion} '
        '-> ${accessibilityCeiling.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ResolvedTier &&
        other.tier == tier &&
        other.profile == profile &&
        other.capabilities == capabilities &&
        other.thermal == thermal &&
        other.frameHealth == frameHealth &&
        other.accessibility == accessibility &&
        other.capabilityCeiling == capabilityCeiling &&
        other.thermalCeiling == thermalCeiling &&
        other.accessibilityCeiling == accessibilityCeiling &&
        other.frameSteps == frameSteps &&
        other.requested == requested;
  }

  @override
  int get hashCode => Object.hash(
    tier,
    profile,
    capabilities,
    thermal,
    frameHealth,
    accessibility,
    capabilityCeiling,
    thermalCeiling,
    accessibilityCeiling,
    frameSteps,
    requested,
  );

  @override
  String toString() => describe();
}

/// Combines every tier input into one effective tier.
///
/// A pure function on purpose: the signals are stateful (the thermal reading
/// is sticky, the watchdog carries hysteresis), but the combination of them
/// is not, so it can be tested exhaustively without a device, a clock or a
/// widget tree.
///
/// The four inputs do not combine the same way, and the difference is not
/// arbitrary:
///
/// - **Capability, thermal and accessibility impose absolute ceilings.**
///   Each is a statement about the device or the user — "this backend cannot
///   run the shader", "this phone is too hot", "this person asked for less
///   glass" — and a statement like that is true regardless of what tier the
///   app happened to be at.
/// - **Frame health steps down relatively.** It is not a statement about the
///   device, it is a statement about the current workload: *whatever you are
///   doing is too much*. So it moves down from wherever the ceilings already
///   put us, rather than naming a floor of its own. On a device already held
///   at [GlassTier.reduced] by heat, a strained watchdog takes it to
///   [GlassTier.flat]; on a healthy device at [GlassTier.full] the same
///   verdict takes it to [GlassTier.balanced].
///
/// [requested] is the escape hatch, and it beats capability, thermal and
/// frame health — a caller that pins a tier gets it. It does **not** lift
/// accessibility, and that asymmetry is deliberate: Reduce Transparency and
/// Increase Contrast are correctness requirements, so a developer opting out
/// of them would be opting out on their users' behalf. Nor does it lift a
/// backend that cannot run the shader at all, which is not a preference
/// either.
ResolvedTier resolveTier({
  required RenderCapabilities capabilities,
  required ThermalState? thermal,
  required FrameHealth frameHealth,
  required AccessibilitySignals accessibility,
  GlassTier? requested,
}) {
  final capabilityCeiling = _capabilityCeiling(capabilities);
  final thermalCeiling = _thermalCeiling(thermal);
  final accessibilityCeiling = _accessibilityCeiling(accessibility);
  final frameSteps = _frameSteps(frameHealth);

  var tier = requested ?? GlassTier.full;
  if (requested == null) {
    tier = tier
        .clampedTo(capabilityCeiling)
        .clampedTo(thermalCeiling)
        .lowered(frameSteps);
  } else if (capabilityCeiling == GlassTier.off) {
    // The one ceiling an explicit request cannot lift: on Skia,
    // `ui.ImageFilter.shader` throws rather than running slowly, so honouring
    // the request would not produce worse glass, it would produce an
    // exception during paint.
    tier = GlassTier.off;
  }
  tier = tier.clampedTo(accessibilityCeiling);

  return ResolvedTier(
    tier: tier,
    profile: _applyAccessibility(tier.profile, accessibility),
    capabilities: capabilities,
    thermal: thermal,
    frameHealth: frameHealth,
    accessibility: accessibility,
    capabilityCeiling: capabilityCeiling,
    thermalCeiling: thermalCeiling,
    accessibilityCeiling: accessibilityCeiling,
    frameSteps: frameSteps,
    requested: requested,
  );
}

GlassTier _capabilityCeiling(RenderCapabilities capabilities) {
  if (!capabilities.shaderFilters) {
    // Skia. Not slow — incapable. `ui.ImageFilter.shader` throws here, so
    // every tier that would construct one is off the table.
    return GlassTier.off;
  }
  if (capabilities.complete && !capabilities.acceleratedGeometry) {
    return GlassTier.balanced;
  }
  // While the probe is still running, `acceleratedGeometry` is a pessimistic
  // default rather than a measurement, and clamping on it would start every
  // app one rung low and then visibly climb. Nothing breaks by staying at
  // `full` in the meantime: `ProducerRegistry.select` falls through to the
  // runtime producer on its own when the accelerated one cannot run.
  return GlassTier.full;
}

GlassTier _thermalCeiling(ThermalState? thermal) {
  switch (thermal) {
    case null:
    // Unknown imposes no ceiling: Windows, Linux, web and Android below API
    // 29 have no thermal API at all, and punishing them for the platform's
    // silence would degrade glass on machines that are perfectly cool. What
    // unknown must never do is *report* as nominal — see
    // [ResolvedTier.thermalIsKnown] — and it must never lift a ceiling a
    // real reading already imposed, which `ThermalSignal` guarantees by
    // refusing to move its value back to null.
    case ThermalState.nominal:
      return GlassTier.full;
    case ThermalState.fair:
      // Fair is common, transient, and reached by ordinary use. Degrading
      // here would make the tier flicker on a phone that is merely awake.
      return GlassTier.full;
    case ThermalState.serious:
      return GlassTier.reduced;
    case ThermalState.critical:
      return GlassTier.flat;
  }
}

GlassTier _accessibilityCeiling(AccessibilitySignals accessibility) {
  if (accessibility.reduceTransparency || accessibility.increaseContrast) {
    // Both settings remove lensing, and lensing is what every rung above
    // `flat` exists to provide. Pinning the rung as well as the profile
    // keeps the reported tier honest about what is on screen.
    return GlassTier.flat;
  }
  return GlassTier.full;
}

int _frameSteps(FrameHealth health) {
  switch (health) {
    case FrameHealth.healthy:
      return 0;
    case FrameHealth.strained:
      return 1;
    case FrameHealth.saturated:
      return 2;
  }
}

/// Applies the accessibility overlay to a rung's profile.
///
/// Apple's contract, verbatim, is what each branch implements. Reduce
/// Transparency "makes Liquid Glass frostier and obscures more of the content
/// behind it": more blur, more opacity, no lensing. Increase Contrast "makes
/// elements predominantly black or white and highlights them with a
/// contrasting border": a monochrome tint at near-full opacity plus a strong
/// contour, and no speculars to soften it. Reduce Motion "disables any
/// elastic properties for the material": the motion flag, and nothing
/// optical — claims that it also eliminates lensing go beyond what Apple
/// says.
TierProfile _applyAccessibility(
  TierProfile profile,
  AccessibilitySignals accessibility,
) {
  var result = profile;

  if (accessibility.reduceTransparency) {
    result = result.copyWith(
      // The accelerated geometry pass exists to bake a refraction band. With
      // no band to bake, it is a whole render pass producing a coverage mask
      // the portable producer makes just as well — which is what the spec
      // means by Reduce Transparency pinning the static tier.
      geometry: result.geometry == GeometryTier.accelerated
          ? GeometryTier.portable
          : result.geometry,
      refractionScale: 0,
      chromaticAberration: false,
      blurScale: math.max(result.blurScale, 1),
      minimumFrost: math.max(result.minimumFrost, 24),
      minimumTintOpacity: math.max(result.minimumTintOpacity, 0.85),
    );
  }

  if (accessibility.increaseContrast) {
    result = result.copyWith(
      refractionScale: 0,
      chromaticAberration: false,
      specularScale: 0,
      monochromeTint: true,
      minimumTintOpacity: math.max(result.minimumTintOpacity, 0.95),
      minimumContour: math.max(result.minimumContour, 0.6),
    );
  }

  if (accessibility.reduceMotion) {
    result = result.copyWith(elasticMotion: false);
  }

  return result;
}
