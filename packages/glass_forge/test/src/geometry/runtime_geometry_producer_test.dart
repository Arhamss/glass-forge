import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

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

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('produces a generation stamped with the scene revision', () {
    final producer = RuntimeGeometryProducer();
    final scene = _sceneWithOneShape();

    final generation = producer.produce(scene, _request)!;
    expect(generation.sceneRevision, scene.revision);

    producer
      ..release(generation)
      ..dispose();
  });

  test('never hands back the same texture twice', () {
    // The invariant: a new generation per change, because a submitted scene
    // may still be sampling the previous one.
    final producer = RuntimeGeometryProducer();
    final scene = _sceneWithOneShape();

    final first = producer.produce(scene, _request)!;
    scene.register(
      'b',
      ShapeGeometry.resolve(
        shape: const GlassOval(),
        size: const Size(20, 20),
        toLayer: Matrix4.translationValues(60, 0, 0),
        devicePixelRatio: 1,
      ),
    );
    final second = producer.produce(scene, _request)!;

    expect(identical(first.texture, second.texture), isFalse);

    producer
      ..release(first)
      ..release(second)
      ..dispose();
  });

  test('returns null for an empty scene rather than a zero-size texture', () {
    // toImageSync on zero-size bounds crashes; upstream issues #149 and #131
    // are both that crash, reported from production.
    final producer = RuntimeGeometryProducer();
    expect(producer.produce(GlassScene(), _request), isNull);
    producer.dispose();
  });

  test('buckets its texture allocation', () {
    final producer = RuntimeGeometryProducer();
    final generation = producer.produce(_sceneWithOneShape(), _request)!;

    expect(generation.texture.width % 64, 0);
    expect(generation.texture.height % 64, 0);

    producer
      ..release(generation)
      ..dispose();
  });

  test('reports itself available', () {
    final producer = RuntimeGeometryProducer();
    expect(producer.capabilities.available, isTrue);
    producer.dispose();
  });
}
