// What the edge band bakes across a thin shape's own medial axis.
//
// Untagged on purpose: the tear this guards against is the model's, not a
// rounding difference between backends, so the software lane shows it just
// as plainly as Metal does and every `flutter test` should catch it.
//
// Given a longer deadline because these bake real mattes through the shader
// and read every texel back. The slowest takes well over a minute on the
// software rasteriser, against `flutter test`'s 30-second default, so the
// whole untagged lane — and therefore CI — went red under load while every
// assertion in the file passed. A timeout that only fires on a busy machine
// is worse than a slow test: it fails somewhere other than the defect.
@Timeout(Duration(minutes: 5))
library;

import 'dart:math' as math;
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

/// The shape's top-left corner in layer space, away from the origin.
const Offset _at = Offset(30, 30);

/// Apple's fitted edge refraction, 27.42 pt, on a 3x phone.
const double _edgeRefraction = 27.42 * 3;

/// One decoded texel: where it sends the backdrop sample, and how deep in.
typedef _Texel = ({Offset displacement, double signedDistance});

Future<_Texel Function(double x, double y)> _bake(Size size) async {
  final producer = RuntimeGeometryProducer();
  final scene = GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        // Every semantic role is a superellipse, and a bar or a control is
        // one rounded all the way to a capsule.
        shape: GlassSuperellipse(
          radius: BorderRadius.all(Radius.circular(size.shortestSide / 2)),
        ),
        size: size,
        toLayer: Matrix4.translationValues(_at.dx, _at.dy, 0),
        devicePixelRatio: 1,
      ),
    );
  final generation = producer.produce(
    scene,
    MatteRequest(
      devicePixelRatio: 1,
      maxDisplacement: MatteCodec.displacementRangeFor(_edgeRefraction),
      edgeRefraction: _edgeRefraction,
      refractionSpread: 0,
      antialiasWidth: 0.5,
    ),
  )!;
  final pixels = (await generation.texture.toByteData())!;
  final width = generation.texture.width;
  final bounds = generation.bounds;
  final codec = generation.codec;
  producer
    ..release(generation)
    ..dispose();

  _Texel read(double x, double y) {
    final base =
        (((y - bounds.top).floor()) * width + (x - bounds.left).floor()) * 4;
    final decoded = codec.decode(
      Float32List.fromList(<double>[
        pixels.getUint8(base) / 255,
        pixels.getUint8(base + 1) / 255,
        pixels.getUint8(base + 2) / 255,
        pixels.getUint8(base + 3) / 255,
      ]),
    );
    // The final pass samples at normal * -magnitude: inward, for a normal
    // that points out of the surface.
    return (
      displacement: decoded.normal * -decoded.displacement,
      signedDistance: decoded.signedDistance,
    );
  }

  return read;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  // A 44 pt control, a 52 pt navigation bar and a 72 pt bar, at 3x. Every
  // one is thinner than twice Apple's band, so its band reaches its own
  // medial axis -- where the SDF normal turns right round between one texel
  // and the next.
  for (final height in const <double>[44, 52, 72]) {
    test('a ${height.toStringAsFixed(0)} pt capsule does not tear down its '
        'own middle', () async {
      final size = Size(320 * 3, height * 3);
      final texel = await _bake(size);
      final x = _at.dx + size.width / 2;
      final axis = _at.dy + size.height / 2;

      // Where each row sends its backdrop sample, down the middle of the
      // straight run, rim to rim.
      final sampled = <double, double>{};
      for (var y = _at.dy + 2; y < _at.dy + size.height - 2; y++) {
        final t = texel(x, y + 0.5);
        if (t.signedDistance < -1) {
          sampled[y + 0.5] = y + 0.5 + t.displacement.dy;
        }
      }

      // The top half refracting from below the axis is the two halves of
      // the image trading places: the band ran past the axis and kept
      // pushing. Past it the next texel's normal points the other way.
      var worstCrossing = 0.0;
      sampled.forEach((y, from) {
        final crossing = y < axis ? from - axis : axis - from;
        worstCrossing = math.max(worstCrossing, crossing);
      });
      expect(
        worstCrossing,
        lessThan(1.5),
        reason:
            'a texel sampled ${worstCrossing.toStringAsFixed(1)} px '
            'across the medial axis',
      );

      // And the rows either side of the axis look at neighbouring backdrop,
      // not at two strips of it a band apart.
      final above = sampled[axis - 1.5]!;
      final below = sampled[axis + 1.5]!;
      expect(
        (below - above).abs(),
        lessThan(4),
        reason:
            'across the axis the image jumped '
            '${(below - above).toStringAsFixed(1)} px',
      );
    });
  }

  test('the band fades into the flat interior without a seam', () async {
    // 600 px deep against a band of 82: nothing is fitted here. Walking in
    // from the rim, where each texel samples the backdrop must move on
    // smoothly through the inner half of the band and into the interior.
    //
    // It did not, for as long as the profile was the convex squircle used
    // directly as the displacement. That curve is a *height* -- kube.io's
    // ray-trace refracts through its slope -- and as a displacement it falls
    // to zero with infinite steepness at the band's inner edge, so the image
    // folded back on itself there: a hard ring inset from every shape's
    // edge, which reads as a bezel rather than as glass.
    const size = Size(1200, 1200);
    final texel = await _bake(size);
    final x = _at.dx + size.width / 2;

    double sampleAt(double depth) {
      final y = _at.dy + depth;
      return y + texel(x, y).displacement.dy;
    }

    var worstJump = 0.0;
    var worstAt = 0.0;
    for (var d = _edgeRefraction / 2; d < _edgeRefraction + 8; d++) {
      final jump = (sampleAt(d + 1) - sampleAt(d) - 1).abs();
      if (jump > worstJump) {
        worstJump = jump;
        worstAt = d;
      }
    }
    expect(
      worstJump,
      lessThan(1.5),
      reason:
          'the sample jumped ${worstJump.toStringAsFixed(1)} px more than '
          'the texel moved, ${worstAt.toStringAsFixed(0)} px in',
    );
  });

  test('the displacement peaks at the rim', () async {
    // edgeRefraction is the displacement *at the edge*: the knob keeps the
    // meaning the presets were fitted with, whatever the curve inside.
    const size = Size(1200, 1200);
    final texel = await _bake(size);
    final x = _at.dx + size.width / 2;
    final rim = texel(x, _at.dy + 1.5).displacement.dy;
    final inside = texel(x, _at.dy + _edgeRefraction / 2).displacement.dy;
    expect(rim, greaterThan(0.6 * _edgeRefraction));
    expect(inside, lessThan(rim / 4));
  });
}
