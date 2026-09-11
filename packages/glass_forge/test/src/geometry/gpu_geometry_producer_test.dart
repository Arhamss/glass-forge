import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/gpu_geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

/// A minimal accelerated producer that always reports itself unavailable, so
/// [ProducerRegistry] must skip past it to the runtime producer.
class _UnavailableProducer implements GeometryProducer {
  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: false, name: 'unavailable');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) => null;

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

GlassScene _sceneWithOneShape() {
  return GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(8)),
        ),
        size: const Size(100, 40),
        toLayer: Matrix4.identity(),
        devicePixelRatio: 1,
      ),
    );
}

Future<Uint8List> _rgbaBytes(ui.Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(ProducerRegistry.debugReset);

  test('reports unavailability rather than throwing', () {
    // Flutter GPU is unavailable on Skia, on older Flutter, and when its
    // shader bundle did not build. All three are normal answers.
    final producer = GpuGeometryProducer();
    expect(() => producer.capabilities.available, returnsNormally);
    producer.dispose();
  });

  test('an unavailable accelerated producer falls through to runtime', () {
    ProducerRegistry.registerAccelerated(_UnavailableProducer.new);

    final selected = ProducerRegistry.select(tier: GeometryTier.accelerated);
    expect(selected, isA<RuntimeGeometryProducer>());
    selected.dispose();
  });

  test('produce returns null when unavailable, never throws', () {
    // A build that cannot use the fast path must still render.
    final producer = GpuGeometryProducer();
    if (!producer.capabilities.available) {
      expect(producer.produce(GlassScene(), _request), isNull);
    }
    producer.dispose();
  });

  test(
    'capabilities.available is corrected to false once warmUp discovers '
    'the shader bundle cannot load, not left permanently true from the '
    'context probe alone (regression: C3 -- claiming availability it does '
    'not have)',
    () async {
      // debugBundleAssetKeys points at a key that can never resolve, so this
      // exercises the real ShaderLibrary.fromAsset failure path -- not a
      // stand-in for it -- deterministically, without needing an
      // actually-broken build.
      final producer = GpuGeometryProducer(
        debugBundleAssetKeys: const [
          'packages/glass_forge/does/not/exist.shaderbundle',
        ],
      );
      if (!producer.capabilities.available) {
        // Flutter GPU's own backend is unavailable here (this environment
        // was not run with --enable-flutter-gpu), so the bundle-load path
        // this test targets never starts. A legitimate outcome -- see
        // dart_test.yaml's `impeller` tag and task-18-fix-report.md.
        producer.dispose();
        return;
      }

      // The context probe alone says available -- the honest, but
      // provisional, first-stage answer.
      expect(producer.capabilities.available, isTrue);

      await producer.warmUp();

      // warmUp() tried to load the (deliberately bogus) bundle, failed, and
      // must have corrected the answer rather than leaving it stuck at the
      // provisional `true`.
      expect(producer.capabilities.available, isFalse);
      producer.dispose();
    },
    tags: ['impeller'],
  );

  group('cross-producer matte parity (acceptance criterion 8)', () {
    // Requires a real Impeller/GPU backend, which flutter_tester's default
    // software backend does not provide -- see dart_test.yaml's `impeller`
    // tag. Run with
    // `flutter test --tags impeller --run-skipped --enable-impeller`.
    setUpAll(() async {
      GpuGeometryProducer.register();
      await ShaderLibrary.instance.warmUp();
    });
    tearDownAll(ShaderLibrary.instance.disposeAll);

    test(
      'accelerated and portable tiers bake pixel-identical mattes',
      () async {
        final scene = _sceneWithOneShape();

        final accelerated = ProducerRegistry.select(
          tier: GeometryTier.accelerated,
        );
        await accelerated.warmUp();

        if (accelerated is! GpuGeometryProducer ||
            !accelerated.capabilities.available) {
          // A legitimate outcome, not a failure: this environment cannot run
          // the Flutter GPU path, so the accelerated tier already fell back
          // to the runtime producer before selection reached this test. See
          // task-18-report.md for what this environment actually showed.
          accelerated.dispose();
          markTestSkipped(
            'GeometryTier.accelerated resolved to '
            '${accelerated.runtimeType}, not GpuGeometryProducer with a '
            'usable GPU context -- the render pass this test exists to '
            'check never ran.',
          );
          return;
        }

        final portable = ProducerRegistry.select(tier: GeometryTier.portable);
        await portable.warmUp();
        addTearDown(portable.dispose);
        addTearDown(accelerated.dispose);

        final acceleratedGeneration = accelerated.produce(scene, _request);
        final portableGeneration = portable.produce(scene, _request);
        expect(acceleratedGeneration, isNotNull);
        expect(portableGeneration, isNotNull);
        addTearDown(() => accelerated.release(acceleratedGeneration!));
        addTearDown(() => portable.release(portableGeneration!));

        expect(
          acceleratedGeneration!.texture.width,
          portableGeneration!.texture.width,
        );
        expect(
          acceleratedGeneration.texture.height,
          portableGeneration.texture.height,
        );

        final acceleratedBytes = await _rgbaBytes(
          acceleratedGeneration.texture,
        );
        final portableBytes = await _rgbaBytes(portableGeneration.texture);
        expect(acceleratedBytes.length, portableBytes.length);

        var maxDelta = 0;
        for (var i = 0; i < acceleratedBytes.length; i++) {
          final delta = (acceleratedBytes[i] - portableBytes[i]).abs();
          if (delta > maxDelta) {
            maxDelta = delta;
          }
        }
        // A couple of code points of float-rounding slack between two
        // independently-executed GPU pipelines evaluating the same SDF;
        // anything larger means the two producers have actually diverged.
        expect(maxDelta, lessThanOrEqualTo(2));
      },
      tags: ['impeller'],
    );
  });
}
