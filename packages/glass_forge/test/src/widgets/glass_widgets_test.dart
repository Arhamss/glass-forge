// `GlassLayer`'s shaders are already warm by the time these tests pump their
// first frame (see `setUpAll`), so its render object takes the real path
// through `GlassComposition`, which constructs `ui.ImageFilter.shader`. That
// throws `UnsupportedError` outside Impeller, so — like
// `glass_composition_test.dart` — this file is excluded from a bare
// `flutter test` run (see dart_test.yaml) and only runs via the separate
// `flutter test --tags impeller --run-skipped --enable-impeller` CI step.
@Tags(<String>['impeller'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/scene/blend_group_link.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ShaderLibrary.instance.warmUp);
  tearDownAll(ShaderLibrary.instance.disposeAll);

  testWidgets('a glass child paints in place, not deferred', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: Center(
            child: Glass(
              shape: GlassRoundedRectangle(
                radius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text('visible'),
            ),
          ),
        ),
      ),
    );

    // Upstream's children are invisible until both shaders load, because its
    // paint() is a no-op and the layer paints them later.
    expect(find.text('visible'), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.text('visible'));
    expect(box.hasSize, isTrue);
  });

  testWidgets('Glass outside a layer still renders', (tester) async {
    // Upstream asserts in debug and null-crashes in release. Create an
    // implicit layer instead and warn.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: Glass(shape: GlassOval(), child: Text('orphan'))),
      ),
    );
    expect(find.text('orphan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more shapes than the cap degrade, never blank the UI', (
    tester,
  ) async {
    // Upstream throws UnsupportedError from inside paint(): a red box in
    // debug, and in release the whole layer plus every child stops painting.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Stack(
            children: <Widget>[
              for (var i = 0; i < 40; i++)
                Positioned(
                  left: i * 4.0,
                  child: const Glass(
                    shape: GlassOval(),
                    child: SizedBox(width: 10, height: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(GlassLayer), findsOneWidget);
  });

  testWidgets('disposing a layer leaks no shaders', (tester) async {
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
    await tester.pump();

    expect(ShaderLibrary.instance.debugOutstandingCount, 0);
  });

  testWidgets('a two-shape blend group has exactly one starter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: GlassBlendGroup(
            blend: 16,
            child: Row(
              children: <Widget>[
                Glass(
                  shape: GlassOval(),
                  child: SizedBox(width: 20, height: 20),
                ),
                Glass(
                  shape: GlassRoundedRectangle(radius: BorderRadius.zero),
                  child: SizedBox(width: 20, height: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );
    final markers = layer.scene.shapes
        .map((g) => decodeBlendMarker(g.blendMarker))
        .toList();

    expect(markers, hasLength(2));
    expect(markers.where((m) => m.startsGroup), hasLength(1));
    // The marker carries the smooth-min's own width, in physical pixels:
    // twice the blend (the widest gap that merges -- the smooth-min lowers
    // the surface by a quarter of its width) at this view's pixel ratio.
    // It used to carry the logical 16 untouched, which on this 3x view ran
    // the merge six times too narrow.
    for (final marker in markers) {
      expect(
        marker.blend,
        closeTo(2 * 16 * tester.view.devicePixelRatio, 1e-9),
      );
    }
  });

  testWidgets(
    'the surviving member becomes the new starter when the first one '
    'unmounts (regression: a vanished starter blends nothing)',
    (tester) async {
      Widget buildTree({required bool includeFirst}) {
        return MaterialApp(
          home: GlassLayer(
            child: GlassBlendGroup(
              child: Row(
                children: <Widget>[
                  if (includeFirst)
                    const Glass(
                      key: ValueKey('first'),
                      shape: GlassOval(),
                      child: SizedBox(width: 20, height: 20),
                    ),
                  const Glass(
                    key: ValueKey('second'),
                    shape: GlassRoundedRectangle(radius: BorderRadius.zero),
                    child: SizedBox(width: 20, height: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTree(includeFirst: true));
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );

      var starters = layer.scene.shapes.where(
        (g) => decodeBlendMarker(g.blendMarker).startsGroup,
      );
      expect(starters, hasLength(1));
      expect(starters.single.type, ShapeType.ellipse);

      await tester.pumpWidget(buildTree(includeFirst: false));

      // No extra pump beyond the rebuild: the surviving shape's marker must
      // already be correct from BlendGroupLink's own notification, not from
      // some later, unrelated layout pass.
      starters = layer.scene.shapes.where(
        (g) => decodeBlendMarker(g.blendMarker).startsGroup,
      );
      expect(starters, hasLength(1));
      expect(starters.single.type, ShapeType.roundedRectangle);
    },
  );

  testWidgets(
    'a Glass positioned via Positioned inside a fixed-size Stack registers '
    'geometry matching that position on its very first paint, and follows '
    'a later move with no intervening relayout '
    '(regression: RenderGlassShape.performLayout runs before RenderStack '
    "assigns this pass's Positioned offset, so the transform read from "
    'inside performLayout is stale on the very first layout -- trusting '
    'that stale value as a paint-time baseline, instead of registering '
    'the transform paint actually reads, left a never-moved-again shape '
    'permanently wrong; a shape that does move again only looked correct '
    'because the next move happened to overwrite it)',
    (tester) async {
      Widget buildTree(double left, double top) {
        return MaterialApp(
          home: GlassLayer(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                children: [
                  Positioned(
                    left: left,
                    top: top,
                    width: 20,
                    height: 20,
                    child: const Glass(
                      shape: GlassRoundedRectangle(radius: BorderRadius.zero),
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Non-zero on both axes: a stale, offset-less first-layout transform
      // and a correct one both read as `Offset.zero`-derived only by
      // coincidence when left and top start at zero, which would let that
      // bug pass silently.
      await tester.pumpWidget(buildTree(20, 30));
      final layer = tester.renderObject<RenderGlassLayer>(
        find.byType(GlassLayer),
      );
      final dpr = tester.view.devicePixelRatio;
      final initialOrigin = layer.scene.shapes.single.origin;

      // ShapeGeometry.origin is the shape's centre, not its top-left corner
      // (the SDF evaluates `abs(local) - halfExtent`, see
      // shape_geometry.dart) -- the 20x20 Positioned's centre sits 10
      // logical px past its own left/top.
      expect(
        initialOrigin,
        offsetMoreOrLessEquals(const Offset(30, 40) * dpr, epsilon: 0.5),
        reason: 'the geometry registered on the very first paint does not '
            "match this Positioned's own offset -- performLayout's stale "
            'transform is what stuck',
      );

      final initialRevision = layer.scene.revision;

      // Same width/height as before, only left changed -- Stack relayouts
      // (its own parent data changed) and repositions the child at paint
      // time, but the child's own incoming constraints are identical, so
      // Flutter skips its performLayout unless something else forces it.
      await tester.pumpWidget(buildTree(100, 30));

      expect(
        layer.scene.revision,
        greaterThan(initialRevision),
        reason: 'moving the shape did not register as a scene change',
      );
      expect(
        layer.scene.shapes.single.origin,
        isNot(equals(initialOrigin)),
        reason: "the registered geometry did not follow the shape's new "
            'Positioned offset',
      );
    },
  );
}
