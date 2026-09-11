import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/motion/glass_decay.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';

const Duration _frame = Duration(milliseconds: 8);

/// Pumps until the controller stops scheduling frames, or gives up.
Future<int> settle(
  WidgetTester tester,
  GlassMotionController controller,
) async {
  var frames = 0;
  while (controller.isAnimating && frames < 1200) {
    await tester.pump(_frame);
    frames++;
  }
  return frames;
}

void main() {
  late GlassMotionController controller;

  void build({
    GlassMotion settleMotion = const GlassMotion.bouncy(),
    GlassOverdrag overdrag = const GlassOverdrag.none(),
    GlassDecay decay = const GlassDecay(),
    bool respectReduceMotion = true,
  }) {
    controller = GlassMotionController(
      vsync: const TestVSync(),
      settleMotion: settleMotion,
      decay: decay,
      overdrag: overdrag,
      respectReduceMotion: respectReduceMotion,
    );
    addTearDown(controller.dispose);
  }

  group('following a pointer', () {
    testWidgets('lags behind the target, then catches it', (tester) async {
      build();
      controller.follow(const Offset(100, 0));
      await tester.pump();
      await tester.pump(_frame);

      // Spring lag: the surface is on its way, not teleported.
      expect(controller.value.translation.dx, greaterThan(0));
      expect(controller.value.translation.dx, lessThan(100));

      await settle(tester, controller);
      expect(controller.value.translation, const Offset(100, 0));
      expect(controller.value.velocity, Offset.zero);
    });

    testWidgets(
      'a target moved every frame is tracked, not restarted — the follow '
      'primitive keeps velocity where animateTo would discard it',
      (tester) async {
        build();
        var target = Offset.zero;
        for (var i = 0; i < 24; i++) {
          target += const Offset(6, 0);
          controller.follow(target);
          await tester.pump(_frame);
        }
        // A surface that rebuilt its simulation from rest on every call
        // would still be crawling; one that keeps velocity is travelling at
        // close to the target's own speed by now.
        expect(controller.value.velocity.dx, greaterThan(300));
        expect(controller.value.translation.dx, greaterThan(target.dx - 40));
        // The framework checks, before any tearDown runs, that no animation
        // outlives the test. That check is worth keeping honest.
        controller.halt();
      },
    );

    testWidgets('never leaves the rubber band, however far it is pulled', (
      tester,
    ) async {
      build(overdrag: const GlassOverdrag(limit: 48));
      controller.follow(const Offset(100000, 0));
      await settle(tester, controller);
      expect(controller.value.translation.dx, lessThan(48));
      expect(controller.value.translation.dx, greaterThan(40));
    });

    testWidgets('reports the raw displacement a gesture should resume from', (
      tester,
    ) async {
      build(overdrag: const GlassOverdrag(limit: 48));
      controller.follow(const Offset(200, 0));
      await settle(tester, controller);
      // Feeding this straight back in must not move the surface at all —
      // otherwise a second gesture compounds the resistance.
      final resumed = controller.rawDisplacement;
      expect(resumed.dx, closeTo(200, 1e-6));
      final before = controller.value.translation;
      controller.follow(resumed);
      await tester.pump(_frame);
      expect(controller.value.translation.dx, closeTo(before.dx, 1e-6));
      controller.halt();
    });
  });

  group('release', () {
    testWidgets('springs home with overshoot when the motion is bouncy', (
      tester,
    ) async {
      build();
      controller.follow(const Offset(80, 0));
      await settle(tester, controller);
      controller.release();
      var crossedZero = false;
      var frames = 0;
      while (controller.isAnimating && frames < 1200) {
        await tester.pump(_frame);
        frames++;
        if (controller.value.translation.dx < -0.5) {
          crossedZero = true;
        }
      }
      expect(crossedZero, isTrue, reason: 'a bouncy release never overshot');
      expect(controller.value.translation, Offset.zero);
    });

    testWidgets('a smooth release never overshoots', (tester) async {
      build(settleMotion: const GlassMotion.smooth());
      controller.follow(const Offset(80, 0));
      await settle(tester, controller);
      controller.release();
      var frames = 0;
      while (controller.isAnimating && frames < 1200) {
        await tester.pump(_frame);
        frames++;
        expect(controller.value.translation.dx, greaterThanOrEqualTo(-1e-9));
      }
      expect(controller.value.translation, Offset.zero);
    });

    testWidgets(
      "takes the pointer velocity, not the spring's own lagging one",
      (tester) async {
        build();
        controller
          ..follow(const Offset(20, 0))
          ..release(withVelocity: const Offset(2500, 0));
        await tester.pump(_frame);
        // The throw carries it further out before it comes back.
        var furthest = 0.0;
        var frames = 0;
        while (controller.isAnimating && frames < 1200) {
          await tester.pump(_frame);
          frames++;
          if (controller.value.translation.dx > furthest) {
            furthest = controller.value.translation.dx;
          }
        }
        expect(furthest, greaterThan(60));
        expect(controller.value.translation, Offset.zero);
      },
    );
  });

  group('fling', () {
    testWidgets('carries the surface under friction and stops', (tester) async {
      build();
      controller.fling(const Offset(2000, 0));
      expect(controller.phase, GlassMotionPhase.flinging);
      final frames = await settle(tester, controller);
      expect(frames, greaterThan(20));
      expect(
        controller.value.translation.dx,
        closeTo(
          const GlassDecay().restingPoint(start: 0, velocity: 2000),
          1e-6,
        ),
      );
      expect(controller.phase, GlassMotionPhase.idle);
    });

    testWidgets('a bounded surface overshoots its band and springs back', (
      tester,
    ) async {
      build(overdrag: const GlassOverdrag(limit: 48));
      controller.fling(const Offset(4000, 0));
      var furthest = 0.0;
      var frames = 0;
      while (controller.isAnimating && frames < 2000) {
        await tester.pump(_frame);
        frames++;
        if (controller.value.translation.dx > furthest) {
          furthest = controller.value.translation.dx;
        }
      }
      expect(furthest, greaterThan(48));
      expect(controller.value.translation.dx, lessThan(48));
    });
  });

  group('press', () {
    testWidgets('settles on exactly 1 and exactly 0', (tester) async {
      build();
      controller.setPressed(pressed: true);
      await tester.pump();
      await tester.pump(_frame);
      expect(controller.value.press, greaterThan(0));
      expect(controller.value.press, lessThan(1));

      await settle(tester, controller);
      expect(controller.value.press, 1);

      controller.setPressed(pressed: false);
      await settle(tester, controller);
      expect(controller.value.press, 0);
    });
  });

  group('cost when settled', () {
    testWidgets(
      'a settled controller schedules no frames and notifies nobody',
      (tester) async {
        build();
        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..follow(const Offset(40, 0))
          ..release();
        await settle(tester, controller);

        expect(controller.isAnimating, isFalse);
        expect(tester.binding.hasScheduledFrame, isFalse);

        final settledAt = notifications;
        for (var i = 0; i < 10; i++) {
          await tester.pump(_frame);
        }
        expect(notifications, settledAt);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets('halt stops immediately and keeps the displacement', (
      tester,
    ) async {
      build();
      controller.follow(const Offset(100, 0));
      await tester.pump();
      await tester.pump(_frame);
      await tester.pump(_frame);
      final held = controller.value.translation;
      expect(held.dx, greaterThan(0));

      controller.halt();
      expect(controller.isAnimating, isFalse);
      expect(controller.value.translation, held);
      expect(controller.value.velocity, Offset.zero);
    });
  });

  group('status', () {
    testWidgets('is dismissed at rest, forward in flight, completed away '
        'from home', (tester) async {
      build();
      expect(controller.status, AnimationStatus.dismissed);

      controller.follow(const Offset(60, 0));
      await tester.pump();
      await tester.pump(_frame);
      expect(controller.status, AnimationStatus.forward);

      await settle(tester, controller);
      expect(controller.status, AnimationStatus.completed);

      controller.release();
      await settle(tester, controller);
      expect(controller.status, AnimationStatus.dismissed);
    });
  });

  group('Reduce Motion', () {
    // The singleton caches the last value it saw so it can tell a real
    // change from an unrelated accessibility flag flipping, so a test value
    // left set would be visible to whichever test ran next.
    void enableReduceMotion(WidgetTester tester) {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    }

    testWidgets('collapses every spring to an instant settle', (tester) async {
      enableReduceMotion(tester);
      build();

      controller.follow(const Offset(100, -40));
      expect(controller.value.translation, const Offset(100, -40));
      expect(controller.value.velocity, Offset.zero);
      expect(controller.isAnimating, isFalse);

      controller.setPressed(pressed: true);
      expect(controller.value.press, 1);
      expect(controller.isAnimating, isFalse);

      controller.release();
      expect(controller.value.translation, Offset.zero);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('leaves no velocity, so nothing squashes or stretches', (
      tester,
    ) async {
      enableReduceMotion(tester);
      build();
      controller.fling(const Offset(5000, 5000));
      expect(controller.value.velocity, Offset.zero);
    });

    testWidgets('the same motion springs normally when it is off', (
      tester,
    ) async {
      build();
      controller.follow(const Offset(100, -40));
      expect(controller.value.translation, isNot(const Offset(100, -40)));
      expect(controller.isAnimating, isTrue);
      controller.halt();
    });

    testWidgets('turning it on mid-flight settles on that frame', (
      tester,
    ) async {
      build();
      controller.follow(const Offset(100, 0));
      await tester.pump();
      await tester.pump(_frame);
      expect(controller.value.translation.dx, lessThan(100));

      enableReduceMotion(tester);
      expect(controller.value.translation, const Offset(100, 0));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('respectReduceMotion: false opts a surface out', (
      tester,
    ) async {
      enableReduceMotion(tester);
      build(respectReduceMotion: false);
      controller.follow(const Offset(100, 0));
      expect(controller.value.translation.dx, lessThan(100));
      expect(controller.isAnimating, isTrue);
      controller.halt();
    });
  });
}
