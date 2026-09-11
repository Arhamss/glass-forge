import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// See `interactive_glass_test.dart` for why the material renders nothing.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// Records what the enclosing layer's scene held at the moment the layer
/// began painting its subtree.
///
/// Placed as the layer's direct child, so its `paint` runs inside
/// `RenderGlassLayer.paint`'s own `super.paint` — which is strictly after
/// `_refreshMatte()`, the call that reads the scene and bakes the matte for
/// this frame, and strictly before any descendant `RenderGlassShape` has had
/// a chance to re-register a moved transform.
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
  testWidgets(
    'the scene a layer reads at paint time is one frame behind the shape '
    'that re-registers during that same paint',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GlassLayer(
            tier: GeometryTier.none,
            material: _inert,
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

      // The frame just painted: the layer read the scene before the shape
      // wrote to it, so its matte is built from the previous frame's
      // transform. A fix would have to move the read after the subtree
      // paints; see the task report.
      expect(probe.revisionSeenByLayer, lessThan(layer.scene.revision));
      expect(
        probe.originSeenByLayer,
        isNot(layer.scene.shapes.single.origin),
      );

      // It is exactly one frame, not a permanent divergence: once the
      // surface stops moving the two agree again, which is why a static
      // glass layer refracts correctly.
      await gesture.up();
      var frames = 0;
      while (motion.controller.isAnimating && frames < 1200) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      await tester.pump(const Duration(milliseconds: 8));
      expect(probe.revisionSeenByLayer, layer.scene.revision);
      expect(probe.originSeenByLayer, layer.scene.shapes.single.origin);
    },
  );
}
