import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/tier/render_capabilities.dart';

/// A producer that answers a capability question and does nothing else.
class _FakeProducer implements GeometryProducer {
  _FakeProducer({required this.available, required this.name});

  final bool available;
  final String name;

  @override
  GeometryCapabilities get capabilities =>
      GeometryCapabilities(available: available, name: name);

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

GeometryProducer _availableProducer() =>
    _FakeProducer(available: true, name: 'fake-accelerated');

GeometryProducer _unavailableProducer() =>
    _FakeProducer(available: false, name: 'fake-unavailable');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RenderCapabilityProbe.debugReset();
    ProducerRegistry.debugReset();
  });
  tearDown(() {
    RenderCapabilityProbe.debugReset();
    ProducerRegistry.debugReset();
  });

  test('the synchronous answer is pessimistic about what it cannot see', () {
    final immediate = RenderCapabilities.immediate();

    // Both of these need something the constructor cannot have: a pixel read
    // back off the GPU, and (on Android) a surface frame that has already
    // been drawn. Guessing optimistically would mean a device briefly
    // claiming an accelerated producer it does not have.
    expect(immediate.complete, isFalse);
    expect(immediate.backend, GraphicsBackend.unknown);
    expect(immediate.acceleratedGeometry, isFalse);
  });

  test('measures once and hands the same answer back afterwards', () async {
    expect(RenderCapabilityProbe.isMeasured, isFalse);

    final first = await RenderCapabilityProbe.run();

    expect(RenderCapabilityProbe.isMeasured, isTrue);
    // Caching is correctness, not speed: the backend probe costs an offscreen
    // draw and a GPU fence, and the answer cannot change while the process
    // lives.
    expect(identical(await RenderCapabilityProbe.run(), first), isTrue);
    expect(RenderCapabilityProbe.immediate, first);
  });

  test(
    'a backend without shader filters is reported as Skia, unprobed',
    () async {
      // `flutter_tester`'s default software backend. The probe must not pay
      // for a GPU read to distinguish GLES from Vulkan on a backend where
      // `ui.ImageFilter.shader` does not run at all.
      expect(ui.ImageFilter.isShaderFilterSupported, isFalse);

      final measured = await RenderCapabilityProbe.run();

      expect(measured.shaderFilters, isFalse);
      expect(measured.backend, GraphicsBackend.skia);
      expect(measured.complete, isTrue);
    },
  );

  test(
    'an Impeller backend is identified, not left unknown',
    () async {
      final measured = await RenderCapabilityProbe.run();

      expect(measured.shaderFilters, isTrue);
      // Whichever it is, the probe has to commit: `unknown` here would mean
      // the pixel read failed, and the tier engine would lose the GLES
      // signal it uses to keep older Android devices off the top rung.
      expect(measured.backend, isNot(GraphicsBackend.unknown));
      expect(measured.backend, isNot(GraphicsBackend.skia));
    },
    tags: <String>['impeller'],
  );

  test('an override replaces measurement entirely', () async {
    const pinned = RenderCapabilities(
      shaderFilters: true,
      backend: GraphicsBackend.vulkan,
      acceleratedGeometry: true,
      complete: true,
    );
    RenderCapabilityProbe.debugOverride = pinned;

    expect(RenderCapabilityProbe.immediate, pinned);
    expect(await RenderCapabilityProbe.run(), pinned);
  });

  group('ProducerRegistry.probeAccelerated', () {
    test('registers the shipped producers before answering', () {
      expect(ProducerRegistry.debugAcceleratedCount, 0);

      ProducerRegistry.probeAccelerated();

      // The tier engine can run before any GlassLayer exists. A probe that
      // reported "no accelerated producer" purely because nothing had built
      // a layer yet would pin the device a rung low for the whole session.
      expect(ProducerRegistry.debugAcceleratedCount, greaterThan(0));
    });

    test('answers null when no registered producer can run here', () {
      // Flutter GPU needs an Impeller context, which the software backend
      // does not have.
      expect(ProducerRegistry.probeAccelerated(), isNull);
    });

    test('names the producer that can run', () {
      ProducerRegistry.debugReset();
      ProducerRegistry.registerAccelerated(_availableProducer);

      expect(ProducerRegistry.probeAccelerated(), 'fake-accelerated');
    });

    test('skips a producer that reports itself unavailable', () {
      ProducerRegistry.debugReset();
      ProducerRegistry.registerAccelerated(_unavailableProducer);
      ProducerRegistry.registerAccelerated(_availableProducer);

      expect(ProducerRegistry.probeAccelerated(), 'fake-accelerated');
    });
  });
}
