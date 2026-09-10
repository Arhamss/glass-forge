// Requires the Impeller rendering engine: `ui.ImageFilter.shader`, exercised
// by every test below via `GlassComposition.build`, throws `UnsupportedError`
// under flutter_tester's default software backend. See dart_test.yaml and
// the file-level note in glass_widgets_test.dart for the two-invocation
// pattern this repo uses everywhere else.
@Tags(<String>['impeller'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';

Widget _glassInList(ScrollController controller) {
  return MaterialApp(
    home: ListView.builder(
      controller: controller,
      itemCount: 200,
      itemBuilder: (context, index) => SizedBox(
        height: 60,
        child: index == 0
            ? const GlassLayer(
                child: Glass(
                  shape: GlassRoundedRectangle(
                    radius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: SizedBox(width: 200, height: 48),
                ),
              )
            : Text('row $index'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);
  setUp(GlassRenderCounters.instance.reset);

  testWidgets('a static layer bakes exactly one matte', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassOval(),
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );
    final afterFirst = GlassRenderCounters.instance.matteProduceCount;
    // Pinned to a literal, not just compared against itself below: a bug
    // that baked more than once on the very first paint would otherwise go
    // undetected, since afterFirst would simply capture whatever the wrong
    // count already was.
    expect(afterFirst, 1);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(GlassRenderCounters.instance.matteProduceCount, afterFirst);
  });

  testWidgets('scrolling bakes no new mattes', (tester) async {
    // ACCEPTANCE CRITERION 4. Upstream re-rasterises every scroll frame,
    // because its layout override dirties geometry before constraints
    // short-circuit. liquid_glass_widgets documents that its best tier "may
    // not render correctly inside ListView on Impeller" and tells users to
    // avoid it. Zero is the bar.
    final controller = ScrollController();
    await tester.pumpWidget(_glassInList(controller));
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();

    for (var i = 0; i < 20; i++) {
      controller.jumpTo(controller.offset + 12);
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      GlassRenderCounters.instance.matteProduceCount,
      0,
      reason: 'scrolling changed no shape geometry, so nothing needed baking',
    );

    controller.dispose();
  });

  test(
    'repeated layout with unchanged geometry does not rebake the matte '
    '(regression: GlassScene revision caching)',
    () async {
      // The scroll test above cannot exercise this path. ListView.builder
      // wraps every item in its own RepaintBoundary by default, and this
      // item's SizedBox gives it identical BoxConstraints on every frame, so
      // RenderObject.layout()'s own "same constraints, not dirty" shortcut
      // means neither performLayout() nor paint() runs again anywhere in
      // this subtree for the whole 20-frame scroll -- confirmed empirically
      // while writing this suite by instrumenting both methods directly.
      // That makes the scroll test a genuine, valuable guard against a
      // layout override that defeats that shortcut (upstream's actual bug),
      // but it never calls GlassScene.register a second time, so it cannot
      // catch a regression in _sameGeometry's tolerance itself. Driving the
      // render objects directly and calling performLayout() by hand is the
      // only way to force that call to happen and prove the revision holds
      // across it.
      await ShaderLibrary.instance.warmUp();
      GlassRenderCounters.instance.reset();

      final owner = PipelineOwner();
      final layer =
          RenderGlassLayer(
            material: const GlassMaterial(),
            tier: GeometryTier.portable,
            devicePixelRatio: 1,
          )
          ..attach(owner);
      final shape = RenderGlassShape(shape: const GlassOval(), group: null)
        ..child = RenderConstrainedBox(
          additionalConstraints: BoxConstraints.tight(const Size(80, 80)),
        );
      layer.child = shape;
      owner.flushCompositingBits();
      layer.layout(const BoxConstraints.tightFor(width: 80, height: 80));

      final rootLayer = ContainerLayer();
      final context = PaintingContext(rootLayer, Rect.largest);
      layer.paint(context, Offset.zero);
      final afterFirst = GlassRenderCounters.instance.matteProduceCount;
      expect(afterFirst, 1);

      for (var i = 0; i < 5; i++) {
        // markNeedsLayout() is required: shape is its own relayout boundary
        // (its incoming constraints are tight), so layout() would otherwise
        // hit RenderObject's own "same constraints, not dirty" shortcut and
        // never reach performLayout() at all -- reproducing the very gap
        // this test exists to close.
        shape.markNeedsLayout();
        shape.layout(shape.constraints, parentUsesSize: true);
      }
      layer.paint(context, Offset.zero);

      expect(
        GlassRenderCounters.instance.matteProduceCount,
        afterFirst,
        reason:
            'geometry did not change, so re-registering it should not bump '
            'GlassScene.revision or trigger a rebake',
      );

      rootLayer.dispose();
      // Disposing releases the finalRender shader GlassComposition.build()
      // checked out above back to ShaderLibrary's pool. Without this, the
      // shader stays outstanding for the rest of this file -- ShaderLibrary
      // is only reset once, in tearDownAll -- and inflates
      // debugOutstandingCount in the leak test below by one, permanently.
      layer.dispose();
    },
  );

  testWidgets('one layer pushes one backdrop filter per frame', (
    tester,
  ) async {
    // ACCEPTANCE CRITERION 2, and the flutter#187820 guard: two stacked
    // filters would show up here as two pushes.
    //
    // Checked straight after pumpWidget, not after a further pump(): a
    // static tree with nothing dirtied does not repaint on a later pump
    // (confirmed empirically while writing this suite -- see the scroll
    // test above), so resetting the counter after the widget has already
    // settled and only then checking it would just measure a pump that
    // never repaints anything, no matter how many backdrops the real paint
    // pushed. setUp() above already resets the counter before this test
    // starts, so what backdropPushCount holds here is exactly what the one
    // real paint call produced.
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Glass(
            shape: GlassOval(),
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    expect(
      GlassRenderCounters.instance.backdropPushCount,
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('changing a shape does bake a new matte', (tester) async {
    // The counter would be trivially satisfiable if nothing ever rebuilt.
    Widget build(double radius) => MaterialApp(
      home: GlassLayer(
        child: Glass(
          shape: GlassRoundedRectangle(
            radius: BorderRadius.all(Radius.circular(radius)),
          ),
          child: const SizedBox(width: 80, height: 80),
        ),
      ),
    );

    await tester.pumpWidget(build(8));
    GlassRenderCounters.instance.reset();
    await tester.pumpWidget(build(24));
    await tester.pump();

    expect(GlassRenderCounters.instance.matteProduceCount, greaterThan(0));
  });

  testWidgets('an idle material pushes no backdrop at all', (tester) async {
    // Checked straight after pumpWidget, for the same reason as the
    // backdrop-per-frame test above: a static tree does not repaint on a
    // later pump(), so an erroneous push on the one real paint call would
    // be invisible to a check that resets the counter afterwards. setUp()
    // already reset it before this test started.
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          material: GlassMaterial(frost: 0, edgeRefraction: 0, highlight: 0),
          child: Glass(
            shape: GlassOval(),
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );

    expect(GlassRenderCounters.instance.backdropPushCount, 0);
  });

  testWidgets('mounting and unmounting 200 times leaks nothing', (
    tester,
  ) async {
    // ACCEPTANCE CRITERION 7. flutter_shaders' ShaderBuilder has no dispose,
    // so upstream leaks a FragmentShader per glass widget.
    //
    // The brief specifies 1000 cycles; measured at ~0.59s/cycle under real
    // Impeller (~9m50s total), which dominates this suite's runtime by two
    // orders of magnitude over every other test combined. A persistent
    // per-mount leak (what this guards against, and what upstream actually
    // has) shows up as a monotonically growing count from the very first
    // cycle, so it is caught just as reliably at a smaller count. Reduced
    // to 200 (~2 minutes) per the task brief's explicit allowance to shrink
    // an impractically slow cycle count rather than delete the test.
    for (var i = 0; i < 200; i++) {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            child: Glass(
              shape: GlassOval(),
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }

    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });
}
