// What the final pass adds on top of the refracted backdrop, read back.
//
// Impeller only: `ui.ImageFilter.shader` throws outside it, so these run in
// the `flutter test --tags impeller --run-skipped --enable-impeller` lane.
// The filter here is applied to a flat colour through a saveLayer rather
// than to a real backdrop -- `RepaintBoundary.toImage()` does not rasterise
// backdrop filters -- which is fine for what is asked: how much light the
// shading adds, as a function of what is behind it.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/filter_snapshot.dart';
import 'package:glass_forge/src/composition/glass_composition.dart';
import 'package:glass_forge/src/composition/glass_glow.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/runtime_geometry_producer.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/material/glass_profile.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

const double _canvas = 240;

/// The workbench's stage ground: dark, but not black. Luma about 0.054.
const Color _stageGround = Color(0xFF0A0E17);
const Color _black = Color(0xFF000000);
const Color _grey = Color(0xFF808080);

/// Light straight down, so the key side of a shape is its bottom edge.
GlassMaterial _lit(GlassProfile profile) => const GlassMaterial().copyWith(
  profile: profile,
  frost: 0,
  tintOpacity: 0,
  saturation: 1,
  contour: 0,
  highlight: 1,
  edgeRefraction: 12,
  thickness: 10,
  lightDirection: const Offset(0, 1),
);

MatteGeneration _bake(RuntimeGeometryProducer producer, GlassMaterial m) {
  final scene = GlassScene()
    ..register(
      'a',
      ShapeGeometry.resolve(
        shape: const GlassRoundedRectangle(
          radius: BorderRadius.all(Radius.circular(24)),
        ),
        size: const Size(160, 160),
        toLayer: Matrix4.translationValues(40, 40, 0),
        devicePixelRatio: 1,
      ),
    );
  return producer.produce(
    scene,
    MatteRequest(
      devicePixelRatio: 1,
      maxDisplacement: m.maxDisplacement,
      edgeRefraction: m.edgeRefraction,
      refractionSpread: m.refractionSpread,
      antialiasWidth: 0.5,
      profile: m.profile,
      thickness: m.profile == GlassProfile.dome ? m.thickness : 0,
    ),
  )!;
}

/// Paints [backdrop] through the glass filter and reads the result back.
Future<ByteData> _render(GlassMaterial material, Color backdrop) async {
  final producer = RuntimeGeometryProducer();
  final composition = GlassComposition();
  try {
    final matte = _bake(producer, material);
    final filter = composition.build(
      matte: matte,
      material: material,
      snapshot: FilterSnapshot.of(
        matte: matte,
        devicePixelRatio: 1,
        materialRevision: material.revision,
        coordinateMapping: Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]),
        presence: 1,
        glow: const GlassGlow.none(),
      ),
      devicePixelRatio: 1,
      presence: 1,
      glow: const GlassGlow.none(),
    )!;
    final recorder = ui.PictureRecorder();
    const bounds = Rect.fromLTWH(0, 0, _canvas, _canvas);
    Canvas(recorder)
      ..saveLayer(bounds, Paint()..imageFilter = filter)
      ..drawRect(bounds, Paint()..color = backdrop)
      ..restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_canvas.toInt(), _canvas.toInt());
    picture.dispose();
    final bytes = (await image.toByteData())!;
    image.dispose();
    producer.release(matte);
    return bytes;
  } finally {
    composition.dispose();
    producer.dispose();
  }
}

/// Rec.709 luma of the pixel at (x, y), 0..255.
double _luma(ByteData bytes, int x, int y) {
  final i = (y * _canvas.toInt() + x) * 4;
  return 0.2126 * bytes.getUint8(i) +
      0.7152 * bytes.getUint8(i + 1) +
      0.0722 * bytes.getUint8(i + 2);
}

/// The most light the shading added anywhere along the key-side rim, over
/// a flat [backdrop] -- the brightest texel just inside the bottom edge,
/// less the backdrop itself.
Future<double> _rimGain(GlassProfile profile, Color backdrop) async {
  final bytes = await _render(_lit(profile), backdrop);
  final base =
      0.2126 * (backdrop.r * 255) +
      0.7152 * (backdrop.g * 255) +
      0.0722 * (backdrop.b * 255);
  var peak = 0.0;
  for (var y = 180; y < 200; y++) {
    for (var x = 100; x < 140; x++) {
      peak = peak > _luma(bytes, x, y) ? peak : _luma(bytes, x, y);
    }
  }
  return peak - base;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  for (final profile in GlassProfile.values) {
    group('$profile', () {
      test('adds nothing to a truly black surface', () async {
        // Upstream #112: a rim over pure black flickers. Exactly zero is
        // the only guard that cannot.
        expect(await _rimGain(profile, _black), 0);
      });

      test(
        'lights the rim over a dark stage as strongly as over mid-grey',
        () async {
          // The old guard, pow(luma, 0.25), scaled the rim to about 57% of
          // its mid-grey strength over the stage ground -- on exactly the
          // backdrop where the rim is the only thing saying "glass".
          final dark = await _rimGain(profile, _stageGround);
          final grey = await _rimGain(profile, _grey);
          expect(grey, greaterThan(20), reason: 'no rim to compare at all');
          expect(dark, greaterThan(grey * 0.9));
        },
      );
    });
  }

  test(
    'the dome reads its backdrop bilinearly, so a magnified edge is not '
    'stair-stepped',
    () async {
      // A dome magnifies, and read nearest-neighbour (flutter#186945) every
      // edge through it snaps to whole texels: a hard black-to-white step,
      // shifted a pixel at a time. Bilinear reads land between texels and
      // leave intermediate greys along the displaced edge.
      final material = _lit(GlassProfile.dome).copyWith(
        highlight: 0,
        edgeRefraction: 30,
      );
      final producer = RuntimeGeometryProducer();
      final composition = GlassComposition();
      addTearDown(producer.dispose);
      addTearDown(composition.dispose);
      final matte = _bake(producer, material);
      addTearDown(() => producer.release(matte));
      final filter = composition.build(
        matte: matte,
        material: material,
        snapshot: FilterSnapshot.of(
          matte: matte,
          devicePixelRatio: 1,
          materialRevision: material.revision,
          coordinateMapping: Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]),
          presence: 1,
          glow: const GlassGlow.none(),
        ),
        devicePixelRatio: 1,
        presence: 1,
        glow: const GlassGlow.none(),
      )!;
      final recorder = ui.PictureRecorder();
      const bounds = Rect.fromLTWH(0, 0, _canvas, _canvas);
      Canvas(recorder)
        ..saveLayer(bounds, Paint()..imageFilter = filter)
        ..drawRect(bounds, Paint()..color = _black)
        ..drawRect(
          const Rect.fromLTWH(97, 0, _canvas - 97, _canvas),
          Paint()..color = const Color(0xFFFFFFFF),
        )
        ..restore();
      final picture = recorder.endRecording();
      final image = picture.toImageSync(_canvas.toInt(), _canvas.toInt());
      picture.dispose();
      final bytes = (await image.toByteData())!;
      image.dispose();

      // Well inside the shape, across the magnified edge.
      final greys = <int>{};
      for (var y = 80; y < 160; y += 4) {
        for (var x = 60; x < 140; x++) {
          final value = bytes.getUint8((y * _canvas.toInt() + x) * 4 + 1);
          if (value > 8 && value < 247) {
            greys.add(value);
          }
        }
      }
      expect(greys.length, greaterThan(10));
    },
  );

  test(
    "the dome's light stays on its edge: the flat interior gets none",
    () async {
      // A dome is lit from a 3D normal, and Blinn's half-vector lobe at
      // these powers puts about 10% of the highlight on a surface facing
      // the viewer -- a white veil across the whole flat middle, which the
      // eye reads as frost. Past the lit band the output must be the
      // backdrop, untouched.
      final bytes = await _render(_lit(GlassProfile.dome), _grey);
      for (final (x, y) in <(int, int)>[(120, 120), (90, 100), (150, 140)]) {
        expect(
          (_luma(bytes, x, y) - 128).abs(),
          lessThan(1.5),
          reason: 'interior texel ($x, $y) was lit',
        );
      }
    },
  );
}
