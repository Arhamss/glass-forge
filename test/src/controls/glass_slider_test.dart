import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/glass_slider.dart';
import 'package:glass_forge/src/geometry/producer_registry.dart';
import 'package:glass_forge/src/material/glass_material.dart';
import 'package:glass_forge/src/shapes/glass_shape.dart';
import 'package:glass_forge/src/shapes/glass_shape_clipper.dart';
import 'package:glass_forge/src/widgets/glass.dart';
import 'package:glass_forge/src/widgets/glass_layer.dart';

/// A material that renders nothing, so the composite pass is skipped — the
/// same reason `glass_button_test.dart` needs it outside Impeller.
const GlassMaterial _inert = GlassMaterial(
  frost: 0,
  edgeRefraction: 0,
  highlight: 0,
);

/// The width every harness below gives the slider, and the geometry every
/// expected fraction in this file is worked out against: a 28-point thumb
/// leaves 222 points of travel, so a pointer at `left + fraction * 222 + 14`
/// lands exactly on that fraction.
const double _width = 250;
const double _thumbSize = 28;
const double _travel = _width - _thumbSize;

/// The x offset, from the slider's left edge, that lands on [fraction].
double _xFor(double fraction) => _thumbSize / 2 + fraction * _travel;

/// [child] in a layer, either on content or, with [onGlass], nested inside a
/// real `Glass` so `GlassHostScope.isOnGlass` reads true for it. Always
/// [_width] wide, the geometry every drag and tap offset below assumes.
Widget _harness({
  required Widget child,
  bool onGlass = false,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final sized = SizedBox(width: _width, child: child);
  final content = onGlass
      ? Glass(
          shape: const GlassOval(),
          child: Center(child: sized),
        )
      : Center(child: sized);
  return Directionality(
    textDirection: textDirection,
    child: GlassLayer(
      tier: GeometryTier.none,
      material: _inert,
      child: SizedBox(width: _width, height: 200, child: content),
    ),
  );
}

/// The point every `_xFor` offset in this file is measured from: the
/// slider's own left edge, at its true vertical centre.
///
/// Not [WidgetTester.getTopLeft]: `GlassControlFrame` centres its child
/// inside a `Center` that fills whatever height it is loosely given —
/// here, the harness's own — rather than shrink-wrapping to the 44-point
/// hit target, so the slider's *reported* top sits well above where the
/// hit-testable area actually is. The rect's own vertical centre is exactly
/// right regardless, because `Center` always centres what it is given.
Offset _anchor(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return Offset(rect.left, rect.center.dy);
}

/// Drags [finder] from [_anchor], as a mouse pointer, through the offsets
/// in [xs] (each an x offset from the slider's left edge), then releases.
Future<void> _dragThrough(
  WidgetTester tester,
  Finder finder,
  List<double> xs,
) async {
  final anchor = _anchor(tester, finder);
  final gesture = await tester.startGesture(
    anchor + Offset(xs.first, 0),
    kind: PointerDeviceKind.mouse,
  );
  for (final x in xs.skip(1)) {
    await gesture.moveTo(anchor + Offset(x, 0));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('a drag reports a value in range', (tester) async {
    double? reported;
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(value: 0, onChanged: (next) => reported = next),
      ),
    );

    await _dragThrough(tester, find.byType(GlassSlider), [
      _xFor(0),
      _xFor(0.5),
    ]);

    expect(reported, isNotNull);
    expect(reported, closeTo(0.5, 0.001));
  });

  testWidgets('a drag snaps to the nearest division', (tester) async {
    double? reported;
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(
          value: 0,
          divisions: 4,
          onChanged: (next) => reported = next,
        ),
      ),
    );

    // 0.6 is nearer the 0.5 division than the 0.75 one.
    await _dragThrough(tester, find.byType(GlassSlider), [
      _xFor(0),
      _xFor(0.6),
    ]);

    expect(reported, closeTo(0.5, 0.001));
  });

  testWidgets('onChangeStart and onChangeEnd bracket a drag', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(
          value: 0,
          onChanged: (next) => events.add('change $next'),
          onChangeStart: (v) => events.add('start $v'),
          onChangeEnd: (v) => events.add('end $v'),
        ),
      ),
    );

    await _dragThrough(tester, find.byType(GlassSlider), [
      _xFor(0),
      _xFor(1),
    ]);

    expect(events, isNotEmpty);
    expect(events.first, 'start 0.0');
    expect(events.last, 'end 1.0');
  });

  testWidgets('a tap sets the value at that position', (tester) async {
    double? reported;
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(value: 0, onChanged: (next) => reported = next),
      ),
    );

    final anchor = _anchor(tester, find.byType(GlassSlider));
    final gesture = await tester.startGesture(
      anchor + Offset(_xFor(0.75), 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();

    expect(reported, closeTo(0.75, 0.001));
  });

  testWidgets('a tap brackets its change with one start and one end', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(
          value: 0,
          onChanged: (next) => events.add('change $next'),
          onChangeStart: (v) => events.add('start $v'),
          onChangeEnd: (v) => events.add('end $v'),
        ),
      ),
    );

    final anchor = _anchor(tester, find.byType(GlassSlider));
    await tester.tapAt(anchor + Offset(_xFor(1), 0));
    await tester.pumpAndSettle();

    expect(events, ['start 0.0', 'change 1.0', 'end 1.0']);
  });

  testWidgets('min == max does not divide by zero and holds its value', (
    tester,
  ) async {
    double? reported;
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(
          value: 5,
          min: 5,
          max: 5,
          onChanged: (next) => reported = next,
        ),
      ),
    );

    await _dragThrough(tester, find.byType(GlassSlider), [
      _xFor(0),
      _xFor(1),
    ]);

    expect(tester.takeException(), isNull);
    expect(reported, anyOf(isNull, 5));
  });

  testWidgets(
    'a disabled slider never fires and ignores taps, drags and keys',
    (tester) async {
      await tester.pumpWidget(
        _harness(child: const GlassSlider(value: 0.5, onChanged: null)),
      );

      await _dragThrough(tester, find.byType(GlassSlider), [
        _xFor(0),
        _xFor(1),
      ]);
      final anchor = _anchor(tester, find.byType(GlassSlider));
      await tester.tapAt(anchor + Offset(_xFor(0.9), 0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('semantics report a slider with the label and value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassSlider(
          value: 0.5,
          onChanged: (_) {},
          semanticLabel: 'Volume',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassSlider)),
      isSemantics(label: 'Volume', isEnabled: true, isSlider: true),
    );
    handle.dispose();
  });

  testWidgets('the increase and decrease semantics actions step the value', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var value = 0.5;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _harness(
            child: GlassSlider(
              value: value,
              semanticLabel: 'Volume',
              onChanged: (next) => setState(() => value = next),
            ),
          );
        },
      ),
    );

    tester.semantics.increase(find.semantics.byLabel('Volume'));
    await tester.pump();
    // No divisions: a step is a tenth of the 0..1 range.
    expect(value, closeTo(0.6, 0.001));

    tester.semantics.decrease(find.semantics.byLabel('Volume'));
    await tester.pump();
    expect(value, closeTo(0.5, 0.001));

    handle.dispose();
  });

  testWidgets('arrow keys step a focused slider', (tester) async {
    var value = 0.5;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _harness(
            child: GlassSlider(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          );
        },
      ),
    );

    // No `focusNode` to reach from outside — same as `GlassSwitch`'s own
    // key test, `GlassControlFrame` owns one internally, and this harness
    // has exactly one focusable node.
    FocusManager.instance.rootScope.descendants
        .firstWhere((node) => node.canRequestFocus)
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, closeTo(0.6, 0.001));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(value, closeTo(0.5, 0.001));
  });

  testWidgets('exactly one Glass on content', (tester) async {
    await tester.pumpWidget(
      _harness(child: GlassSlider(value: 0.5, onChanged: (_) {})),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSlider),
        matching: find.byType(Glass),
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero Glass under GlassHostScope', (tester) async {
    await tester.pumpWidget(
      _harness(
        onGlass: true,
        child: GlassSlider(value: 0.5, onChanged: (_) {}),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSlider),
        matching: find.byType(Glass),
      ),
      findsNothing,
    );
  });

  testWidgets('the thumb relaxes back to round after a fast drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(child: GlassSlider(value: 0, onChanged: (_) {})),
    );
    double stretch() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(GlassSlider),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getColumn(0)
        .x;

    final anchor = _anchor(tester, find.byType(GlassSlider));
    final gesture = await tester.startGesture(
      anchor + Offset(_xFor(0), 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(
      anchor + Offset(_xFor(0.5), 0),
      timeStamp: const Duration(milliseconds: 16),
    );
    await gesture.moveTo(
      anchor + Offset(_xFor(1), 0),
      timeStamp: const Duration(milliseconds: 32),
    );
    await tester.pump();
    expect(stretch(), greaterThan(1.05), reason: 'the drag was not fast');

    await gesture.up();
    await tester.pumpAndSettle();
    // The spring's pixel tolerance must not stop it short in a ratio
    // domain, where the whole stretch is under 0.2.
    expect(stretch(), closeTo(1, 0.005));
  });

  testWidgets('Reduce Motion applies no stretch to a fast drag', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(
      _harness(child: GlassSlider(value: 0, onChanged: (_) {})),
    );

    final anchor = _anchor(tester, find.byType(GlassSlider));
    final gesture = await tester.startGesture(
      anchor + Offset(_xFor(0), 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(anchor + Offset(_xFor(1), 0));
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(GlassSlider),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.getColumn(0).x, 1);
    expect(transform.transform.getColumn(1).y, 1);

    await gesture.up();
    await tester.pump();
  });

  testWidgets(
    'disabled mid-drag, the thumb goes back and follows value afterwards',
    (tester) async {
      var value = 0.25;
      var enabled = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _harness(
              child: GlassSlider(
                value: value,
                onChanged: enabled ? (_) {} : null,
              ),
            );
          },
        ),
      );
      double thumbX() =>
          tester
              .getRect(
                find.descendant(
                  of: find.byType(GlassSlider),
                  matching: find.byType(Glass),
                ),
              )
              .center
              .dx -
          tester.getRect(find.byType(GlassSlider)).left;

      final anchor = _anchor(tester, find.byType(GlassSlider));
      final gesture = await tester.startGesture(
        anchor + Offset(_xFor(0.25), 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(anchor + Offset(_xFor(0.8), 0));
      await tester.pump();
      expect(thumbX(), closeTo(_xFor(0.8), 0.001));

      rebuild(() => enabled = false);
      await tester.pumpAndSettle();
      expect(thumbX(), closeTo(_xFor(0.25), 0.001));
      await gesture.up();
      await tester.pumpAndSettle();

      rebuild(() {
        enabled = true;
        value = 0.5;
      });
      await tester.pumpAndSettle();
      expect(thumbX(), closeTo(_xFor(0.5), 0.001));
    },
  );

  group('the owner rejects the change', () {
    // An `onChanged` that neither rebuilds nor stores. The thumb may follow
    // the finger while it is down, but once the gesture is over the slider
    // must show `value` again, as `Slider` does.
    Widget rejecting(List<double> reported) => _harness(
      child: GlassSlider(
        value: 0.25,
        onChanged: reported.add,
        semanticLabel: 'Volume',
      ),
    );

    void expectAtQuarter(WidgetTester tester) {
      final slider = tester.getRect(find.byType(GlassSlider));
      final thumb = tester.getRect(
        find.descendant(
          of: find.byType(GlassSlider),
          matching: find.byType(Glass),
        ),
      );
      expect(thumb.center.dx - slider.left, closeTo(_xFor(0.25), 0.001));
      expect(
        tester.getSemantics(find.byType(GlassSlider)),
        isSemantics(label: 'Volume', value: '0.25', isSlider: true),
      );
    }

    testWidgets('a tap leaves the thumb where value says', (tester) async {
      final handle = tester.ensureSemantics();
      final reported = <double>[];
      await tester.pumpWidget(rejecting(reported));

      final anchor = _anchor(tester, find.byType(GlassSlider));
      final gesture = await tester.startGesture(
        anchor + Offset(_xFor(0.75), 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported.last, closeTo(0.75, 0.001));
      expectAtQuarter(tester);
      handle.dispose();
    });

    testWidgets('a drag puts the thumb back when it ends', (tester) async {
      final handle = tester.ensureSemantics();
      final reported = <double>[];
      await tester.pumpWidget(rejecting(reported));

      await _dragThrough(tester, find.byType(GlassSlider), [
        _xFor(0.25),
        _xFor(0.5),
        _xFor(0.9),
      ]);
      await tester.pumpAndSettle();

      expect(reported.last, closeTo(0.9, 0.001));
      expectAtQuarter(tester);
      handle.dispose();
    });

    testWidgets('an arrow key leaves the thumb where value says', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final reported = <double>[];
      await tester.pumpWidget(rejecting(reported));
      FocusManager.instance.rootScope.descendants
          .firstWhere((node) => node.canRequestFocus)
          .requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(reported, [closeTo(0.35, 0.001)]);
      expectAtQuarter(tester);
      handle.dispose();
    });
  });

  group('reports only a change', () {
    void focusIt() => FocusManager.instance.rootScope.descendants
        .firstWhere((node) => node.canRequestFocus)
        .requestFocus();

    testWidgets('a drag within one division reports it once', (
      tester,
    ) async {
      final reported = <double>[];
      await tester.pumpWidget(
        _harness(
          child: GlassSlider(value: 0, divisions: 4, onChanged: reported.add),
        ),
      );

      await _dragThrough(tester, find.byType(GlassSlider), [
        _xFor(0.45),
        _xFor(0.48),
        _xFor(0.52),
        _xFor(0.55),
      ]);

      expect(reported, [0.5]);
    });

    testWidgets('min == max never reports', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(
        _harness(
          child: GlassSlider(
            value: 5,
            min: 5,
            max: 5,
            onChanged: reported.add,
          ),
        ),
      );

      await _dragThrough(tester, find.byType(GlassSlider), [
        _xFor(0),
        _xFor(0.5),
        _xFor(1),
      ]);

      expect(reported, isEmpty);
    });

    testWidgets('an arrow key at a bound reports nothing', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(
        _harness(child: GlassSlider(value: 1, onChanged: reported.add)),
      );
      focusIt();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(reported, isEmpty);
    });

    testWidgets('semantics offer no step past a bound', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          child: GlassSlider(
            value: 1,
            onChanged: (_) {},
            semanticLabel: 'Volume',
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(GlassSlider)),
        isSemantics(
          label: 'Volume',
          isSlider: true,
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('an arrow key off the grid steps onto it', (tester) async {
      var value = 0.3;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _harness(
            child: GlassSlider(
              value: value,
              divisions: 4,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      focusIt();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(0.5, 1e-9));

      value = 0.3;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _harness(
            child: GlassSlider(
              value: value,
              divisions: 4,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, closeTo(0.25, 1e-9));
    });
  });

  group('inside a vertical scroll view', () {
    // A settings list: the slider shares the arena with the list's own
    // vertical drag. Touch, not mouse — the pointer a phone list sees.
    Widget inList(ValueChanged<double> onChanged, ScrollController scroll) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: GlassLayer(
            tier: GeometryTier.none,
            material: _inert,
            child: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 200),
                Center(
                  child: SizedBox(
                    width: _width,
                    child: GlassSlider(value: 0, onChanged: onChanged),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        );

    testWidgets('a tap sets the value', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final reported = <double>[];
      await tester.pumpWidget(inList(reported.add, scroll));

      final anchor = _anchor(tester, find.byType(GlassSlider));
      await tester.tapAt(anchor + Offset(_xFor(0.75), 0));
      await tester.pumpAndSettle();

      expect(reported, [closeTo(0.75, 0.001)]);
      expect(scroll.offset, 0);
    });

    testWidgets('a horizontal drag sets the value and does not scroll', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final reported = <double>[];
      await tester.pumpWidget(inList(reported.add, scroll));

      final anchor = _anchor(tester, find.byType(GlassSlider));
      final gesture = await tester.startGesture(
        anchor + Offset(_xFor(0.1), 0),
      );
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(
          anchor + Offset(_xFor(0.1 + 0.05 * i), 0),
        );
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      expect(reported.last, closeTo(0.6, 0.001));
      expect(scroll.offset, 0);
    });

    testWidgets('a vertical drag scrolls and leaves the value alone', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final reported = <double>[];
      await tester.pumpWidget(inList(reported.add, scroll));

      final anchor = _anchor(tester, find.byType(GlassSlider));
      await tester.dragFrom(
        anchor + Offset(_xFor(0.5), 0),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();

      expect(reported, isEmpty);
      expect(scroll.offset, greaterThan(0));
    });
  });

  group('right to left', () {
    Widget rtl({required double value, ValueChanged<double>? onChanged}) =>
        _harness(
          textDirection: TextDirection.rtl,
          child: GlassSlider(value: value, onChanged: onChanged ?? (_) {}),
        );

    /// The slider's right edge — where [GlassSlider.min] is under RTL — at
    /// its vertical centre. Every `_xFor` offset below is measured leftward
    /// from here.
    Offset rightAnchor(WidgetTester tester) {
      final rect = tester.getRect(find.byType(GlassSlider));
      return Offset(rect.right, rect.center.dy);
    }

    Rect thumbOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(GlassSlider),
        matching: find.byType(Glass),
      ),
    );

    /// The fill: the one painted box on the 6-point track narrower than it.
    Rect fillOf(WidgetTester tester) => tester
        .renderObjectList<RenderBox>(
          find.descendant(
            of: find.byType(GlassSlider),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.localToGlobal(Offset.zero) & box.size)
        .singleWhere((rect) => rect.height == 6 && rect.width < _width);

    /// The painted-track hole, in global coordinates.
    Rect holeOf(WidgetTester tester) {
      final clip = find.descendant(
        of: find.byType(GlassSlider),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ClipPath &&
              w.clipper is GlassShapeClipper &&
              (w.clipper! as GlassShapeClipper).hole != null,
        ),
      );
      final clipper =
          tester.widget<ClipPath>(clip).clipper! as GlassShapeClipper;
      return clipper.hole!.shift(tester.getTopLeft(clip));
    }

    testWidgets('min puts the thumb, and its hole, at the right end', (
      tester,
    ) async {
      await tester.pumpWidget(rtl(value: 0));
      final slider = tester.getRect(find.byType(GlassSlider));
      expect(thumbOf(tester).right, slider.right);
      expect(holeOf(tester), thumbOf(tester));
    });

    testWidgets('the fill grows leftward from the right end', (tester) async {
      await tester.pumpWidget(rtl(value: 0.25));
      final slider = tester.getRect(find.byType(GlassSlider));
      final fill = fillOf(tester);
      expect(fill.right, slider.right);
      expect(fill.width, closeTo(_xFor(0.25), 0.001));
      expect(thumbOf(tester).center.dx, closeTo(fill.left, 0.001));
      expect(holeOf(tester), thumbOf(tester));
    });

    testWidgets('a drag measures from the right edge', (tester) async {
      double? reported;
      await tester.pumpWidget(
        rtl(value: 0, onChanged: (next) => reported = next),
      );
      final anchor = rightAnchor(tester);
      final gesture = await tester.startGesture(
        anchor - Offset(_xFor(0), 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(anchor - Offset(_xFor(0.25), 0));
      await gesture.up();
      await tester.pump();

      expect(reported, closeTo(0.25, 0.001));
    });

    testWidgets('a tap sets the value measured from the right edge', (
      tester,
    ) async {
      double? reported;
      await tester.pumpWidget(
        rtl(value: 0, onChanged: (next) => reported = next),
      );
      final gesture = await tester.startGesture(
        rightAnchor(tester) - Offset(_xFor(0.75), 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.up();
      await tester.pump();

      expect(reported, closeTo(0.75, 0.001));
    });

    testWidgets('the left arrow increases the value', (tester) async {
      var value = 0.5;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => rtl(
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      FocusManager.instance.rootScope.descendants
          .firstWhere((node) => node.canRequestFocus)
          .requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value, closeTo(0.6, 0.001));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(0.5, 0.001));
    });
  });
}
