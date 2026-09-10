import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/null_geometry_producer.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

/// A producer that reports itself unavailable and records whether the
/// registry disposed it, without doing any real work.
class _UnavailableFakeProducer implements GeometryProducer {
  bool disposed = false;

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: false, name: 'fake');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  setUp(ProducerRegistry.debugReset);
  tearDown(ProducerRegistry.debugReset);

  test('portable tier returns a runtime producer', () {
    final producer = ProducerRegistry.select(tier: GeometryTier.portable);
    expect(producer, isA<RuntimeGeometryProducer>());
  });

  test('none tier returns a null producer that produces nothing', () {
    final producer = ProducerRegistry.select(tier: GeometryTier.none);
    expect(producer, isA<NullGeometryProducer>());
    expect(producer.produce(GlassScene(), _request), isNull);
  });

  test(
    'accelerated tier falls through to the runtime producer when nothing '
    'is registered',
    () {
      final producer = ProducerRegistry.select(tier: GeometryTier.accelerated);
      expect(producer, isA<RuntimeGeometryProducer>());
    },
  );

  test(
    'accelerated tier disposes an unavailable candidate and falls through',
    () {
      final fake = _UnavailableFakeProducer();
      ProducerRegistry.registerAccelerated(() => fake);

      final producer = ProducerRegistry.select(tier: GeometryTier.accelerated);

      expect(fake.disposed, isTrue);
      expect(producer, isA<RuntimeGeometryProducer>());
    },
  );

  test('debugReset clears registrations', () {
    ProducerRegistry.registerAccelerated(_UnavailableFakeProducer.new);
    ProducerRegistry.debugReset();

    // With the registration cleared, selection has nothing to try and no
    // candidate to dispose — it falls straight to the runtime producer, the
    // same outcome as if nothing had ever been registered.
    final producer = ProducerRegistry.select(tier: GeometryTier.accelerated);
    expect(producer, isA<RuntimeGeometryProducer>());
  });
}
