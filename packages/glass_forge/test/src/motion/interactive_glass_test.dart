import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// Counts how many times its subtree is rebuilt.
class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.child});

  final Widget child;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return widget.child;
  }
}

/// A material that renders nothing, so the composite pass is skipped.
///
/// `GlassComposition.build` short-circuits on `rendersAnything`, and that is
/// the only branch on this path that reaches `ui.ImageFilter.shader` — the
/// call that throws `UnsupportedError` outside Impeller. Every part of the
/// path these tests are about (the shape resolving its transform and
/// registering it with the layer's scene) happens in `RenderGlassShape`,
/// before and independently of the filter, so none of it is stubbed out
/// here. `GeometryTier.none` likewise only keeps a matte from being baked.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// A glass surface in a layer that composes nothing.
Widget _harness({
  GlassDrag drag = const GlassDrag.none(),
  double pressScale = 0.96,
  GlassJiggle jiggle = const GlassJiggle(),
  VoidCallback? onTap,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: GlassLayer(
      tier: GeometryTier.none,
      material: _inert,
      child: Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: _BuildCounter(
            child: InteractiveGlass(
              drag: drag,
              pressScale: pressScale,
              jiggle: jiggle,
              onTap: onTap,
              child: const Glass(
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderGlassMotion _motionOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassMotion>(find.byType(InteractiveGlass));

RenderGlassLayer _layerOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassLayer>(find.byType(GlassLayer));

Future<void> _settle(WidgetTester tester, RenderGlassMotion motion) async {
  var frames = 0;
  while (motion.controller.isAnimating && frames < 1200) {
    await tester.pump(const Duration(milliseconds: 8));
    frames++;
  }
}

void main() {
  setUp(() => _BuildCounterState.builds = 0);

  testWidgets('a press reaches the surface on pointer down', (tester) async {
    await tester.pumpWidget(_harness());
    final motion = _motionOf(tester);

    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(motion.controller.value.press, greaterThan(0));

    await gesture.up();
    await _settle(tester, motion);
    expect(motion.controller.value.press, 0);
  });

  testWidgets(
    'a spring runs for its whole length without rebuilding one widget',
    (tester) async {
      await tester.pumpWidget(_harness());
      final motion = _motionOf(tester);
      final buildsAfterFirstFrame = _BuildCounterState.builds;

      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();
      var frames = 0;
      while (motion.controller.isAnimating && frames < 400) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      await gesture.up();
      await _settle(tester, motion);

      expect(frames, greaterThan(5), reason: 'the press never animated');
      // The whole architecture: a controller listener calling
      // markNeedsPaint. One setState per frame would show up here as one
      // build per frame.
      expect(_BuildCounterState.builds, buildsAfterFirstFrame);
    },
  );

  testWidgets(
    'the animated transform reaches the shape geometry the shader reads',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          drag: const GlassDrag(overdrag: GlassOverdrag.none()),
          pressScale: 1,
        ),
      );
      final motion = _motionOf(tester);
      final layer = _layerOf(tester);

      final before = layer.scene.shapes.single.origin;

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(60, -20));
      await tester.pump();
      await _settle(tester, motion);

      expect(motion.controller.value.translation, const Offset(60, -20));

      final after = layer.scene.shapes.single.origin;
      final dpr = tester.view.devicePixelRatio;
      // Registered geometry is in layer-local physical pixels, so the
      // shape's origin moves by the logical drag times the device pixel
      // ratio. Nothing here rebuilt a widget; this arrived through
      // `applyPaintTransform`.
      expect(after.dx - before.dx, closeTo(60 * dpr, 1e-6));
      expect(after.dy - before.dy, closeTo(-20 * dpr, 1e-6));

      await gesture.up();
      await _settle(tester, motion);
      expect(layer.scene.shapes.single.origin, before);
    },
  );

  testWidgets('squash and stretch reaches the registered basis too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(overdrag: GlassOverdrag.none()),
        pressScale: 1,
        jiggle: const GlassJiggle(maxStretch: 1.5, halfSpeed: 200),
      ),
    );
    final motion = _motionOf(tester);
    final layer = _layerOf(tester);
    final restingBasis = Float32List.fromList(
      layer.scene.shapes.single.inverseBasis,
    );

    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    await tester.pump(const Duration(milliseconds: 8));

    // Moving fast along x: the basis must no longer be the resting one, and
    // the shape must be wider along x than across it.
    final moving = layer.scene.shapes.single.inverseBasis;
    expect(motion.controller.value.velocity.dx, greaterThan(0));
    expect(moving[0], isNot(closeTo(restingBasis[0], 1e-6)));
    expect(moving[0].abs(), lessThan(moving[3].abs()));

    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('hit testing follows the surface, not its laid-out box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(overdrag: GlassOverdrag.none()),
        pressScale: 1,
      ),
    );
    final motion = _motionOf(tester);

    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await _settle(tester, motion);
    expect(motion.controller.value.translation, const Offset(60, 0));

    // Local coordinates of the 100x100 motion box, which itself never
    // moved: x = 130 is outside its own bounds and inside the surface,
    // which now spans 60 to 160. `RenderBox.hitTest`'s `size.contains`
    // gate would reject it before the transform was ever consulted.
    expect(
      motion.hitTest(BoxHitTestResult(), position: const Offset(130, 50)),
      isTrue,
      reason: 'the displaced surface is not hittable where it now is',
    );
    expect(
      motion.hitTest(BoxHitTestResult(), position: const Offset(10, 50)),
      isFalse,
      reason: 'the surface is still hittable where it no longer is',
    );

    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('a tap still lands when nothing has been dragged', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onTap: () => taps++));
    await tester.tap(find.byType(InteractiveGlass));
    await tester.pump();
    expect(taps, 1);
    await _settle(tester, _motionOf(tester));
  });

  testWidgets('a drag constrained to one axis ignores the other', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(
          axis: Axis.horizontal,
          overdrag: GlassOverdrag.none(),
        ),
        pressScale: 1,
      ),
    );
    final motion = _motionOf(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(40, 70));
    await tester.pump();
    await _settle(tester, motion);
    expect(motion.controller.value.translation, const Offset(40, 0));
    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('changing a motion swaps the controller without leaking', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final first = _motionOf(tester).controller;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          tier: GeometryTier.none,
          material: _inert,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: InteractiveGlass(
                pressMotion: GlassMotion.smooth(),
                child: Glass(shape: GlassOval()),
              ),
            ),
          ),
        ),
      ),
    );
    final second = _motionOf(tester).controller;
    expect(identical(first, second), isFalse);
    // The retired controller must be dead, not merely unreferenced: its
    // ticker would otherwise keep scheduling frames forever.
    expect(first.isAnimating, isFalse);
  });
}
