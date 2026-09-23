import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// A `Glass` that is scrolled must register where it now is.
///
/// Scrolling is the one motion nothing in the render tree reports to a glass
/// layer. `ListView` wraps every row in a `RepaintBoundary`, and a scroll
/// re-lays out nothing, so a scrolled row's own `performLayout` and `paint`
/// are both skipped — and `RenderViewportBase.isRepaintBoundary` is true, so
/// the layer *above* the viewport is not asked to paint either. Nothing at
/// all runs, and the layer goes on refracting the positions its rows held
/// when they were last painted.
///
/// Every expectation below is sourced from the widget tree through
/// `tester.getCenter`, never from the layer: the scene is the thing under
/// test, so an expectation read out of the scene would agree with it however
/// wrong it was. And every check counts what it actually compared, because
/// the finders here can legitimately come up empty — a lazy list recycles
/// rows — and a silent zero would pass as loudly as a hundred matches.
void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  const rowHeight = 100.0;
  const rows = 40;
  const viewportHeight = 600.0;

  /// What the layer holds for each shape, keyed by the render object that
  /// registered it.
  ///
  /// `shapeOwners` and `shapes` are the same map's keys and values, so they
  /// are in the same order.
  Map<RenderObject, ShapeGeometry> sceneByOwner(WidgetTester tester) {
    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );
    final owners = layer.scene.shapeOwners.toList();
    final shapes = layer.scene.shapes;
    expect(owners, hasLength(shapes.length));
    return <RenderObject, ShapeGeometry>{
      for (var i = 0; i < owners.length; i++) owners[i]: shapes[i],
    };
  }

  Widget listUnderALayer(ScrollController controller) => MaterialApp(
    home: GlassLayer(
      tier: GeometryTier.none,
      child: ListView.builder(
        controller: controller,
        itemCount: rows,
        itemBuilder: (context, i) => SizedBox(
          height: rowHeight,
          child: Center(
            child: Glass(
              shape: const GlassOval(),
              child: SizedBox(
                key: ValueKey<int>(i),
                width: 200,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Every mounted row's registered origin against where the tree puts it.
  void expectSceneMatchesTree(WidgetTester tester, String when) {
    final scene = sceneByOwner(tester);
    final dpr = tester.view.devicePixelRatio;
    var compared = 0;
    for (var i = 0; i < rows; i++) {
      final row = find.byKey(ValueKey<int>(i), skipOffstage: false);
      if (row.evaluate().isEmpty) {
        continue;
      }
      final owner = tester.renderObject(
        find.ancestor(
          of: row,
          matching: find.byType(Glass, skipOffstage: false),
        ),
      );
      final geometry = scene[owner];
      expect(
        geometry,
        isNotNull,
        reason: 'row $i is mounted $when but the layer does not hold it',
      );
      if (geometry!.distanceScale == 0) {
        // A row built into the cache region ahead of the viewport, which
        // has laid out but never painted. It deliberately registers a
        // shape with no interior rather than inventing a position — see
        // `RenderGlassShape._nowhereYet` — and there is nothing here to
        // compare it against.
        continue;
      }
      expect(
        geometry.origin.dy / dpr,
        closeTo(tester.getCenter(row).dy, 0.01),
        reason: 'row $i sits at y = ${tester.getCenter(row).dy} $when',
      );
      compared++;
    }
    expect(
      compared,
      greaterThanOrEqualTo(viewportHeight ~/ rowHeight),
      reason:
          'only $compared rows had a drawable shape to compare $when, so '
          'this check passed without checking the viewport',
    );
  }

  testWidgets('a scrolled row registers where it now is, not where it '
      'last painted', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(listUnderALayer(controller));

    expectSceneMatchesTree(tester, 'at rest');

    // Deliberately not a multiple of [rowHeight], and deliberately small
    // enough that no row is recycled: a jump that replaces every mounted
    // row builds fresh ones, which lay out and paint and so register
    // correctly whatever this layer does. Thirty pixels moves the same six
    // rows without re-laying out or repainting any of them, which is the
    // case that was wrong.
    controller.jumpTo(30);
    await tester.pump();
    expectSceneMatchesTree(tester, 'after a 30-pixel scroll');

    // And it keeps tracking rather than correcting once: three more small
    // scrolls, each one a fresh chance to freeze.
    for (final offset in <double>[47, 61.5, 88]) {
      controller.jumpTo(offset);
      await tester.pump();
      expectSceneMatchesTree(tester, 'after scrolling to $offset');
    }

    // A fling, which recycles rows as well as moving them.
    await tester.fling(find.byType(ListView), const Offset(0, -900), 2000);
    await tester.pumpAndSettle();
    expectSceneMatchesTree(tester, 'after a fling');
  });

  testWidgets('a row scrolled out of the viewport registers its real '
      'position rather than the last one on screen', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(listUnderALayer(controller));

    // Row 0's centre starts at y = 50. Scrolling by 180 puts it at -130,
    // above the viewport but still inside the cache region, so it is still
    // mounted and still registered — and where it is registered is the
    // whole question, since -130 is exactly the number a layer that only
    // hears from rows that paint can never arrive at.
    controller.jumpTo(180);
    await tester.pump();

    final row = find.byKey(const ValueKey<int>(0), skipOffstage: false);
    expect(
      row.evaluate(),
      isNotEmpty,
      reason: 'row 0 was recycled, so this proves nothing about it',
    );
    expect(tester.getCenter(row).dy, closeTo(-130, 0.01));

    final owner = tester.renderObject(
      find.ancestor(
        of: row,
        matching: find.byType(Glass, skipOffstage: false),
      ),
    );
    final geometry = sceneByOwner(tester)[owner];
    expect(geometry, isNotNull, reason: 'row 0 is not registered at all');
    expect(
      geometry!.origin.dy / tester.view.devicePixelRatio,
      closeTo(-130, 0.01),
    );
  });
}
