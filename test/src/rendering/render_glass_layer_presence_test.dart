import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';

void main() {
  testWidgets('animating presence bakes no new mattes', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: controller,
            child: const Glass(
              shape: GlassOval(),
              child: SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    controller.forward();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // The 20 pumps above land the controller just short of `completed`
    // (the first pump only primes its ticker's start reference; the
    // other 19 each advance it by 10ms, for 190ms of the 200ms duration),
    // so its ticker is still active here. Stopping it directly, rather
    // than pumping a 21st frame, keeps this test's frame count exactly
    // what the brief specifies and leaves nothing for the framework's
    // end-of-test "was every ticker disposed" check to catch.
    controller.stop();

    expect(
      GlassRenderCounters.instance.matteProduceCount,
      0,
      reason: 'presence must not re-key a pass or invalidate its matte',
    );
  });

  testWidgets('presence 0 pushes no backdrop filter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassLayer(
          child: GlassPresence(
            presence: AlwaysStoppedAnimation<double>(0),
            child: Glass(
              shape: GlassOval(),
              child: SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    GlassRenderCounters.instance.reset();
    await tester.pump();
    expect(GlassRenderCounters.instance.backdropPushCount, 0);
  });
}
