import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shaders/shader_library.dart';
import 'package:glass_forge/src/shapes/shape_geometry.dart';

/// `RenderGlassShape` must never walk its ancestors from inside a layout
/// pass.
///
/// Three hosts that made it throw when it did, one per test: a `Transform`
/// on its first layout, a `FittedBox`, and a lazy `SliverList` building rows
/// as they scroll in. One walk, three hosts — and between them at least
/// three different exceptions: a `hasSize` assertion against a box that has
/// no size yet, a `sizeAccessAllowed` assertion against one that has a size
/// but sits above a relayout boundary, and a null check inside
/// `RenderSliverMultiBoxAdaptor.childMainAxisPosition`. So each test demands
/// that **nothing at all** was thrown rather than matching a message: a
/// message match pins an SDK line number, and there is no one message to
/// pin — it would wave through whichever exception shape it was not written
/// for.
///
/// Each test also pins where the shape ended up, against a position the
/// widget tree states rather than anything the package reports. "Nothing
/// threw" on its own would pass just as happily for a shape that quietly
/// stopped registering, and not registering is the failure mode the fix has
/// to avoid: the walk moved to paint, so a shape that never reached paint
/// would refract from a placeholder.
void main() {
  setUpAll(ShaderLibrary.instance.warmUp);

  /// Every shape the one `GlassLayer` on screen holds, top to bottom.
  ///
  /// Sorted because registration order is mount order, which a lazy list
  /// reshuffles as it recycles rows.
  List<ShapeGeometry> shapesOf(WidgetTester tester) {
    final layer = tester.renderObject<RenderGlassLayer>(
      find.byType(GlassLayer),
    );
    return layer.scene.shapes.toList()
      ..sort((a, b) => a.origin.dy.compareTo(b.origin.dy));
  }

  /// Runs [body] with every framework error collected instead of reported.
  ///
  /// Not `tester.takeException()`: the binding collapses several
  /// `FlutterErrorDetails` raised by one pump into a single synthetic
  /// "Multiple exceptions" string and discards the originals, so a real
  /// regression riding alongside a tolerated one would disappear, and the
  /// count — the thing that showed this fires once per row forever rather
  /// than once at launch — would be lost with it.
  Future<List<FlutterErrorDetails>> errorsFrom(
    Future<void> Function() body,
  ) async {
    final caught = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = caught.add;
    try {
      await body();
    } finally {
      FlutterError.onError = original;
    }
    return caught;
  }

  String describe(Iterable<FlutterErrorDetails> caught) =>
      caught.map((d) => '${d.exception}').join('\n--\n');

  testWidgets('a Glass under a Transform that has not been laid out', (
    tester,
  ) async {
    // `Transform.scale` aligns on its own centre, so `applyPaintTransform`
    // reads the RenderTransform's size. On its first layout it has none: it
    // is mid-`performLayout`, having just called down into this shape.
    // Material wraps every scroll view in one of these for its stretch
    // overscroll indicator, which is where this was first found.
    final dpr = tester.view.devicePixelRatio;
    final caught = await errorsFrom(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            tier: GeometryTier.none,
            child: Center(
              child: Transform.scale(
                scale: 0.5,
                child: const Glass(
                  shape: GlassOval(),
                  child: SizedBox(width: 200, height: 80),
                ),
              ),
            ),
          ),
        ),
      );
    });

    expect(
      caught,
      isEmpty,
      reason:
          'the walk threw under a Transform on its first layout:\n'
          '${describe(caught)}',
    );

    // Where it landed, derived from the tree above and nothing else: an
    // 800x600 test window centres a 200x80 box on (400, 300), and a scale
    // of 0.5 about that box's own centre leaves the centre alone and
    // halves both unit axes.
    final shapes = shapesOf(tester);
    expect(shapes, hasLength(1));
    expect(shapes.single.origin.dx, closeTo(400 * dpr, 0.01));
    expect(shapes.single.origin.dy, closeTo(300 * dpr, 0.01));
    expect(
      shapes.single.distanceScale,
      closeTo(0.5, 1e-6),
      reason:
          'the Transform half of the walk has to survive the move to '
          'paint, not just the offset half',
    );
  });

  testWidgets('a Glass under a FittedBox', (tester) async {
    // A `FittedBox` reads its own size *and* its child's from
    // `applyPaintTransform`, and holds a transform it only computes once it
    // has laid out. The catalogue example's index puts every row thumbnail
    // in one.
    final dpr = tester.view.devicePixelRatio;
    final caught = await errorsFrom(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassLayer(
            tier: GeometryTier.none,
            child: Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: FittedBox(
                  child: Glass(
                    shape: GlassOval(),
                    child: SizedBox(width: 200, height: 80),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });

    expect(
      caught,
      isEmpty,
      reason: 'the walk threw under a FittedBox:\n${describe(caught)}',
    );

    // `BoxFit.contain` of 200x80 into 60x60 is min(60/200, 60/80) = 0.3,
    // centred, so the specimen's centre stays on the window's centre.
    final shapes = shapesOf(tester);
    expect(shapes, hasLength(1));
    expect(shapes.single.origin.dx, closeTo(400 * dpr, 0.01));
    expect(shapes.single.origin.dy, closeTo(300 * dpr, 0.01));
    expect(shapes.single.distanceScale, closeTo(0.3, 1e-6));
  });

  testWidgets('a Glass in a lazy SliverList being scrolled', (tester) async {
    // The case that fires repeatedly rather than once. `RenderSliverList`
    // builds and lays out each row the first time it scrolls into range,
    // and assigns that row's `layoutOffset` only *after* laying it out — so
    // a walk from inside the row's own layout null-checks it. A lazy list
    // therefore re-raises this for the life of the scroll, not once at
    // launch: measured at 17 exceptions after the first frame, 81 after a
    // fling down and 144 after flinging back.
    //
    // Left on Material's default scroll behaviour deliberately. Its stretch
    // overscroll indicator is a `Transform`, so a fling that reaches either
    // end puts the first test's host on top of this one's.
    const rows = 40;
    const rowHeight = 100.0;
    final dpr = tester.view.devicePixelRatio;

    Widget app() => MaterialApp(
      home: GlassLayer(
        tier: GeometryTier.none,
        child: ListView.builder(
          itemCount: rows,
          itemBuilder: (context, i) => SizedBox(
            height: rowHeight,
            child: Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: FittedBox(
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
        ),
      ),
    );

    final firstFrame = await errorsFrom(() async {
      await tester.pumpWidget(app());
    });
    expect(
      firstFrame,
      isEmpty,
      reason:
          'the walk threw on the first frame of a lazy list:\n'
          '${describe(firstFrame)}',
    );

    // Every shape that can draw is exactly where the tree puts it, and
    // there are no others. A 600-tall viewport shows six 100-tall rows, so
    // their centres are 50, 150 ... 550 with the list at rest; each row
    // fits 200x80 into 60x60, which is a scale of 0.3.
    //
    // Both halves of that matter. The positions are the fix working. "No
    // others" is the fix not having invented one: a row built into the
    // cache region ahead of the viewport lays out but never paints, and
    // paint is now the only place a transform is read, so such a row has to
    // register something it cannot know. It registers a shape with no
    // interior — `distanceScale` 0, which the shader's coverage term
    // collapses — rather than the identity, which would park it at the
    // layer's own origin and refract there.
    expect(
      shapesOf(tester)
          .where((s) => s.distanceScale > 0)
          .map(
            (s) =>
                '${(s.origin.dx / dpr).toStringAsFixed(2)}, '
                '${(s.origin.dy / dpr).toStringAsFixed(2)}',
          )
          .toList(),
      <String>[
        '400.00, 50.00',
        '400.00, 150.00',
        '400.00, 250.00',
        '400.00, 350.00',
        '400.00, 450.00',
        '400.00, 550.00',
      ],
    );
    for (final shape in shapesOf(tester).where((s) => s.distanceScale > 0)) {
      expect(shape.distanceScale, closeTo(0.3, 1e-6));
    }

    final flungDown = await errorsFrom(() async {
      await tester.fling(
        find.byType(ListView),
        const Offset(0, -900),
        2000,
      );
      await tester.pumpAndSettle();
    });
    expect(
      flungDown,
      isEmpty,
      reason:
          'the walk threw on rows built by scrolling down — this is the '
          'one that repeats for the life of the list:\n'
          '${describe(flungDown)}',
    );

    final flungBack = await errorsFrom(() async {
      await tester.fling(find.byType(ListView), const Offset(0, 900), 2000);
      await tester.pumpAndSettle();
    });
    expect(
      flungBack,
      isEmpty,
      reason:
          'the walk threw on rows rebuilt scrolling back up:\n'
          '${describe(flungBack)}',
    );

    // And rows are still registering after all that, rather than having
    // quietly stopped: a viewport this tall shows six, every one of them
    // fitted to the same 0.3.
    final settled = shapesOf(tester).where((s) => s.distanceScale > 0);
    expect(
      settled.length,
      greaterThanOrEqualTo(600 ~/ rowHeight),
      reason:
          'rows stopped registering rather than stopped throwing; the '
          'scene holds ${shapesOf(tester).map((s) => s.origin).toList()}',
    );
    for (final shape in settled) {
      expect(shape.distanceScale, closeTo(0.3, 1e-6));
    }
    // Deliberately not asserted here: *where* those six sit once the list
    // has been flung. They are stale, and by a lot — rows that should be at
    // y = 2.6, 102.6, 202.6 ... register at 467.5, 518.8, 567.5 and so on.
    // `ListView` wraps every row in a `RepaintBoundary` and a scroll
    // re-lays out nothing, so a scrolled row neither paints nor lays out
    // and nothing ever asks it where it went.
    //
    // That is a separate defect and it is not this fix's: the same numbers
    // come out of the same probe with this fix reverted, and out of an
    // unfixed tree the exceptions above were merely hiding. Pinning it here
    // would be pinning the bug. It wants its own task.
  });
}
