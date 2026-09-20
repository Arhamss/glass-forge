import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  late GlassDetentSheetController controller;

  Widget host() {
    return MaterialApp(
      home: GlassLayer(
        // `GeometryTier.none` swaps the matte producer for the one that bakes
        // nothing. Nothing this file claims is about the matte: every
        // assertion is about where a vertical delta goes, which is decided in
        // `GlassSheetScrollPhysics` long before any geometry is produced. What
        // the tier drops is the software rasterisation of the texture, which
        // off Impeller runs a full SDF fragment shader over the sheet's bounds
        // on the CPU — seconds per frame, rising with the sheet's height, for
        // every frame the sheet moves. This file drags a sheet to the top
        // detent, where it is the whole window, several times over; at the
        // default tier it takes tens of minutes and reads as a hang.
        tier: GeometryTier.none,
        child: Stack(
          children: <Widget>[
            const SizedBox.expand(),
            GlassDetentSheet(
              controller: controller,
              detents: const <GlassDetent>[
                GlassDetent.fraction(0.2),
                GlassDetent.fraction(1),
              ],
              child: ListView.builder(
                itemCount: 60,
                itemBuilder: (context, i) =>
                    SizedBox(height: 40, child: Text('row $i')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Puts a finger on [target] and gets the touch slop out of the way.
  ///
  /// `Scrollable` drags with `DragStartBehavior.start`, which throws away the
  /// delta of the very event that crosses the slop — the drag is treated as
  /// starting where the finger was when it was recognised, not where it went
  /// down. So the first move here is deliberately spent: it arms the
  /// recogniser and moves nothing, and every move after it is reported in
  /// full. Without it a single large [TestGesture.moveBy] is swallowed
  /// entirely and the test measures nothing.
  Future<TestGesture> armedGestureOn(WidgetTester tester, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(0, -kDragSlopDefault));
    await tester.pump();
    return gesture;
  }

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  setUp(() {
    controller = GlassDetentSheetController(vsync: const TestVSync());
    addTearDown(controller.dispose);
  });

  testWidgets('below the top detent a drag moves the sheet, not the list', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    expect(position.pixels, 0);

    final gesture = await armedGestureOn(tester, find.text('row 0'));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();

    expect(position.pixels, 0, reason: 'the list must not have scrolled');
    expect(controller.value, greaterThan(controller.lowest));
    // The lowest detent is a fifth of the 600-high test window, and the whole
    // 80 went to the sheet.
    expect(controller.value, closeTo(200, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('at the top detent the list scrolls', (tester) async {
    await tester.pumpWidget(host());
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    final gesture = await armedGestureOn(tester, find.text('row 0'));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();

    expect(position.pixels, closeTo(80, 0.5));
    expect(controller.value, controller.top);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  // The rule that needs one gesture rather than two: scroll the list down,
  // hit its own zero, keep dragging, and the sheet takes over.
  testWidgets('at scroll zero, dragging down hands back to the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    final gesture = await armedGestureOn(tester, find.text('row 2'));

    await gesture.moveBy(const Offset(0, -120)); // scroll the list down
    await tester.pump();
    expect(position.pixels, greaterThan(0));

    await gesture.moveBy(const Offset(0, 120)); // back to its own zero
    await tester.pump();
    expect(position.pixels, closeTo(0, 1));
    expect(controller.value, controller.top, reason: 'sheet has not moved yet');

    await gesture.moveBy(const Offset(0, 120)); // still dragging down
    await tester.pump();
    expect(
      controller.value,
      lessThan(controller.top),
      reason: 'the sheet should have taken the gesture back',
    );
    expect(position.pixels, 0, reason: 'and the list stayed at its zero');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('dragging up from a descended sheet raises it before scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    final gesture = await armedGestureOn(tester, find.text('row 1'));
    await gesture.moveBy(const Offset(0, -600));
    await tester.pump();

    expect(controller.value, controller.top);
    expect(position.pixels, 0, reason: 'the list waits until the sheet is up');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('letting go of a drag the sheet took snaps it to a detent', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await armedGestureOn(tester, find.text('row 0'));
    await gesture.moveBy(const Offset(0, -400));
    await tester.pump();
    expect(controller.value, closeTo(520, 0.5));

    await gesture.up();
    await tester.pumpAndSettle();

    // A sheet raised through the list is still a sheet: it rests at a detent
    // rather than wherever the finger left it.
    expect(controller.value, controller.top);
    expect(controller.detent, 1);
  });

  testWidgets('a widget in the content can reach the sheet controller', (
    tester,
  ) async {
    GlassDetentSheetController? seen;

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          tier: GeometryTier.none,
          child: GlassDetentSheet(
            controller: controller,
            detents: const <GlassDetent>[
              GlassDetent.fraction(0.2),
              GlassDetent.fraction(1),
            ],
            child: Builder(
              builder: (context) {
                seen = GlassDetentSheetScope.maybeOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seen, same(controller));
  });

  testWidgets('outside a sheet there is no controller to find', (tester) async {
    GlassDetentSheetController? seen = controller;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = GlassDetentSheetScope.maybeOf(context);
          return const SizedBox.expand();
        },
      ),
    );

    expect(seen, isNull);
  });
}
