import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/geometry_producer.dart';
import 'package:glass_forge/src/geometry/matte_generation.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/glass_scene.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// Frost and nothing else.
///
/// Deliberately not the inert material `interactive_glass_test.dart` uses:
/// a material that renders nothing now means the layer pushes no backdrop
/// pass, so it never reaches the matte bake this file is entirely about.
/// Frost alone is the cheapest material that still does — and on the
/// untagged lane's software backend it composes to a plain blur rather than
/// to `ui.ImageFilter.shader`, which would throw there.
const GlassMaterial _frostOnly = GlassMaterial(
  frost: 5.5,
  edgeRefraction: 0,
  highlight: 0,
);

/// Records the scene each matte was baked from, and bakes nothing.
///
/// The point of observation the probe below cannot reach: what the layer
/// actually handed a producer is the scene the refraction is built out of,
/// and a null generation is a perfectly ordinary answer (see
/// `NullGeometryProducer`), so returning one costs this test nothing.
class _RecordingProducer implements GeometryProducer {
  final List<Offset> bakedOrigins = <Offset>[];

  @override
  GeometryCapabilities get capabilities =>
      const GeometryCapabilities(available: true, name: 'recording');

  @override
  Future<void> warmUp() async {}

  @override
  MatteGeneration? produce(GlassScene scene, MatteRequest request) {
    if (scene.shapes.isNotEmpty) {
      bakedOrigins.add(scene.shapes.first.origin);
    }
    return null;
  }

  @override
  void release(MatteGeneration generation) {}

  @override
  void dispose() {}
}

/// Records what the enclosing layer's scene held at the moment the layer
/// began painting its subtree.
///
/// Placed as the layer's direct child, so its `paint` runs inside
/// `RenderGlassLayer.paint`'s own subtree paint — strictly before any
/// descendant `RenderGlassShape` has had a chance to re-register a moved
/// transform, and therefore strictly before the scene describes this frame.
/// That much is unchanged by the fix and cannot be fixed: the scene is
/// written by the shapes as they paint. What the fix moved is the *bake*,
/// from ahead of this point to behind it.
class _RenderSceneProbe extends RenderProxyBox {
  int paints = 0;
  int? revisionSeenByLayer;
  Offset? originSeenByLayer;

  @override
  void paint(PaintingContext context, Offset offset) {
    var node = parent;
    while (node != null && node is! RenderGlassLayer) {
      node = node.parent;
    }
    if (node is RenderGlassLayer) {
      paints++;
      revisionSeenByLayer = node.scene.revision;
      final shapes = node.scene.shapes;
      originSeenByLayer = shapes.isEmpty ? null : shapes.first.origin;
    }
    super.paint(context, offset);
  }
}

class _SceneProbe extends SingleChildRenderObjectWidget {
  const _SceneProbe({required Widget super.child});

  @override
  _RenderSceneProbe createRenderObject(BuildContext context) =>
      _RenderSceneProbe();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  late _RecordingProducer producer;

  setUp(() {
    ProducerRegistry.debugReset();
    producer = _RecordingProducer();
    ProducerRegistry.registerAccelerated(() => producer);
  });

  tearDown(() {
    ProducerRegistry.debugReset();
    debugResetAcceleratedProducerRegistration();
  });

  testWidgets(
    'the matte an animating layer bakes describes where its shape just '
    'painted, not where it was a frame ago',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GlassLayer(
            tier: GeometryTier.accelerated,
            material: _frostOnly,
            child: _SceneProbe(
              child: Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: InteractiveGlass(
                    pressScale: 1,
                    drag: GlassDrag(overdrag: GlassOverdrag.none()),
                    child: Glass(
                      shape: GlassRoundedRectangle(
                        radius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final probe = tester.renderObject<_RenderSceneProbe>(
        find.byType(_SceneProbe),
      );
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      final motion = tester.renderObject<RenderGlassMotion>(
        find.byType(InteractiveGlass),
      );

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));

      final paintsBefore = probe.paints;
      producer.bakedOrigins.clear();
      await tester.pump(const Duration(milliseconds: 8));
      expect(
        motion.controller.isAnimating,
        isTrue,
        reason: 'nothing was moving, so there was no lag to observe',
      );
      expect(
        probe.paints,
        greaterThan(paintsBefore),
        reason: 'the layer did not repaint on an animating frame at all, '
            'which would mean the matte never updates rather than updating '
            'late',
      );
      expect(
        producer.bakedOrigins,
        isNotEmpty,
        reason: 'the layer repainted without baking anything, so this frame '
            'says nothing about when the bake happens',
      );

      final origin = layer.scene.shapes.single.origin;

      // The regression. Until the backdrop pass was pushed first and its
      // filter filled in after the subtree painted, the bake ran ahead of
      // the shape's own paint and could only ever see the previous frame's
      // transform -- so every moving surface refracted one frame behind its
      // own pixels.
      expect(
        producer.bakedOrigins.last,
        origin,
        reason: 'the matte was baked from the scene as the previous frame '
            'left it',
      );

      // The control, and the reason the probe is here at all: on this frame
      // the scene really did change *during* the subtree paint. Without
      // this, the assertion above would also hold on a frame where nothing
      // moved, which is to say on a frame that proves nothing.
      expect(
        probe.revisionSeenByLayer,
        lessThan(layer.scene.revision),
        reason: 'the shape registered nothing while this frame painted, so '
            'baking before or after it would look identical',
      );
      expect(probe.originSeenByLayer, isNot(origin));

      // And it converges: the surface comes to rest with the matte already
      // describing where it came to rest, without a further frame being
      // needed to catch up. The count is the half that matters -- a layer
      // that kept re-baking a settled scene would satisfy the origin check
      // on every frame forever while doing the work of an animation.
      await gesture.up();
      var frames = 0;
      while (motion.controller.isAnimating && frames < 1200) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      final settled = layer.scene.shapes.single.origin;
      expect(producer.bakedOrigins.last, settled);

      final bakesAtRest = producer.bakedOrigins.length;
      await tester.pump(const Duration(milliseconds: 8));
      await tester.pump(const Duration(milliseconds: 8));
      expect(producer.bakedOrigins.length, bakesAtRest);
      expect(layer.scene.shapes.single.origin, settled);
    },
  );

  testWidgets(
    'a shape behind a repaint boundary still reaches a matte, one frame '
    'later, because the layer never painted with it',
    (tester) async {
      // The one case `RenderGlassShape._scheduleLayerRepaint` still exists
      // for. A repaint boundary between the layer and the shape lets the
      // shape repaint on its own: the layer is not painting, so the bake
      // that now follows a subtree paint never happens, and without the
      // deferred repaint the move would never reach a matte at all.
      final key = GlobalKey();
      Widget build(double left) => Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          tier: GeometryTier.accelerated,
          material: _frostOnly,
          child: RepaintBoundary(
            key: key,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: left,
                  top: 10,
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: Glass(shape: GlassOval()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(10));
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      final before = layer.scene.shapes.single.origin;

      // Repainting only the boundary's subtree: `Positioned` inside a
      // `Stack` changes the child's offset without changing its incoming
      // constraints, so the shape's own `performLayout` never runs and the
      // move is caught at paint time or not at all.
      await tester.pumpWidget(build(90));
      producer.bakedOrigins.clear();
      await tester.pump();

      final after = layer.scene.shapes.single.origin;
      expect(after.dx, greaterThan(before.dx));
      expect(
        producer.bakedOrigins,
        isNotEmpty,
        reason: 'the layer was never asked to repaint, so the matte still '
            'describes where the shape used to be',
      );
      expect(producer.bakedOrigins.last, after);
    },
  );
}
