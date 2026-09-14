// What the dome bakes, read back texel by texel.
//
// Impeller-tagged on purpose. These are claims about the numbers the GPU
// writes, and the lane that matches the device is the one that can be
// trusted with them: the software lane runs the same shader as SkSL on the
// CPU, whose sin/asin/sqrt round differently -- the oval that creased along
// its own axis on Metal and not on Skia (ellipse_axis_test.dart) is exactly
// that. Run with
// `flutter test --tags impeller --run-skipped --enable-impeller`.
@Tags(<String>['impeller'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_codec.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// The shape's top-left corner in layer space. Away from the origin, so
/// nothing here depends on a shape sitting where the allocation starts.
const Offset _at = Offset(30, 30);

/// One decoded texel: where it sends the backdrop sample, and how deep in.
typedef _Texel = ({Offset displacement, double signedDistance});

/// A baked matte, decoded on demand, addressed in layer pixels.
class _Baked {
  _Baked(this._pixels, this._width, this._bounds, this._codec);

  final ByteData _pixels;
  final int _width;
  final Rect _bounds;
  final MatteCodec _codec;

  _Texel at(double x, double y) {
    final px = (x - _bounds.left).floor();
    final py = (y - _bounds.top).floor();
    final base = (py * _width + px) * 4;
    final decoded = _codec.decode(
      Float32List.fromList(<double>[
        _pixels.getUint8(base) / 255,
        _pixels.getUint8(base + 1) / 255,
        _pixels.getUint8(base + 2) / 255,
        _pixels.getUint8(base + 3) / 255,
      ]),
    );
    // The final pass samples at normal * -magnitude: inward, toward the
    // middle, for a normal that points out of the surface.
    return (
      displacement: decoded.normal * -decoded.displacement,
      signedDistance: decoded.signedDistance,
    );
  }
}

MatteRequest _request({
  required GlassProfile profile,
  double edgeRefraction = 84,
  double thickness = 24,
}) {
  return MatteRequest(
    devicePixelRatio: 1,
    maxDisplacement: MatteCodec.displacementRangeFor(edgeRefraction),
    edgeRefraction: edgeRefraction,
    refractionSpread: 0,
    antialiasWidth: 0.5,
    profile: profile,
    thickness: thickness,
  );
}

Future<_Baked> _bake(
  GlassShape shape,
  Size size,
  MatteRequest request,
) async {
  final producer = RuntimeGeometryProducer();
  final scene = GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        shape: shape,
        size: size,
        toLayer: Matrix4.translationValues(_at.dx, _at.dy, 0),
        devicePixelRatio: 1,
      ),
    );
  final generation = producer.produce(scene, request)!;
  final pixels = (await generation.texture.toByteData())!;
  final baked = _Baked(
    pixels,
    generation.texture.width,
    generation.bounds,
    generation.codec,
  );
  producer
    ..release(generation)
    ..dispose();
  return baked;
}

/// Two 288-pixel ovals in one blend group, [separation] apart centre to
/// centre, merged with the smooth-min width [k] -- what a
/// `GlassBlendGroup(blend: k / 2)` hands the shader at a ratio of 1.
Future<_Baked> _bakePair(
  double separation,
  double k,
  MatteRequest request,
) async {
  final producer = RuntimeGeometryProducer();
  ShapeGeometry oval(double x, double marker) => ShapeGeometry.resolve(
    shape: const GlassOval(),
    size: const Size(288, 288),
    toLayer: Matrix4.translationValues(x, _at.dy, 0),
    devicePixelRatio: 1,
    blendMarker: marker,
  );
  final scene = GlassScene()
    ..register('a', oval(_at.dx, -(k + 1)))
    ..register('b', oval(_at.dx + separation, k));
  final generation = producer.produce(scene, request)!;
  final pixels = (await generation.texture.toByteData())!;
  final baked = _Baked(
    pixels,
    generation.texture.width,
    generation.bounds,
    generation.codec,
  );
  producer
    ..release(generation)
    ..dispose();
  return baked;
}

/// The largest jump in displacement between horizontal neighbours across
/// the vertical line through a merged pair's neck, over the neck's height.
double _tearAcrossNeck(_Baked baked, double neckX) {
  var worst = 0.0;
  for (var y = _at.dy + 60; y < _at.dy + 228; y++) {
    final left = baked.at(neckX - 1, y);
    final right = baked.at(neckX + 1, y);
    if (left.signedDistance > -4 || right.signedDistance > -4) {
      continue;
    }
    worst = math.max(worst, (left.displacement - right.displacement).distance);
  }
  return worst;
}

const _roundedRect = GlassRoundedRectangle(
  radius: BorderRadius.all(Radius.circular(84)),
);
const _superellipse = GlassSuperellipse(
  radius: BorderRadius.all(Radius.circular(84)),
);

/// The six the dome has to hold up on: each silhouette as a square, where
/// a rounded box's SDF has its seams, and as a pill, where the core is a
/// segment and an oval's ends curve tighter than anything else here.
const Map<String, (GlassShape, Size)> _shapes = <String, (GlassShape, Size)>{
  'rounded square': (_roundedRect, Size(600, 600)),
  'rounded pill': (_roundedRect, Size(780, 192)),
  'oval': (GlassOval(), Size(600, 600)),
  'oval pill': (GlassOval(), Size(780, 192)),
  'superellipse square': (_superellipse, Size(600, 600)),
  'superellipse pill': (_superellipse, Size(780, 192)),
};

/// Local distortion of the dome's image map, `p -> p + displacement(p)`.
///
/// Returns the worst ratio between how much the map stretches the backdrop
/// in one direction and the other, and its smallest singular value, which
/// goes through zero and negative where the map folds the image back on
/// itself. A lens stretches a little and everywhere the same way; a fold
/// or a pinch is a streak or a star in the picture.
({double worstStretch, double leastScale}) _distortion(
  _Baked baked,
  Size size,
) {
  const step = 3.0;
  var worstStretch = 0.0;
  var leastScale = double.infinity;
  for (var y = _at.dy + 8; y < _at.dy + size.height - 8; y += step) {
    for (var x = _at.dx + 8; x < _at.dx + size.width - 8; x += step) {
      final centre = baked.at(x, y);
      if (centre.signedDistance > -6) {
        continue;
      }
      final right = baked.at(x + step, y);
      final left = baked.at(x - step, y);
      final down = baked.at(x, y + step);
      final up = baked.at(x, y - step);
      if (<_Texel>[right, left, down, up].any((t) => t.signedDistance > -3)) {
        continue;
      }
      final a = 1 + (right.displacement.dx - left.displacement.dx) / (2 * step);
      final c = (right.displacement.dy - left.displacement.dy) / (2 * step);
      final b = (down.displacement.dx - up.displacement.dx) / (2 * step);
      final d = 1 + (down.displacement.dy - up.displacement.dy) / (2 * step);
      final sum = a * a + b * b + c * c + d * d;
      final det = a * d - b * c;
      final spread = math.sqrt(math.max(0, sum * sum - 4 * det * det));
      final largest = math.sqrt((sum + spread) / 2);
      final smallest =
          math.sqrt(math.max(0, (sum - spread) / 2)) * (det > 0 ? 1 : -1);
      worstStretch = math.max(worstStretch, largest / smallest.abs());
      leastScale = math.min(leastScale, smallest);
    }
  }
  return (worstStretch: worstStretch, leastScale: leastScale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  const square = Size(600, 600);
  final centre = Offset(_at.dx + 300, _at.dy + 300);

  test(
    'the dome refracts its whole interior; the edge band leaves it flat',
    () async {
      // The whole point of the second profile. Halfway between the rim and
      // the centre the Apple band has nothing left to do -- which, over a
      // soft backdrop, is what makes it read as a frosted pane.
      final dome = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.dome),
      );
      final band = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.edgeBand),
      );
      final halfway = centre.translate(150, 0);

      expect(band.at(halfway.dx, halfway.dy).displacement.distance, 0);
      expect(
        dome.at(halfway.dx, halfway.dy).displacement.distance,
        greaterThan(15),
      );
      expect(
        dome.at(halfway.dx, halfway.dy).displacement.dx,
        lessThan(0),
        reason: 'right of centre, a lens samples from further left -- '
            'toward the middle, which is what magnifies it',
      );
    },
  );

  test(
    'the rim displaces by edgeRefraction, and the middle by nothing',
    () async {
      // edgeRefraction means the same thing under both profiles. 84 is
      // well under the 0.35-of-depth cap for a 300-pixel-deep square, so
      // the cap is not what is being measured here.
      final dome = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.dome),
      );
      final rim = dome.at(_at.dx + 599.5, centre.dy).displacement.distance;
      expect(rim, closeTo(84, 84 * 0.06));
      expect(dome.at(centre.dx, centre.dy).displacement.distance,
          lessThan(1.5));
    },
  );

  test(
    'a small shape is a thinner lens: its rim never moves more than 0.35 of '
    'its depth',
    () async {
      // 192 tall is 96 deep. Asked for 84 at the rim, it gives 0.35 * 96:
      // pushed further, a shape this small folds its image at the rim
      // whatever the cap's angle, and the fold reads as streaks.
      final pill = await _bake(
        _roundedRect,
        const Size(780, 192),
        _request(profile: GlassProfile.dome),
      );
      final rim = pill.at(_at.dx + 390, _at.dy + 0.5).displacement.distance;
      expect(rim, closeTo(0.35 * 96, 3));
    },
  );

  for (final entry in _shapes.entries) {
    test('the ${entry.key} dome never folds or pinches its image', () async {
      // The shape this test stops is three separate bugs the dome had on
      // the way here, each of which looked like streaks on screen: a
      // hemisphere's vertical rim folding the image back on itself; a
      // rounded corner's normals converging closer in than the dome
      // pushes samples, turning each corner inside out; and an oval's
      // ends curving tighter than the displacement. On the fixed code
      // every shape stretches at most about 2x and never below 0.36.
      final (shape, size) = entry.value;
      final baked = await _bake(
        shape,
        size,
        _request(profile: GlassProfile.dome, edgeRefraction: 132),
      );
      final distortion = _distortion(baked, size);
      expect(distortion.leastScale, greaterThan(0.25));
      expect(distortion.worstStretch, lessThan(3));
    });
  }

  for (final (label, size, refraction) in <(String, Size, double)>[
    ('a rounded square', square, 132),
    // Large and gently refracting: the steering proxy's corners are only
    // rounded to 3x a small displacement here, so its own seams start well
    // before the radial term has taken over. This is the case the widening
    // stencil is for.
    ('a large rounded square with a small edge refraction',
        const Size(1200, 1200), 60),
  ]) {
    test('$label has no seam down its diagonals', () async {
      // Inside a rounded box the SDF gradient is piecewise constant, and
      // its pieces meet along the diagonals. Driving the displacement from
      // it tears the backdrop there -- about 50 pixels between neighbouring
      // texels with the radial dome term alone. The fixed code moves no
      // more than 1.5 between any two neighbours this deep.
      final dome = await _bake(
        _roundedRect,
        size,
        _request(profile: GlassProfile.dome, edgeRefraction: refraction),
      );
      var worst = 0.0;
      for (var y = _at.dy + 1; y < _at.dy + size.height - 1; y++) {
        for (var x = _at.dx + 1; x < _at.dx + size.width - 1; x++) {
          final here = dome.at(x, y);
          if (here.signedDistance > -40) {
            continue;
          }
          for (final next in <_Texel>[
            dome.at(x + 1, y),
            dome.at(x, y + 1),
          ]) {
            if (next.signedDistance > -40) {
              continue;
            }
            worst = math.max(
              worst,
              (here.displacement - next.displacement).distance,
            );
          }
        }
      }
      expect(worst, lessThan(3));
    });
  }

  test(
    'straight lines behind the dome bend smoothly across its diagonals',
    () async {
      // The depth inside a rounded box is a hip roof, and a magnitude read
      // straight off it kinks along the ridge: the slope of the vertical
      // displacement along a row turned by 0.21 px/px where it crossed a
      // diagonal, which on screen is every straight line breaking there.
      // Averaging that depth over a four-tap stencil only split the one
      // crease into three softer ones (0.09 px/px, and a visible zigzag
      // through fine stripes). Reading the steering proxy's depth inside
      // leaves no ridge to cross: under 0.03 at every depth checked.
      // Compared as slopes either side of the crossing, each averaged over
      // three texels to stand above the codec's steps.
      final dome = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.dome, edgeRefraction: 132),
      );
      const offsets = <double>[-60, -90, -120, -150, -180];
      for (final above in offsets) {
        final y = centre.dy + above;
        final crossing = centre.dx + above;
        double dyAt(double x) =>
            (dome.at(x - 1, y).displacement.dy +
                dome.at(x, y).displacement.dy +
                dome.at(x + 1, y).displacement.dy) /
            3;
        final before = (dyAt(crossing) - dyAt(crossing - 18)) / 18;
        final after = (dyAt(crossing + 18) - dyAt(crossing)) / 18;
        expect(
          (after - before).abs(),
          lessThan(0.05),
          reason: 'the row ${above.round()} above centre turns by '
              '${(after - before).toStringAsFixed(3)} px/px at the diagonal',
        );
      }
    },
  );

  test(
    'the edge band ignores the thickness the dome reads',
    () async {
      // The edge band's bake is fitted data's bake; the dome's arrival
      // must not reach it. Thickness is the one input the dome added.
      final thin = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.edgeBand, thickness: 0),
      );
      final thick = await _bake(
        _roundedRect,
        square,
        _request(profile: GlassProfile.edgeBand, thickness: 36),
      );
      for (var y = _at.dy; y < _at.dy + 600; y += 7) {
        for (var x = _at.dx; x < _at.dx + 600; x += 7) {
          expect(thick.at(x, y), thin.at(x, y));
        }
      }
    },
  );

  test(
    'inside a large rounded rectangle the dome leans straight away from its '
    'core',
    () async {
      // A lens's middle pushes everything toward one line -- the core --
      // along the shortest way. On a shape this large the steering proxy's
      // corners are rounded to only three small displacements, and its own
      // structure leaked into the middle: without the radial dome term the
      // direction there strayed from the core by 10 degrees on average and
      // by 80 at worst. With it, under half a degree and 4.
      const size = Size(1200, 700);
      final dome = await _bake(
        const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(40)),
        ),
        size,
        _request(profile: GlassProfile.dome, edgeRefraction: 60),
      );
      final middle = Offset(_at.dx + 600, _at.dy + 350);
      const coreHalf = (1200 - 700) / 2;
      var worst = 0.0;
      var total = 0.0;
      var count = 0;
      for (var y = middle.dy - 245; y < middle.dy + 245; y += 7) {
        for (var x = middle.dx - 420; x < middle.dx + 420; x += 7) {
          final texel = dome.at(x, y);
          if (texel.displacement.distance < 2) {
            continue;
          }
          final along = (x - middle.dx).clamp(-coreHalf, coreHalf);
          final away = Offset(x - middle.dx - along, y - middle.dy);
          // Displacement points back toward the core, so it should oppose
          // the way out of it.
          final off = (away.direction - (-texel.displacement).direction).abs();
          final angle = off > math.pi ? 2 * math.pi - off : off;
          worst = math.max(worst, angle);
          total += angle;
          count++;
        }
      }
      expect(count, greaterThan(1000));
      expect(total / count * 180 / math.pi, lessThan(2));
      expect(worst * 180 / math.pi, lessThan(12));
    },
  );

  group('where two blended shapes merge', () {
    // Two 288-pixel ovals 200 apart overlap by 88 and merge through a neck.
    const separation = 200.0;
    const k = 120.0;
    final neckX = _at.dx + 144 + separation / 2;

    test('the dome pools into one smooth surface: no fold, no tear', () async {
      // Across the neck the fold's core slides from one shape's centre to
      // the other's, and the two sides of the bridge face each other. With
      // neither handled, the dome folded its image back at the saddle and
      // tore the neck open by 47 pixels between neighbouring texels.
      final pair = await _bakePair(
        separation,
        k,
        _request(profile: GlassProfile.dome),
      );
      final distortion = _distortion(pair, const Size(488, 288));
      expect(distortion.leastScale, greaterThan(0.25));
      expect(distortion.worstStretch, lessThan(3));
      expect(_tearAcrossNeck(pair, neckX), lessThan(3));
    });

    for (final tight in <double>[20, 0]) {
      test('even at a blend of $tight the dome does not tear across the '
          'crease', () async {
        // A tight blend leaves a crease where the two shapes cross, and each
        // side of it points at its own core: 37 pixels apart between
        // neighbours at a blend of 20, before the steering fold was allowed
        // to merge wider than the caller's blend.
        final pair = await _bakePair(
          separation,
          tight,
          _request(profile: GlassProfile.dome),
        );
        expect(_tearAcrossNeck(pair, neckX), lessThan(3));
      });
    }

    test('the edge band does not tear down the centre of the bridge', () async {
      // shader_techniques.md s3's "union necks": the smooth-min's gradient
      // collapses along the neck's centreline and turns round, so the band
      // there pushed one way on one texel and the opposite way on the next:
      // 150 pixels apart. With the fade the worst neighbours are under 4,
      // on the neck's curved flanks where the contour itself turns fast. A
      // band wide enough to reach the centreline is what exposes it.
      final pair = await _bakePair(
        separation,
        k,
        MatteRequest(
          devicePixelRatio: 1,
          maxDisplacement: MatteCodec.displacementRangeFor(84),
          edgeRefraction: 84,
          refractionSpread: 1,
          antialiasWidth: 0.5,
        ),
      );
      expect(_tearAcrossNeck(pair, neckX), lessThan(6));
    });
  });
}
