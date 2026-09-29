import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/controls/glass_segmented_control.dart';
import 'package:glass_forge/src/design/glass_legibility.dart';
import 'package:glass_forge/src/design/glass_surfaces.dart';
import 'package:glass_forge/src/design/glass_theme.dart';
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

/// The width every three-segment harness below gives the control: three
/// 80-point segments, the geometry every drag offset in this file is worked
/// out against.
const double _width = 240;

const List<GlassSegment<int>> _threeSegments = [
  GlassSegment(value: 0, label: Text('Day')),
  GlassSegment(value: 1, label: Text('Week')),
  GlassSegment(value: 2, label: Text('Month')),
];

/// [child] in a layer, either on content or, with [onGlass], nested inside a
/// real `Glass` so `GlassHostScope.isOnGlass` reads true for it. Always
/// [_width] wide, the geometry every drag offset below assumes.
///
/// [brightness] stands in for the platform scheme — light unless a test
/// asks otherwise, the same default a bare `MediaQueryData` carries, so
/// every test written before this parameter existed still sees what it
/// always saw.
Widget _harness({
  required Widget child,
  bool onGlass = false,
  Brightness brightness = Brightness.light,
}) {
  final sized = SizedBox(width: _width, child: child);
  final content = onGlass
      ? Glass(
          shape: const GlassOval(),
          child: Center(child: sized),
        )
      : Center(child: sized);
  return MediaQuery(
    data: MediaQueryData(platformBrightness: brightness),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: GlassLayer(
        tier: GeometryTier.none,
        material: _inert,
        child: SizedBox(width: _width, height: 200, child: content),
      ),
    ),
  );
}

/// Drags [finder] horizontally by [dx] logical pixels from its centre, as a
/// mouse pointer.
///
/// Mouse, not the default touch — `kTouchSlop` for touch is 18 logical
/// pixels, which would swallow most of a short drag before it is ever
/// reported; `kPrecisePointerPanSlop` for a mouse is 2. See `GlassSwitch`'s
/// own test file for the same reasoning.
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
  testWidgets('a tap on a segment selects it and reports the value', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (next) => selected = next,
        ),
      ),
    );

    await tester.tap(find.text('Month'));
    await tester.pump();

    expect(selected, 2);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a disabled control never fires and never builds a press response',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          child: const GlassSegmentedControl<int>(
            segments: _threeSegments,
            selected: 0,
            onChanged: null,
          ),
        ),
      );

      await tester.tap(find.text('Month'));
      await tester.pump();
      await _dragBy(tester, find.byType(GlassSegmentedControl<int>), 80);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a drag that lands between segments snaps to the nearest one',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        _harness(
          child: GlassSegmentedControl<int>(
            segments: _threeSegments,
            selected: 0,
            onChanged: (next) => selected = next,
          ),
        ),
      );

      // Travel is 160px across three 80px segments (index 0 at 0, index 1
      // at 80, index 2 at 160). 100px lands at fraction 100/160 = 0.625, or
      // raw index 1.25 — closer to segment 1 than to segment 2.
      await _dragBy(
        tester,
        find.byType(GlassSegmentedControl<int>),
        100,
      );

      expect(selected, 1);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a drag that lands closer to the far segment snaps there instead',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        _harness(
          child: GlassSegmentedControl<int>(
            segments: _threeSegments,
            selected: 0,
            onChanged: (next) => selected = next,
          ),
        ),
      );

      // 140px is fraction 140/160 = 0.875, raw index 1.75 — closer to
      // segment 2 than to segment 1.
      await _dragBy(
        tester,
        find.byType(GlassSegmentedControl<int>),
        140,
      );

      expect(selected, 2);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('selected not in segments asserts in debug', (tester) async {
    expect(
      () => GlassSegmentedControl<int>(
        segments: _threeSegments,
        selected: 99,
        onChanged: (_) {},
      ),
      returnsNormally,
      reason: 'construction alone must not assert; only mounting it does',
    );

    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 99,
          onChanged: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('a single segment renders without dividing by zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: const [GlassSegment(value: 0, label: Text('Only'))],
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    // A drag has nowhere to travel and must not throw or produce NaN.
    await _dragBy(tester, find.byType(GlassSegmentedControl<int>), 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'each segment is named by its label, is a button selected on exactly '
    'one, and is not adjustable',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          child: GlassSegmentedControl<int>(
            segments: _threeSegments,
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      );

      final frames = find.byType(GlassControlFrame);
      expect(frames, findsNWidgets(3));
      const labels = ['Day', 'Week', 'Month'];
      var selectedCount = 0;
      for (var i = 0; i < 3; i++) {
        final data = tester.getSemantics(frames.at(i)).getSemanticsData();
        expect(data.label, labels[i]);
        expect(data.flagsCollection.isButton, isTrue);
        if (data.flagsCollection.isSelected == Tristate.isTrue) {
          selectedCount++;
        }
        // Adjustable is the slider's role. A segment that offered
        // increase/decrease was announced as one on iOS.
        expect(data.hasAction(SemanticsAction.increase), isFalse);
        expect(data.hasAction(SemanticsAction.decrease), isFalse);
      }
      expect(selectedCount, 1);
      handle.dispose();
    },
  );

  testWidgets('an explicit segment semanticLabel replaces its label text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: const [
            GlassSegment(
              value: 0,
              label: Text('D'),
              semanticLabel: 'Day view',
            ),
            GlassSegment(value: 1, label: Text('W')),
          ],
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );

    final frames = find.byType(GlassControlFrame);
    expect(tester.getSemantics(frames.at(0)).label, 'Day view');
    expect(tester.getSemantics(frames.at(1)).label, 'W');
    handle.dispose();
  });

  testWidgets('semantics report a selectable button, selected on one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 1,
          onChanged: (_) {},
        ),
      ),
    );

    final frames = find.byType(GlassControlFrame);
    expect(frames, findsNWidgets(3));

    expect(
      tester.getSemantics(frames.at(0)),
      isSemantics(isButton: true, isEnabled: true, isSelected: false),
    );
    expect(
      tester.getSemantics(frames.at(1)),
      isSemantics(isButton: true, isEnabled: true, isSelected: true),
    );
    expect(
      tester.getSemantics(frames.at(2)),
      isSemantics(isButton: true, isEnabled: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('arrow keys move a focused selection', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (next) => selected = next,
        ),
      ),
    );

    // No `focusNode` of its own to reach from outside — `GlassControlFrame`
    // owns one per segment internally, the same as `GlassSlider`'s own
    // single node. The harness's first focusable node is segment 0.
    FocusManager.instance.rootScope.descendants
        .firstWhere((node) => node.canRequestFocus)
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(selected, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(selected, 0);

    await tester.pumpAndSettle();
  });

  testWidgets('Enter activates the focused segment', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (next) => selected = next,
        ),
      ),
    );

    final nodes = FocusManager.instance.rootScope.descendants
        .where((node) => node.canRequestFocus)
        .toList();
    // The third focusable node is segment 2 ("Month") in traversal order.
    nodes[2].requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, 2);
    await tester.pumpAndSettle();
  });

  testWidgets('exactly one Glass on content', (tester) async {
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSegmentedControl<int>),
        matching: find.byType(Glass),
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero Glass under GlassHostScope', (tester) async {
    await tester.pumpWidget(
      _harness(
        onGlass: true,
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(GlassSegmentedControl<int>),
        matching: find.byType(Glass),
      ),
      findsNothing,
    );
  });

  testWidgets('Reduce Motion lands the pill instantly', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    int? selected;
    await tester.pumpWidget(
      _harness(
        child: GlassSegmentedControl<int>(
          segments: _threeSegments,
          selected: 0,
          onChanged: (next) => selected = next,
        ),
      ),
    );

    await tester.tap(find.text('Month'));
    // Exactly one frame: an instant settle needs no further pumps to reach
    // its target, unlike a spring, which would still be travelling here.
    await tester.pump();

    final positioned = tester.widgetList<Positioned>(
      find.descendant(
        of: find.byType(GlassSegmentedControl<int>),
        matching: find.byType(Positioned),
      ),
    );
    // The pill is the one Positioned with a non-null `width` (the track
    // itself is a `Positioned.fill`).
    final pill = positioned.firstWhere((p) => p.width != null);
    // The last slot starts at 160; the pill sits 3 px inside it.
    expect(pill.left, 163);
    expect(selected, 2);
  });

  testWidgets(
    'Reduce Motion turned on mid-travel lands the pill instantly instead '
    'of freezing halfway',
    (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        _harness(
          child: GlassSegmentedControl<int>(
            segments: _threeSegments,
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Month'));
      // A handful of frames into the settle spring — not settled, not at
      // rest — is the one moment this test exists to catch.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      Positioned pillOf(WidgetTester t) => t
          .widgetList<Positioned>(
            find.descendant(
              of: find.byType(GlassSegmentedControl<int>),
              matching: find.byType(Positioned),
            ),
          )
          .firstWhere((p) => p.width != null);

      final midLeft = pillOf(tester).left;
      expect(
        midLeft,
        isNot(anyOf(3, 163)),
        reason:
            'the spring already settled before Reduce Motion turned on '
            '— this test proves nothing without a mid-travel frame',
      );

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();

      expect(pillOf(tester).left, 163);
    },
  );

  group('the selected label reads against its own pill', () {
    /// The backdrop that hurts [brightness] most — pure white flips a dark
    /// scheme's own worst case, pure black a light scheme's — the same
    /// convention `glass_surfaces_test.dart` measures every role's promise
    /// against.
    Color worstBackdropFor(Brightness brightness) =>
        brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);

    /// The contrast between the selected segment's rendered label colour and
    /// its pill.
    ///
    /// Off a glass host the pill is a real, translucent `Glass` — there is
    /// no fixed colour to check it against directly, so this measures the
    /// same worst case `style.labelColor`'s own package-wide promise is held
    /// to: the control role's material, composited at its own opacity over
    /// the backdrop that scheme faces worst. On a glass host the pill paints
    /// flat and always white (`GlassSegmentedControl._pillColor`), so that
    /// is what this checks against directly instead.
    Future<double> selectedContrast(
      WidgetTester tester, {
      required bool onGlass,
      required Brightness brightness,
    }) async {
      late GlassSurfaceStyle style;
      await tester.pumpWidget(
        _harness(
          onGlass: onGlass,
          brightness: brightness,
          child: Builder(
            builder: (context) {
              style = GlassTheme.surfaceOf(
                context,
                GlassSurfaceRole.control,
                size: const Size(_width, GlassControlFrame.minimumExtent),
              );
              return GlassSegmentedControl<int>(
                segments: _threeSegments,
                selected: 0,
                onChanged: (_) {},
              );
            },
          ),
        ),
      );

      final labelStyle = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Day'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      final labelColor = labelStyle.color!;

      final pillColor = onGlass
          ? const Color(0xFFFFFFFF)
          : GlassLegibility.surfaceOver(
              tint: style.material.tint,
              opacity: style.material.tintOpacity,
              backdrop: worstBackdropFor(brightness),
            );

      return GlassLegibility.contrastRatio(pillColor, labelColor);
    }

    for (final brightness in Brightness.values) {
      for (final onGlass in [false, true]) {
        testWidgets(
          'onGlass=$onGlass, ${brightness.name} scheme: selected label '
          'clears 3:1 against its pill',
          (tester) async {
            final contrast = await selectedContrast(
              tester,
              onGlass: onGlass,
              brightness: brightness,
            );
            expect(contrast, greaterThanOrEqualTo(3.0));
          },
        );
      }
    }
  });
}
