// Requires the Impeller rendering engine: every test here renders real
// glass, which means `ui.ImageFilter.shader`, which throws `UnsupportedError`
// under flutter_tester's default software backend. See dart_test.yaml and the
// file-level note in glass_widgets_test.dart for the two-invocation pattern
// this repo uses everywhere else.
@Tags(<String>['impeller'])
library;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/design/glass_surface.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_blend_group.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

// Two constraints shape every layout below, both of them properties of
// `flutter_test`'s rasterizer rather than of this package. Neither is worth
// working around in production code, and both are worth writing down so the
// next person does not read the odd-looking geometry as arbitrary.
//
// 1. Glass is drawn at the top-left, never centred. A shader backdrop filter
//    here is evaluated over a region anchored at the canvas origin and sized
//    to the matte it samples, not over the saveLayer bounds a device uses.
//    Measured directly: the same oval at (20, 20) renders, and at (340, 240)
//    renders nothing at all. Anything further from the origin than its own
//    matte is wide simply is not rasterised.
// 2. Every tree carries its own `MediaQuery`, whose default device pixel
//    ratio is 1, in place of the harness's 3. A matte is baked in physical
//    pixels and the final pass maps `FlutterFragCoord` into it, but the
//    fragment coordinates this rasterizer hands the filter are logical, so
//    at a ratio of 3 the two disagree by a factor of three and the glass
//    lands nowhere near its shape.
//
// Layers pin `GeometryTier.portable` for an unrelated third reason: which
// producer bakes the matte changes nothing about how passes are grouped or
// pushed, but the accelerated producer's bundle load is asynchronous and
// does not settle inside a pumped frame, so `produce()` keeps returning null
// and nothing renders at all. That is true on `main` as it is here.

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);
const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);
const Color _green = Color(0xFF00FF00);

/// A material that paints its tint and nothing else.
///
/// `tintOpacity: 1` drives `final_render.frag`'s tint mix all the way, and
/// with no frost, no rim and no contour the only thing left between the
/// backdrop and the output is the tint itself — so an interior texel reads
/// back as exactly [colour]. That makes "which material rendered this shape"
/// answerable from one pixel, with no tolerance to tune.
///
/// [GlassMaterial.edgeRefraction] stays at its default on purpose: it is
/// what sizes the matte's displacement range, and at zero the bake encodes
/// every texel as far outside, which is to say the shape stops existing.
GlassMaterial _tinted(Color colour) => GlassMaterial(
  tint: colour,
  tintOpacity: 1,
  frost: 0,
  highlight: 0,
);

/// Counts what each backdrop pass was asked to bake.
class _RecordingProducer implements GeometryProducer {
  /// How many shapes each `produce()` call saw, in call order.
  final List<int> shapeCounts = <int>[];

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'recording');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    shapeCounts.add(scene.shapes.length);
    return null;
  }

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

/// Rasterizes the [RenderRepaintBoundary] at [key] and reads back its RGBA.
///
/// `toImage()` and `Image.toByteData()` both complete via a real engine
/// callback, which the fake clock `testWidgets` runs under never fires --
/// awaiting either directly inside a `testWidgets` body hangs forever.
/// `tester.runAsync` drops out of that fake zone just for this call.
Future<_CapturedImage> _captureRgba(WidgetTester tester, Key key) async {
  late Uint8List pixels;
  late int width;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage();
    try {
      final byteData = await image.toByteData();
      pixels = byteData!.buffer.asUint8List();
      width = image.width;
    } finally {
      image.dispose();
    }
  });
  return _CapturedImage(pixels, width);
}

class _CapturedImage {
  const _CapturedImage(this._pixels, this._width);

  final Uint8List _pixels;
  final int _width;

  /// The colour at [point].
  Color colorAt(Offset point) {
    final index = ((point.dy.round() * _width) + point.dx.round()) * 4;
    return Color.fromARGB(
      _pixels[index + 3],
      _pixels[index],
      _pixels[index + 1],
      _pixels[index + 2],
    );
  }

  /// Every pixel inside [rect], as one flat list.
  List<int> block(Rect rect) {
    final out = <int>[];
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      for (var x = rect.left.round(); x < rect.right.round(); x++) {
        final index = ((y * _width) + x) * 4;
        out.addAll(_pixels.getRange(index, index + 4));
      }
    }
    return out;
  }
}

/// Wraps [child] in everything the two constraints above require.
///
/// The `MediaQuery` is load-bearing despite carrying only defaults: one of
/// those defaults is a device pixel ratio of 1. See constraint 2 above.
Widget _scene(Key key, Widget child) => RepaintBoundary(
  key: key,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);
  setUp(GlassRenderCounters.instance.reset);

  const key = ValueKey<String>('boundary');

  testWidgets(
    'a shape renders in the material it asked for, not in the one its '
    'layer was given',
    (tester) async {
      // The whole of problem 2 in two frames. `Glass(material:)` was
      // accepted and dropped -- both pumps below would have come back
      // green, the material of the layer above them.
      Widget build(GlassMaterial? override) => _scene(
        key,
        ColoredBox(
          color: _white,
          child: GlassLayer(
            tier: GeometryTier.portable,
            material: _tinted(_green),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Glass(shape: const GlassOval(), material: override),
              ),
            ),
          ),
        ),
      );

      const inside = Offset(60, 60);

      await tester.pumpWidget(build(null));
      expect((await _captureRgba(tester, key)).colorAt(inside), _green);

      await tester.pumpWidget(build(_tinted(_red)));
      expect((await _captureRgba(tester, key)).colorAt(inside), _red);

      await tester.pumpWidget(build(_tinted(_blue)));
      expect((await _captureRgba(tester, key)).colorAt(inside), _blue);
    },
  );

  testWidgets(
    'a layer pushes one backdrop pass per distinct material, not one per '
    'shape, and each bakes only its own shapes',
    (tester) async {
      // The invariant `GlassComposition` exists to protect, restated for
      // more than one material. One pass per shape would be six stacked
      // saveLayers and six full backdrop reads -- what upstream does, and
      // what flutter#187820 punishes.
      ProducerRegistry.debugReset();
      final producer = _RecordingProducer();
      ProducerRegistry.registerAccelerated(() => producer);
      addTearDown(() {
        ProducerRegistry.debugReset();
        debugResetAcceleratedProducerRegistration();
      });

      Widget build(List<Color> tints) => _scene(
        key,
        ColoredBox(
          color: _white,
          child: GlassLayer(
            tier: GeometryTier.accelerated,
            material: _tinted(_green),
            child: Stack(
              children: <Widget>[
                for (var i = 0; i < tints.length; i++)
                  Positioned(
                    left: 20 + i * 110.0,
                    top: 60,
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: Glass(
                        shape: const GlassOval(),
                        material: _tinted(tints[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        build(const <Color>[_red, _red, _red, _blue, _blue, _blue]),
      );
      expect(GlassRenderCounters.instance.backdropPushCount, 2);
      expect(
        producer.shapeCounts,
        <int>[3, 3],
        reason:
            'a matte holding a shape from another pass would smooth-min '
            'that shape into this one and then fill it with the wrong '
            'material',
      );

      GlassRenderCounters.instance.reset();
      producer.shapeCounts.clear();
      await tester.pumpWidget(
        build(const <Color>[_red, _red, _red, _red, _red, _red]),
      );
      expect(
        GlassRenderCounters.instance.backdropPushCount,
        1,
        reason: 'one material must stay exactly one backdrop filter',
      );
      expect(producer.shapeCounts, <int>[6]);
    },
  );

  testWidgets(
    'both materials in one frame put glass on screen, including the pass '
    'that paints no content of its own',
    (tester) async {
      // The subtree paints once, inside the last pass; every earlier pass is
      // pushed with a painter that draws nothing and exists only to apply
      // its filter to the backdrop. Whether the engine renders such a pass
      // at all is the one assumption in the pass split that cannot be read
      // off the Dart side -- an empty `BackdropFilterLayer` takes its bounds
      // from the enclosing cull rect rather than from children it does not
      // have. Red below is that pass.
      await tester.pumpWidget(
        _scene(
          key,
          ColoredBox(
            color: _white,
            child: GlassLayer(
              tier: GeometryTier.portable,
              material: _tinted(_green),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Glass(
                        shape: const GlassOval(),
                        material: _tinted(_red),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 0,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Glass(
                        shape: const GlassOval(),
                        material: _tinted(_blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(GlassRenderCounters.instance.backdropPushCount, 2);
      final captured = await _captureRgba(tester, key);
      expect(
        captured.colorAt(const Offset(5, 30)),
        _red,
        reason:
            'the first pass drew nothing, so an empty backdrop pass '
            'never reached the compositor',
      );
      expect(
        captured.colorAt(const Offset(55, 30)),
        _blue,
        reason:
            'where the two overlap the later pass wins, because it is '
            'composited over the earlier one',
      );
    },
  );

  testWidgets('a layer with no glass in it pushes no backdrop at all', (
    tester,
  ) async {
    // A `GlassLayer` wrapped around a screen that has no `Glass` beneath it
    // used to pay a full-screen saveLayer and backdrop read to render
    // nothing: the shader early-outs everywhere the matte says there is no
    // shape, and with no shapes at all that is everywhere.
    await tester.pumpWidget(
      _scene(
        key,
        const GlassLayer(
          tier: GeometryTier.portable,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    expect(GlassRenderCounters.instance.backdropPushCount, 0);
  });

  testWidgets(
    'a blend group renders whole, in the material its first shape asked '
    'for, rather than splitting across two mattes',
    (tester) async {
      // Smooth-min only reaches shapes folded into the same matte, so a
      // group split by material would not merge at all -- the members would
      // overlap with a hard seam exactly where the caller asked for a join.
      // The group takes one material instead, and it is the first
      // member's.
      await tester.pumpWidget(
        _scene(
          key,
          ColoredBox(
            color: _white,
            child: GlassLayer(
              tier: GeometryTier.portable,
              material: _tinted(_green),
              child: GlassBlendGroup(
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Glass(
                          shape: const GlassOval(),
                          material: _tinted(_red),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 50,
                      top: 0,
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: Glass(
                          shape: const GlassOval(),
                          material: _tinted(_blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        GlassRenderCounters.instance.backdropPushCount,
        1,
        reason: 'a blend group split across two passes could not blend',
      );
      final captured = await _captureRgba(tester, key);
      expect(captured.colorAt(const Offset(30, 30)), _red);
      expect(
        captured.colorAt(const Offset(80, 30)),
        _red,
        reason:
            'the second member declared blue, but a shape that merges '
            'into another is part of one surface and takes one material',
      );
    },
  );

  testWidgets('the five semantic surfaces render five different results', (
    tester,
  ) async {
    // The point of the design layer. Every `GlassSurface` role resolves to
    // its own `GlassMaterial` -- its own blur step, its own tint step -- and
    // until a layer could push more than one material they all rendered with
    // the enclosing layer's instead, which made all five pixel-identical and
    // the whole semantic-surface layer decorative.
    //
    // A hard black/white edge behind the surface, so a blur step has
    // something to smear: over a flat backdrop every sigma produces the same
    // answer, and this would then pass on any two materials that merely
    // tinted alike.
    Widget build(GlassSurfaceRole role) => _scene(
      key,
      Stack(
        children: <Widget>[
          const Positioned(
            left: 0,
            top: 0,
            width: 60,
            height: 120,
            child: ColoredBox(color: _black),
          ),
          const Positioned(
            left: 60,
            top: 0,
            width: 60,
            height: 120,
            child: ColoredBox(color: _white),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 120,
              height: 60,
              child: GlassLayer(
                tier: GeometryTier.portable,
                child: GlassSurface(role: role),
              ),
            ),
          ),
        ],
      ),
    );

    // Well inside the smallest silhouette any role resolves to -- a 120x60
    // capsule, radius 30 -- so what is compared is the glass, not the corner
    // radius the role also chose. Comparing whole captures instead would
    // pass on the unfixed code, where the five differ by shape and shadow
    // while rendering the same material.
    const interior = Rect.fromLTWH(45, 20, 30, 20);

    final renders = <GlassSurfaceRole, List<int>>{};
    for (final role in GlassSurfaceRole.values) {
      await tester.pumpWidget(build(role));
      renders[role] = (await _captureRgba(tester, key)).block(interior);
    }

    const roles = GlassSurfaceRole.values;
    for (var a = 0; a < roles.length; a++) {
      for (var b = a + 1; b < roles.length; b++) {
        expect(
          renders[roles[a]],
          isNot(renders[roles[b]]),
          reason:
              '${roles[a].name} and ${roles[b].name} rendered the same '
              'glass, so their materials never reached the renderer',
        );
      }
    }
  });
}
