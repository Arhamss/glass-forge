import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_motion_controller.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

// The touch response at its shipped defaults, measured the way the eye
// meets it: through the transform the surface actually paints under. See
// the research behind the numbers in `GlassPressStretch`'s doc comment.

const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// A default `InteractiveGlass` of [size] — no knob set — in a layer that
/// composes nothing.
Widget _surface(
  Size size, {
  Brightness brightness = Brightness.light,
}) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: GlassLayer(
        tier: GeometryTier.none,
        material: _inert,
        child: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: const InteractiveGlass(
              child: Glass(shape: GlassOval()),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderGlassMotion _motionOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassMotion>(find.byType(InteractiveGlass));

/// The transform the surface paints under right now, read through the
/// render object's own `applyPaintTransform`.
Matrix4 _painted(RenderGlassMotion motion) {
  final m = Matrix4.identity();
  motion.applyPaintTransform(motion.child!, m);
  return m;
}

/// The 2x2's singular values, largest first.
(double, double) _axes(Matrix4 m) {
  final a = m.entry(0, 0);
  final b = m.entry(0, 1);
  final c = m.entry(1, 0);
  final d = m.entry(1, 1);
  final s = a * a + b * b + c * c + d * d;
  final det = (a * d - b * c).abs();
  final root = math.sqrt(math.max(0, s * s / 4 - det * det));
  return (math.sqrt(s / 2 + root), math.sqrt(math.max(0, s / 2 - root)));
}

/// How far the 2x2 departs from a uniform scale: 1 when it is one.
double _elongation(Matrix4 m) {
  final (major, minor) = _axes(m);
  return major / minor;
}

Future<void> _hold(WidgetTester tester, [int frames = 60]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a finger held still at the edge does not stretch the glass', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(const Size(200, 80)));
    final motion = _motionOf(tester);
    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre + const Offset(95, 35));
    await _hold(tester);

    final m = _painted(motion);
    expect(m.entry(0, 1), closeTo(0, 1e-9));
    expect(m.entry(1, 0), closeTo(0, 1e-9));
    expect(m.entry(0, 0), closeTo(m.entry(1, 1), 1e-9));

    await gesture.up();
    await _hold(tester, 120);
  });

  testWidgets('a 2 pt drag is inside the dead zone', (tester) async {
    await tester.pumpWidget(_surface(const Size(100, 100)));
    final motion = _motionOf(tester);
    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre);
    await _hold(tester, 10);
    await gesture.moveBy(const Offset(2, 0));
    await _hold(tester);

    expect(_elongation(_painted(motion)), closeTo(1, 1e-9));

    await gesture.up();
    await _hold(tester, 120);
  });

  testWidgets('a long drag stretches, but never past about 5 %', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(const Size(100, 100)));
    final motion = _motionOf(tester);
    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre);
    var largest = 1.0;
    for (var i = 0; i < 60; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
      // Elongation along the drag over squash across it: with squash 1
      // that is the stretch squared.
      largest = math.max(largest, math.sqrt(_elongation(_painted(motion))));
    }
    expect(largest, greaterThan(1.01), reason: 'the drag never stretched');
    expect(largest, lessThanOrEqualTo(1.05 + 1e-9));

    await gesture.up();
    await _hold(tester, 120);
  });

  group('a press grows the surface by a fixed amount', () {
    Future<double> pressedScale(WidgetTester tester, Size size) async {
      await tester.pumpWidget(_surface(size));
      final motion = _motionOf(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InteractiveGlass)),
      );
      await _hold(tester, 90);
      final (major, minor) = _axes(_painted(motion));
      expect(major, closeTo(minor, 1e-9), reason: 'not a uniform scale');
      await gesture.up();
      await _hold(tester, 120);
      return major;
    }

    testWidgets('+17 pt on a 132 pt pill', (tester) async {
      final scale = await pressedScale(tester, const Size(132, 44));
      expect(scale * 132 - 132, closeTo(17, 0.05));
    });

    testWidgets('a tiny surface is clamped to 1.3', (tester) async {
      expect(
        await pressedScale(tester, const Size(24, 24)),
        closeTo(1.3, 1e-6),
      );
    });

    testWidgets('a huge surface is clamped to 1.04', (tester) async {
      final scale = await pressedScale(tester, const Size(700, 200));
      expect(scale, closeTo(1.04, 1e-6));
    });
  });

  testWidgets('the touch glow is a soft lift across the whole surface', (
    tester,
  ) async {
    const size = Size(132, 44);
    await tester.pumpWidget(_surface(size));
    final scope = tester.widget<GlassGlowScope>(find.byType(GlassGlowScope));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveGlass)),
    );
    var peak = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      peak = math.max(peak, scope.glow.value.strength);
    }
    expect(peak, greaterThan(0), reason: 'no glow');
    // Overshoot of the press spring may carry it a hair past full press.
    expect(peak, lessThanOrEqualTo(0.10 * 1.2));
    expect(scope.glow.value.strength, closeTo(0.10, 0.005));
    expect(
      scope.glow.value.radius,
      greaterThanOrEqualTo(size.longestSide),
      reason: 'the glow does not reach across the surface',
    );
    await gesture.up();
    await _hold(tester, 120);
  });

  testWidgets('the glow is half as strong in dark mode', (tester) async {
    await tester.pumpWidget(
      _surface(const Size(132, 44), brightness: Brightness.dark),
    );
    final scope = tester.widget<GlassGlowScope>(find.byType(GlassGlowScope));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveGlass)),
    );
    await _hold(tester);
    expect(scope.glow.value.strength, closeTo(0.05, 0.003));
    await gesture.up();
    await _hold(tester, 120);
  });

  test('the velocity jiggle tops out at 1.08, half of it at 2000 px/s', () {
    const jiggle = GlassJiggle();
    expect(jiggle.maxStretch, 1.08);
    expect(jiggle.stretchFor(2000), closeTo(1.04, 1e-9));
  });

  test('the press spring is snappy, 250 ms with a 0.25 bounce', () {
    const glass = InteractiveGlass(child: SizedBox.shrink());
    expect(glass.pressMotion.duration, const Duration(milliseconds: 250));
    expect(glass.pressMotion.bounce, closeTo(0.25, 1e-9));
  });

  test('the release runs its own spring: bouncy, 280 ms, 0.45', () {
    const glass = InteractiveGlass(child: SizedBox.shrink());
    expect(
      glass.pressReleaseMotion.duration,
      const Duration(milliseconds: 280),
    );
    expect(glass.pressReleaseMotion.bounce, closeTo(0.45, 1e-9));
  });

  group('letting go', () {
    /// The lowest the press channel dips after a full press is released.
    double undershoot(GlassMotion release) {
      final controller = GlassMotionController(
        vsync: const TestVSync(),
        pressReleaseMotion: release,
      );
      addTearDown(controller.dispose);
      var lowest = 0.0;
      var clock = 0;
      void run({required bool pressed}) {
        controller.setPressed(pressed: pressed);
        final binding = TestWidgetsFlutterBinding.instance;
        for (var t = 0; t < 120; t++) {
          clock += 8;
          binding
            ..handleBeginFrame(Duration(milliseconds: clock))
            ..handleDrawFrame();
          lowest = math.min(lowest, controller.value.press);
        }
      }

      run(pressed: true);
      lowest = 0;
      run(pressed: false);
      return lowest;
    }

    testWidgets('rides the release spring, not the press one', (
      tester,
    ) async {
      expect(undershoot(const GlassMotion.smooth()), closeTo(0, 1e-3));
      expect(
        undershoot(
          const InteractiveGlass(child: SizedBox.shrink()).pressReleaseMotion,
        ),
        lessThan(-0.02),
      );
    });
  });
}
