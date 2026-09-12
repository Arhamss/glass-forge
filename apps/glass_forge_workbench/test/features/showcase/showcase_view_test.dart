import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/showcase/presentation/views/showcase_view.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_media_card.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/navigation/glass_circle_button.dart';

import '../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(testApp(const ShowcaseView()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('holds up on a 320 pt screen at twice the text size', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saved starts empty, and offers a way back', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);

    await tester.tap(find.text('Show all places'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassMediaCard), findsWidgets);
  });

  testWidgets('a bookmarked place shows up under Saved', (tester) async {
    await _pump(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(GlassMediaCard).first,
            matching: find.byType(GlassCircleButton),
          )
          .first,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Lago di Braies'), findsOneWidget);
  });

  testWidgets('a search with no match clears from the empty state', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'atlantis');
    await tester.pumpAndSettle();
    expect(find.text('No places match'), findsOneWidget);

    await tester.tap(find.text('Show all places'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassMediaCard), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('tapping a card opens its sheet', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(GlassMediaCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Save to list'), findsOneWidget);
  });
}
