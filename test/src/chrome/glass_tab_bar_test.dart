import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/controls/control_frame.dart';

const List<GlassTab> _tabs = [
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Home'),
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Search'),
  GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Profile'),
];

/// The screen every test puts the bar on: the test window, the bar pinned
/// to the bottom, [bottomInset] of safe area under it, and — when given — a
/// [barPresence] wrapped around it the way `GlassScaffold` wraps its bars.
Widget _harness({
  required Widget bar,
  double bottomInset = 0,
  Animation<double>? barPresence,
}) {
  final pinned = Align(alignment: Alignment.bottomCenter, child: bar);
  return MediaQuery(
    data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: GlassLayer(
        tier: GeometryTier.none,
        child: barPresence == null
            ? pinned
            : GlassPresence(presence: barPresence, child: pinned),
      ),
    ),
  );
}

/// A bar that follows its own taps, recording each one in [taps].
Widget _followingBar(List<int> taps, {int initial = 0}) {
  var index = initial;
  return StatefulBuilder(
    builder: (context, setState) => GlassTabBar(
      tabs: _tabs,
      currentIndex: index,
      onTap: (next) {
        taps.add(next);
        setState(() => index = next);
      },
    ),
  );
}

/// The lens's own presence — the only [GlassPresence] the bar builds.
Animation<double> _lensPresence(WidgetTester tester) {
  return tester
      .widget<GlassPresence>(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.byType(GlassPresence),
        ),
      )
      .presence;
}

/// How opaque [finder] is actually drawn: every [FadeTransition] and
/// [Opacity] between it and the root, multiplied together.
double _effectiveOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList(
    find.ancestor(of: finder, matching: find.byType(FadeTransition)),
  )) {
    opacity *= (widget as FadeTransition).opacity.value;
  }
  for (final widget in tester.widgetList(
    find.ancestor(of: finder, matching: find.byType(Opacity)),
  )) {
    opacity *= (widget as Opacity).opacity;
  }
  return opacity;
}

void main() {
  testWidgets('a tap reports the tab index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_harness(bar: _followingBar(taps)));

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(taps, [2, 1]);
  });

  testWidgets('exactly one tab reports itself selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(tabs: _tabs, currentIndex: 1, onTap: (_) {}),
      ),
    );

    final frames = find.byType(GlassControlFrame);
    expect(frames, findsNWidgets(3));
    final selected = [
      for (var i = 0; i < 3; i++)
        tester
                .getSemantics(frames.at(i))
                .flagsCollection
                .isSelected
                .toBoolOrNull() ??
            false,
    ];
    expect(selected, [false, true, false]);
    expect(
      tester.getSemantics(frames.at(1)),
      isSemantics(
        label: 'Search',
        isButton: true,
        isSelected: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the lens is absent at rest and rises while it travels', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

    // At rest: a painted pill, and a lens whose pass does not exist.
    expect(_lensPresence(tester).value, 0);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_lensPresence(tester).value, greaterThan(0));

    await tester.pumpAndSettle();
    expect(_lensPresence(tester).value, 0);
  });

  testWidgets('a drag carries the selection to where it is released', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(_harness(bar: _followingBar(taps)));

    final from = tester.getCenter(find.text('Home'));
    final to = tester.getCenter(find.text('Profile'));
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Held mid-drag, the lens is up; nothing is committed yet.
    expect(_lensPresence(tester).value, greaterThan(0));
    expect(taps, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, [2]);
    expect(_lensPresence(tester).value, 0);
  });

  testWidgets('Reduce Motion: no lens, and the pill lands instantly', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

    // Only the bar's own glass.
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(Glass),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(GlassPresence),
      ),
      findsNothing,
    );

    final pill = find.descendant(
      of: find.byType(GlassTabBar),
      matching: find.byType(ClipPath),
    );
    double pillLeft() => tester.getTopLeft(pill.last).dx;
    final homeLeft = pillLeft();

    await tester.tap(find.text('Profile'));
    // One frame for the parent to rebuild with the new index — and no more.
    await tester.pump();
    final landed = pillLeft();
    expect(landed, greaterThan(homeLeft));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
    expect(pillLeft(), landed);
  });

  testWidgets('bar presence 0 hides the labels, icons and pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        bar: _followingBar(<int>[]),
        barPresence: const AlwaysStoppedAnimation<double>(0),
      ),
    );

    for (final label in ['Home', 'Search', 'Profile']) {
      expect(_effectiveOpacity(tester, find.text(label)), 0, reason: label);
    }
  });

  testWidgets('full bar presence leaves the labels drawn', (tester) async {
    await tester.pumpWidget(
      _harness(
        bar: _followingBar(<int>[]),
        barPresence: const AlwaysStoppedAnimation<double>(1),
      ),
    );

    expect(_effectiveOpacity(tester, find.text('Home')), 1);
  });

  testWidgets("a covered bar's lens has no presence, even mid-flight", (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        bar: _followingBar(<int>[]),
        barPresence: const AlwaysStoppedAnimation<double>(0),
      ),
    );

    await tester.tap(find.text('Profile'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_lensPresence(tester).value, 0);
  });

  testWidgets('the bottom safe area is built in', (tester) async {
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
        bottomInset: 34,
      ),
    );

    final glass = find.descendant(
      of: find.byType(GlassTabBar),
      matching: find.byType(GlassSurface),
    );
    final screenBottom = tester.getBottomLeft(find.byType(GlassLayer)).dy;
    expect(tester.getBottomLeft(glass).dy, screenBottom - 34);
  });
}
