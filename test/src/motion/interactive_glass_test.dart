import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/motion/glass_jiggle.dart';
import 'package:glass_forge/src/motion/glass_motion.dart';
import 'package:glass_forge/src/motion/glass_overdrag.dart';
import 'package:glass_forge/src/motion/glass_press_stretch.dart';
import 'package:glass_forge/src/motion/interactive_glass.dart';
import 'package:glass_forge/src/motion/render_glass_motion.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// Counts how many times its subtree is rebuilt.
class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.child});

  final Widget child;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return widget.child;
  }
}

/// A material that renders nothing, so the composite pass is skipped.
///
/// `GlassComposition.build` short-circuits on `rendersAnything`, and that is
/// the only branch on this path that reaches `ui.ImageFilter.shader` — the
/// call that throws `UnsupportedError` outside Impeller. Every part of the
/// path these tests are about (the shape resolving its transform and
/// registering it with the layer's scene) happens in `RenderGlassShape`,
/// before and independently of the filter, so none of it is stubbed out
/// here. `GeometryTier.none` likewise only keeps a matte from being baked.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// A glass surface in a layer that composes nothing.
///
/// [pressStretch] defaults to [GlassPressStretch.none], unlike
/// [InteractiveGlass]'s own default: it is a second deformation channel
/// that every test predating it was written against a world without, and
/// leaving it active by default here would quietly perturb their geometry.
/// The press-stretch tests below opt into a real one explicitly.
Widget _harness({
  GlassDrag drag = const GlassDrag.none(),
  double? pressScale,
  GlassJiggle jiggle = const GlassJiggle(),
  GlassPressStretch pressStretch = const GlassPressStretch.none(),
  bool glow = true,
  Size size = const Size(100, 100),
  VoidCallback? onTap,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: GlassLayer(
      tier: GeometryTier.none,
      material: _inert,
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: _BuildCounter(
            child: InteractiveGlass(
              drag: drag,
              pressScale: pressScale,
              jiggle: jiggle,
              pressStretch: pressStretch,
              glow: glow,
              onTap: onTap,
              child: const Glass(
                shape: GlassRoundedRectangle(
                  radius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderGlassMotion _motionOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassMotion>(find.byType(InteractiveGlass));

RenderGlassLayer _layerOf(WidgetTester tester) =>
    tester.renderObject<RenderGlassLayer>(find.byType(GlassLayer));

/// The transform [motion] is painting under right now — the exact function
/// `RenderGlassMotion.paint` calls, rebuilt from its public getters so the
/// test reads what the render object would actually paint rather than
/// duplicating the maths.
Matrix4 _transformOf(RenderGlassMotion motion) => glassSurfaceTransform(
  size: motion.size,
  state: motion.controller.value,
  jiggle: motion.jiggle,
  pressStretch: motion.pressStretch,
  pressScale: motion.resolvedPressScale,
);

Future<void> _settle(WidgetTester tester, RenderGlassMotion motion) async {
  var frames = 0;
  while (motion.controller.isAnimating && frames < 1200) {
    await tester.pump(const Duration(milliseconds: 8));
    frames++;
  }
}

/// Every `FlutterErrorDetails` reported while [body] runs.
///
/// Deliberately not `tester.takeException()`: that collapses however many
/// errors one `pumpWidget` produced into a single synthetic string and
/// throws the originals away, so a test built on it can neither say how
/// many errors there were nor which one it caught. This installs its own
/// handler and keeps every report whole.
Future<List<FlutterErrorDetails>> _errorsDuring(
  Future<void> Function() body,
) async {
  final reports = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reports.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reports;
}

/// What [_errorsDuring] caught, as strings, for a readable failure.
Iterable<String> _messages(List<FlutterErrorDetails> reports) =>
    reports.map((report) => report.exceptionAsString());

/// One `InteractiveGlass` in a fixed slot, keyless on purpose.
///
/// Keyless is the whole point: Flutter matches the old element to the new
/// widget by runtime type and updates it in place, which is what a tree
/// whose shape depends on [drag] cannot survive.
Widget _slot(GlassDrag drag) => Directionality(
  textDirection: TextDirection.ltr,
  child: GlassLayer(
    tier: GeometryTier.none,
    material: _inert,
    child: Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: InteractiveGlass(
          drag: drag,
          pressStretch: const GlassPressStretch.none(),
          child: const Glass(
            shape: GlassRoundedRectangle(
              radius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// A surface with no drag and no [InteractiveGlass.onTap]: nothing for it
/// to handle, which is the configuration the hit-testing tests below pin.
const Widget _plainSurface = SizedBox(
  width: 100,
  height: 100,
  child: InteractiveGlass(
    pressStretch: GlassPressStretch.none(),
    child: Glass(
      shape: GlassRoundedRectangle(
        radius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  ),
);

void main() {
  _retuneTests();
  _treeShapeTests();
  setUp(() => _BuildCounterState.builds = 0);

  testWidgets('a press reaches the surface on pointer down', (tester) async {
    await tester.pumpWidget(_harness());
    final motion = _motionOf(tester);

    final gesture = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(motion.controller.value.press, greaterThan(0));

    await gesture.up();
    await _settle(tester, motion);
    expect(motion.controller.value.press, 0);
  });

  testWidgets(
    'a spring runs for its whole length without rebuilding one widget',
    (tester) async {
      await tester.pumpWidget(_harness());
      final motion = _motionOf(tester);
      final buildsAfterFirstFrame = _BuildCounterState.builds;

      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump();
      var frames = 0;
      while (motion.controller.isAnimating && frames < 400) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      await gesture.up();
      await _settle(tester, motion);

      expect(frames, greaterThan(5), reason: 'the press never animated');
      // The whole architecture: a controller listener calling
      // markNeedsPaint. One setState per frame would show up here as one
      // build per frame.
      expect(_BuildCounterState.builds, buildsAfterFirstFrame);
    },
  );

  testWidgets(
    'the animated transform reaches the shape geometry the shader reads',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          drag: const GlassDrag(overdrag: GlassOverdrag.none()),
          pressScale: 1,
        ),
      );
      final motion = _motionOf(tester);
      final layer = _layerOf(tester);

      final before = layer.scene.shapes.single.origin;

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(60, -20));
      await tester.pump();
      await _settle(tester, motion);

      expect(motion.controller.value.translation, const Offset(60, -20));

      final after = layer.scene.shapes.single.origin;
      final dpr = tester.view.devicePixelRatio;
      // Registered geometry is in layer-local physical pixels, so the
      // shape's origin moves by the logical drag times the device pixel
      // ratio. Nothing here rebuilt a widget; this arrived through
      // `applyPaintTransform`.
      expect(after.dx - before.dx, closeTo(60 * dpr, 1e-6));
      expect(after.dy - before.dy, closeTo(-20 * dpr, 1e-6));

      await gesture.up();
      await _settle(tester, motion);
      expect(layer.scene.shapes.single.origin, before);
    },
  );

  testWidgets('squash and stretch reaches the registered basis too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(overdrag: GlassOverdrag.none()),
        pressScale: 1,
        jiggle: const GlassJiggle(maxStretch: 1.5, halfSpeed: 200),
      ),
    );
    final motion = _motionOf(tester);
    final layer = _layerOf(tester);
    final restingBasis = Float32List.fromList(
      layer.scene.shapes.single.inverseBasis,
    );

    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 8));
    await tester.pump(const Duration(milliseconds: 8));

    // Moving fast along x: the basis must no longer be the resting one, and
    // the shape must be wider along x than across it.
    final moving = layer.scene.shapes.single.inverseBasis;
    expect(motion.controller.value.velocity.dx, greaterThan(0));
    expect(moving[0], isNot(closeTo(restingBasis[0], 1e-6)));
    expect(moving[0].abs(), lessThan(moving[3].abs()));

    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('hit testing follows the surface, not its laid-out box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(overdrag: GlassOverdrag.none()),
        pressScale: 1,
      ),
    );
    final motion = _motionOf(tester);

    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await _settle(tester, motion);
    expect(motion.controller.value.translation, const Offset(60, 0));

    // Local coordinates of the 100x100 motion box, which itself never
    // moved: x = 130 is outside its own bounds and inside the surface,
    // which now spans 60 to 160. `RenderBox.hitTest`'s `size.contains`
    // gate would reject it before the transform was ever consulted.
    expect(
      motion.hitTest(BoxHitTestResult(), position: const Offset(130, 50)),
      isTrue,
      reason: 'the displaced surface is not hittable where it now is',
    );
    expect(
      motion.hitTest(BoxHitTestResult(), position: const Offset(10, 50)),
      isFalse,
      reason: 'the surface is still hittable where it no longer is',
    );

    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('a tap still lands when nothing has been dragged', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onTap: () => taps++));
    await tester.tap(find.byType(InteractiveGlass));
    await tester.pump();
    expect(taps, 1);
    await _settle(tester, _motionOf(tester));
  });

  testWidgets('a drag constrained to one axis ignores the other', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        drag: const GlassDrag(
          axis: Axis.horizontal,
          overdrag: GlassOverdrag.none(),
        ),
        pressScale: 1,
      ),
    );
    final motion = _motionOf(tester);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(40, 70));
    await tester.pump();
    await _settle(tester, motion);
    expect(motion.controller.value.translation, const Offset(40, 0));
    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets('changing a motion swaps the controller without leaking', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final first = _motionOf(tester).controller;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          tier: GeometryTier.none,
          material: _inert,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: InteractiveGlass(
                pressMotion: GlassMotion.smooth(),
                child: Glass(shape: GlassOval()),
              ),
            ),
          ),
        ),
      ),
    );
    final second = _motionOf(tester).controller;
    expect(identical(first, second), isFalse);
    // The retired controller must be dead, not merely unreferenced: its
    // ticker would otherwise keep scheduling frames forever.
    expect(first.isAnimating, isFalse);
  });

  testWidgets(
    'a dragging pointer stretches the surface along the drag, and '
    'releasing returns it to identity',
    (tester) async {
      await tester.pumpWidget(
        // pressStretch is turned on explicitly (the harness defaults it
        // off) and pressScale: 1 isolates the stretch from the surface's
        // separate, unrelated press growth, the same way the drag and
        // hit-testing tests above isolate the channel they are about.
        _harness(
          size: const Size(200, 80),
          pressScale: 1,
          pressStretch: const GlassPressStretch(),
        ),
      );
      final motion = _motionOf(tester);

      final centre = tester.getCenter(find.byType(InteractiveGlass));
      final gesture = await tester.startGesture(centre);
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        _transformOf(motion),
        equals(Matrix4.identity()),
        reason: 'a finger that has not moved stretched the surface',
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Longer along x, the drag's own axis, and shorter across it.
      final m = _transformOf(motion);
      expect(m.entry(0, 0), greaterThan(1));
      // No squash by default: a native button keeps its width.
      expect(m.entry(1, 1), closeTo(1, 1e-9));

      await gesture.up();
      await _settle(tester, motion);
      expect(_transformOf(motion), equals(Matrix4.identity()));
      expect(motion.controller.value.pressDrag, Offset.zero);
    },
  );

  testWidgets('Reduce Motion stretches nothing while dragged', (
    tester,
  ) async {
    // The singleton caches the last value it saw, so a test value left set
    // would be visible to whichever test ran next.
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(
      _harness(
        size: const Size(200, 80),
        pressScale: 1,
        pressStretch: const GlassPressStretch(),
      ),
    );
    final motion = _motionOf(tester);

    final centre = tester.getCenter(find.byType(InteractiveGlass));
    final gesture = await tester.startGesture(centre);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Without the explicit `GlassPressStretch.none()` resolution under
    // Reduce Motion, `press` would still snap straight to 1 while the
    // drag is live, and this would come back stretched, not identity.
    expect(motion.controller.value.pressDrag, isNot(Offset.zero));
    expect(_transformOf(motion), equals(Matrix4.identity()));

    await gesture.up();
    await _settle(tester, motion);
  });

  testWidgets(
    'the press drag reaches the render object without rebuilding a '
    'widget',
    (tester) async {
      await tester.pumpWidget(_harness(size: const Size(200, 80)));
      final motion = _motionOf(tester);
      final buildsAfterFirstFrame = _BuildCounterState.builds;

      final centre = tester.getCenter(find.byType(InteractiveGlass));
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      // The drag is not sprung, so it reaches the controller's published
      // state on the very next frame — no extra pump, no rebuild.
      expect(motion.controller.value.pressDrag, const Offset(30, 0));

      var frames = 0;
      while (motion.controller.isAnimating && frames < 400) {
        await tester.pump(const Duration(milliseconds: 8));
        frames++;
      }
      await gesture.up();
      await _settle(tester, motion);

      expect(frames, greaterThan(5), reason: 'the press never animated');
      expect(_BuildCounterState.builds, buildsAfterFirstFrame);
    },
  );

  testWidgets(
    'carrying a surface a long way stretches it no more than the cap',
    (tester) async {
      // The surface follows the finger, so the finger's travel is large
      // however little it moves relative to the glass. The rubber band on
      // the drag is what keeps a 300 px carry from pulling the glass into
      // a needle.
      await tester.pumpWidget(
        _harness(
          drag: const GlassDrag(
            returnsHome: false,
            overdrag: GlassOverdrag.none(),
          ),
          pressScale: 1,
          jiggle: const GlassJiggle.none(),
          pressStretch: const GlassPressStretch(),
        ),
      );
      final motion = _motionOf(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InteractiveGlass)),
      );
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final state = motion.controller.value;
      expect(state.translation.dx, greaterThan(250), reason: 'never dragged');
      expect(state.pressDrag.dx, closeTo(300, 1e-6));
      final m = _transformOf(motion);
      expect(m.entry(0, 0), greaterThan(1));
      expect(m.entry(0, 0), lessThanOrEqualTo(1.35 + 1e-9));

      await gesture.up();
      await _settle(tester, motion);
    },
  );

  testWidgets('a press lights its own surface, not the whole layer', (
    tester,
  ) async {
    // The glow is one light per layer, shared by every surface in it. At a
    // fixed 320 px and 0.55 it washed a whole screen of 64 px tiles white
    // for a press on any one of them. Sized to the pressed surface and
    // soft, it lifts that surface evenly and spills only a little past it.
    await tester.pumpWidget(_harness(size: const Size(64, 64)));
    final glow = tester.widget<GlassGlowScope>(find.byType(GlassGlowScope));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveGlass)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(glow.glow.value.strength, greaterThan(0), reason: 'no glow');
    expect(glow.glow.value.strength, lessThanOrEqualTo(0.12));
    expect(glow.glow.value.radius, greaterThanOrEqualTo(64));
    expect(glow.glow.value.radius, lessThanOrEqualTo(96));
    await gesture.up();
    await _settle(tester, _motionOf(tester));
  });

  testWidgets('glow: false never claims or writes the shared channel', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(size: const Size(64, 64), glow: false));
    final glow = tester.widget<GlassGlowScope>(find.byType(GlassGlowScope));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InteractiveGlass)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(glow.glow.value.strength, 0, reason: 'glow: false still glowed');
    await gesture.up();
    await _settle(tester, _motionOf(tester));
    expect(glow.glow.value.strength, 0);
  });
}

void _retuneTests() {
  testWidgets('retuning a spring at runtime does not throw', (tester) async {
    // Regression: the state used SingleTickerProviderStateMixin, whose guard
    // fires if a ticker was ever created rather than if one is still live.
    // Replacing the controller to adopt new springs therefore threw
    // "multiple tickers were created" — so every spring control in the
    // workbench's motion playground crashed the screen on first use.
    Widget build(GlassMotion settle) => Directionality(
      textDirection: TextDirection.ltr,
      child: GlassLayer(
        child: InteractiveGlass(
          settleMotion: settle,
          drag: const GlassDrag(),
          child: const Glass(shape: GlassOval()),
        ),
      ),
    );

    await tester.pumpWidget(build(const GlassMotion.smooth()));
    await tester.pumpWidget(build(const GlassMotion.bouncy()));
    await tester.pumpWidget(
      build(const GlassMotion.snappy(duration: Duration(milliseconds: 240))),
    );

    expect(tester.takeException(), isNull);
  });
}

void _treeShapeTests() {
  // Regression: `build` used to wrap the child in a `GestureDetector` only
  // when `drag.enabled || onTap != null`, so two `InteractiveGlass`es that
  // differed only in that produced differently-shaped subtrees. Swapping
  // one for the other in the same slot left Flutter updating an element
  // against a widget of a different type, and the mismatch surfaced as a
  // layout-time crash rather than as anything the API hints at.
  testWidgets('swapping a still surface for a draggable one does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(_slot(const GlassDrag.none()));
    final before = tester.state<State<InteractiveGlass>>(
      find.byType(InteractiveGlass),
    );

    final reports = await _errorsDuring(
      () => tester.pumpWidget(_slot(const GlassDrag())),
    );

    expect(_messages(reports), isEmpty);
    expect(
      tester.state<State<InteractiveGlass>>(find.byType(InteractiveGlass)),
      same(before),
      reason:
          'the swap inflated a fresh element, so it never exercised '
          'the in-place update this is about',
    );
    await _settle(tester, _motionOf(tester));
  });

  testWidgets('swapping a draggable surface for a still one does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(_slot(const GlassDrag()));
    final before = tester.state<State<InteractiveGlass>>(
      find.byType(InteractiveGlass),
    );

    final reports = await _errorsDuring(
      () => tester.pumpWidget(_slot(const GlassDrag.none())),
    );

    expect(_messages(reports), isEmpty);
    expect(
      tester.state<State<InteractiveGlass>>(find.byType(InteractiveGlass)),
      same(before),
      reason:
          'the swap inflated a fresh element, so it never exercised '
          'the in-place update this is about',
    );
    await _settle(tester, _motionOf(tester));
  });

  // The two below are the regression the fix above risks: keeping the tree
  // shape stable means a `GestureDetector` is now present on surfaces that
  // handle no gesture at all, and that must not change what such a surface
  // does to a pointer.
  testWidgets('a surface with no drag and no onTap is still opaque', (
    tester,
  ) async {
    var behind = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          tier: GeometryTier.none,
          material: _inert,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => behind++,
                ),
              ),
              const Center(child: _plainSurface),
            ],
          ),
        ),
      ),
    );

    // The control: the widget behind is reachable everywhere the surface
    // is not, so a zero below means the surface swallowed the tap rather
    // than that nothing was listening.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(behind, 1, reason: 'the widget behind never received a tap');

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(
      behind,
      1,
      reason: 'a tap passed through the surface to the widget behind it',
    );
    await _settle(tester, _motionOf(tester));
  });

  // A parent *pan* is the gesture a spurious child recognizer would
  // actually take. A parent vertical or horizontal drag proves nothing
  // here: it declares victory at `kTouchSlop` while a pan is still waiting
  // for `kPanSlop`, so it beats a child pan either way — a scrollable
  // ancestor is never at risk. Pan against pan is decided by which
  // recognizer accepts first, and the child's is added to the arena and
  // routed its events first, so the child takes it.
  testWidgets('a surface with no drag leaves a parent pan to the parent', (
    tester,
  ) async {
    var starts = 0;
    var cancels = 0;
    var travel = Offset.zero;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GlassLayer(
          tier: GeometryTier.none,
          material: _inert,
          child: GestureDetector(
            onPanStart: (_) => starts++,
            onPanUpdate: (details) => travel += details.delta,
            onPanCancel: () => cancels++,
            child: const Center(child: _plainSurface),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(InteractiveGlass), const Offset(0, -150));
    await tester.pump();

    expect(starts, 1, reason: 'the surface took the parent pan');
    expect(cancels, 0, reason: 'the arena cancelled the parent pan');
    expect(
      travel.dy,
      lessThan(-100),
      reason: 'the parent pan won but never tracked the finger',
    );
    await _settle(tester, _motionOf(tester));
  });
}
