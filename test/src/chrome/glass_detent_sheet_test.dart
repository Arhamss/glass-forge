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
}) {
  return MaterialApp(
    home: GlassLayer(
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
}
