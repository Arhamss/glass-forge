import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:glass_forge/src/tier/glass_tier_engine.dart';
import 'package:glass_forge/src/tier/glass_tier_scope.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';
import 'package:glass_forge/src/tier/thermal_state.dart';
import 'package:glass_forge/src/tier/tier_profile.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _capable = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.metal,
  acceleratedGeometry: true,
  complete: true,
);

/// A platform that answers nothing, so the engine's tier comes only from
/// what each test pins or reports.
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

GlassTierEngine _engine({GlassTier? requested}) {
  final platform = _SilentPlatform();
  return GlassTierEngine(
    requested: requested,
    thermal: ThermalSignal(platform: platform),
    accessibility: AccessibilitySignalSource(
      platform: platform,
      features: () => const FakeAccessibilityFeatures(),
    ),
    capabilities: _capable,
  );
}

/// Mounts [layer] without ever painting it.
///
/// `Offstage` keeps the composite pass from running, and the composite pass
/// is the one part of this package that needs Impeller —
/// `ui.ImageFilter.shader` throws on `flutter_tester`'s software backend.
/// Everything these tests assert about is decided during build and update,
/// so paying for a whole Impeller test lane to reach it would buy nothing.
Future<void> _mount(WidgetTester tester, Widget layer) {
  return tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Offstage(child: layer),
    ),
  );
}

// `skipOffstage: false` because [_mount] deliberately puts the layer
// offstage; the widgets are built and updated exactly as they would be
// onstage, they simply never paint.
RenderGlassLayer _renderLayer(WidgetTester tester) {
  return tester.renderObject<RenderGlassLayer>(
    find.byType(GlassLayer, skipOffstage: false),
  );
}

GlassMaterial _scopedMaterial(WidgetTester tester) {
  return tester
      .widget<GlassLayerScope>(
        find.byType(GlassLayerScope, skipOffstage: false),
      )
      .material;
}

void main() {
  // Pinned so these tests describe one device rather than whatever backend
  // `flutter_tester` happened to bind — on the software backend the real
  // probe reports no shader filters, which correctly resolves every tier to
  // `off` and would say nothing about adoption.
  setUp(() => RenderCapabilityProbe.debugOverride = _capable);
  tearDown(() => RenderCapabilityProbe.debugOverride = null);
  testWidgets('a layer with no scope keeps the accelerated default', (
    tester,
  ) async {
    await _mount(
      tester,
      const GlassLayer(child: SizedBox(width: 10, height: 10)),
    );

    // Tiering is opt-in. An app that never wrapped itself in a scope must
    // behave exactly as it did before the tier engine existed.
    expect(_renderLayer(tester).tier, GeometryTier.accelerated);
  });

  testWidgets('a layer under a scope adopts the resolved producer', (
    tester,
  ) async {
    final engine = _engine(requested: GlassTier.flat);
    addTearDown(engine.dispose);

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: const GlassLayer(child: SizedBox(width: 10, height: 10)),
      ),
    );

    expect(_renderLayer(tester).tier, GeometryTier.portable);
  });

  testWidgets('a layer under an off scope bakes no matte at all', (
    tester,
  ) async {
    final engine = _engine(requested: GlassTier.off);
    addTearDown(engine.dispose);

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: const GlassLayer(child: SizedBox(width: 10, height: 10)),
      ),
    );

    expect(_renderLayer(tester).tier, GeometryTier.none);
    expect(_scopedMaterial(tester).rendersAnything, isFalse);
  });

  testWidgets('an explicit tier on the layer wins over the scope', (
    tester,
  ) async {
    final engine = _engine(requested: GlassTier.off);
    addTearDown(engine.dispose);

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: const GlassLayer(
          tier: GeometryTier.accelerated,
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    );

    // The manual escape hatch, unchanged: a surface whose cost is known can
    // still pin its own producer.
    expect(_renderLayer(tester).tier, GeometryTier.accelerated);
  });

  testWidgets('a pinned tier does not opt the layer out of accessibility', (
    tester,
  ) async {
    final platform = _SilentPlatform();
    final engine = GlassTierEngine(
      thermal: ThermalSignal(platform: platform),
      accessibility: AccessibilitySignalSource(
        platform: platform,
        features: () => const FakeAccessibilityFeatures(highContrast: true),
      ),
      capabilities: _capable,
    );
    addTearDown(engine.dispose);
    await engine.accessibility.start();

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: GlassLayer(
          tier: GeometryTier.accelerated,
          material: GlassMaterial.regular(brightness: Brightness.light),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    // The producer is pinned, as asked. The material is not: Increase
    // Contrast is a correctness requirement, and a developer pinning a tier
    // would be opting out of it on their users' behalf.
    expect(_renderLayer(tester).tier, GeometryTier.accelerated);
    expect(_scopedMaterial(tester).contour, greaterThanOrEqualTo(0.6));
    expect(_scopedMaterial(tester).edgeRefraction, 0);
  });

  testWidgets('the material a layer renders is degraded by the scope', (
    tester,
  ) async {
    final engine = _engine(requested: GlassTier.reduced);
    addTearDown(engine.dispose);
    final material = GlassMaterial.regular(brightness: Brightness.dark);

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: GlassLayer(
          material: material,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    expect(
      _scopedMaterial(tester).edgeRefraction,
      material.edgeRefraction * 0.5,
    );
  });

  testWidgets('a live downgrade reaches the render object', (tester) async {
    final engine = _engine();
    addTearDown(engine.dispose);

    await _mount(
      tester,
      GlassTierScope(
        engine: engine,
        child: const GlassLayer(child: SizedBox(width: 10, height: 10)),
      ),
    );
    expect(_renderLayer(tester).tier, GeometryTier.accelerated);

    engine.thermal.debugReport(ThermalState.critical);
    await tester.pump();

    // Nothing rebuilt the widget tree — the same GlassLayer instance is
    // still mounted. A tier that could only be chosen at construction would
    // leave this render object on the accelerated producer for the rest of
    // the session, which makes every downgrade the engine resolves invisible
    // to the thing that renders.
    expect(_renderLayer(tester).tier, GeometryTier.portable);
  });

  testWidgets('a scope with no engine of its own still resolves a tier', (
    tester,
  ) async {
    await _mount(
      tester,
      const GlassTierScope(
        requested: GlassTier.reduced,
        child: GlassLayer(child: SizedBox(width: 10, height: 10)),
      ),
    );

    expect(_renderLayer(tester).tier, GeometryTier.portable);
  });

  testWidgets('of() explains itself when there is no scope', (tester) async {
    late BuildContext captured;
    await _mount(
      tester,
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );

    expect(GlassTierScope.maybeOf(captured), isNull);
    expect(() => GlassTierScope.of(captured), throwsFlutterError);
  });
}
