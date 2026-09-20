import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

void main() {
  late GlassDetentSheetController controller;

  Widget host({
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    int itemCount = 60,
  }) {
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
                scrollDirection: scrollDirection,
                reverse: reverse,
                itemCount: itemCount,
                itemBuilder: (context, i) => SizedBox(
                  height: 40,
                  width: 40,
                  child: Text('row $i'),
                ),
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
  Future<TestGesture> armedGestureOn(
    WidgetTester tester,
    Finder target, {
    Offset arm = const Offset(0, -kDragSlopDefault),
  }) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(arm);
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

  testWidgets('a drag on the handle stays the sheet own drag', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final sheet = find.descendant(
      of: find.byType(GlassDetentSheet),
      matching: find.byType(Glass),
    );
    // Ten points below the sheet's own top edge is the grab handle, and the
    // point of this test is that it is *not* the list: a gesture there is the
    // sheet's `GestureDetector`'s, start to finish, and the physics has no
    // claim on it.
    final grab = Offset(
      tester.getCenter(sheet).dx,
      tester.getTopLeft(sheet).dy + 10,
    );
    expect(
      grab.dy,
      lessThan(tester.getRect(find.byType(Scrollable)).top),
      reason: 'the grab point must be above the list for this to mean anything',
    );

    final gesture = await tester.startGesture(grab);
    await gesture.moveBy(const Offset(0, -kDragSlopDefault));
    await tester.pump();
    expect(controller.isDragging, isTrue);

    // Each of these resizes the sheet, which resizes the list's viewport.
    // That is a dimension change, and an idle `ScrollPosition` answers one
    // with `goBallistic(0)` — which is how a drag nobody handed to the
    // physics used to get ended underneath a finger that was still down.
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(
        controller.isDragging,
        isTrue,
        reason: 'the finger is still down after move ${i + 1}',
      );
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isDragging, isFalse);
    expect(controller.detents, contains(controller.value));
  });

  testWidgets('a horizontal scrollable inside the sheet scrolls itself', (
    tester,
  ) async {
    await tester.pumpWidget(host(scrollDirection: Axis.horizontal));
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    final gesture = await armedGestureOn(
      tester,
      find.text('row 0'),
      arm: const Offset(-kDragSlopDefault, 0),
    );
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(position.pixels, closeTo(120, 0.5));
    expect(
      controller.value,
      controller.lowest,
      reason: 'a sideways swipe is not a gesture the sheet has a claim on',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a reversed list is read by the finger, not the scroll offset', (
    tester,
  ) async {
    await tester.pumpWidget(host(reverse: true));
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = positionOf(tester);
    final list = find.byType(Scrollable);

    // A reversed viewport negates the delta a second time, so a finger going
    // *up* arrives here as a positive offset — which the naive reading takes
    // for a downward finger and hands to the sheet.
    var gesture = await armedGestureOn(tester, list);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(
      controller.value,
      controller.top,
      reason: 'a finger going up never lowers the sheet',
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // Downward is the direction that scrolls a reversed list back through its
    // content, and at its near end that is the list's business, not the
    // sheet's.
    gesture = await armedGestureOn(tester, list);
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(position.pixels, closeTo(80, 0.5));
    expect(controller.value, controller.top);
    await gesture.up();
    await tester.pumpAndSettle();

    // The far end of a reversed list is the top of its content, so that —
    // not pixel zero — is where rule 3 hands the gesture back.
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    gesture = await armedGestureOn(tester, list);
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(
      controller.value,
      closeTo(controller.top - 120, 0.5),
      reason: 'the sheet should have taken the gesture back',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('at the top detent a downward drag off zero still scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    controller.animateToDetent(1);
    await tester.pumpAndSettle();

    final position = positionOf(tester)..jumpTo(200);
    await tester.pump();

    final gesture = await armedGestureOn(tester, find.byType(Scrollable));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();

    // The half that is load-bearing: the finger is going the direction that
    // lowers the sheet, and the sheet stays put because the list still has
    // somewhere to go.
    expect(position.pixels, closeTo(120, 0.5));
    expect(controller.value, controller.top);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a sibling scrollable does not end another one drag', (
    tester,
  ) async {
    // Two lists in one sheet. Only one of them is under the finger; the other
    // is idle, and an idle `ScrollPosition` answers the dimension change that
    // every frame of the drag causes with `goBallistic(0)`.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
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
                child: Row(
                  children: <Widget>[
                    for (final side in <String>['a', 'b'])
                      Expanded(
                        child: ListView.builder(
                          itemCount: 60,
                          itemBuilder: (context, i) => SizedBox(
                            height: 40,
                            child: Text('$side row $i'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scrollable), findsNWidgets(2));

    final gesture = await armedGestureOn(tester, find.text('a row 0'));
    var previous = controller.value;
    for (var i = 0; i < 3; i++) {
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(
        controller.isDragging,
        isTrue,
        reason: 'the finger is still down after move ${i + 1}',
      );
      expect(
        controller.value,
        greaterThan(previous),
        reason: 'and the sheet is still rising on move ${i + 1}',
      );
      previous = controller.value;
    }

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isDragging, isFalse);
    expect(controller.detents, contains(controller.value));
  });

  testWidgets('a rebuild in the middle of a drag does not orphan it', (
    tester,
  ) async {
    late StateSetter rebuildAboveTheSheet;

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          tier: GeometryTier.none,
          child: Stack(
            children: <Widget>[
              const SizedBox.expand(),
              StatefulBuilder(
                builder: (context, setState) {
                  rebuildAboveTheSheet = setState;
                  return GlassDetentSheet(
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await armedGestureOn(tester, find.text('row 0'));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(controller.isDragging, isTrue);
    expect(controller.value, closeTo(200, 0.5));

    // Something above the sheet rebuilds for a reason of its own — an
    // ancestor's `setState`, an inherited widget, a theme change. The sheet
    // rebuilds with it, and the drag is not supposed to notice.
    rebuildAboveTheSheet(() {});
    await tester.pump();
    expect(controller.isDragging, isTrue, reason: 'the finger is still down');
    expect(
      controller.value,
      closeTo(200, 0.5),
      reason: 'and the sheet did not jump',
    );

    // The release has to find its way to the sheet through whatever the
    // rebuild left behind.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.isDragging, isFalse);
    expect(controller.detents, contains(controller.value));
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
