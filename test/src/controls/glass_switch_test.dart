import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/glass_switch.dart';
import 'package:glass_forge/src/controls/track_cutout.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// A material that renders nothing, so the composite pass is skipped — the
/// same reason `glass_button_test.dart` needs it outside Impeller.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// [child] in a layer, either on content or, with [onGlass], nested inside a
/// real `Glass` so `GlassHostScope.isOnGlass` reads true for it.
Widget _harness({
  required Widget child,
  bool onGlass = false,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final content = onGlass
      ? Glass(
          shape: const GlassOval(),
          child: Center(child: child),
        )
      : Center(child: child);
  return Directionality(
    textDirection: textDirection,
    child: GlassLayer(
      tier: GeometryTier.none,
      material: _inert,
      child: SizedBox(width: 200, height: 200, child: content),
    ),
  );
}

/// Drags [finder] horizontally by [dx] logical pixels from its centre, as a
/// mouse pointer.
///
/// Mouse, not the default touch: `kTouchSlop` for touch is 18 logical
/// pixels against a 22-pixel knob travel, which leaves no room to express
/// "past half" and "short of half" as distinct, unambiguous drags. A mouse
/// pointer's slop (`kPrecisePointerPanSlop`) is 2, which does.
Future<void> _dragBy(WidgetTester tester, Finder finder, double dx) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('a tap toggles and reports the new value', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _harness(
        child: GlassSwitch(value: value, onChanged: (next) => value = next),
      ),
    );

    await tester.tap(find.byType(GlassSwitch));
    await tester.pump();

    expect(value, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('a drag past half flips and reports true', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _harness(
        child: GlassSwitch(value: value, onChanged: (next) => value = next),
      ),
    );

    // Travel is 22px; past half is > 11.
    await _dragBy(tester, find.byType(GlassSwitch), 16);

    expect(value, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('a drag short of half does not flip', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _harness(
        child: GlassSwitch(value: value, onChanged: (next) => value = next),
      ),
    );

    // Travel is 22px; short of half is < 11.
    await _dragBy(tester, find.byType(GlassSwitch), 6);

    expect(value, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a disabled switch never fires and never builds a press response',
    (tester) async {
      await tester.pumpWidget(
        _harness(child: const GlassSwitch(value: false, onChanged: null)),
      );

      await tester.tap(find.byType(GlassSwitch));
      await tester.pump();
      await _dragBy(tester, find.byType(GlassSwitch), 16);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('semantics report a toggle, on, with the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassSwitch(
          value: true,
          onChanged: (_) {},
          semanticLabel: 'Wi-Fi',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassSwitch)),
      isSemantics(
        label: 'Wi-Fi',
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('semantics report a toggle, off, when disabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: const GlassSwitch(
          value: false,
          onChanged: null,
          semanticLabel: 'Wi-Fi',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassSwitch)),
      isSemantics(
        label: 'Wi-Fi',
        isEnabled: false,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('Space toggles a focused switch', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _harness(
        child: GlassSwitch(value: value, onChanged: (next) => value = next),
      ),
    );

    // `GlassSwitch` has no `focusNode` of its own to reach from outside —
    // `GlassControlFrame` owns one internally, the same as it does for a
    // `GlassButton` built without one. The harness has exactly one
    // focusable node, so it is found directly rather than through a
    // traversal policy, which the bare `Directionality` root here has none
    // of (that is `WidgetsApp`'s job, and this harness has no `WidgetsApp`).
    FocusManager.instance.rootScope.descendants
        .firstWhere((node) => node.canRequestFocus)
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(value, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('exactly one Glass on content', (tester) async {
    await tester.pumpWidget(
      _harness(child: GlassSwitch(value: false, onChanged: (_) {})),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byType(Glass),
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero Glass under GlassHostScope', (tester) async {
    await tester.pumpWidget(
      _harness(
        onGlass: true,
        child: GlassSwitch(value: false, onChanged: (_) {}),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byType(Glass),
      ),
      findsNothing,
    );
  });

  testWidgets('Reduce Motion lands the knob instantly', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    var value = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _harness(
          child: GlassSwitch(
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GlassSwitch));
    // Exactly one frame: an instant settle needs no further pumps to reach
    // its target, unlike a spring, which would still be travelling here.
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.getTranslation().x, 22);
    expect(value, isTrue);
  });

  testWidgets(
    'Reduce Motion turned on mid-travel lands the knob instantly instead '
    'of freezing halfway',
    (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      var value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _harness(
            child: GlassSwitch(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GlassSwitch));
      // A handful of frames into the settle spring — not settled, not at
      // rest — is the one moment this test exists to catch.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final midTransform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(GlassSwitch),
          matching: find.byType(Transform),
        ),
      );
      final midX = midTransform.transform.getTranslation().x;
      expect(
        midX,
        isNot(anyOf(0, 22)),
        reason:
            'the spring already settled before Reduce Motion turned on '
            '— this test proves nothing without a mid-travel frame',
      );

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();

      final settledTransform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(GlassSwitch),
          matching: find.byType(Transform),
        ),
      );
      expect(settledTransform.transform.getTranslation().x, 22);
    },
  );

  group('the owner rejects the change', () {
    // An `onChanged` that neither rebuilds nor stores: a confirm dialog, a
    // save that fails, a placeholder. The switch must go on showing
    // `value`, as `Switch` and `CupertinoSwitch` do.
    Widget rejecting(List<bool> reported) => _harness(
      child: GlassSwitch(
        value: false,
        onChanged: reported.add,
        semanticLabel: 'Wi-Fi',
      ),
    );

    void expectOff(WidgetTester tester) {
      expect(_knobX(tester), 0);
      expect(
        tester.getSemantics(find.byType(GlassSwitch)),
        isSemantics(
          label: 'Wi-Fi',
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
    }

    testWidgets('a tap springs the knob back to off', (tester) async {
      final handle = tester.ensureSemantics();
      final reported = <bool>[];
      await tester.pumpWidget(rejecting(reported));

      await tester.tap(find.byType(GlassSwitch));
      await tester.pumpAndSettle();

      expect(reported, [true]);
      expectOff(tester);
      handle.dispose();
    });

    testWidgets('a drag past half springs the knob back to off', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final reported = <bool>[];
      await tester.pumpWidget(rejecting(reported));

      await _dragBy(tester, find.byType(GlassSwitch), 16);
      await tester.pumpAndSettle();

      expect(reported, [true]);
      expectOff(tester);
      handle.dispose();
    });

    testWidgets('Space springs the knob back to off', (tester) async {
      final handle = tester.ensureSemantics();
      final reported = <bool>[];
      await tester.pumpWidget(rejecting(reported));
      FocusManager.instance.rootScope.descendants
          .firstWhere((node) => node.canRequestFocus)
          .requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(reported, [true]);
      expectOff(tester);
      handle.dispose();
    });

    testWidgets('an owner that accepts later moves the knob then', (
      tester,
    ) async {
      var value = false;
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _harness(
              child: GlassSwitch(value: value, onChanged: (_) {}),
            );
          },
        ),
      );

      await tester.tap(find.byType(GlassSwitch));
      await tester.pumpAndSettle();
      expect(_knobX(tester), 0);

      // The save came back: the owner now rebuilds with the new value.
      rebuild(() => value = true);
      await tester.pumpAndSettle();
      expect(_knobX(tester), 22);
    });
  });

  group('right to left', () {
    Widget rtl({required bool value, ValueChanged<bool>? onChanged}) =>
        _harness(
          textDirection: TextDirection.rtl,
          child: GlassSwitch(value: value, onChanged: onChanged ?? (_) {}),
        );

    Rect knobOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byType(Glass),
      ),
    );

    /// The painted-track hole, in global coordinates.
    Rect holeOf(WidgetTester tester) {
      final clip = find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is TrackCutoutClipper,
        ),
      );
      final clipper =
          tester.widget<ClipPath>(clip).clipper! as TrackCutoutClipper;
      return clipper.hole!.shift(tester.getTopLeft(clip));
    }

    testWidgets('on puts the knob, and its hole, on the left', (
      tester,
    ) async {
      await tester.pumpWidget(rtl(value: true));
      final centre = tester.getCenter(find.byType(GlassSwitch)).dx;
      expect(knobOf(tester).center.dx, lessThan(centre));
      expect(holeOf(tester), knobOf(tester));
    });

    testWidgets('off puts the knob, and its hole, on the right', (
      tester,
    ) async {
      await tester.pumpWidget(rtl(value: false));
      final centre = tester.getCenter(find.byType(GlassSwitch)).dx;
      expect(knobOf(tester).center.dx, greaterThan(centre));
      expect(holeOf(tester), knobOf(tester));
    });

    testWidgets('a drag left past half turns it on', (tester) async {
      bool? value;
      await tester.pumpWidget(
        rtl(value: false, onChanged: (next) => value = next),
      );
      await _dragBy(tester, find.byType(GlassSwitch), -15);
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('a drag right leaves it off', (tester) async {
      bool? value;
      await tester.pumpWidget(
        rtl(value: false, onChanged: (next) => value = next),
      );
      await _dragBy(tester, find.byType(GlassSwitch), 15);
      await tester.pumpAndSettle();
      expect(value, isNull);
    });

    testWidgets('a drag right past half turns it off', (tester) async {
      bool? value;
      await tester.pumpWidget(
        rtl(value: true, onChanged: (next) => value = next),
      );
      await _dragBy(tester, find.byType(GlassSwitch), 15);
      await tester.pumpAndSettle();
      expect(value, isFalse);
    });
  });
}

/// The knob's travel from its off side, read off the paint-time translate.
double _knobX(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(GlassSwitch),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .x;
