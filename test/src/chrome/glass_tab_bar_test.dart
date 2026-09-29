import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge/src/controls/control_frame.dart';
import 'package:glass_forge/src/rendering/render_glass_layer.dart';

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

/// Every glass the bar builds. The lens is the only one.
final Finder _barGlass = find.descendant(
  of: find.byType(GlassTabBar),
  matching: find.byType(Glass),
);

/// The lens's glass.
final Finder _lens = _barGlass;

/// The presence the lens renders at: the one it inherits, or full.
double _lensPresence(WidgetTester tester) =>
    GlassPresenceScope.maybeOf(tester.element(_lens))?.value ?? 1;

/// The lens as drawn, squash included: [WidgetTester.getRect] puts the
/// corners through every transform above it.
Rect _lensRect(WidgetTester tester) => tester.getRect(_lens);

/// The bar's painted body: the one shape-decorated box in the bar.
final Finder _body = find.descendant(
  of: find.byType(GlassTabBar),
  matching: find.byWidgetPredicate(
    (widget) => widget is DecoratedBox && widget.decoration is ShapeDecoration,
  ),
);

/// The fill the bar's body is painted in.
Color? _bodyColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_body).decoration as ShapeDecoration).color;

/// Records every haptic the bar asks the platform for, by type.
List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}

/// Drags from [from] to [to] in ten steps, a frame apart, and holds.
Future<TestGesture> _dragTo(
  WidgetTester tester,
  Offset from,
  Offset to,
) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

void expectUnder(Rect rect, Offset label) {
  expect(rect.left, lessThan(label.dx));
  expect(rect.right, greaterThan(label.dx));
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

  group('the lens', () {
    testWidgets('is glass at rest, in its own material, under the '
        'selected tab', (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

      expect(_lensPresence(tester), 1);
      final lens = tester.widget<Glass>(_lens);
      expect(lens.material, GlassTabBar.defaultSelectionMaterial);
      expectUnder(_lensRect(tester), tester.getCenter(find.text('Home')));
    });

    testWidgets('settles under a tapped tab, and stays glass', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(_lensPresence(tester), 1);
      expectUnder(_lensRect(tester), tester.getCenter(find.text('Profile')));
    });

    testWidgets('takes a selectionMaterial in place of its own', (
      tester,
    ) async {
      // Clear of every floor, so it is used exactly as passed.
      const material = GlassMaterial(
        frost: 3,
        tintOpacity: 0.2,
        highlight: 2.5,
      );
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(
            tabs: _tabs,
            currentIndex: 0,
            onTap: (_) {},
            selectionMaterial: material,
          ),
        ),
      );
      expect(tester.widget<Glass>(_lens).material, material);
    });

    testWidgets('by default is lit, faintly white and bends its edge '
        'hard enough to read over a dark photo', (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));
      final lens = tester.widget<Glass>(_lens).material!;
      expect(lens.highlight, greaterThanOrEqualTo(2.5));
      expect(lens.edgeRefraction, greaterThanOrEqualTo(24));
      expect(lens.tint.toARGB32() & 0xFFFFFF, 0xFFFFFF);
      expect(lens.tintOpacity, inInclusiveRange(0.12, 0.16));
      expect(lens.chromaticAberration, lessThanOrEqualTo(0.4));
      expect(lens.frost, 0);
    });

    testWidgets('floors a near-clear material, keeping the rest of it', (
      tester,
    ) async {
      // The example's "Clear" preset, and weaker: a lip of 6, a 2% tint
      // and a faint rim. Alone it all but vanishes over a dark photo.
      const clear = GlassMaterial(
        thickness: 14,
        edgeRefraction: 6,
        frost: 0.6,
        chromaticAberration: 0.03,
        tint: Color(0xFF5AC8FA),
        tintOpacity: 0.02,
        saturation: 1.3,
        highlight: 0.3,
      );
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(
            tabs: _tabs,
            currentIndex: 0,
            onTap: (_) {},
            selectionMaterial: clear,
          ),
        ),
      );
      final lens = tester.widget<Glass>(_lens).material!;
      expect(lens.highlight, 2);
      expect(lens.tintOpacity, 0.12);
      expect(lens.edgeRefraction, 14);
      // Everything else is the caller's.
      expect(
        lens.copyWith(highlight: 0.3, tintOpacity: 0.02, edgeRefraction: 6),
        clear,
      );
    });

    testWidgets('squashes along its travel, and is its own shape at rest', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));
      final rest = _lensRect(tester).size;

      await tester.tap(find.text('Profile'));
      await tester.pump();
      var narrowest = rest.width;
      var tallest = rest.height;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final size = _lensRect(tester).size;
        if (size.width < narrowest) {
          narrowest = size.width;
        }
        if (size.height > tallest) {
          tallest = size.height;
        }
      }
      // Two tabs in half a second peaks well past 5 tabs a second — at
      // least a quarter of the full squash on a three-tab bar.
      expect(narrowest, lessThan(rest.width * 0.95));
      expect(tallest, greaterThan(rest.height * 1.03));

      await tester.pumpAndSettle();
      final landed = _lensRect(tester).size;
      expect(landed.width, closeTo(rest.width, 1e-6));
      expect(landed.height, closeTo(rest.height, 1e-6));
    });

    testWidgets("as a GlassScaffold's bottomBar, never reaches past the "
        "bar's clip, however hard it squashes", (tester) async {
      var index = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (context, setState) => GlassScaffold(
                body: const SizedBox.expand(),
                bottomBar: GlassTabBar(
                  tabs: _tabs,
                  currentIndex: index,
                  onTap: (next) => setState(() => index = next),
                ),
              ),
            ),
          ),
        ),
      );

      // The layer the scaffold gave the bar, which clips its glass to its
      // own bounds.
      RenderObject? node = tester.renderObject(_lens);
      while (node is! RenderGlassLayer || !node.clipGlassToBounds) {
        node = node!.parent;
      }
      final layer = node;
      final clip = MatrixUtils.transformRect(
        layer.getTransformTo(null),
        Offset.zero & layer.size,
      );
      final body = tester.getRect(_body);
      expect(clip.contains(body.topLeft), isTrue);
      expect(clip.contains(body.bottomRight), isTrue);
      final rest = _lensRect(tester).height;

      var tallest = rest;
      for (final label in ['Profile', 'Home', 'Profile']) {
        await tester.tap(find.text(label));
        await tester.pump();
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 8));
          final lens = _lensRect(tester);
          tallest = math.max(tallest, lens.height);
          // Inside the clip, and a point clear of the painted capsule's
          // edge, top and bottom, so its rim is never cut.
          expect(lens.top, greaterThanOrEqualTo(body.top + 1), reason: '$i');
          expect(
            lens.bottom,
            lessThanOrEqualTo(body.bottom - 1),
            reason: '$i',
          );
          expect(lens.left, greaterThanOrEqualTo(clip.left), reason: '$i');
          expect(lens.right, lessThanOrEqualTo(clip.right), reason: '$i');
        }
        await tester.pumpAndSettle();
      }
      // It did squash, and hard.
      expect(tallest, greaterThan(rest * 1.1));
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
      expect(_lensPresence(tester), 0);

      await tester.tap(find.text('Profile'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_lensPresence(tester), 0);
    });
  });

  group('a drag', () {
    testWidgets('carries the lens under the finger, clamped to the bar', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(_harness(bar: _followingBar(taps)));

      final home = tester.getCenter(find.text('Home'));
      final search = tester.getCenter(find.text('Search'));
      final profile = tester.getCenter(find.text('Profile'));
      final between = Offset.lerp(search, profile, 0.5)!;
      final gesture = await _dragTo(tester, home, between);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_lensRect(tester).center.dx, closeTo(between.dx, 0.5));
      expect(taps, isEmpty, reason: 'nothing is reported until release');

      // Far past the bar's end: the lens stops under the last tab.
      await gesture.moveTo(Offset(profile.dx + 400, profile.dy));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_lensRect(tester).center.dx, closeTo(profile.dx, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, [2]);
    });

    testWidgets('clicks once per tab crossed, and commits the tab under the '
        'finger on release', (tester) async {
      final haptics = _recordHaptics(tester);
      final taps = <int>[];
      await tester.pumpWidget(_harness(bar: _followingBar(taps)));

      final gesture = await _dragTo(
        tester,
        tester.getCenter(find.text('Home')),
        tester.getCenter(find.text('Search')),
      );
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(taps, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, [1]);
      expect(haptics, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
      ]);
      expectUnder(_lensRect(tester), tester.getCenter(find.text('Search')));
    });

    testWidgets('released on the current tab reports nothing', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(_harness(bar: _followingBar(taps)));
      final home = tester.getCenter(find.text('Home'));
      final gesture = await _dragTo(tester, home, home + const Offset(20, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
    });

    testWidgets('cancelled, sends the lens back', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(_harness(bar: _followingBar(taps)));
      final gesture = await _dragTo(
        tester,
        tester.getCenter(find.text('Home')),
        tester.getCenter(find.text('Profile')),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
      expectUnder(_lensRect(tester), tester.getCenter(find.text('Home')));
    });
  });

  testWidgets('Reduce Motion: the lens is glass, and lands at once without '
      'squashing', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));

    // The lens, and nothing else.
    expect(_barGlass, findsOneWidget);
    expect(_lensPresence(tester), 1);
    final rest = _lensRect(tester);

    await tester.tap(find.text('Profile'));
    // One frame for the parent to rebuild with the new index — and no more.
    await tester.pump();
    final landed = _lensRect(tester);
    expectUnder(landed, tester.getCenter(find.text('Profile')));
    expect(landed.size, rest.size);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
    expect(_lensRect(tester), landed);
  });

  testWidgets('bar presence 0 hides the painted bar, labels and icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        bar: _followingBar(<int>[]),
        barPresence: const AlwaysStoppedAnimation<double>(0),
      ),
    );

    expect(_effectiveOpacity(tester, _body), 0);
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

  testWidgets('the bottom safe area is built in', (tester) async {
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
        bottomInset: 34,
      ),
    );

    final screenBottom = tester.getBottomLeft(find.byType(GlassLayer)).dy;
    expect(tester.getBottomLeft(_body).dy, screenBottom - 34);
  });

  group('the body', () {
    testWidgets('is painted: the lens is the only glass, and nothing in '
        'the bar blurs', (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar(<int>[])));
      expect(_body, findsOneWidget);
      expect(_barGlass, findsOneWidget);
      expect(
        find.descendant(of: _body, matching: find.byType(Glass)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    testWidgets('takes a backgroundColor', (tester) async {
      const color = Color(0xCC20304A);
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(
            tabs: _tabs,
            currentIndex: 0,
            onTap: (_) {},
            backgroundColor: color,
          ),
        ),
      );
      expect(_bodyColor(tester), color);
    });

    for (final brightness in Brightness.values) {
      testWidgets("with none, is the role's ${brightness.name} tint at its "
          'legible step: translucent, well short of opaque', (tester) async {
        final ramp = const GlassTints().of(brightness);
        await tester.pumpWidget(
          GlassTheme(
            data: GlassThemeData(brightness: brightness),
            child: _harness(
              bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
            ),
          ),
        );
        final fill = _bodyColor(tester)!;
        expect(fill.toARGB32() | 0xFF000000, ramp.color.toARGB32());
        expect(fill.a, closeTo(ramp.legible, 1e-6));
        // At most 54%, so a photo shows through it.
        expect(fill.a, lessThanOrEqualTo(0.55));
        expect(fill.a, lessThan(ramp.readable));
      });

      testWidgets('in ${brightness.name} mode, an unselected label clears '
          "3:1 over the ramp's worst backdrop", (tester) async {
        final ramp = const GlassTints().of(brightness);
        // White is what hurts the dark scheme most, black the light one.
        final worst = brightness == Brightness.dark
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF000000);
        await tester.pumpWidget(
          GlassTheme(
            data: GlassThemeData(brightness: brightness),
            child: _harness(
              bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
            ),
          ),
        );
        final surface = Color.alphaBlend(_bodyColor(tester)!, worst);
        for (final label in ['Search', 'Profile']) {
          final ink = tester.widget<Text>(find.text(label)).style!.color!;
          expect(ink.toARGB32() | 0xFF000000, ramp.label.toARGB32());
          final drawn = Color.alphaBlend(ink, surface);
          expect(
            GlassLegibility.contrastRatio(drawn, surface),
            greaterThanOrEqualTo(3),
            reason: label,
          );
        }
      });

      testWidgets('in ${brightness.name} mode, the rim is a hairline that '
          'shows against the fill', (tester) async {
        await tester.pumpWidget(
          GlassTheme(
            data: GlassThemeData(brightness: brightness),
            child: _harness(
              bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
            ),
          ),
        );
        final shape =
            (tester.widget<DecoratedBox>(_body).decoration as ShapeDecoration)
                    .shape
                as OutlinedBorder;
        final rim = shape.side.color;
        expect(shape.side.width, 1);
        expect(rim.a, inInclusiveRange(0.1, 0.3));
        // White on the dark fill, black on the light one: a rim the colour
        // of its own fill is invisible.
        final ink = brightness == Brightness.dark ? 1.0 : 0.0;
        expect(rim.r, ink);
        expect(rim.g, ink);
        expect(rim.b, ink);
      });
    }
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
    expect(tester.getSize(_body).height, GlassTabBar.height);
    // With no safe area, the widget is the bar plus its public margin.
    expect(
      tester.getSize(find.byType(GlassTabBar)).height,
      GlassTabBar.height + GlassTabBar.margin.vertical,
    );
  });

  testWidgets('on a wide screen the bar stops at its maximum width, '
      'centred', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(tabs: _tabs, currentIndex: 0, onTap: (_) {}),
      ),
    );

    final body = tester.getRect(_body);
    expect(body.width, GlassTabBar.defaultMaxWidth);
    expect(body.center.dx, 600);

    // A caller's own cap wins, and infinity takes it away.
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(
          tabs: _tabs,
          currentIndex: 0,
          onTap: (_) {},
          maxWidth: 700,
        ),
      ),
    );
    expect(tester.getSize(_body).width, 700);
    await tester.pumpWidget(
      _harness(
        bar: GlassTabBar(
          tabs: _tabs,
          currentIndex: 0,
          onTap: (_) {},
          maxWidth: double.infinity,
        ),
      ),
    );
    expect(
      tester.getSize(_body).width,
      1200 - GlassTabBar.margin.horizontal,
    );
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

      final gesture = await _dragTo(
        tester,
        tester.getCenter(find.text('Home')),
        tester.getCenter(find.text('Profile')),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, [2]);
      expectUnder(_lensRect(tester), tester.getCenter(find.text('Home')));
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

    testWidgets('the first tab is on the right', (tester) async {
      await tester.pumpWidget(rtl(<int>[]));
      expect(
        tester.getCenter(find.text('Home')).dx,
        greaterThan(tester.getCenter(find.text('Profile')).dx),
      );
    });

    for (final (index, label) in [(0, 'Home'), (2, 'Profile')]) {
      testWidgets('the lens sits under "$label" at rest', (tester) async {
        await tester.pumpWidget(rtl(<int>[], initial: index));
        expectUnder(_lensRect(tester), tester.getCenter(find.text(label)));
      });
    }

    testWidgets('a drag follows the finger, clicks once per tab, and '
        'commits the tab under it', (tester) async {
      final haptics = _recordHaptics(tester);
      final taps = <int>[];
      await tester.pumpWidget(rtl(taps, initial: 1));

      final search = tester.getCenter(find.text('Search'));
      final home = tester.getCenter(find.text('Home'));
      final between = Offset.lerp(search, home, 0.4)!;
      final gesture = await _dragTo(tester, search, between);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_lensRect(tester).center.dx, closeTo(between.dx, 0.5));

      await gesture.moveTo(home);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(taps, [0]);
      expect(
        haptics.where((h) => h == 'HapticFeedbackType.selectionClick'),
        hasLength(1),
      );
      expectUnder(_lensRect(tester), home);
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
      final midFlight = _lensRect(tester).center.dx;
      expect(midFlight, lessThan(home));
      expect(midFlight, greaterThan(profile));

      await tester.pumpAndSettle();
      expectUnder(_lensRect(tester), Offset(profile, 0));
    });
  });

  group('keyboard and hit targets', () {
    List<FocusNode> tabNodes() => FocusManager.instance.rootScope.descendants
        .where((node) => node.canRequestFocus)
        .toList();

    testWidgets('Enter and Space activate the focused tab', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(_harness(bar: _followingBar(taps)));
      tabNodes()[2].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      tabNodes()[1].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, [2, 1]);
    });

    testWidgets('the arrow keys move focus along the tabs, not the '
        'selection', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => _harness(bar: _followingBar(taps)),
        ),
      );
      final nodes = tabNodes();
      nodes[0].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(nodes[1].hasPrimaryFocus, isTrue);
      expect(taps, isEmpty);
    });

    testWidgets('every tab is at least 44 x 44', (tester) async {
      await tester.pumpWidget(_harness(bar: _followingBar([])));
      for (final label in ['Home', 'Search', 'Profile']) {
        final frame = find.ancestor(
          of: find.text(label),
          matching: find.byType(GlassControlFrame),
        );
        final size = tester.getSize(frame);
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
    });

    testWidgets('too many tabs for 44 pt each is reported, not silently '
        'shrunk', (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(
            tabs: [
              for (var i = 0; i < 8; i++)
                GlassTab(
                  icon: const SizedBox(width: 24, height: 24),
                  label: 'Tab $i',
                ),
            ],
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect('$error', contains('44'));
    });

    testWidgets("a tab's semanticLabel names it in place of its label", (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          bar: GlassTabBar(
            tabs: const [
              GlassTab(
                icon: SizedBox(width: 24, height: 24),
                label: 'In',
                semanticLabel: 'Inbox',
              ),
              GlassTab(icon: SizedBox(width: 24, height: 24), label: 'Out'),
            ],
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Inbox'), findsOneWidget);
      expect(find.bySemanticsLabel('Out'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('on glass already, the bar paints and never raises a lens', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      _harness(
        bar: Glass(
          shape: const GlassOval(),
          child: _followingBar(taps),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Glass), findsOneWidget);
    expect(_body, findsOneWidget);

    await tester.tap(find.text('Profile'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(Glass), findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(taps, [2]);
  });
}
