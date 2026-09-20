import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/platform/glass_forge_platform_interface.dart';
import 'package:glass_forge/src/tier/accessibility_signals.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A platform whose Reduce Transparency answers the test controls.
class _FakePlatform extends GlassForgePlatform with MockPlatformInterfaceMixin {
  _FakePlatform({this.initial, this.channelMissing = false});

  final bool? initial;
  final bool channelMissing;
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  @override
  Future<bool?> isReduceTransparencyEnabled() async => initial;

  @override
  Stream<bool> reduceTransparencyChanges() {
    if (channelMissing) {
      return const Stream<bool>.empty();
    }
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccessibilitySignals.fromPlatform', () {
    test('reads Reduce Motion from the engine bitmask', () {
      final signals = AccessibilitySignals.fromPlatform(
        nativeReduceTransparency: false,
        features: const FakeAccessibilityFeatures(reduceMotion: true),
      );

      // The engine has a `reduceMotion` bit; `MediaQueryData` does not, and
      // its nearest neighbour `disableAnimations` is documented not to be
      // set by iOS Reduce Motion (flutter#65874). Reading it from
      // MediaQuery would answer false for every iOS user who turned the
      // setting on.
      expect(signals.reduceMotion, isTrue);
    });

    test("takes Android's disableAnimations as Reduce Motion too", () {
      // This test used to assert the opposite, and pinned a real bug in
      // place. The two engine bits are not interchangeable: `dart:ui`
      // documents `reduceMotion` as "only supported on iOS", while
      // `disableAnimations` is the generic flag Android sets from its
      // animator duration scale. Honouring only `reduceMotion` is the
      // mirror-image of the MediaQuery trap the test above guards — correct
      // on iOS, and silently "off" for every Android user who asked for less
      // motion. `GlassReduceMotion` already took the union, so the same
      // setting degraded motion but not the tier on the same device.
      final signals = AccessibilitySignals.fromPlatform(
        nativeReduceTransparency: false,
        features: const FakeAccessibilityFeatures(disableAnimations: true),
      );

      expect(signals.reduceMotion, isTrue);
    });

    test('maps the highContrast bit to Increase Contrast', () {
      final signals = AccessibilitySignals.fromPlatform(
        nativeReduceTransparency: false,
        features: const FakeAccessibilityFeatures(highContrast: true),
      );

      expect(signals.increaseContrast, isTrue);
    });

    test(
      'a real Reduce Transparency answer beats the highContrast guess',
      () {
        final signals = AccessibilitySignals.fromPlatform(
          nativeReduceTransparency: false,
          features: const FakeAccessibilityFeatures(highContrast: true),
        );

        // This is the case every competing package gets wrong in the other
        // direction: Increase Contrast on, Reduce Transparency off. The
        // approximation would strip the glass from someone who never asked
        // for that.
        expect(signals.reduceTransparency, isFalse);
        expect(signals.reduceTransparencyIsApproximated, isFalse);
      },
    );

    test('falls back to highContrast, and says that it did', () {
      final signals = AccessibilitySignals.fromPlatform(
        nativeReduceTransparency: null,
        features: const FakeAccessibilityFeatures(highContrast: true),
      );

      expect(signals.reduceTransparency, isTrue);
      expect(signals.reduceTransparencyIsApproximated, isTrue);
      expect(signals.toString(), contains('approximated'));
    });

    test('an unanswered platform with no contrast setting reports off', () {
      final signals = AccessibilitySignals.fromPlatform(
        nativeReduceTransparency: null,
        features: const FakeAccessibilityFeatures(),
      );

      expect(signals.reduceTransparency, isFalse);
      expect(signals.reduceTransparencyIsApproximated, isTrue);
    });
  });

  group('AccessibilitySignalSource', () {
    test('adopts the platform answer at startup', () async {
      final platform = _FakePlatform(initial: true);
      addTearDown(platform.controller.close);
      final source = AccessibilitySignalSource(
        platform: platform,
        features: () => const FakeAccessibilityFeatures(),
      );
      addTearDown(source.dispose);

      await source.start();

      expect(source.value.reduceTransparency, isTrue);
      expect(source.value.reduceTransparencyIsApproximated, isFalse);
    });

    test('follows the platform when the user toggles the setting', () async {
      final platform = _FakePlatform(initial: false);
      addTearDown(platform.controller.close);
      final source = AccessibilitySignalSource(
        platform: platform,
        features: () => const FakeAccessibilityFeatures(),
      );
      addTearDown(source.dispose);
      await source.start();
      expect(source.value.reduceTransparency, isFalse);

      // Toggling Reduce Transparency raises no engine accessibility
      // notification at all, on any platform — the setting is not in the
      // bitmask — so without the channel's own stream this value would be
      // frozen at whatever it was when the app launched.
      platform.controller.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(source.value.reduceTransparency, isTrue);
    });

    test(
      'a platform with no channel stays on the approximation',
      () async {
        final platform = _FakePlatform(channelMissing: true);
        addTearDown(platform.controller.close);
        final source = AccessibilitySignalSource(
          platform: platform,
          features: () => const FakeAccessibilityFeatures(highContrast: true),
        );
        addTearDown(source.dispose);

        await source.start();

        expect(source.value.reduceTransparency, isTrue);
        expect(source.value.reduceTransparencyIsApproximated, isTrue);
      },
    );

    testWidgets(
      'reads Reduce Motion off the engine bitmask with no seam at all',
      (tester) async {
        final platform = _FakePlatform(initial: false);
        addTearDown(platform.controller.close);
        // No `features:` override: this exercises the production read path,
        // which goes through the binding's platform dispatcher precisely so
        // a widget test can drive it.
        final source = AccessibilitySignalSource(platform: platform);
        addTearDown(source.dispose);
        await source.start();
        expect(source.value.reduceMotion, isFalse);

        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(reduceMotion: true);
        source.didChangeAccessibilityFeatures();

        expect(source.value.reduceMotion, isTrue);
      },
    );

    testWidgets(
      'disableAnimations alone does turn Reduce Motion on',
      (tester) async {
        final platform = _FakePlatform(initial: false);
        addTearDown(platform.controller.close);
        final source = AccessibilitySignalSource(platform: platform);
        addTearDown(source.dispose);
        await source.start();

        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        source.didChangeAccessibilityFeatures();

        // They are different bits with different meanings — and both of them
        // mean the user asked for less motion. `dart:ui` documents
        // `reduceMotion` as "only supported on iOS"; `disableAnimations` is
        // what Android sets from its animator duration scale. Honouring only
        // the first, which this test used to require, answered "off" for
        // every Android user who turned the setting on, while
        // `GlassReduceMotion` was already honouring both — so the same
        // setting degraded motion but not the tier on the same device.
        expect(source.value.reduceMotion, isTrue);
      },
    );

    test('recomputes when the engine bitmask changes', () async {
      final platform = _FakePlatform(initial: false);
      addTearDown(platform.controller.close);
      var contrast = false;
      final source = AccessibilitySignalSource(
        platform: platform,
        features: () => FakeAccessibilityFeatures(highContrast: contrast),
      );
      addTearDown(source.dispose);
      await source.start();
      expect(source.value.increaseContrast, isFalse);

      contrast = true;
      source.didChangeAccessibilityFeatures();

      expect(source.value.increaseContrast, isTrue);
    });
  });
}
