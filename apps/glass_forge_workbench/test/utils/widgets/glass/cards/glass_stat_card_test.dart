import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/app_colors.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/cards/glass_stat_card.dart';

import '../../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    testApp(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(child: SizedBox(width: 160, child: card)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the label, value, unit and delta', (tester) async {
    await _pump(
      tester,
      const GlassStatCard(
        label: 'Distance',
        value: '4.2',
        unit: 'km',
        delta: '+12%',
      ),
    );

    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
  });

  testWidgets('a falling delta reads in the danger colour', (tester) async {
    await _pump(
      tester,
      const GlassStatCard(
        label: 'Distance',
        value: '4.2',
        unit: 'km',
        delta: '-3%',
        deltaIsPositive: false,
      ),
    );

    final delta = tester.widget<Text>(find.text('-3%'));
    expect(delta.style?.color, AppColors.danger);
  });

  testWidgets('reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const GlassStatCard(
        label: 'Distance',
        value: '4.2',
        unit: 'km',
        delta: '+12%',
      ),
    );

    expect(
      tester.getSemantics(find.byType(GlassStatCard)),
      isSemantics(label: 'Distance, 4.2 km, +12%'),
    );
    expect(find.bySemanticsLabel('DISTANCE'), findsNothing);
    handle.dispose();
  });

  testWidgets('fits 160 pt on a 320 pt screen at twice the text size', (
    tester,
  ) async {
    await _pump(
      tester,
      const GlassStatCard(
        label: 'Temperature',
        value: '1,284.5',
        unit: 'kWh',
        delta: '+12.5% this week',
      ),
      textScale: 2,
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });
}
