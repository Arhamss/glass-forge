@Tags(['impeller'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// Impeller-tagged on purpose, and only meaningful there.
///
/// sdEllipse took its sign from `sign(q.y - nearest.y)`. On the horizontal
/// axis q.y is 0, and whenever the Newton step overshoots to t <= 0 the clamp
/// snaps it to exactly 0 — so nearest.y is exactly 0 and sign(0) zeroes the
/// distance, inside or outside. Whether it overshoots depends on the GPU's
/// sin/asin precision. Skia's CPU raster lands a hair above zero and gets the
/// right answer by luck, so an untagged version of this test passes against
/// the bug and guards nothing. Metal overshoots, which is where it has to run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('an oval is inside along its own horizontal axis', () async {
    final producer = RuntimeGeometryProducer();
    addTearDown(producer.dispose);
    final scene = GlassScene()
      ..register(
        'a',
        ShapeGeometry.resolve(
          shape: const GlassOval(),
          size: const Size(96, 96),
          // A pixel centre has to land exactly on the axis for the bug to
          // show: centre at 268.5, sampled at pixel centres x.5.
          toLayer: Matrix4.translationValues(300.5, 220.5, 0),
          devicePixelRatio: 1,
        ),
      );

    final generation = producer.produce(
      scene,
      const MatteRequest(
        devicePixelRatio: 1,
        maxDisplacement: 32,
        edgeRefraction: 27.42,
        refractionSpread: 0,
        antialiasWidth: 0.5,
      ),
    )!;
    final pixels = (await generation.texture.toByteData())!;
    final width = generation.texture.width;

    // Every texel along the axis row, well inside a 48px radius. One zero
    // anywhere on it is the hairline.
    final row = 268 - generation.bounds.top.floor();
    final distances = <double>[
      for (var x = 312; x <= 384; x += 4)
        generation.codec.decodeSignedDistance(
          pixels.getUint8(
                (row * width + (x - generation.bounds.left.floor())) * 4 + 2,
              ) /
              255,
        ),
    ];
    producer.release(generation);

    expect(
      distances.every((d) => d < -4),
      isTrue,
      reason: 'a texel on the horizontal axis read as the boundary: '
          '$distances',
    );
  });
}
