import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/feedback/glass_toast_host.dart';

import '../../../../helpers/test_app.dart';

/// A screen with one button that runs [onPressed] with a context below the
/// app's navigator, the way a real caller would.
Future<void> _pumpLauncher(
  WidgetTester tester,
  void Function(BuildContext context) onPressed,
) async {
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => onPressed(context),
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Lets the current toast run out and remove itself.
Future<void> _runOut(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the message, announces it, then removes itself', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      (context) => showGlassToast(
        context,
        message: 'Saved to your list',
        icon: AssetPaths.check,
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(tester.getRect(find.text('Saved to your list')).bottom, lessThan(0));

    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Saved to your list')).top, greaterThan(0));
    expect(
      tester.takeAnnouncements(),
      contains(isAccessibilityAnnouncement('Saved to your list')),
    );

    await _runOut(tester);

    expect(find.text('Saved to your list'), findsNothing);
    expect(find.byType(GlassToastHost), findsNothing);
  });

  testWidgets('a second toast replaces the first', (tester) async {
    var count = 0;
    await _pumpLauncher(tester, (context) {
      count++;
      showGlassToast(context, message: 'Toast $count');
    });

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 2'), findsOneWidget);
    expect(find.byType(GlassToastHost), findsOneWidget);

    await _runOut(tester);
    expect(find.byType(GlassToastHost), findsNothing);
  });

  testWidgets('two in the same frame still leave only one', (tester) async {
    await _pumpLauncher(tester, (context) {
      showGlassToast(context, message: 'First');
      showGlassToast(context, message: 'Second');
    });

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await _runOut(tester);
    expect(find.byType(GlassToastHost), findsNothing);
  });

  testWidgets('swiping it up dismisses it early', (tester) async {
    await _pumpLauncher(
      tester,
      (context) => showGlassToast(context, message: 'Copied'),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.fling(find.text('Copied'), const Offset(0, -80), 800);
    await tester.pumpAndSettle();

    expect(find.text('Copied'), findsNothing);
    expect(find.byType(GlassToastHost), findsNothing);
  });

  testWidgets('under Reduce Motion it appears and leaves at once', (
    tester,
  ) async {
    // Set where a device sets it, above the navigator: the toast lives in the
    // root overlay, out of reach of a MediaQuery wrapped around one screen.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pumpLauncher(
      tester,
      (context) => showGlassToast(context, message: 'Quiet'),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(tester.getRect(find.text('Quiet')).top, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump();
    expect(find.text('Quiet'), findsNothing);
    expect(find.byType(GlassToastHost), findsNothing);
  });
}
