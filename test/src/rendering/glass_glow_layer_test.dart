import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/diagnostics/render_counters.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';

RenderGlassLayer _layerOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassLayer>(find.byType(GlassLayer));

Widget _surface({
  Key? key,
  // Defaults match `InteractiveGlass`'s own (a null `pressScale` grows the
  // surface by `pressGrowth`); a test that wants to isolate the glow from
  // the unrelated press-scale and press-stretch channels (which really do
  // deform geometry, and really do cost a fresh matte once their own
  // spring actually ticks) passes `pressScale: 1` and
  // `pressStretch: const GlassPressStretch.none()` explicitly, the same
  // isolation `interactive_glass_test.dart` uses for the channels it is
  // about.
  double? pressScale,
  GlassPressStretch pressStretch = const GlassPressStretch(),
}) => InteractiveGlass(
  key: key,
  pressScale: pressScale,
  pressStretch: pressStretch,
  child: const Glass(
    shape: GlassRoundedRectangle(
      radius: BorderRadius.all(Radius.circular(28)),
    ),
    child: SizedBox(width: 160, height: 56),
  ),
);

void main() {
  testWidgets('pressing raises the glow and releasing lets it go', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          // Depth scale and press-stretch are switched off so a real
          // press-spring tick, below, cannot be mistaken for the cost this
          // test is actually about: those two channels really do deform
          // geometry once they animate, and really do cost a fresh matte
          // when they do -- unrelated to whether the glow itself costs one.
          child: Center(
            child: _surface(
              pressScale: 1,
              pressStretch: const GlassPressStretch.none(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    GlassRenderCounters.instance.reset();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Glass)),
    );
    // A ticker's very first callback always reports zero elapsed (nothing
    // has moved yet to integrate), so an initial zero-duration pump is
    // needed to consume that no-op tick before a timed one can observe any
    // real movement — the same two-pump shape every other test in this
    // package that presses and checks a spring value right away uses.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // The glow must not cost a matte: it is a uniform, not geometry.
    expect(GlassRenderCounters.instance.matteProduceCount, 0);
    // And it must actually have reached the layer's render object.
    expect(_layerOf(tester).glow.isActive, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_layerOf(tester).glow, const GlassGlow.none());
  });

  testWidgets('Reduce Motion keeps a static glow, not a spreading one', (
    tester,
  ) async {
    // The peak to expect, read off a press held to rest under normal
    // motion rather than restated here: it tracks the glow's configured
    // strength for this brightness, whatever that is tuned to.
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(child: Center(child: _surface())),
      ),
    );
    final reference = await tester.startGesture(
      tester.getCenter(find.byType(Glass)),
    );
    await tester.pumpAndSettle();
    final peak = _layerOf(tester).glow.strength;
    expect(peak, greaterThan(0), reason: 'the reference press never glowed');
    await reference.up();
    await tester.pumpAndSettle();

    // The singleton caches the last value it saw, so a test value left set
    // would leak into whichever test runs next.
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GlassLayer(child: Center(child: _surface())),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Glass)),
    );
    // One frame, not a ramp: the glow is at full strength
    // immediately, not partway through an animation.
    await tester.pump();
    final glow = _layerOf(tester).glow;
    expect(glow.isActive, isTrue);
    expect(
      glow.strength,
      closeTo(peak, 1e-9),
      reason:
          'under Reduce Motion the press channel settles instantly, so '
          'strength should already be at its full value on the '
          'very first frame rather than partway through a ramp',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_layerOf(tester).glow, const GlassGlow.none());
  });

  testWidgets(
    'under normal motion the glow actually ramps in, unlike under Reduce '
    'Motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(child: Center(child: _surface())),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Glass)),
      );
      // The leading zero-duration pump consumes the ticker's always-zero
      // first callback; the short one after it is where the spring has
      // barely started moving.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 8));
      final early = _layerOf(tester).glow;
      expect(early.isActive, isTrue);
      expect(
        early.strength,
        lessThan(0.4),
        reason:
            'the press spring has barely started, this should not '
            'already be near full strength',
      );

      await tester.pump(const Duration(milliseconds: 400));
      final settled = _layerOf(tester).glow;
      expect(settled.strength, greaterThan(early.strength));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'the glow reaches the render object without rebuilding a widget',
    (tester) async {
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            child: Center(
              child: Builder(
                builder: (context) {
                  builds++;
                  return _surface();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final buildsAfterFirstFrame = builds;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Glass)),
      );
      var frames = 0;
      while (frames < 60) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(builds, buildsAfterFirstFrame);
    },
  );

  testWidgets(
    'last writer wins, and a release does not clobber a newer claim',
    (tester) async {
      const keyA = ValueKey('a');
      const keyB = ValueKey('b');
      await tester.pumpWidget(
        MaterialApp(
          home: GlassLayer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _surface(key: keyA),
                _surface(key: keyB),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final centreA = tester.getCenter(
        find.descendant(
          of: find.byKey(keyA),
          matching: find.byType(Glass),
        ),
      );
      final centreB = tester.getCenter(
        find.descendant(
          of: find.byKey(keyB),
          matching: find.byType(Glass),
        ),
      );

      // A is pressed and settles: it owns the channel.
      final gestureA = await tester.startGesture(centreA);
      await tester.pumpAndSettle();
      final glowA = _layerOf(tester).glow;
      expect(glowA.isActive, isTrue);
      expect(glowA.centre.dx, closeTo(centreA.dx, 1));

      // B is pressed while A is still held, and settles: last writer wins,
      // so the one shared glow now follows B, not A.
      final gestureB = await tester.startGesture(centreB);
      await tester.pumpAndSettle();
      final glowB = _layerOf(tester).glow;
      expect(glowB.centre.dx, closeTo(centreB.dx, 1));
      expect(glowB.centre.dx, isNot(closeTo(centreA.dx, 1)));

      // A releases while B is still held. A's own decay must not zero — or
      // otherwise disturb — the claim B has since taken.
      await gestureA.up();
      await tester.pumpAndSettle();
      expect(_layerOf(tester).glow, glowB);

      // B finally releases too: now the channel really is empty.
      await gestureB.up();
      await tester.pumpAndSettle();
      expect(_layerOf(tester).glow, const GlassGlow.none());
    },
  );

  testWidgets("the glow centre lands in the layer's space, not the surface's", (
    tester,
  ) async {
    const keyA = ValueKey('a');
    await tester.pumpWidget(
      MaterialApp(
        home: GlassLayer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: _surface(key: keyA),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final layer = _layerOf(tester);
    final glassCentreGlobal = tester.getCenter(find.byType(Glass));
    final expectedLocal = layer.globalToLocal(glassCentreGlobal);

    final gesture = await tester.startGesture(glassCentreGlobal);
    await tester.pumpAndSettle();

    final glow = layer.glow;
    expect(glow.centre.dx, closeTo(expectedLocal.dx, 1));
    expect(glow.centre.dy, closeTo(expectedLocal.dy, 1));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
