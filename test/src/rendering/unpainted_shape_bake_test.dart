// Bakes real mattes and reads them back, which needs a real Impeller
// backend. Run with `flutter test --tags impeller --run-skipped
// --enable-impeller --enable-flutter-gpu test/src/rendering/`.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_limits.dart';

/// Keeps the last scene and request a layer asked to bake, so the test can
/// bake them itself -- through the real shader -- and read the result.
class _CapturingProducer implements GeometryProducer {
  GlassScene? scene;
  MatteRequest? request;

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'capturing');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    final copy = GlassScene();
    for (var i = 0; i < scene.shapes.length; i++) {
      copy.register(i, scene.shapes[i]);
    }
    this.scene = copy;
    this.request = request;
    return null;
  }

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

const double _tile = 60;
const double _gap = 12;
const int _columns = 4;
const int _count = 11;

Rect _tileRect(int i) => Rect.fromLTWH(
  (i % _columns) * (_tile + _gap),
  (i ~/ _columns) * (_tile + _gap),
  _tile,
  _tile,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('tiles still under a zero Opacity cost a painted tile at the '
      'origin nothing, and every tile bakes once faded in', (tester) async {
    // Tiles 1 to 10 mount first, under a zero Opacity, so they register
    // ahead of tile 0 and have not painted. Tile 0 is shown from the start,
    // at the layer's origin -- right where a shape that has not painted
    // used to sit. Counted in, the ten made one cluster of eleven with it,
    // and tile 0, eleventh in registration order, was past the eight one
    // draw carries: a shown tile with no glass under it.
    final producer = _CapturingProducer();
    ProducerRegistry.debugReset();
    ProducerRegistry.registerAccelerated(() => producer);
    addTearDown(() {
      ProducerRegistry.debugReset();
      debugResetAcceleratedProducerRegistration();
    });
    final opacity = ValueNotifier<double>(0);
    addTearDown(opacity.dispose);
    expect(_count, greaterThan(kMaxShapes));

    Widget glass(int i) => Positioned.fromRect(
      rect: _tileRect(i),
      child: const Glass(
        shape: GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(16)),
        ),
        child: SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          tier: GeometryTier.accelerated,
          child: Stack(
            children: <Widget>[
              for (var i = 1; i < _count; i++)
                ValueListenableBuilder<double>(
                  valueListenable: opacity,
                  builder: (context, value, child) => Positioned.fill(
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: Stack(children: <Widget>[glass(i)]),
                ),
              glass(0),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final dpr = tester.view.devicePixelRatio;
    final baker = RuntimeGeometryProducer();
    addTearDown(baker.dispose);

    /// Bakes what the layer last asked for, and decodes each tile's centre.
    Future<List<double>> signedDistancesAtCentres() async {
      final matte = baker.produce(producer.scene!, producer.request!)!;
      addTearDown(() => baker.release(matte));
      late ByteData pixels;
      await tester.runAsync(() async {
        pixels = (await matte.texture.toByteData())!;
      });
      return <double>[
        for (var i = 0; i < _count; i++)
          () {
            final centre = _tileRect(i).center * dpr;
            final px = (centre.dx - matte.bounds.left).floor();
            final py = (centre.dy - matte.bounds.top).floor();
            if (px < 0 ||
                py < 0 ||
                px >= matte.texture.width ||
                py >= matte.texture.height) {
              return double.infinity;
            }
            final base = (py * matte.texture.width + px) * 4;
            return matte.codec
                .decode(
                  Float32List.fromList(<double>[
                    for (var c = 0; c < 4; c++) pixels.getUint8(base + c) / 255,
                  ]),
                )
                .signedDistance;
          }(),
      ];
    }

    expect(
      (await signedDistancesAtCentres())[0],
      lessThan(0),
      reason: 'tile 0 is shown but is not glass at its centre',
    );

    opacity.value = 1;
    await tester.pump();
    final faded = await signedDistancesAtCentres();
    for (var i = 0; i < _count; i++) {
      expect(
        faded[i],
        lessThan(0),
        reason: 'tile $i is faded in but is not glass at its centre',
      );
    }
  });
}
