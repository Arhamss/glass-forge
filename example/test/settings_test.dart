import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge/benchmark.dart' show warmUpGlassForgeShaders;
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/main.dart';
import 'package:glass_forge_example/src/playground.dart';

/// The backdrop drifts forever, so nothing ever settles: pump long enough
/// for any route, sheet or scroll to land instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is GlassButton && w.semanticLabel == label,
);

void main() {
  setUpAll(warmUpGlassForgeShaders);

  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GlassForgeExample(playground: Playground()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(_button('Settings'));
    await _settle(tester);
  }

  testWidgets('the settings page is a GlassScaffold with a GlassAppBar, '
      'its controls sharing the body layer', (tester) async {
    await openSettings(tester);
    expect(find.byType(GlassScaffold), findsOneWidget);
    expect(find.byType(GlassAppBar), findsOneWidget);
    expect(find.byType(GlassSwitch), findsNWidgets(2));
    expect(find.byType(GlassSlider), findsOneWidget);
    expect(find.byType(GlassSegmentedControl<int>), findsOneWidget);
    expect(find.byType(GlassTextField), findsNWidgets(2));
    // The body's layer and one for each bar, and no implicit ones.
    expect(
      find.descendant(
        of: find.byType(GlassScaffold),
        matching: find.byType(GlassLayer),
      ),
      findsNWidgets(3),
    );

    await tester.tap(_button('Back'));
    await _settle(tester);
    expect(find.byType(GlassScaffold), findsNothing);
  });

  testWidgets('a field in the body scrolls clear of the keyboard and the '
      'search bar riding it', (tester) async {
    await openSettings(tester);
    await tester.tap(find.widgetWithText(GlassTextField, 'Glass Forge'));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    await _settle(tester);

    final screen = tester.view.physicalSize.height / 3;
    final bar = tester.getTopLeft(
      find.widgetWithText(GlassTextField, 'Search settings'),
    );
    final field = tester.getBottomLeft(
      find.widgetWithText(GlassTextField, 'Glass Forge'),
    );
    expect(bar.dy, lessThan(screen - 336));
    expect(field.dy, lessThanOrEqualTo(bar.dy));
  });

  testWidgets('rename in a sheet completes with the new name', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.ensureVisible(find.text('Rename in a sheet'));
    await _settle(tester);
    await tester.tap(find.text('Rename in a sheet'));
    await _settle(tester);
    expect(find.text('Rename'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.ancestor(
          of: find.text('Rename'),
          matching: find.byType(Column),
        ),
        matching: find.byType(EditableText),
      ),
      'Liquid',
    );
    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('Rename'), findsNothing);
    expect(find.widgetWithText(GlassTextField, 'Liquid'), findsOneWidget);
  });
}
