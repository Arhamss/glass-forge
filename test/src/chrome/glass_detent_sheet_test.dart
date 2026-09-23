import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/rendering/render_glass_shape.dart';

/// The sheet's visible box.
///
/// Not `find.byType(GlassDetentSheet)`: the widget returns an `Align` under
/// the `Stack`'s loose constraints, so its element fills the whole window
/// whatever the detent is. Its `getSize` is the window's height at every
/// detent, and its centre is empty space well above the sheet — a `drag` there
/// misses the gesture detector entirely. The `Glass` inside it is the thing
/// that is actually the size of the sheet.
Finder get _sheet => find.descendant(
  of: find.byType(GlassDetentSheet),
  matching: find.byType(Glass),
);

Widget _host({
  List<GlassDetent> detents = const <GlassDetent>[
    GlassDetent.fraction(0.1),
    GlassDetent.fraction(0.5),
    GlassDetent.fraction(1),
  ],
  GlassDetentSheetController? controller,
  ValueChanged<int>? onDetentChanged,
  int initialDetent = 0,
  Widget? child,
  EdgeInsets viewPadding = EdgeInsets.zero,
  GlassMotionDefaults? motion,
}) {
  final layer = _layer(
    detents: detents,
    controller: controller,
    onDetentChanged: onDetentChanged,
    initialDetent: initialDetent,
    child: child,
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        // The test window has no insets of its own, so a sheet's safe-area
        // behaviour is invisible unless one is put here.
        data: MediaQuery.of(
          context,
        ).copyWith(padding: viewPadding, viewPadding: viewPadding),
        child: motion == null
            ? layer
            : GlassTheme(
                data: GlassThemeData(motion: motion),
                child: layer,
              ),
      ),
    ),
  );
}

Widget _layer({
  required List<GlassDetent> detents,
  required GlassDetentSheetController? controller,
  required ValueChanged<int>? onDetentChanged,
  required int initialDetent,
  required Widget? child,
}) {
  return GlassLayer(
    // `GeometryTier.none` swaps the matte producer for the one that bakes
    // nothing. Every claim in this file survives that: the shape still
    // registers its geometry, the scene still bumps its revision, the
    // cross-pass overlap check still runs, and `matteProduceCount` still
    // counts — `RenderGlassLayer._refreshMatte` records a bake around the
    // producer call whatever the producer returns, so "a settled sheet
    // bakes nothing" still pins the revision guard that is the actual
    // claim. What it drops is the software rasterisation of the texture,
    // which off Impeller runs a full SDF fragment shader over the sheet's
    // bounds on the CPU: measured at 2s for a 60-high sheet and rising
    // with its height, once per frame for every frame it moves. At the
    // default tier this file takes tens of minutes and reads as a hang.
    tier: GeometryTier.none,
    child: Stack(
      children: <Widget>[
        const SizedBox.expand(child: ColoredBox(color: Color(0xFF203040))),
        GlassDetentSheet(
          detents: detents,
          controller: controller,
          initialDetent: initialDetent,
          onDetentChanged: onDetentChanged,
          child: child ?? const SizedBox.expand(),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('opens at its initial detent', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // A tenth of the 600-high test window, less nothing: the test window has
    // no safe-area inset.
    expect(tester.getSize(_sheet).height, closeTo(60, 0.5));
  });

  testWidgets('opens at a non-zero initial detent', (tester) async {
    await tester.pumpWidget(_host(initialDetent: 1));
    await tester.pumpAndSettle();

    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));
  });

  testWidgets('a drag up moves the sheet and it snaps to the next detent', (
    tester,
  ) async {
    final changed = <int>[];
    await tester.pumpWidget(_host(onDetentChanged: changed.add));
    await tester.pumpAndSettle();

    await tester.drag(_sheet, const Offset(0, -220));
    await tester.pumpAndSettle();

    expect(changed, <int>[1]);
    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));
  });

  testWidgets('the gap closes and the radius grows as it rises', (
    tester,
  ) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    double radius() {
      final shape = tester.renderObject<RenderGlassShape>(_sheet);
      return shape.shape.resolveRadius(shape.size);
    }

    double left() => tester.getTopLeft(_sheet).dx;

    final lowRadius = radius();
    final lowLeft = left();
    expect(lowLeft, closeTo(12, 0.5)); // the floating gap

    controller.animateToDetent(2);
    await tester.pumpAndSettle();

    expect(left(), closeTo(0, 0.5)); // flush
    expect(radius(), greaterThan(lowRadius));
  });

  // The claim the spec makes about cost, in the form that is actually true.
  // See "A correction to the spec" at the top of this plan: a resizing,
  // radius-morphing shape rebakes its matte per frame while it moves. What
  // must hold is that it stops when the sheet does, and that the sheet is one
  // backdrop pass throughout, never two.
  testWidgets('a settled sheet bakes nothing per frame', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(GlassRenderCounters.instance.matteProduceCount, 0);
  });

  // Two ways the sheet could get its composition wrong, both of which the
  // renderer announces on `debugPrint` and neither of which a golden would
  // catch. The cross-pass overlap warning fires when two *different* backdrop
  // passes cover one region — nothing here has a second pass, so seeing it
  // means the sheet brought its own. The implicit-layer warning fires when a
  // `Glass` finds no enclosing `GlassLayer` and wraps itself in one, which is
  // the same mistake arriving from the other side.
  testWidgets('the composition warnings stay quiet through a whole drag', (
    tester,
  ) async {
    final warnings = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        warnings.add(message);
      }
    };
    // Restored in a finally, not an addTearDown: flutter_test's end-of-test
    // invariant check that debugPrint was not left changed runs *before*
    // tear-downs, so restoring there is too late and the check throws. Same
    // reasoning, same shape as glass_overlap_warning_test.dart.
    try {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(_sheet));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    } finally {
      debugPrint = previous;
    }

    expect(
      warnings.where(
        (w) => w.contains('overlap') || w.contains('implicit one'),
      ),
      isEmpty,
      reason: warnings.join('\n'),
    );
  });

  // One `GlassLayer`, one sheet, one distinct material — so one backdrop
  // capture per frame, whatever the sheet is doing. This is the claim that
  // replaced the spec's "one matte produce for the whole drag", which a
  // resizing, radius-morphing shape cannot honour: see the plan's correction
  // section. Two pushes over one region would be flutter#187820, and it is
  // the reason `GlassRenderCounters` exists.
  testWidgets('one backdrop pass per frame of a drag, never two', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(_sheet));
    final counts = <int>[];
    for (var i = 0; i < 20; i++) {
      GlassRenderCounters.instance.reset();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 8));
      counts.add(GlassRenderCounters.instance.backdropPushCount);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(counts, everyElement(1), reason: counts.join(', '));
  });

  // The branch's stated constraint: springs come from the theme by role, not
  // written out by hand. The sheet role names `GlassMotionRole.present`, so
  // retuning that one spring has to retune this sheet — which is exactly the
  // promise `GlassMotionDefaults` makes in its own doc.
  testWidgets("the snap spring is the theme's, by role", (tester) async {
    const retuned = GlassMotion.smooth(duration: Duration(milliseconds: 1200));
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        controller: controller,
        motion: const GlassMotionDefaults(present: retuned),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.settleMotion, retuned);
  });

  testWidgets('a retuned theme spring changes how long the snap takes', (
    tester,
  ) async {
    Future<int> framesToSettle(GlassMotionDefaults? motion) async {
      final controller = GlassDetentSheetController(vsync: const TestVSync());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(controller: controller, motion: motion),
      );
      await tester.pumpAndSettle();

      controller.animateToDetent(2);
      var frames = 0;
      while (controller.isAnimating && frames < 600) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      await tester.pumpAndSettle();
      // Torn down here rather than at the end of the test: the second call
      // mounts a second sheet over the first, and a controller still driving
      // an unmounted one is not what the next measurement should inherit.
      await tester.pumpWidget(const SizedBox.shrink());
      return frames;
    }

    final byDefault = await framesToSettle(null);
    final slowed = await framesToSettle(
      const GlassMotionDefaults(
        present: GlassMotion.smooth(duration: Duration(milliseconds: 1600)),
      ),
    );

    expect(
      slowed,
      greaterThan(byDefault * 2),
      reason: 'default $byDefault frames, retuned $slowed',
    );
  });

  testWidgets('Reduce Motion makes the snap instant', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    controller.animateToDetent(2);
    await tester.pump();

    expect(tester.getSize(_sheet).height, closeTo(600, 0.5));
  });

  testWidgets('semantics expose a draggable with increase and decrease', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(
      // `_sheet`, not `find.byType(GlassDetentSheet)`, and for the same
      // reason the size assertions use it: `getSemantics` walks *up* from
      // the finder's render object, and the widget's own render object is
      // the `LayoutBuilder` that sits above the sheet's `Semantics`. From
      // there the nearest node up is the route's, which carries none of
      // this. From the `Glass` the nearest node up is the sheet's own.
      tester.getSemantics(_sheet),
      // `isSemantics`, not `matchesSemantics`: the latter is exhaustive and
      // this node also carries a value and the two either side of it, which
      // this test has no opinion about. (The plan said `containsSemantics`,
      // which is the same matcher under the name it carried before it was
      // deprecated in v3.40.0-1.0.pre.)
      isSemantics(hasIncreaseAction: true, hasDecreaseAction: true),
    );
    handle.dispose();
  });

  testWidgets('the increase action raises it one detent', (tester) async {
    final handle = tester.ensureSemantics();
    final changed = <int>[];
    await tester.pumpWidget(_host(onDetentChanged: changed.add));
    await tester.pumpAndSettle();

    // The plan reached the owner through `tester.binding.pipelineOwner`,
    // which is deprecated — the binding no longer has one pipeline owner to
    // hand out. A node carries its own, and it is the same object that call
    // used to arrive at, so the action still leaves from where the platform
    // would send it.
    final node = tester.getSemantics(_sheet);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    expect(changed, <int>[1]);
    handle.dispose();
  });

  testWidgets('a controller the caller owns is not disposed by the widget', (
    tester,
  ) async {
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpWidget(const SizedBox.shrink());

    // Still usable: disposing it here would throw.
    expect(controller.value, isNotNull);
  });

  // The bottom safe-area inset is carried in two halves — the sheet's own
  // offset while it floats, the child's padding once it is flush — that
  // always sum to the whole inset. Invisible in every other test in this
  // file, because the test window has no insets of its own.
  testWidgets(
    'the bottom safe area is cleared while floating and never jumps flush',
    (tester) async {
      // An iPhone home indicator, against the default 12 gap.
      const inset = EdgeInsets.only(bottom: 34);
      const content = ValueKey<String>('content');
      final controller = GlassDetentSheetController(vsync: const TestVSync());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          controller: controller,
          viewPadding: inset,
          child: const SizedBox.expand(key: content),
        ),
      );
      await tester.pumpAndSettle();

      // Measured up from the bottom of the 600-high test window.
      double above(Finder target) => 600 - tester.getBottomLeft(target).dy;
      final child = find.byKey(content);

      // Floating, the sheet's own box clears the indicator and the gap is
      // on top of it — not 12 from the screen's edge with 22 of that inside
      // the indicator, which is where a gap that ignored the inset put it.
      expect(above(_sheet), closeTo(12 + 34, 0.5));
      expect(above(child), closeTo(12 + 34, 0.5));

      final trail = <double>[above(child)];
      controller.animateToDetent(2);
      for (var i = 0; controller.isAnimating && i < 600; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        trail.add(above(child));
      }
      await tester.pumpAndSettle();

      // Flush, the box runs to the screen's edge and the content carries the
      // whole inset itself.
      expect(above(_sheet), closeTo(0, 0.5));
      expect(above(child), closeTo(34, 0.5));

      // And it got there continuously. With the inset switched on at the top
      // detent instead of split, the last frame alone moved it by all 34.
      var worst = 0.0;
      for (var i = 1; i < trail.length; i++) {
        final step = (trail[i] - trail[i - 1]).abs();
        if (step > worst) {
          worst = step;
        }
      }
      expect(worst, lessThan(6), reason: trail.join(', '));
    },
  );

  testWidgets('a controller handed to a live sheet inherits its detents', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    // A no-op that leaves the sheet at 60 if the hand-over left the new
    // controller with nothing: `_syncDetents` only speaks up when the
    // resolved heights change, and a controller swap does not change them.
    // `animateToDetent` no longer throws on an empty list — it is a legal
    // call before the first layout — so the height below is what catches it.
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));

    // Unmounting asserts if the displaced internal controller's ticker was
    // never disposed.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('taking the controller away leaves the sheet where it was', (
    tester,
  ) async {
    // The full round trip, and it has to start here: a sheet that was given
    // a controller at mount never made one of its own, so swapping away from
    // it only ever creates a first ticker. It is the sheet that had one,
    // gave it up and needs another that creates a second.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller: controller));
    await tester.pumpAndSettle();

    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    // Back to an internal controller — the second one this state has made.
    // `SingleTickerProviderStateMixin` counts tickers ever created, not
    // tickers alive, so it asserts here however carefully the first was
    // disposed.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // A fresh controller has no opinion about where the sheet is, so it
    // takes the position the sheet already had rather than snapping to
    // `initialDetent`.
    expect(tester.getSize(_sheet).height, closeTo(300, 0.5));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a sibling listening to the controller survives the mount', (
    tester,
  ) async {
    // The sheet resolves its detents inside a `LayoutBuilder`, which is the
    // only place the available height exists, and resolving them notifies
    // the controller. A listener built before the sheet laid out is a
    // sibling rather than a descendant, so marking it dirty from inside
    // that layout throws "setState called during build" — which is what a
    // caller fading chrome out under a rising sheet gets on mount, and what
    // `GlassScaffold` will assemble for them.
    final controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);

    final errors = <FlutterErrorDetails>[];
    final reportToTest = FlutterError.onError;
    // Collected one `FlutterErrorDetails` at a time rather than through
    // `tester.takeException`, which folds every error from one pump into a
    // single synthetic string and drops the originals.
    FlutterError.onError = errors.add;

    final seen = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          // See the note on `_layer`: the software SDF bake is seconds per
          // frame and nothing here reads the matte.
          tier: GeometryTier.none,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  seen.add(controller.value);
                  return const SizedBox.expand();
                },
              ),
              GlassDetentSheet(
                controller: controller,
                detents: const <GlassDetent>[
                  GlassDetent.fraction(0.1),
                  GlassDetent.fraction(0.5),
                ],
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    FlutterError.onError = reportToTest;

    expect(
      errors.map((details) => details.exceptionAsString()).toList(),
      isEmpty,
    );
    // A tenth of the 600-high test window: the sibling was told the height
    // the sheet resolved, rather than merely not crashing.
    expect(
      seen.last,
      closeTo(60, 0.5),
      reason: 'the sibling never heard the sheet resolve its detents',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
