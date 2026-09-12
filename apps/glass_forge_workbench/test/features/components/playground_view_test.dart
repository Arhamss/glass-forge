import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/features/components/presentation/views/playground_view.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> pumpPlayground(WidgetTester tester, ComponentId id) async {
    tester.view.physicalSize =
        const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(testApp(PlaygroundView(component: id)));
    await tester.pumpAndSettle();
  }

  for (final id in ComponentId.values) {
    testWidgets('the ${id.name} playground builds every pane', (tester) async {
      await pumpPlayground(tester, id);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Material'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Copy code'), findsOneWidget);
    });
  }

  testWidgets('a knob change reaches the component', (tester) async {
    await pumpPlayground(tester, ComponentId.tabBar);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Decrease'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('reset puts the knobs back', (tester) async {
    await pumpPlayground(tester, ComponentId.tabBar);
    await tester.tap(find.bySemanticsLabel('Decrease'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Reset to defaults'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
  });
}
