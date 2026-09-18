// Finding 1: `GlassGlow.isActive` and what the shader actually draws must
// never disagree. A glow with `radius: 0, strength: > 0` reports itself
// inactive (`isActive => radius > 0 && strength > 0`), so it must put
// nothing on screen -- not the near-centre `smoothstep` falloff the shader's
// old `uGlow.w > 0.0`-only gate would still draw.
//
// A pixel test, not a `_writeUniforms`-level unit test: `_writeUniforms` is
// private and the only thing worth proving is what lands on screen, which a
// unit test on the uniform floats cannot show without duplicating the
// shader's own gate in Dart.
//
// Impeller only: `ui.ImageFilter.shader` throws outside it, so this runs in
// the `flutter test --tags impeller --run-skipped --enable-impeller` lane,
// same as `final_pass_shading_test.dart`, whose backdrop-through-a-filter
// technique this reuses.
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
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

const double _canvas = 240;
const Color _grey = Color(0xFF808080);

/// Flat interior, no other source of light, so the only thing that can
/// brighten the shape's centre texel is the glow.
const GlassMaterial _material = GlassMaterial(frost: 0, highlight: 0);

MatteGeneration _bake(RuntimeGeometryProducer producer) {
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
      maxDisplacement: _material.maxDisplacement,
      edgeRefraction: _material.edgeRefraction,
      refractionSpread: _material.refractionSpread,
      antialiasWidth: 0.5,
      profile: _material.profile,
    ),
  )!;
}

/// Renders a flat [_grey] backdrop through the glass filter with [glow] and
/// reads back the shape's centre texel, at (120, 120) -- the middle of the
/// 160x160 shape placed at (40, 40).
Future<int> _centreGreen(GlassGlow glow) async {
  final producer = RuntimeGeometryProducer();
  final composition = GlassComposition();
  try {
    final matte = _bake(producer);
    final filter = composition.build(
      matte: matte,
      material: _material,
      snapshot: FilterSnapshot.of(
        matte: matte,
        devicePixelRatio: 1,
        materialRevision: _material.revision,
        coordinateMapping: Float32List.fromList(<double>[1, 0, 0, 1, 0, 0]),
        presence: 1,
        glow: glow,
      ),
      devicePixelRatio: 1,
      presence: 1,
      glow: glow,
    )!;
    final recorder = ui.PictureRecorder();
    const bounds = Rect.fromLTWH(0, 0, _canvas, _canvas);
    Canvas(recorder)
      ..saveLayer(bounds, Paint()..imageFilter = filter)
      ..drawRect(bounds, Paint()..color = _grey)
      ..restore();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_canvas.toInt(), _canvas.toInt());
    picture.dispose();
    final bytes = (await image.toByteData())!;
    image.dispose();
    producer.release(matte);
    // Green channel of the centre texel; any channel would do over a grey
    // backdrop, since the glow brightens all three equally.
    return bytes.getUint8((120 * _canvas.toInt() + 120) * 4 + 1);
  } finally {
    composition.dispose();
    producer.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  test('a real glow brightens the shape it sits under', () async {
    // Positive control: proves this test can actually see the glow at all,
    // so the inactive case below is not passing for an unrelated reason.
    final none = await _centreGreen(const GlassGlow.none());
    final active = await _centreGreen(
      const GlassGlow(centre: Offset(120, 120), radius: 60, strength: 1),
    );
    expect(active, greaterThan(none + 10));
  });

  test(
    'isActive == false (zero radius, nonzero strength) draws nothing',
    () async {
      final none = await _centreGreen(const GlassGlow.none());
      final zeroRadius = await _centreGreen(
        const GlassGlow(centre: Offset(120, 120), radius: 0, strength: 1),
      );
      expect(
        zeroRadius,
        none,
        reason:
            'GlassGlow(radius: 0, strength: 1).isActive is false, so this '
            'must land on screen identically to no glow at all',
      );
    },
  );
}
