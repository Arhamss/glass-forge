import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/app/view/app_page.dart';
import 'package:glass_forge_workbench/features/components/presentation/views/components_view.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_media_card.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';
import 'package:integration_test/integration_test.dart';

/// Walks every screen and overlay of the real app on a device, and takes a
/// screenshot at each step (`scripts/tour_screenshots.sh` saves them).
///
/// On its own it is a smoke test: any exception on any screen fails it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold(WidgetTester tester, String step) async {
    await tester.pumpAndSettle();
    // Real time for the glass to finish its fade-in and settle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump();
    await binding.takeScreenshot(step);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Back').last);
    await tester.pumpAndSettle();
  }

  Future<void> dismissOverlay(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 120));
    await tester.pumpAndSettle();
  }

  testWidgets('tour every screen', (tester) async {
    await tester.pumpWidget(const App());
    await hold(tester, '01-showcase');

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -560),
    );
    await hold(tester, '02-showcase-scrolled');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 560),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GlassMediaCard).first);
    await hold(tester, '03-place-sheet');
    await dismissOverlay(tester);

    await tester.tap(
      find
          .descendant(
            of: find.byType(GlassMediaCard).first,
            matching: find.byType(GlassCircleButton),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('04-toast');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(GlassMediaCard).first);
    await hold(tester, '05-context-menu');
    await dismissOverlay(tester);

    await tester.tap(find.text('Saved'));
    await hold(tester, '06-saved');
    await tester.tap(find.text('For you'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Notifications'));
    await hold(tester, '07-alerts-sheet');
    await dismissOverlay(tester);

    await tester.tap(find.text('Components'));
    await hold(tester, '08-components');

    await tester.tap(find.text('Tab bar'));
    await hold(tester, '08a-playground-tab-bar');
    await tester.tap(find.text('Code'));
    await hold(tester, '08b-playground-code');
    await back(tester);

    await tester.dragUntilVisible(
      find.text('Media card'),
      find.byType(ComponentsView),
      const Offset(0, -240),
    );
    await tester.tap(find.text('Media card'));
    await hold(tester, '08c-playground-media-card');
    await back(tester);

    await tester.tap(find.text('Material').last);
    await hold(tester, '09-material');
    await tester.tap(find.text('Clear').first);
    await tester.pump(const Duration(milliseconds: 140));
    await binding.takeScreenshot('09a-material-morphing');
    await hold(tester, '09b-material-clear');
    await tester.tap(find.text('Shape').first);
    await hold(tester, '09c-material-shape');

    await tester.tap(find.text('Lab').last);
    await hold(tester, '10-lab');

    for (final (step, title) in [
      ('11-lab-tiers', 'Tiers'),
      ('12-lab-blend', 'Blend'),
      ('13-lab-motion', 'Motion'),
      ('14-lab-surfaces', 'Surfaces'),
    ]) {
      await tester.tap(find.text(title).first);
      await hold(tester, step);
      await back(tester);
    }

    // The same screens at twice the text size, in this run rather than a
    // second one: one app for the whole tour keeps the run short, and the
    // screens are the subject either way.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();

    await tester.tap(find.text('Showcase'));
    await hold(tester, '20-large-text-showcase');
    await tester.tap(find.text('Components'));
    await hold(tester, '21-large-text-components');
    await tester.tap(find.text('Material').last);
    await hold(tester, '22-large-text-material');
    await tester.tap(find.text('Lab').last);
    await hold(tester, '23-large-text-lab');
  });
}
