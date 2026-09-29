import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

/// The screen every test puts the bar on: the test window, the bar pinned
/// to the top, [topInset] of safe area above it, and — when given — a
/// [barPresence] wrapped around it the way `GlassScaffold` wraps its bars.
Widget _harness({
  required Widget bar,
  double topInset = 0,
  Animation<double>? barPresence,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final pinned = Align(alignment: Alignment.topCenter, child: bar);
  return MediaQuery(
    data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
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
  testWidgets('the top safe area is built in', (tester) async {
    await tester.pumpWidget(
      _harness(
        bar: const GlassAppBar(title: SizedBox(width: 40, height: 20)),
        topInset: 44,
      ),
    );

    final glass = find.descendant(
      of: find.byType(GlassAppBar),
      matching: find.byType(GlassSurface),
    );
    final screenTop = tester.getTopLeft(find.byType(GlassLayer)).dy;
    expect(tester.getTopLeft(glass).dy, screenTop + 44);
  });

  testWidgets('with no safe area the bar sits flush with the top', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(bar: const GlassAppBar(title: SizedBox(width: 40, height: 20))),
    );

    final glass = find.descendant(
      of: find.byType(GlassAppBar),
      matching: find.byType(GlassSurface),
    );
    final screenTop = tester.getTopLeft(find.byType(GlassLayer)).dy;
    expect(tester.getTopLeft(glass).dy, screenTop);
  });

  testWidgets(
    'a GlassButton.icon action paints — zero Glass descendants of it',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          bar: GlassAppBar(
            actions: [
              GlassButton.icon(
                onPressed: () {},
                icon: const SizedBox(width: 20, height: 20),
                semanticLabel: 'Search',
              ),
            ],
          ),
        ),
      );

      final action = find.byType(GlassButton);
      expect(action, findsOneWidget);
      expect(
        find.descendant(of: action, matching: find.byType(Glass)),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the title centres on the full bar, not the space between leading and '
    'actions',
    (tester) async {
      const titleKey = ValueKey('title');
      await tester.pumpWidget(
        _harness(
          bar: const SizedBox(
            width: 400,
            child: GlassAppBar(
              leading: SizedBox(width: 8, height: 8),
              title: SizedBox(key: titleKey, width: 60, height: 20),
              actions: [SizedBox(width: 60, height: 44)],
            ),
          ),
        ),
      );

      final barCenter = tester.getRect(find.byType(GlassAppBar)).center.dx;
      final titleCenter = tester.getRect(find.byKey(titleKey)).center.dx;
      // Leading (8) and actions (60) are deliberately unequal: a title
      // centred in the *leftover* space between them would land well off
      // the bar's own centre here, not within a pixel of it.
      expect(titleCenter, closeTo(barCenter, 1));
    },
  );

  testWidgets(
    'an asymmetric leading and two actions never let the title overlap '
    'them',
    (tester) async {
      const titleKey = ValueKey('title');
      const leadingKey = ValueKey('leading');
      const actionsKey = ValueKey('actions');
      await tester.pumpWidget(
        _harness(
          bar: const SizedBox(
            width: 300,
            child: GlassAppBar(
              leading: SizedBox(key: leadingKey, width: 8, height: 8),
              title: SizedBox(key: titleKey, width: 100, height: 20),
              actions: [
                SizedBox(key: actionsKey, width: 60, height: 44),
                SizedBox(width: 60, height: 44),
              ],
            ),
          ),
        ),
      );

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final titleRect = tester.getRect(find.byKey(titleKey));
      final actionsRect = tester.getRect(find.byKey(actionsKey));

      expect(titleRect.left, greaterThanOrEqualTo(leadingRect.right));
      expect(titleRect.right, lessThanOrEqualTo(actionsRect.left));
    },
  );

  testWidgets('bar presence 0 hides the title, leading and actions', (
    tester,
  ) async {
    const titleKey = ValueKey('title');
    await tester.pumpWidget(
      _harness(
        bar: const GlassAppBar(
          title: SizedBox(key: titleKey, width: 40, height: 20),
        ),
        barPresence: const AlwaysStoppedAnimation<double>(0),
      ),
    );

    expect(_effectiveOpacity(tester, find.byKey(titleKey)), 0);
  });

  testWidgets('full bar presence leaves the title drawn', (tester) async {
    const titleKey = ValueKey('title');
    await tester.pumpWidget(
      _harness(
        bar: const GlassAppBar(
          title: SizedBox(key: titleKey, width: 40, height: 20),
        ),
        barPresence: const AlwaysStoppedAnimation<double>(1),
      ),
    );

    expect(_effectiveOpacity(tester, find.byKey(titleKey)), 1);
  });

  testWidgets('with no enclosing presence the bar is fully drawn', (
    tester,
  ) async {
    const titleKey = ValueKey('title');
    await tester.pumpWidget(
      _harness(
        bar: const GlassAppBar(
          title: SizedBox(key: titleKey, width: 40, height: 20),
        ),
      ),
    );

    expect(_effectiveOpacity(tester, find.byKey(titleKey)), 1);
  });

  testWidgets('right to left puts leading on the right, actions on the left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        textDirection: TextDirection.rtl,
        bar: const GlassAppBar(
          leading: SizedBox(key: Key('leading'), width: 24, height: 24),
          title: SizedBox(key: Key('title'), width: 40, height: 20),
          actions: [
            SizedBox(key: Key('first'), width: 24, height: 24),
            SizedBox(key: Key('second'), width: 24, height: 24),
          ],
        ),
      ),
    );

    double x(String key) => tester.getCenter(find.byKey(Key(key))).dx;
    expect(x('leading'), greaterThan(x('title')));
    expect(x('title'), greaterThan(x('first')));
    expect(x('first'), greaterThan(x('second')));
  });
}
