import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_slider.dart';
import 'package:glass_forge_workbench/utils/widgets/instrument/instrument_value_row.dart';

import '../../../helpers/test_app.dart';

Future<void> _pump(WidgetTester tester, Widget child, double textScale) async {
  tester.view.physicalSize =
      const Size(320, 640) * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const longRow = InstrumentValueRow(
    label: 'Chromatic aberration',
    value: '12.0 px · was 24.0',
  );

  testWidgets('a value row fits a narrow phone at normal size', (tester) async {
    await _pump(tester, longRow, 1);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('12.0 px · was 24.0')).dy,
      tester.getTopLeft(find.text('Chromatic aberration')).dy,
    );
  });

  testWidgets('at twice the size the reading drops below its label', (
    tester,
  ) async {
    await _pump(tester, longRow, 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('12.0 px · was 24.0')).dy,
      greaterThan(tester.getTopLeft(find.text('Chromatic aberration')).dy),
    );
  });

  testWidgets('a slider row fits at twice the size', (tester) async {
    await _pump(
      tester,
      InstrumentSlider(
        label: 'Chromatic aberration',
        value: 0.35,
        unit: '×',
        max: 1,
        onChanged: (_) {},
      ),
      2,
    );
    expect(tester.takeException(), isNull);
  });
}
