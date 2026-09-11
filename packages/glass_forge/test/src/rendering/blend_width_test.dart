// Requires the Impeller rendering engine: the layer under test paints
// through `ui.ImageFilter.shader`, which throws under flutter_tester's
// default software backend. See dart_test.yaml.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_blend_group.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// Keeps the last scene a layer asked to bake, so the test can bake it
/// itself -- through the real shader -- and read the result.
class _CapturingProducer implements GeometryProducer {
  GlassScene? scene;

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'capturing');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    this.scene = scene;
    return null;
  }

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets(
    'on a 3x screen, two shapes closer than the blend width merge into one',
    (tester) async {
      // The Blend screen's own claim: "gap 24 px, blend 40 px -> one shape".
      // It was false on a phone. The blend width reached the shader in
      // logical pixels while every other length was physical, and the
      // smooth-min only lowers the surface by a quarter of its width -- so
      // on a 3x screen a 40-pixel blend closed gaps under about 7 pixels.
      final producer = _CapturingProducer();
      ProducerRegistry.debugReset();
      ProducerRegistry.registerAccelerated(() => producer);
      addTearDown(() {
        ProducerRegistry.debugReset();
        debugResetAcceleratedProducerRegistration();
      });

      const diameter = 96.0;
      const gap = 24.0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: GlassLayer(
              tier: GeometryTier.accelerated,
              child: GlassBlendGroup(
                blend: 40,
                child: Stack(
                  children: <Widget>[
                    for (final left in <double>[0, diameter + gap])
                      Positioned(
                        left: left,
                        top: 0,
                        child: const SizedBox(
                          width: diameter,
                          height: diameter,
                          child: Glass(shape: GlassOval()),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final scene = producer.scene;
      expect(scene, isNotNull, reason: 'the layer never asked for a bake');
      expect(scene!.shapes, hasLength(2));

      // Bake what the layer registered, and look at the middle of the gap.
      final baker = RuntimeGeometryProducer();
      addTearDown(baker.dispose);
      final matte = baker.produce(
        scene,
        const MatteRequest(
          devicePixelRatio: 3,
          maxDisplacement: 86.4,
          edgeRefraction: 82.3,
          refractionSpread: 0,
          antialiasWidth: 0.5,
        ),
      )!;
      addTearDown(() => baker.release(matte));

      late ByteData pixels;
      await tester.runAsync(() async {
        pixels = (await matte.texture.toByteData())!;
      });
      // Layer-local, in physical pixels: the layer sits at the origin.
      final midpoint = const Offset(diameter + gap / 2, diameter / 2) * 3;
      final px = (midpoint.dx - matte.bounds.left).floor();
      final py = (midpoint.dy - matte.bounds.top).floor();
      final blue = pixels.getUint8((py * matte.texture.width + px) * 4 + 2);

      expect(
        matte.codec.decodeSignedDistance(blue / 255),
        lessThan(0),
        reason: 'the middle of a 24-pixel gap under a 40-pixel blend is '
            'outside the glass: the shapes did not merge',
      );
    },
  );
}
