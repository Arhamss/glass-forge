// Needs a real Impeller backend to read a baked matte back, and the Flutter
// GPU half needs --enable-flutter-gpu as well. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller
// --enable-flutter-gpu test/src/geometry/`.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/gpu_geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/geometry/shape_clusters.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

const _request = MatteRequest(
  devicePixelRatio: 1,
  maxDisplacement: 32,
  edgeRefraction: 27.42,
  refractionSpread: 0,
  antialiasWidth: 0.5,
);

const double _size = 40;
const double _pitch = 140;
const int _columns = 4;
const int _count = 12;

/// The top-left corner of oval [i], on a four-wide grid.
///
/// A grid rather than a row so each cluster's clip is offset on both axes:
/// a scissor with its y flipped, or its axes swapped, would draw the wrong
/// texels and the equivalence test below would see it.
Offset _cornerOf(int i) =>
    Offset((i % _columns) * _pitch + 13, (i ~/ _columns) * _pitch + 7);

Offset _centreOf(int i) => _cornerOf(i) + const Offset(_size / 2, _size / 2);

ShapeGeometry _oval(int i) => ShapeGeometry.resolve(
  shape: const GlassOval(),
  size: const Size(_size, _size),
  toLayer: Matrix4.translationValues(_cornerOf(i).dx, _cornerOf(i).dy, 0),
  devicePixelRatio: 1,
  // Ungrouped, as RenderGlassShape registers a shape outside any group.
  blendMarker: encodeBlendMarker(startsGroup: true, blend: 0),
);

GlassScene _scene(Iterable<int> ovals) {
  final scene = GlassScene();
  for (final i in ovals) {
    scene.register(i, _oval(i));
  }
  return scene;
}

/// A Control-Centre tile grid: twelve 60 px rounded squares, four wide, with
/// 12 px gaps -- dense enough that padding clusters by the displacement
/// reach merged every tile into one cluster and dropped the last four.
const double _tile = 60;
const double _gap = 12;

Rect _tileRect(int i) => Rect.fromLTWH(
  (i % _columns) * (_tile + _gap) + 13,
  (i ~/ _columns) * (_tile + _gap) + 7,
  _tile,
  _tile,
);

ShapeGeometry _tileShape(int i) => ShapeGeometry.resolve(
  shape: const GlassRoundedRectangle(
    radius: BorderRadius.all(Radius.circular(16)),
  ),
  size: const Size(_tile, _tile),
  toLayer: Matrix4.translationValues(
    _tileRect(i).left,
    _tileRect(i).top,
    0,
  ),
  devicePixelRatio: 1,
  blendMarker: encodeBlendMarker(startsGroup: true, blend: 0),
);

GlassScene _tiles(Iterable<int> tiles) {
  final scene = GlassScene();
  for (final i in tiles) {
    scene.register(i, _tileShape(i));
  }
  return scene;
}

/// A baked matte read back to the CPU, addressed in layer space.
class _Baked {
  _Baked(this.pixels, this.generation);

  final ByteData pixels;
  final MatteGeneration generation;

  int get _width => generation.texture.width;

  bool contains(Offset layerPoint) =>
      generation.bounds.contains(layerPoint + const Offset(0.5, 0.5));

  List<int> bytesAt(Offset layerPoint) {
    final px = (layerPoint.dx - generation.bounds.left).floor();
    final py = (layerPoint.dy - generation.bounds.top).floor();
    final base = (py * _width + px) * 4;
    return <int>[for (var c = 0; c < 4; c++) pixels.getUint8(base + c)];
  }

  double signedDistanceAt(Offset layerPoint) {
    final bytes = bytesAt(layerPoint);
    return generation.codec
        .decode(Float32List.fromList(<double>[for (final b in bytes) b / 255]))
        .signedDistance;
  }
}

Future<_Baked> _bake(GeometryProducer producer, GlassScene scene) async {
  final generation = producer.produce(scene, _request);
  expect(generation, isNotNull);
  addTearDown(() => producer.release(generation!));
  final pixels = (await generation!.texture.toByteData())!;
  return _Baked(pixels, generation);
}

/// The Flutter GPU producer, or null when this environment cannot run it.
Future<GeometryProducer?> _gpuProducer() async {
  GpuGeometryProducer.register();
  final producer = ProducerRegistry.select(tier: GeometryTier.accelerated);
  await producer.warmUp();
  if (producer is! GpuGeometryProducer || !producer.capabilities.available) {
    producer.dispose();
    return null;
  }
  addTearDown(producer.dispose);
  return producer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);
  tearDown(ProducerRegistry.debugReset);

  test('the scene really is twelve clusters, past the per-draw cap', () {
    // Guards the premise of every test below: were these ovals one cluster,
    // they would exercise the single-draw path and prove nothing.
    final clusters = clusterShapes(
      _scene(List<int>.generate(_count, (i) => i)).shapes,
      padding: clusterPadding(_request),
    );
    expect(clusters, hasLength(_count));
    expect(_count, greaterThan(kMaxShapes));
  });

  Future<void> expectTwelveOvals(GeometryProducer producer) async {
    final baked = await _bake(
      producer,
      _scene(List<int>.generate(_count, (i) => i)),
    );

    // The twelfth oval, four past the cap, is glass at its centre. A single
    // draw of kMaxShapes never wrote it.
    for (var i = 0; i < _count; i++) {
      expect(
        baked.signedDistanceAt(_centreOf(i)),
        lessThan(0),
        reason: 'oval ${i + 1} should bake as inside at its centre',
      );
    }

    // Halfway between the first two ovals: 50 px from each, outside both
    // clusters' clips, so only the clear ever writes it. Left zeroed it
    // would decode as the deep interior -- solid glass between clusters.
    final between = Offset(
      (_cornerOf(0).dx + _size + _cornerOf(1).dx) / 2,
      _centreOf(0).dy,
    );
    expect(baked.contains(between), isTrue);
    expect(baked.signedDistanceAt(between), greaterThan(0));
    expect(
      baked.signedDistanceAt(between),
      greaterThan(_request.maxDisplacement * 0.9),
      reason: 'the gap between clusters should read as far outside',
    );
  }

  Future<void> expectEachClusterMatchesItsShapeAlone(
    GeometryProducer producer,
  ) async {
    // Inside its clip, a cluster's draw must bake exactly what that shape
    // bakes on its own through the single-draw path -- the clip is in the
    // right place, on both axes, and the uniforms carry the right shapes.
    final all = await _bake(
      producer,
      _scene(List<int>.generate(_count, (i) => i)),
    );
    final padding = clusterPadding(_request);
    for (final i in <int>[0, 5, 11]) {
      final alone = await _bake(producer, _scene(<int>[i]));
      final clip = _oval(i).layerBounds.inflate(padding);
      var compared = 0;
      var maxDelta = 0;
      for (var y = clip.top.ceil(); y < clip.bottom.floor(); y++) {
        for (var x = clip.left.ceil(); x < clip.right.floor(); x++) {
          final p = Offset(x.toDouble(), y.toDouble());
          if (!alone.contains(p)) {
            continue;
          }
          final a = all.bytesAt(p);
          final b = alone.bytesAt(p);
          for (var c = 0; c < 4; c++) {
            final delta = (a[c] - b[c]).abs();
            if (delta > maxDelta) {
              maxDelta = delta;
            }
          }
          compared++;
        }
      }
      expect(compared, greaterThan(_size * _size));
      expect(maxDelta, lessThanOrEqualTo(1), reason: 'oval ${i + 1}');
    }
  }

  Future<void> expectTileGrid(GeometryProducer producer) async {
    final all = await _bake(
      producer,
      _tiles(List<int>.generate(_count, (i) => i)),
    );

    // Every tile is glass at its centre -- the ninth to twelfth included,
    // which one merged cluster capped at kMaxShapes never drew.
    for (var i = 0; i < _count; i++) {
      expect(
        all.signedDistanceAt(_tileRect(i).center),
        lessThan(0),
        reason: 'tile ${i + 1} should bake as inside at its centre',
      );
    }

    // Every texel in the gaps reads as outside glass, and the middle of each
    // gap -- six pixels from both neighbours, past both clusters' clips --
    // as far outside.
    final grid = _tileRect(0).expandToInclude(_tileRect(_count - 1));
    var gapTexels = 0;
    for (var y = grid.top.floor(); y < grid.bottom.ceil(); y++) {
      for (var x = grid.left.floor(); x < grid.right.ceil(); x++) {
        final centre = Offset(x + 0.5, y + 0.5);
        final inTile = <int>[
          for (var i = 0; i < _count; i++) i,
        ].any((i) => _tileRect(i).contains(centre));
        if (inTile) {
          continue;
        }
        gapTexels++;
        expect(
          all.signedDistanceAt(Offset(x.toDouble(), y.toDouble())),
          greaterThan(0),
          reason: 'gap texel ($x, $y) should read as outside',
        );
      }
    }
    expect(gapTexels, greaterThan(0));
    final midGap = Offset(
      _tileRect(0).right + _gap / 2,
      _tileRect(0).center.dy,
    );
    expect(
      all.signedDistanceAt(midGap),
      greaterThan(_request.maxDisplacement * 0.9),
    );

    // Each tile's edge -- the antialiased fringe either side of it -- bakes
    // exactly as the tile does on its own through the single-draw path.
    for (final i in <int>[0, 6, 11]) {
      final alone = await _bake(producer, _tiles(<int>[i]));
      final fringe = _tileRect(i).inflate(_request.antialiasWidth + 1.5);
      var compared = 0;
      var maxDelta = 0;
      for (var y = fringe.top.floor(); y < fringe.bottom.ceil(); y++) {
        for (var x = fringe.left.floor(); x < fringe.right.ceil(); x++) {
          final p = Offset(x.toDouble(), y.toDouble());
          if (!alone.contains(p)) {
            continue;
          }
          final a = all.bytesAt(p);
          final b = alone.bytesAt(p);
          for (var c = 0; c < 4; c++) {
            final delta = (a[c] - b[c]).abs();
            if (delta > maxDelta) {
              maxDelta = delta;
            }
          }
          compared++;
        }
      }
      expect(compared, greaterThan(_tile * _tile));
      expect(maxDelta, lessThanOrEqualTo(1), reason: 'tile ${i + 1}');
    }
  }

  group('runtime-effect producer', () {
    test('bakes all twelve separate ovals of one material', () async {
      final producer = RuntimeGeometryProducer();
      addTearDown(producer.dispose);
      await expectTwelveOvals(producer);
    });

    test('bakes each cluster as its shape bakes alone', () async {
      final producer = RuntimeGeometryProducer();
      addTearDown(producer.dispose);
      await expectEachClusterMatchesItsShapeAlone(producer);
    });

    test('bakes a 12 px-gapped grid of twelve tiles, every one', () async {
      final producer = RuntimeGeometryProducer();
      addTearDown(producer.dispose);
      await expectTileGrid(producer);
    });
  });

  group('Flutter GPU producer', () {
    test('bakes all twelve separate ovals of one material', () async {
      final producer = await _gpuProducer();
      if (producer == null) {
        markTestSkipped('Flutter GPU is unavailable here.');
        return;
      }
      await expectTwelveOvals(producer);
    });

    test('bakes each cluster as its shape bakes alone', () async {
      final producer = await _gpuProducer();
      if (producer == null) {
        markTestSkipped('Flutter GPU is unavailable here.');
        return;
      }
      await expectEachClusterMatchesItsShapeAlone(producer);
    });

    test('bakes a 12 px-gapped grid of twelve tiles, every one', () async {
      final producer = await _gpuProducer();
      if (producer == null) {
        markTestSkipped('Flutter GPU is unavailable here.');
        return;
      }
      await expectTileGrid(producer);
    });

    test('matches the runtime-effect producer byte for byte', () async {
      final gpu = await _gpuProducer();
      if (gpu == null) {
        markTestSkipped('Flutter GPU is unavailable here.');
        return;
      }
      final runtime = RuntimeGeometryProducer();
      addTearDown(runtime.dispose);
      final scene = _scene(List<int>.generate(_count, (i) => i));

      final fromGpu = await _bake(gpu, scene);
      final fromRuntime = await _bake(runtime, scene);
      expect(fromGpu.generation.bounds, fromRuntime.generation.bounds);
      expect(fromGpu.pixels.lengthInBytes, fromRuntime.pixels.lengthInBytes);

      var maxDelta = 0;
      for (var i = 0; i < fromGpu.pixels.lengthInBytes; i++) {
        final delta =
            (fromGpu.pixels.getUint8(i) - fromRuntime.pixels.getUint8(i)).abs();
        if (delta > maxDelta) {
          maxDelta = delta;
        }
      }
      // The same slack the single-draw parity test allows: two pipelines
      // evaluating one SDF. A misplaced scissor or a missing clear is
      // hundreds of texels off by up to 255.
      expect(maxDelta, lessThanOrEqualTo(2));
    });
  });
}
