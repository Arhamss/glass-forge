import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_bottom_sheet.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

import '../../../../helpers/test_app.dart';

const _screen = Size(390, 844);

Future<void> _open(WidgetTester tester, WidgetBuilder builder) async {
  tester.view.physicalSize = _screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showGlassSheet<void>(context, builder: builder),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows what the builder returns, floating off every edge', (
    tester,
  ) async {
    await _open(tester, (_) => const Text('Sheet body'));

    expect(find.byType(GlassBottomSheet), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);

    final glass = tester.getRect(find.byType(KitGlassLayer));
    expect(glass.left, 8);
    expect(glass.right, _screen.width - 8);
    expect(glass.bottom, lessThanOrEqualTo(_screen.height - 8));
  });

  testWidgets('a downward fling dismisses it', (tester) async {
    await _open(tester, (_) => const Text('Sheet body'));

    await tester.fling(find.text('Sheet body'), const Offset(0, 300), 1200);
    await tester.pumpAndSettle();

    expect(find.text('Sheet body'), findsNothing);
    expect(find.byType(GlassBottomSheet), findsNothing);
  });

  testWidgets('content taller than the screen scrolls inside the cap', (
    tester,
  ) async {
    await _open(
      tester,
      (_) => Column(
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('Row $i')),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(KitGlassLayer)).height,
      lessThanOrEqualTo(_screen.height * 0.85),
    );
    expect(find.text('Row 39').hitTestable(), findsNothing);

    await tester.dragUntilVisible(
      find.text('Row 39'),
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Row 39').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
