import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

GlassScene _sceneWithOneShape() {
  return GlassScene()..register(
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

  _matteContentTests();
  _offOriginTests();
  _flatShapeTests();

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

  test(
    'releasing a translated view does not dispose the texture it borrows',
    () {
      // A translated() generation aliases its origin's texture rather than
      // owning it. release() is keyed on texture identity, so without the
      // isOwner guard this call would dispose the shared texture out from
      // under the generation that actually owns it.
      final producer = RuntimeGeometryProducer();
      final original = producer.produce(_sceneWithOneShape(), _request)!;
      final view = original.translated(const Offset(10, 0));

      expect(view.isOwner, isFalse);
      expect(identical(view.texture, original.texture), isTrue);

      producer.release(view);
      expect(original.texture.debugDisposed, isFalse);

      producer
        ..release(original)
        ..dispose();
    },
  );

  test('releasing the owning generation still disposes its texture', () {
    // The other half of the same hazard: the isOwner guard must not turn
    // release() into a no-op for the generation that actually owns the
    // texture, or every matte leaks.
    final producer = RuntimeGeometryProducer();
    final generation = producer.produce(_sceneWithOneShape(), _request)!;

    expect(generation.isOwner, isTrue);

    producer.release(generation);
    expect(generation.texture.debugDisposed, isTrue);

    producer.dispose();
  });
}

/// Bakes a matte for one large rounded rectangle and reads its pixels back.
///
/// Large on purpose: the edge-band profile leaves the interior undistorted,
/// so a shape has to be several times wider than the band before it has a
/// genuine interior — the region where the displacement magnitude is exactly
/// zero and the signed distance is the only thing left that knows the
/// surface is there.
Future<({ByteData pixels, Rect bounds, MatteCodec codec, int width})>
_bakeLargeSquare() async {
  final producer = RuntimeGeometryProducer();
  final scene = GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(24)),
        ),
        size: const Size(400, 400),
        toLayer: Matrix4.identity(),
        devicePixelRatio: 1,
      ),
    );
  final generation = producer.produce(scene, _request)!;
  final pixels = (await generation.texture.toByteData())!;
  final result = (
    pixels: pixels,
    bounds: generation.bounds,
    codec: generation.codec,
    width: generation.texture.width,
  );
  producer
    ..release(generation)
    ..dispose();
  return result;
}

Float32List _texelAt(
  ByteData pixels,
  int width,
  Rect bounds,
  Offset layerPoint,
) {
  final px = (layerPoint.dx - bounds.left).floor();
  final py = (layerPoint.dy - bounds.top).floor();
  final base = (py * width + px) * 4;
  return Float32List.fromList([
    pixels.getUint8(base) / 255,
    pixels.getUint8(base + 1) / 255,
    pixels.getUint8(base + 2) / 255,
    pixels.getUint8(base + 3) / 255,
  ]);
}

void _matteContentTests() {
  test(
    'the deep interior carries a signed distance even though its '
    'displacement magnitude is zero',
    () async {
      final baked = await _bakeLargeSquare();
      final centre = _texelAt(
        baked.pixels,
        baked.width,
        baked.bounds,
        const Offset(200, 200),
      );
      final decoded = baked.codec.decode(centre);

      // The regression this pins: the final pass used to derive coverage
      // from the alpha channel, which the band profile drives to exactly
      // zero across the whole interior by design. Every shape was therefore
      // hollow — its middle received no tint, no saturation, no rim and no
      // scrim, only the composed blur. Alpha being zero here is correct;
      // coverage must come from the signed distance instead.
      expect(decoded.displacement, 0);
      expect(decoded.signedDistance, lessThan(-_request.maxDisplacement / 2));
    },
  );

  test('a texel outside the shape encodes a positive distance', () async {
    final baked = await _bakeLargeSquare();
    // Inside the padded bounds but outside the rounded corner's arc.
    final corner = _texelAt(
      baked.pixels,
      baked.width,
      baked.bounds,
      const Offset(1, 1),
    );

    // A zeroed texel would decode to -maxDisplacement, the deep interior,
    // and the padding around every shape would read as solid glass.
    expect(baked.codec.decode(corner).signedDistance, greaterThan(0));
  });
}

void _offOriginTests() {
  test(
    'a shape away from its layer origin still bakes as inside at its centre',
    () async {
      // Regression: both producers wrote shape origins relative to the
      // matte allocation (`origin - allocation.left`) while evaluating the
      // SDF at a *layer-local* coordinate — FlutterFragCoord in the
      // pre-translation space here, gl_FragCoord plus an origin uniform in
      // the Flutter GPU producer. The allocation offset was therefore
      // applied twice. It is invisible for a shape at its layer's top-left,
      // where the allocation starts at about zero — which is every shape
      // the earlier tests used, and the workbench's specimen screen, which
      // is why it survived. Anywhere else the SDF is evaluated entirely off
      // the shape: the blend screen's two circles rendered as nothing at all.
      final producer = RuntimeGeometryProducer();
      addTearDown(producer.dispose);
      final scene = GlassScene()
        ..register(
          'a',
          ShapeGeometry.resolve(
            shape: const GlassOval(),
            size: const Size(96, 96),
            toLayer: Matrix4.translationValues(300, 220, 0),
            devicePixelRatio: 1,
          ),
        );

      final generation = producer.produce(scene, _request)!;
      final pixels = (await generation.texture.toByteData())!;
      final centre = _texelAt(
        pixels,
        generation.texture.width,
        generation.bounds,
        const Offset(348, 268),
      );
      producer.release(generation);

      expect(
        generation.bounds.left,
        greaterThan(200),
        reason:
            'the test only means something if the allocation is well '
            'away from the layer origin',
      );
      expect(generation.codec.decode(centre).signedDistance, lessThan(0));
    },
  );
}

void _flatShapeTests() {
  test('a shape keeps its corners when nothing refracts', () async {
    // Regression: the matte's signed distance is normalised by the same
    // range as the displacement, and `displacementRangeFor` floors that at
    // 1e-3. At edgeRefraction 0 — every `flat` tier, and every Reduce
    // Transparency and Increase Contrast path — every distance saturated to
    // that floor, so coverage decoded to about 0.5 everywhere and the glass
    // drew as a half-opaque *rectangle* with its rounded corners lost. The
    // users this hits are exactly the ones the accessibility work is for.
    //
    // A range covers coverage, the contour and the rim as well as the
    // displacement, so it cannot collapse just because nothing is bending.
    final producer = RuntimeGeometryProducer();
    addTearDown(producer.dispose);
    const radius = 40.0;
    final scene = GlassScene()
      ..register(
        'a',
        ShapeGeometry.resolve(
          shape: const GlassRoundedRectangle(
            radius: BorderRadius.all(Radius.circular(radius)),
          ),
          size: const Size(200, 200),
          toLayer: Matrix4.identity(),
          devicePixelRatio: 1,
        ),
      );

    final flat = MatteRequest(
      devicePixelRatio: 1,
      maxDisplacement: MatteCodec.displacementRangeFor(0),
      edgeRefraction: 0,
      refractionSpread: 0,
      antialiasWidth: 0.5,
    );
    final generation = producer.produce(scene, flat)!;
    final pixels = (await generation.texture.toByteData())!;
    final width = generation.texture.width;

    Offset at(double x, double y) => Offset(x, y);
    double distanceAt(Offset point) => generation.codec.decodeSignedDistance(
      _texelAt(pixels, width, generation.bounds, point)[2],
    );

    // Well inside, and outside the top-left corner's arc — the corner of the
    // bounding box, which a rounded rectangle does not cover.
    final inside = distanceAt(at(100, 100));
    final pastCorner = distanceAt(at(4, 4));
    producer.release(generation);

    // The sign survives the collapse; the magnitude is what dies. The final
    // pass resolves coverage over about a pixel — `clamp(0.5 - sd / scale)`
    // — so a distance of 1e-3 lands at 0.4999 inside and 0.5001 outside and
    // every fragment in the matte comes out half covered. Both sides have to
    // clear a pixel for the silhouette to exist at all.
    expect(
      inside,
      lessThan(-1),
      reason: 'the middle decoded at $inside: too small to read as covered',
    );
    expect(
      pastCorner,
      greaterThan(1),
      reason:
          'the bounding box corner decoded at $pastCorner, inside a '
          '${radius}px round: the shape draws as a rectangle',
    );
  });
}
