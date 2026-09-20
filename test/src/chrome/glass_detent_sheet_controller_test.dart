import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/chrome/glass_detent_sheet_controller.dart';

const Duration _frame = Duration(milliseconds: 8);

Future<void> settle(
  WidgetTester tester,
  GlassDetentSheetController controller,
) async {
  var frames = 0;
  while (controller.isAnimating && frames < 1200) {
    await tester.pump(_frame);
    frames++;
  }
}

void main() {
  late GlassDetentSheetController controller;

  void build({bool respectReduceMotion = true}) {
    controller = GlassDetentSheetController(
      vsync: const TestVSync(),
      respectReduceMotion: respectReduceMotion,
    )..setDetents(const <double>[80, 400, 800]);
    addTearDown(controller.dispose);
  }

  testWidgets('starts at the initial detent with no motion', (tester) async {
    controller = GlassDetentSheetController(vsync: const TestVSync())
      ..setDetents(const <double>[80, 400, 800], initialDetent: 1);
    addTearDown(controller.dispose);

    expect(controller.value, 400);
    expect(controller.detent, 1);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('a drag moves the sheet under the finger, one to one', (
    tester,
  ) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(60);
    expect(controller.value, 140);
    expect(controller.isDragging, isTrue);
  });

  testWidgets('a release snaps to the nearest detent', (tester) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(220) // 300, nearer 400 than 80
      ..endDrag();
    await settle(tester, controller);

    expect(controller.value, 400);
    expect(controller.detent, 1);
  });

  testWidgets('a fling carries past the nearest detent', (tester) async {
    build();
    controller
      ..beginDrag()
      ..dragBy(40) // 120, nearest is still the lowest
      ..endDrag(velocity: 900);
    await settle(tester, controller);

    expect(controller.detent, 1);
  });

  testWidgets('onDetentChanged fires once, when the detent actually changes', (
    tester,
  ) async {
    build();
    final seen = <int>[];
    controller
      ..onDetentChanged = seen.add
      ..beginDrag()
      ..dragBy(220)
      ..endDrag();
    await settle(tester, controller);
    expect(seen, <int>[1]);

    // Releasing again at the same place is not a change.
    controller
      ..beginDrag()
      ..dragBy(2)
      ..endDrag();
    await settle(tester, controller);
    expect(seen, <int>[1]);
  });

  testWidgets('listeners fire while the spring runs, not only at the end', (
    tester,
  ) async {
    build();
    var notifications = 0;
    controller
      ..addListener(() => notifications++)
      ..animateToDetent(2);
    // A Ticker's first callback always reports zero elapsed, so a bare
    // pump is needed before a duration-bearing one produces real motion —
    // the same pattern `glass_motion_controller_test.dart` uses throughout.
    await tester.pump();
    await tester.pump(_frame);
    await tester.pump(_frame);
    expect(notifications, greaterThan(1));
    expect(controller.value, greaterThan(80));
    expect(controller.value, lessThan(800));

    await settle(tester, controller);
    expect(controller.value, 800);
  });

  // The accessibility contract is "no elastic properties", which is a
  // statement about simulations. A faster spring is still motion.
  testWidgets('Reduce Motion snaps with no frames in between', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    build();
    controller.animateToDetent(2);

    expect(controller.value, 800);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('respectReduceMotion: false keeps the spring', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    build(respectReduceMotion: false);
    controller.animateToDetent(2);

    expect(controller.value, lessThan(800));
    expect(controller.isAnimating, isTrue);
    await settle(tester, controller);
  });

  testWidgets('re-resolving detents keeps the current one', (tester) async {
    build();
    controller.animateToDetent(1);
    await settle(tester, controller);
    expect(controller.value, 400);

    // A rotation: the same three fractions against a shorter window.
    controller.setDetents(const <double>[40, 200, 400]);
    expect(controller.detent, 1);
    expect(controller.value, 200);
  });

  testWidgets('a drag started mid-spring takes the sheet over', (
    tester,
  ) async {
    build();
    controller.animateToDetent(2);
    await tester.pump(_frame);
    await tester.pump(_frame);
    final caught = controller.value;

    controller.beginDrag();
    expect(controller.isAnimating, isFalse);
    expect(controller.value, caught);
  });
}
