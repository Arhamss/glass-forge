import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/reduce_motion.dart';

void main() {
  tearDown(() {
    // Returns the singleton's cached value to the real one, so the next
    // test's first change is still seen as a change.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('reads the engine bitmask, not MediaQuery', (tester) async {
    // MediaQueryData.disableAnimations is documented not to be set by iOS
    // Reduce Motion, which is exactly why this signal must not come from
    // there. A widget tree claiming animations are disabled must not be
    // able to move this.
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SizedBox.shrink(),
      ),
    );
    expect(GlassReduceMotion.instance.value, isFalse);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    expect(GlassReduceMotion.instance.value, isTrue);
  });

  testWidgets('notifies when the setting actually changes', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var notifications = 0;
    void listener() => notifications++;
    GlassReduceMotion.instance.addListener(listener);
    addTearDown(() => GlassReduceMotion.instance.removeListener(listener));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    expect(notifications, 1);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    expect(notifications, 2);
    expect(GlassReduceMotion.instance.value, isFalse);
  });

  testWidgets('stays quiet when an unrelated accessibility flag flips', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var notifications = 0;
    void listener() => notifications++;
    GlassReduceMotion.instance.addListener(listener);
    addTearDown(() => GlassReduceMotion.instance.removeListener(listener));

    // The engine hands out one bitmask for a dozen features. Waking every
    // settled spring in the app because the user turned on bold text would
    // be a real cost for a signal that did not change.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true, highContrast: true);
    expect(notifications, 0);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          boldText: true,
          highContrast: true,
          disableAnimations: true,
        );
    expect(notifications, 1);
  });
}
