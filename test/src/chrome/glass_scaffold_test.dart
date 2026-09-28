import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

const ValueKey<String> _topBarKey = ValueKey('topBar');
const ValueKey<String> _bottomBarKey = ValueKey('bottomBar');
const ValueKey<String> _backgroundKey = ValueKey('background');

void main() {
  testWidgets(
    'exactly one GlassLayer; background outside it, bars inside it',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassScaffold(
            background: SizedBox.expand(key: _backgroundKey),
            topBar: SizedBox(key: _topBarKey, height: 44),
            bottomBar: SizedBox(key: _bottomBarKey, height: 44),
            body: SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(GlassLayer), findsOneWidget);

      final layer = find.byType(GlassLayer);
      expect(
        find.descendant(of: layer, matching: find.byKey(_backgroundKey)),
        findsNothing,
        reason: 'what glass refracts must be painted behind the layer',
      );
      expect(
        find.descendant(of: layer, matching: find.byKey(_topBarKey)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: layer, matching: find.byKey(_bottomBarKey)),
        findsOneWidget,
      );
    },
  );

  testWidgets('body padding equals bar heights plus safe areas', (
    tester,
  ) async {
    MediaQueryData? bodyMediaQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            // The test window has no insets of its own, so a bar's
            // safe-area behaviour is invisible unless one is put here.
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
            ),
            child: GlassScaffold(
              topBar: const SizedBox(height: 50),
              bottomBar: const SizedBox(height: 30),
              body: Builder(
                builder: (context) {
                  bodyMediaQuery = MediaQuery.of(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    // `_MeasureSize` defers its report to the end of the frame it measured
    // in — reporting straight from `performLayout` would call `setState`
    // while a layout is still in progress — so the body only sees the real
    // bar heights one frame later.
    await tester.pump();

    expect(bodyMediaQuery!.padding.top, 70);
    expect(bodyMediaQuery!.padding.bottom, 40);
  });

  testWidgets('a pushed route drives bar presence to 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return GlassScaffold(
              topBar: const SizedBox(key: _topBarKey, height: 44),
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const SizedBox.expand(),
                      ),
                    );
                  },
                  child: const Text('push'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Captured once, before the push, and read by reference from then on.
    // A default `MaterialPageRoute` is opaque, and once its entrance
    // transition settles `Overlay` stops even building the route it covers
    // — by design, the same optimization the bar's own presence exists to
    // avoid paying for twice — so `find.byKey` can no longer see the bar
    // by then. The `Animation` itself, unlike the widget, survives that:
    // it is owned by the covered route, not by anything `Overlay` decided
    // not to build.
    final presence = tester
        .widget<GlassPresence>(
          find.ancestor(
            of: find.byKey(_topBarKey),
            matching: find.byType(GlassPresence),
          ),
        )
        .presence;

    expect(presence.value, 1, reason: 'nothing covers the page yet');

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(
      presence.value,
      0,
      reason: 'a covering route settled over the whole page',
    );
  });

  testWidgets('the bottom bar rides the keyboard inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: const GlassScaffold(
              bottomBar: SizedBox(key: _bottomBarKey, height: 44),
              body: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(
      find.ancestor(
        of: find.byKey(_bottomBarKey),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.only(bottom: 300),
        ),
      ),
      findsOneWidget,
      reason: 'the bar lifts clear of the keyboard by its own inset',
    );
  });
}
