import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/glass_forge.dart';

const ValueKey<String> _barKey = ValueKey('bar');
const ValueKey<String> _openKey = ValueKey('open');
const ValueKey<String> _contentKey = ValueKey('content');
const ValueKey<String> _pickKey = ValueKey('pick');

/// A `GlassScaffold` page with a bottom bar — the chrome a sheet covers —
/// and a button that presents a sheet. Every result the sheet completes
/// with lands in [results].
Future<void> _pumpPage(
  WidgetTester tester, {
  required List<String?> results,
  bool isDismissible = true,
  bool plainPageRoute = false,
  GlassMaterial? material,
}) async {
  final page = Builder(
    builder: (context) => GlassScaffold(
      background: const ColoredBox(color: Color(0xFF203040)),
      bottomBar: const SizedBox(key: _barKey, height: 44),
      body: Center(
        child: GestureDetector(
          key: _openKey,
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            results.add(
              await showGlassSheet<String>(
                context: context,
                isDismissible: isDismissible,
                material: material,
                builder: (context) => SizedBox(
                  key: _contentKey,
                  height: 200,
                  child: Center(
                    child: GestureDetector(
                      key: _pickKey,
                      onTap: () => Navigator.of(context).pop('picked'),
                      child: const Text('pick'),
                    ),
                  ),
                ),
              ),
            );
          },
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ),
  );

  await tester.pumpWidget(
    // Tier off: no matte is baked. The sheet slides, and a moving shape
    // rebakes its matte every frame — off Impeller that is a CPU-emulated
    // SDF shader over the sheet's bounds, measured at ~6.6 s a frame at the
    // test view's size. Nothing here is about the matte: presence, routing
    // and gestures all run the same at any tier.
    GlassTierScope(
      requested: GlassTier.off,
      child: MaterialApp(
        home: plainPageRoute ? null : page,
        // A plain `PageRouteBuilder`, the kind `WidgetsApp` builds, lets
        // only another `PageRoute` drive its `secondaryAnimation`.
        onGenerateRoute: plainPageRoute
            ? (settings) => PageRouteBuilder<void>(
                settings: settings,
                pageBuilder: (context, _, _) => page,
              )
            : null,
      ),
    ),
  );
}

/// The bar's presence, read by reference: the `Animation` outlives any
/// frame's widget.
Animation<double> _chromePresence(WidgetTester tester) => tester
    .widget<GlassPresence>(
      find.ancestor(
        of: find.byKey(_barKey),
        matching: find.byType(GlassPresence),
      ),
    )
    .presence;

Animation<double> _sheetPresence(WidgetTester tester) => tester
    .widget<GlassPresence>(
      find.ancestor(
        // The first frame of a push is built offstage, for `HeroController`
        // to measure; the presence object is already the one it keeps.
        of: find.byKey(_contentKey, skipOffstage: false),
        matching: find.byType(GlassPresence, skipOffstage: false),
      ),
    )
    .presence;

/// Pumps in 5 ms steps until nothing is scheduled, checking the handoff every
/// frame, and returns how many frames had chrome or sheet part-way through
/// a ramp — proof the sampling actually walked through the ramps rather than
/// jumping over them.
Future<int> _pumpCheckingHandoff(
  WidgetTester tester,
  Animation<double> chrome,
  Animation<double> sheet,
) async {
  var partial = 0;
  var frames = 0;
  do {
    await tester.pump(const Duration(milliseconds: 5));
    frames++;
    expect(
      chrome.value * sheet.value,
      0,
      reason:
          'chrome ${chrome.value} and sheet ${sheet.value} both rendering '
          'is a stacked backdrop filter (frame $frames)',
    );
    if (chrome.value > 0 && chrome.value < 1) {
      partial++;
    }
    if (sheet.value > 0 && sheet.value < 1) {
      partial++;
    }
  } while (tester.binding.hasScheduledFrame && frames < 1000);
  return partial;
}

void main() {
  testWidgets('material replaces the sheet role material', (tester) async {
    const custom = GlassMaterial(tint: Color(0xFFFF2200), tintOpacity: 0.3);
    await _pumpPage(tester, results: [], material: custom);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    final sheetGlass = find.ancestor(
      of: find.byKey(_contentKey),
      matching: find.byType(Glass),
    );
    expect(tester.widget<Glass>(sheetGlass).material, custom);
  });

  testWidgets('completes with the value the sheet is popped with', (
    tester,
  ) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_contentKey), findsOneWidget);

    await tester.tap(find.byKey(_pickKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsNothing);
    expect(results, ['picked']);
  });

  testWidgets('chrome and sheet are never both present, either way', (
    tester,
  ) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results);
    final chrome = _chromePresence(tester);

    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    final sheet = _sheetPresence(tester);
    expect(chrome.value * sheet.value, 0);

    final presenting = await _pumpCheckingHandoff(tester, chrome, sheet);
    expect(presenting, greaterThan(10), reason: 'both ramps were sampled');
    expect(chrome.value, 0);
    expect(sheet.value, 1);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    final dismissing = await _pumpCheckingHandoff(tester, chrome, sheet);
    expect(dismissing, greaterThan(10), reason: 'both ramps were sampled');
    expect(chrome.value, 1);
    expect(sheet.value, 0);
    expect(find.byKey(_contentKey), findsNothing);
  });

  testWidgets('the handoff also holds through a drag dismissal', (
    tester,
  ) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results);
    final chrome = _chromePresence(tester);

    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    final sheet = _sheetPresence(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_contentKey)),
    );
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(chrome.value * sheet.value, 0);
    }
    await gesture.up();
    await _pumpCheckingHandoff(tester, chrome, sheet);

    expect(find.byKey(_contentKey), findsNothing);
    expect(results, [null]);
  });

  testWidgets('a short drag springs the sheet back', (tester) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    final sheet = _sheetPresence(tester);

    // Slow, so it is not a fling.
    await tester.timedDrag(
      find.byKey(_contentKey),
      const Offset(0, 30),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsOneWidget);
    expect(sheet.value, 1);
    expect(results, isEmpty);
  });

  testWidgets('a scrim tap dismisses a dismissible sheet', (tester) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsNothing);
    expect(results, [null]);
  });

  testWidgets('a non-dismissible sheet ignores scrim taps and drags', (
    tester,
  ) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results, isDismissible: false);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(_contentKey), findsOneWidget);

    await tester.fling(find.byKey(_contentKey), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(find.byKey(_contentKey), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.byKey(_pickKey));
    await tester.pumpAndSettle();
    expect(results, ['picked']);
  });

  testWidgets('Reduce Motion presents and dismisses instantly', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final results = <String?>[];
    await _pumpPage(tester, results: results);
    final chrome = _chromePresence(tester);

    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    expect(chrome.value, 0);
    expect(_sheetPresence(tester).value, 1);

    await tester.tap(find.byKey(_pickKey));
    await tester.pump();
    expect(find.byKey(_contentKey), findsNothing);
    expect(chrome.value, 1);
    expect(results, ['picked']);
  });

  testWidgets('the handoff reaches chrome on a plain PageRouteBuilder page', (
    tester,
  ) async {
    final results = <String?>[];
    await _pumpPage(tester, results: results, plainPageRoute: true);
    final chrome = _chromePresence(tester);

    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    final sheet = _sheetPresence(tester);
    final partial = await _pumpCheckingHandoff(tester, chrome, sheet);

    expect(partial, greaterThan(10));
    expect(chrome.value, 0);
    expect(sheet.value, 1);
  });
}
