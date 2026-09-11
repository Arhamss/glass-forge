import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:glass_forge/src/tier/frame_watchdog.dart';
import 'package:glass_forge/src/tier/glass_tier_engine.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _capable = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.metal,
  acceleratedGeometry: true,
  complete: true,
);

/// A platform that says nothing, so every signal starts at its unknown or
/// off value and the tests drive them explicitly.
class _SilentPlatform extends GlassForgePlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<bool?> isReduceTransparencyEnabled() async => null;

  @override
  Stream<bool> reduceTransparencyChanges() => const Stream<bool>.empty();

  @override
  Future<ThermalState?> getThermalState() async => null;

  @override
  Stream<ThermalState> thermalStateChanges() =>
      const Stream<ThermalState>.empty();
}

ui.FrameTiming _frame(int rasterMicros) {
  return ui.FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: 1000,
    rasterStart: 1000,
    rasterFinish: 1000 + rasterMicros,
    rasterFinishWallTime: 1000 + rasterMicros,
  );
}

/// An engine wired entirely to injected signals, so nothing here depends on a
/// device, a clock or a real frame.
({
  GlassTierEngine engine,
  FrameWatchdog watchdog,
  ThermalSignal thermal,
  AccessibilitySignalSource accessibility,
}) _build({GlassTier? requested}) {
  final platform = _SilentPlatform();
  final watchdog = FrameWatchdog(
    frameBudget: const Duration(microseconds: 16667),
    windowFrames: 100,
    recoveryFrames: 20,
  );
  final thermal = ThermalSignal(platform: platform);
  final accessibility = AccessibilitySignalSource(
    platform: platform,
    features: () => const FakeAccessibilityFeatures(),
  );
  final engine = GlassTierEngine(
    requested: requested,
    watchdog: watchdog,
    thermal: thermal,
    accessibility: accessibility,
    capabilities: _capable,
  );
  return (
    engine: engine,
    watchdog: watchdog,
    thermal: thermal,
    accessibility: accessibility,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('publishes a usable tier before anything has started', () {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    // Every signal's initial value is already valid — unknown thermal,
    // healthy frames, whatever bitmask the engine already has — so the first
    // frame renders a real tier instead of waiting on a platform channel.
    expect(parts.engine.value.tier, GlassTier.full);
  });

  test('a thermal reading moves the published tier', () {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);
    var notifications = 0;
    parts.engine.addListener(() => notifications++);

    parts.thermal.debugReport(ThermalState.serious);

    expect(parts.engine.value.tier, GlassTier.reduced);
    expect(notifications, 1);
  });

  test('a watchdog downgrade moves the published tier', () {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    parts.watchdog.recordTimings(
      List<ui.FrameTiming>.filled(100, _frame(40000)),
    );

    expect(parts.engine.value.frameHealth, FrameHealth.saturated);
    expect(parts.engine.value.tier, GlassTier.reduced);
  });

  test('an accessibility change moves the published tier', () async {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    parts.accessibility.debugReportReduceTransparency(enabled: true);

    expect(parts.engine.value.tier, GlassTier.flat);
    expect(parts.engine.value.profile.refractionScale, 0);
  });

  test('publishes fresh evidence even when the verdict does not move', () {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    // Nominal and fair both leave the tier at full, but a host reading the
    // engine for diagnostics still needs to see that the device warmed up.
    // Keeping glass layers from rebuilding over it is GlassTierScope's job.
    parts.thermal
      ..debugReport(ThermalState.nominal)
      ..debugReport(ThermalState.fair);

    expect(parts.engine.value.tier, GlassTier.full);
    expect(parts.engine.value.thermal, ThermalState.fair);
    expect(parts.engine.value.profile, GlassTier.full.profile);
  });

  test('pinning a tier republishes immediately', () {
    final parts = _build();
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);
    parts.thermal.debugReport(ThermalState.critical);
    expect(parts.engine.value.tier, GlassTier.flat);

    parts.engine.requested = GlassTier.full;

    expect(parts.engine.value.tier, GlassTier.full);
    expect(parts.engine.value.requested, GlassTier.full);
  });

  test('an engine built with a pin starts pinned', () {
    final parts = _build(requested: GlassTier.reduced);
    addTearDown(parts.engine.dispose);
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    expect(parts.engine.value.tier, GlassTier.reduced);
  });

  test('leaves injected signals alive when it is disposed', () {
    final parts = _build();
    addTearDown(parts.watchdog.dispose);
    addTearDown(parts.thermal.dispose);
    addTearDown(parts.accessibility.dispose);

    parts.engine.dispose();

    // A disposed ChangeNotifier throws on addListener. Injected signals
    // belong to whoever made them — usually a test fixture or an app-level
    // host — and an engine that tore them down would take the fixture with
    // it.
    expect(() => parts.watchdog.addListener(() {}), returnsNormally);
    expect(() => parts.thermal.addListener(() {}), returnsNormally);
    expect(() => parts.accessibility.addListener(() {}), returnsNormally);
  });

  test('disposes the signals it created itself', () {
    final engine = GlassTierEngine(capabilities: _capable);
    final watchdog = engine.watchdog;

    engine.dispose();

    expect(() => watchdog.addListener(() {}), throwsFlutterError);
  });
}
