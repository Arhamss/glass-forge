import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/main.dart' as app;
import 'package:glass_forge_example/src/catalogue/catalogue.dart';
import 'package:glass_forge_example/src/catalogue/entry_page.dart';
import 'package:glass_forge_example/src/catalogue/index_page.dart';

/// Glass inside a scroll view that is being overscrolled must raise
/// nothing.
///
/// Material's stretch overscroll indicator scales the whole viewport with
/// a `Transform` (the Impeller shader path is unavailable here, so
/// `StretchEffect` falls back to one), and a `Transform` between a shape
/// and its `GlassLayer` is exactly the ancestor
/// `RenderGlassShape._syncGeometry` used to walk mid-layout and throw
/// against. Until the walk moved to paint, the example carried three
/// `ScrollConfiguration(...copyWith(overscroll: false))` overrides — one
/// app-wide in `main.dart`, one on each catalogue page — to keep that
/// `Transform` out of the tree entirely. All three are gone; these tests
/// are what stops them coming back unnoticed.
///
/// Each test collects every framework error through `FlutterError.onError`
/// rather than reading one back through `tester.takeException()`, which
/// collapses several `FlutterErrorDetails` from a single pump into one
/// synthetic string and throws the originals away. The count matters here:
/// the old failure fired once per row, every frame.
///
/// And each test proves the stretch actually engaged before believing that
/// nothing threw. An overscroll that never reached the indicator would
/// leave a scroll view with no `Transform` over it at all, and the test
/// would pass by testing nothing.
void main() {
  /// Runs [body] with every framework error collected instead of reported.
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
      caught.map((details) => '${details.exception}').join('\n--\n');

  /// The vertical scale the stretch indicator is applying right now.
  ///
  /// Read off the one `Transform` that is both inside Material's
  /// [StretchEffect] and above the `Viewport` — the ancestor a glass row's
  /// transform walk has to cross. `StretchEffect.stretchStrength` would
  /// say the indicator engaged without saying a `Transform` is what it
  /// engaged with, and the `Transform` is the whole reason these pages
  /// were once kept away from it.
  double stretchScale(WidgetTester tester) {
    final transform = find.ancestor(
      of: find.byType(Viewport),
      matching: find.descendant(
        of: find.byType(StretchEffect),
        matching: find.byType(Transform),
      ),
    );
    expect(
      transform,
      findsOneWidget,
      reason:
          'the stretch indicator no longer puts a Transform over the '
          'viewport, so this test would no longer be exercising the walk '
          'it exists to exercise',
    );
    // Column-major: index 5 is the matrix's y scale, which is the axis
    // `StretchEffect` stretches a vertical viewport along.
    return tester.widget<Transform>(transform).transform.storage[5];
  }

  /// Drags the scroll view down past its top edge and returns the largest
  /// stretch seen on the way.
  ///
  /// A held gesture moved in steps rather than `tester.drag`: the stretch
  /// only exists between an `OverscrollNotification` and the
  /// `ScrollEndNotification` that resets it, so a drag that starts and
  /// ends inside one call leaves nothing to sample.
  Future<double> overscrollFromTop(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    var peak = 1.0;
    for (var step = 0; step < 8; step++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final scale = stretchScale(tester);
      if (scale > peak) {
        peak = scale;
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();
    return peak;
  }

  /// Glass really is inside the viewport being stretched.
  ///
  /// Without this the pages could stop putting any glass in their scroll
  /// views and every assertion below would still hold.
  void expectGlassInsideTheViewport(Type glassType) {
    expect(
      find.descendant(
        of: find.byType(Viewport),
        matching: find.byType(glassType),
      ),
      findsWidgets,
      reason:
          'the point of this test is a $glassType under a stretched '
          'Transform; there is no $glassType in the viewport',
    );
  }

  testWidgets('the index overscrolls with its rows raising nothing', (
    tester,
  ) async {
    // A plain `MaterialApp`, not `main.dart`'s: the page has to survive
    // the default scroll behaviour on its own, which is what removing its
    // page-local override means.
    late double peak;
    final caught = await errorsFrom(() async {
      await tester.pumpWidget(
        const MaterialApp(home: CatalogueIndexPage()),
      );
      await tester.pumpAndSettle();
      expectGlassInsideTheViewport(InteractiveGlass);
      peak = await overscrollFromTop(tester);
    });

    expect(
      peak,
      greaterThan(1),
      reason: 'the drag never reached the stretch indicator',
    );
    expect(
      caught,
      isEmpty,
      reason:
          'overscrolling the index raised ${caught.length} error(s):\n'
          '${describe(caught)}',
    );
  });

  testWidgets('an entry page overscrolls with its specimen raising '
      'nothing', (tester) async {
    final entry = entriesIn('Surfaces').first;
    late double peak;
    final caught = await errorsFrom(() async {
      await tester.pumpWidget(
        MaterialApp(home: CatalogueEntryPage(entry: entry)),
      );
      await tester.pumpAndSettle();
      expectGlassInsideTheViewport(Glass);
      peak = await overscrollFromTop(tester);
    });

    expect(
      peak,
      greaterThan(1),
      reason: 'the drag never reached the stretch indicator',
    );
    expect(
      caught,
      isEmpty,
      reason:
          "overscrolling ${entry.api}'s page raised ${caught.length} "
          'error(s):\n${describe(caught)}',
    );
  });

  testWidgets('the app as main() starts it overscrolls raising nothing', (
    tester,
  ) async {
    // The third removed override was `main.dart`'s app-wide
    // `scrollBehavior`, and only booting the real app exercises its
    // absence.
    late double peak;
    final caught = await errorsFrom(() async {
      app.main();
      await tester.pumpAndSettle();
      expectGlassInsideTheViewport(InteractiveGlass);
      peak = await overscrollFromTop(tester);
    });

    expect(
      peak,
      greaterThan(1),
      reason:
          'the app still suppresses the overscroll indicator, so this '
          'drag stretched nothing',
    );
    expect(
      caught,
      isEmpty,
      reason:
          'overscrolling the running app raised ${caught.length} '
          'error(s):\n${describe(caught)}',
    );
  });
}
