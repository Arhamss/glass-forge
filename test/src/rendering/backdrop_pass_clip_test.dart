// No Impeller tag, and that is the point: the clip pushed around each
// backdrop pass is decided entirely on the Dart side, so it is readable off
// the layer tree on the default software backend. Every material below keeps
// `frost` above zero so `GlassComposition.willRender` is true there too --
// without a shader filter the pass still builds, as a plain blur, and is
// still pushed, which is all these tests look at.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/composition/pixel_buckets.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// The layer's own box, and the clip it pushes around all of its passes.
const Size _layerSize = Size(400, 400);
final Rect _layerRect = Offset.zero & _layerSize;

/// A material whose reach is arithmetic anyone can redo by hand.
///
/// `edgeRefraction: 20` gives a displacement range of `max(8, 1.05 * 20)`,
/// which is 21 logical pixels (`MatteCodec.displacementRangeFor`), and
/// `frost: 4` gives a blur sigma of 4. At a device pixel ratio of 1 those
/// are physical pixels already.
const GlassMaterial _near = GlassMaterial(
  frost: 4,
  edgeRefraction: 20,
  highlight: 0,
);

/// A second material, so the layer has two passes to keep apart.
const GlassMaterial _far = GlassMaterial(
  frost: 2,
  edgeRefraction: 10,
  highlight: 0,
);

/// A material that reaches a long way outside its own shape: a displacement
/// range of `1.05 * 40` and a blur sigma of 20.
const GlassMaterial _reaching = GlassMaterial(
  frost: 20,
  edgeRefraction: 40,
  highlight: 0,
);

/// A 40x40 glass square at [at], rendered with [material].
Widget _square(Offset at, GlassMaterial material) {
  return Positioned(
    left: at.dx,
    top: at.dy,
    child: Glass(
      shape: const GlassRoundedRectangle(
        radius: BorderRadius.all(Radius.circular(8)),
      ),
      material: material,
      child: const SizedBox(width: 40, height: 40),
    ),
  );
}

/// The box [_square] occupies in the layer, in layer-local pixels.
Rect _squareBounds(Offset at) => at & const Size(40, 40);

/// A layer at the top-left of the view holding [children].
///
/// The device pixel ratio is pinned to 1 so that layer-local physical pixels
/// and logical pixels coincide and every expected rect below can be read
/// straight off the layout. `GeometryTier.none` pins the producer to the one
/// that bakes nothing: which producer runs changes nothing about how a pass
/// is clipped, and the runtime one runs the SDF on the CPU here, seconds at
/// a time. No `GlassTierScope` anywhere in the tree, so the materials above
/// reach the render object exactly as written rather than degraded.
Widget _scene(List<Widget> children) {
  return MediaQuery(
    // A bare `MediaQueryData`, whose device pixel ratio is 1, in place of
    // the harness's 3.
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _layerSize,
          child: GlassLayer(
            tier: GeometryTier.none,
            material: _near,
            child: Stack(children: children),
          ),
        ),
      ),
    ),
  );
}

/// The nearest enclosing clip rect of every layer of type [T], in the order
/// the layers were appended.
///
/// Null for a layer with no clip above it at all. A per-pass clip sits
/// immediately around its own `BackdropFilterLayer`, so for a pass this is
/// that clip when there is one and the layer's own outer clip when there is
/// not -- which is exactly the difference these tests are about.
List<Rect?> _clipsAround<T extends Layer>(WidgetTester tester) {
  final found = <Rect?>[];
  void walk(Layer layer, Rect? enclosing) {
    if (layer is T) {
      found.add(enclosing);
    }
    if (layer is ContainerLayer) {
      final inner = layer is ClipRectLayer ? layer.clipRect : enclosing;
      for (
        var child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        walk(child, inner);
      }
    }
  }

  walk(tester.layers.first, null);
  return found;
}

/// Whether [outer] covers every pixel of [inner].
bool _covers(Rect outer, Rect inner) => outer.expandToInclude(inner) == outer;

void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  testWidgets(
    'each backdrop pass is clipped to its own shapes, inflated by the '
    "material's displacement and blur",
    (tester) async {
      await tester.pumpWidget(
        _scene(<Widget>[
          _square(const Offset(10, 10), _near),
          _square(const Offset(250, 250), _far),
        ]),
      );

      // Hand-derived, and deliberately not by calling the code under test.
      //
      // _near: displacement 21 + three sigmas of a 4-pixel blur (12) + the
      // two pixels of coverage and bilinear slack = 35. Around (10, 10,
      // 50, 50) that is (-25, -25, 85, 85), whose origin floors to
      // (-25, -25) and whose 110x110 size rounds up to one 64-pixel bucket
      // past it, 128x128.
      //
      // _far: displacement 10.5 + three sigmas of a 2-pixel blur (6) + 2 =
      // 18.5. Around (250, 250, 290, 290) that is (231.5, 231.5, 308.5,
      // 308.5), flooring to (231, 231) and 77.5 rounding up to 128.
      expect(_clipsAround<BackdropFilterLayer>(tester), <Rect>[
        const Rect.fromLTWH(-25, -25, 128, 128),
        const Rect.fromLTWH(231, 231, 128, 128),
      ]);
    },
  );

  testWidgets('two passes whose shapes are far apart no longer stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scene(<Widget>[
        _square(const Offset(10, 10), _near),
        _square(const Offset(250, 250), _far),
      ]),
    );

    final clips = _clipsAround<BackdropFilterLayer>(tester);
    expect(clips, hasLength(2));
    expect(
      clips.first!.overlaps(clips.last!),
      isFalse,
      reason:
          'two backdrop filters over the same pixels is flutter#187820, '
          'and these two shapes are 200 pixels apart',
    );
  });

  testWidgets(
    'a pass reaches at least as far as its shader can sample: the full '
    'displacement, and three sigmas of the composed frost blur',
    (tester) async {
      await tester.pumpWidget(
        _scene(<Widget>[
          _square(const Offset(120, 120), _reaching),
          _square(const Offset(10, 10), _far),
        ]),
      );

      final clips = _clipsAround<BackdropFilterLayer>(tester);
      expect(clips, hasLength(2));

      // The contract, stated from the material rather than from the clip:
      // `final_render.frag` reads the backdrop up to `maxDisplacement` away
      // from a written pixel, and reads it through a blur whose value at
      // that point draws on its input for three sigmas around it. Anything
      // short of this cuts refraction off at a hard line.
      final samples = _squareBounds(
        const Offset(120, 120),
      ).inflate(_reaching.maxDisplacement + 3 * _reaching.frost);
      expect(
        _covers(clips.first!, samples),
        isTrue,
        reason: '$samples is not covered by ${clips.first}',
      );
    },
  );

  testWidgets(
    'a pass whose shapes are all degenerate clips to nothing, not to '
    'everything',
    (tester) async {
      await tester.pumpWidget(
        _scene(<Widget>[
          _square(const Offset(10, 10), _near),
          // Two of them, at different places. One on its own would prove
          // little: its box is empty wherever the union starts from it. Two
          // is the case that bites -- an empty box is a *point* at the
          // shape's origin, and unioning two points 60 pixels apart makes a
          // 60x60 rectangle out of two shapes that between them cover
          // nothing.
          const Positioned(
            left: 200,
            top: 200,
            child: Glass(
              shape: GlassOval(),
              material: _far,
              child: SizedBox.shrink(),
            ),
          ),
          const Positioned(
            left: 260,
            top: 260,
            child: Glass(
              shape: GlassOval(),
              material: _far,
              child: SizedBox.shrink(),
            ),
          ),
        ]),
      );

      final clips = _clipsAround<BackdropFilterLayer>(tester);
      expect(clips, hasLength(2));
      expect(
        clips.last,
        Rect.zero,
        reason:
            'a zero-extent shape has an empty box, and a pass with nothing '
            'but those draws nothing',
      );
      expect(
        clips.first,
        isNot(Rect.zero),
        reason: 'the other pass still has a real shape in it',
      );
    },
  );

  testWidgets(
    'the subtree is painted over the passes, never inside one, so a '
    "pass's clip cannot crop the page",
    (tester) async {
      await tester.pumpWidget(
        _scene(<Widget>[
          _square(const Offset(10, 10), _near),
          _square(const Offset(250, 250), _far),
          // Far from both shapes, and past either pass's clip.
          Positioned(
            left: 150,
            top: 0,
            child: Container(width: 60, height: 400, color: _ink),
          ),
        ]),
      );

      for (final clip in _clipsAround<PictureLayer>(tester)) {
        expect(
          clip == null || _covers(clip, _layerRect),
          isTrue,
          reason:
              'a picture inside a pass clip ($clip) is subtree content '
              "cropped to that pass's shapes",
        );
      }
    },
  );

  testWidgets(
    'a layer with one pass keeps the arrangement it always had: no clip of '
    'its own, and the subtree inside it',
    (tester) async {
      await tester.pumpWidget(
        _scene(<Widget>[
          _square(const Offset(10, 10), _near),
          _square(const Offset(250, 250), _near),
        ]),
      );

      expect(
        _clipsAround<BackdropFilterLayer>(tester),
        <Rect>[expandToPixelBuckets(_layerRect)],
        reason:
            'one pass stacks over nothing, so it is still pushed under the '
            "layer's own clip and nothing narrower",
      );
    },
  );
}

const Color _ink = Color(0xFF101014);
