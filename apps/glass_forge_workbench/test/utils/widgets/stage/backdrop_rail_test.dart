import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/enums/glass_backdrop.dart';
import 'package:glass_forge_workbench/utils/widgets/stage/backdrop_rail.dart';

import '../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required ValueChanged<GlassBackdrop> onChanged,
  double width = 320,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 640) * tester.view.devicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BackdropRail(
            selected: GlassBackdrop.photographic,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every backdrop is on screen, on the narrowest phone', (
    tester,
  ) async {
    await _pump(tester, onChanged: (_) {});

    for (final backdrop in GlassBackdrop.values) {
      final finder = find.text(backdrop.label);
      expect(finder, findsOneWidget, reason: backdrop.name);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: backdrop.name);
      expect(rect.right, lessThanOrEqualTo(320), reason: backdrop.name);
    }
  });

  testWidgets('the last one is reachable and reports itself', (tester) async {
    GlassBackdrop? picked;
    await _pump(tester, onChanged: (value) => picked = value);

    await tester.tap(find.text(GlassBackdrop.pureBlack.label));
    expect(picked, GlassBackdrop.pureBlack);
  });

  testWidgets('it survives twice the text size', (tester) async {
    await _pump(tester, onChanged: (_) {}, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
