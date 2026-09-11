import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_workbench/features/tiers/presentation/cubit/tier_cubit.dart';

const _healthyDevice = RenderCapabilities(
  shaderFilters: true,
  backend: GraphicsBackend.metal,
  acceleratedGeometry: true,
  complete: true,
);

const _skiaDevice = RenderCapabilities(
  shaderFilters: false,
  backend: GraphicsBackend.skia,
  acceleratedGeometry: false,
  complete: true,
);

TierCubit _cubitFor(RenderCapabilities capabilities) {
  final engine = GlassTierEngine(capabilities: capabilities);
  final cubit = TierCubit(engine: engine);
  addTearDown(() async {
    await cubit.close();
    engine.dispose();
  });
  return cubit;
}

void main() {
  // The accessibility signal reads the engine's accessibility bitmask
  // through the binding, so there has to be one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TierCubit', () {
    test('a healthy device with nothing pinned runs at full', () {
      final cubit = _cubitFor(_healthyDevice);

      expect(cubit.state.resolved.tier, GlassTier.full);
      expect(cubit.state.requested, isNull);
      expect(cubit.state.isPinHeld, isFalse);
    });

    test('a pinned tier overrides the one the engine resolved', () {
      final cubit = _cubitFor(_healthyDevice)..forceTier(GlassTier.flat);

      expect(cubit.state.resolved.tier, GlassTier.flat);
      expect(cubit.state.requested, GlassTier.flat);
      expect(cubit.state.isPinHeld, isFalse);
    });

    test('clearing the pin hands the decision back to the engine', () {
      final cubit = _cubitFor(_healthyDevice)
        ..forceTier(GlassTier.flat)
        ..forceTier(null);

      expect(cubit.state.resolved.tier, GlassTier.full);
      expect(cubit.state.requested, isNull);
    });

    test('a pin lifts a thermal ceiling, because heat is not a '
        'requirement', () {
      final cubit = _cubitFor(_healthyDevice);
      cubit.engine.thermal.debugReport(ThermalState.critical);
      expect(cubit.state.resolved.tier, GlassTier.flat);

      cubit.forceTier(GlassTier.full);

      expect(cubit.state.resolved.tier, GlassTier.full);
      expect(cubit.state.isPinHeld, isFalse);
    });

    test('a pin does not lift Reduce Transparency', () {
      final cubit = _cubitFor(_healthyDevice);
      cubit.engine.accessibility.debugReportReduceTransparency(enabled: true);
      expect(cubit.state.resolved.tier, GlassTier.flat);

      cubit.forceTier(GlassTier.full);

      expect(cubit.state.resolved.tier, GlassTier.flat);
      expect(cubit.state.requested, GlassTier.full);
      expect(
        cubit.state.isPinHeld,
        isTrue,
        reason: 'the screen has to be able to say the pin was not honoured',
      );
    });

    test('a pin does not lift a backend that cannot run the shader', () {
      final cubit = _cubitFor(_skiaDevice)..forceTier(GlassTier.full);

      expect(cubit.state.resolved.tier, GlassTier.off);
      expect(cubit.state.isPinHeld, isTrue);
    });
  });

  group('TierState.outcomeFor', () {
    test('reports where each rung would land before you tap it', () {
      final cubit = _cubitFor(_healthyDevice);
      cubit.engine.accessibility.debugReportReduceTransparency(enabled: true);

      final state = cubit.state;

      expect(state.outcomeFor(GlassTier.full), GlassTier.flat);
      expect(state.outcomeFor(GlassTier.balanced), GlassTier.flat);
      expect(state.outcomeFor(GlassTier.flat), GlassTier.flat);
      expect(state.outcomeFor(GlassTier.off), GlassTier.off);
    });

    test('leaves every rung reachable on a healthy device', () {
      final state = _cubitFor(_healthyDevice).state;

      for (final tier in GlassTier.values) {
        expect(state.outcomeFor(tier), tier, reason: tier.name);
      }
    });
  });
}
