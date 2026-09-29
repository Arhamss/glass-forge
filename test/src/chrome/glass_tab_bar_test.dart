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
  TextDirection textDirection = TextDirection.ltr,
}) {
  final pinned = Align(alignment: Alignment.bottomCenter, child: bar);
  return MediaQuery(
    data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
    child: Directionality(
      textDirection: textDirection,
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

  testWidgets(
    'a finger resting on the bar without moving never raises the lens',
    (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

      // On the current tab and on another one: neither is travel until the
      // finger lifts.
      for (final label in ['Home', 'Search']) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text(label)),
        );
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            _lensPresence(tester).value,
            0,
            reason: 'a resting finger on $label raised the lens',
          );
        }
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'a drag that stops keeps the lens only until the selection catches up',
    (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_lensPresence(tester).value, greaterThan(0));

      // Finger still, still down: the spring settles on the finger and the
      // lens sinks. One second is generous for a settle spring plus the
      // 280 ms sink.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_lensPresence(tester).value, 0);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

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

  testWidgets("a passed material reaches the bar's Glass", (tester) async {
    const material = GlassMaterial(frost: 2, tintOpacity: 0.3);
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(
          tabs: _tabs,
          currentIndex: 0,
          onTap: (_) {},
          material: material,
        ),
      ),
    );

    final glass = tester.widget<Glass>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(Glass),
          )
          .first,
    );
    expect(glass.material, material);
  });

  testWidgets("no material passed keeps the role's own", (tester) async {
    late GlassSurfaceStyle role;
    await tester.pumpWidget(
      _harness(
        bar: Builder(
          builder: (context) {
            role = GlassTheme.surfaceOf(
              context,
              GlassSurfaceRole.navigationBar,
              size: const Size(300, GlassTabBar.height),
            );
            return GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {});
          },
        ),
      ),
    );

    final glass = tester.widget<Glass>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(Glass),
          )
          .first,
    );
    expect(glass.material, role.material);
  });

  testWidgets("the bar's height is public, and matches the built bar", (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
      ),
    );

    expect(GlassTabBar.height, 62);
    final surface = find.byType(GlassSurface);
    expect(tester.getSize(surface).height, GlassTabBar.height);
  });

  group('large text', () {
    for (final scale in [1.0, 2.0, 3.0, 5.0]) {
      testWidgets('at ${scale}x the tabs fit the bar without overflow', (
        tester,
      ) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GlassLayer(
                tier: GeometryTier.none,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassTabBar(
                    tabs: const [
                      GlassTab(
                        icon: SizedBox(width: 24, height: 24),
                        label: 'Home',
                      ),
                      GlassTab(
                        icon: SizedBox(width: 24, height: 24),
                        label: 'Notifications',
                      ),
                      GlassTab(
                        icon: SizedBox(width: 24, height: 24),
                        label: 'Profile',
                      ),
                    ],
                    currentIndex: 0,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(GlassTabBar));
        for (final label in ['Home', 'Notifications', 'Profile']) {
          final text = tester.getRect(find.text(label));
          expect(text.bottom, lessThanOrEqualTo(bar.bottom));
          expect(text.top, greaterThanOrEqualTo(bar.top));
          // The test font's line is exactly its size: 11 pt, scaled by the
          // reader's text size up to 1.5 and no further.
          expect(text.height, closeTo(11 * (scale < 1.5 ? scale : 1.5), 1));
        }
      });
    }
  });

  group('the owner rejects the change', () {
    /// The painted pill: the last clip the bar builds.
    Rect pillOf(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(GlassTabBar),
            matching: find.byType(ClipPath),
          )
          .last,
    );

    Rect lensOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(GlassPresence),
        matching: find.byType(Glass),
      ),
    );

    testWidgets('a drag released on another tab settles back', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final taps = <int>[];
      // `onTap` that neither rebuilds nor stores: the bar must go on
      // showing `currentIndex`.
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: taps.add),
        ),
      );

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
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, [2]);
      final home = tester.getCenter(find.text('Home')).dx;
      for (final rect in [pillOf(tester), lensOf(tester)]) {
        expect(rect.left, lessThan(home));
        expect(rect.right, greaterThan(home));
      }
      expect(
        tester.getSemantics(find.byType(GlassControlFrame).at(0)),
        isSemantics(
          label: 'Home',
          isButton: true,
          isSelected: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('right to left', () {
    Widget rtl(List<int> taps, {int initial = 0}) => _harness(
      textDirection: TextDirection.rtl,
      bar: _followingBar(taps, initial: initial),
    );

    /// The painted pill: the last clip the bar builds, as the Reduce
    /// Motion test above reads it.
    Rect pillOf(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byType(GlassTabBar),
            matching: find.byType(ClipPath),
          )
          .last,
    );

    /// The lens's glass: the one under the lens's own presence.
    Rect lensOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(GlassPresence),
        matching: find.byType(Glass),
      ),
    );

    void expectUnder(Rect rect, Offset label) {
      expect(rect.left, lessThan(label.dx));
      expect(rect.right, greaterThan(label.dx));
    }

    testWidgets('the first tab is on the right', (tester) async {
      await tester.pumpWidget(rtl(<int>[]));
      expect(
        tester.getCenter(find.text('Home')).dx,
        greaterThan(tester.getCenter(find.text('Profile')).dx),
      );
    });

    for (final (index, label) in [(0, 'Home'), (2, 'Profile')]) {
      testWidgets('the pill and lens sit under "$label" at rest', (
        tester,
      ) async {
        await tester.pumpWidget(rtl(<int>[], initial: index));
        final centre = tester.getCenter(find.text(label));
        expectUnder(pillOf(tester), centre);
        expectUnder(lensOf(tester), centre);
      });
    }

    testWidgets('a drag commits the tab under the finger', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(rtl(taps, initial: 1));

      final from = tester.getCenter(find.text('Search'));
      final to = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, [0]);
      expectUnder(pillOf(tester), tester.getCenter(find.text('Home')));
    });

    testWidgets('the lens travels leftward toward a later tab', (
      tester,
    ) async {
      await tester.pumpWidget(rtl(<int>[]));
      final home = tester.getCenter(find.text('Home')).dx;
      final profile = tester.getCenter(find.text('Profile')).dx;

      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midFlight = lensOf(tester).center.dx;
      expect(midFlight, lessThan(home));
      expect(midFlight, greaterThan(profile));

      await tester.pumpAndSettle();
      expectUnder(lensOf(tester), Offset(profile, 0));
    });
  });
}
