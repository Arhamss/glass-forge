import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_action.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/overlays/glass_context_menu.dart';
import 'package:glass_forge_workbench/utils/widgets/glass/zones/kit_glass_layer.dart';

import '../../../../helpers/test_app.dart';

const _screen = Size(390, 844);

Future<void> _pump(
  WidgetTester tester, {
  required List<GlassContextAction> actions,
  AlignmentGeometry alignment = Alignment.center,
}) async {
  tester.view.physicalSize = _screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Align(
          alignment: alignment,
          child: GlassContextMenu(
            actions: actions,
            child: const SizedBox(
              width: 200,
              height: 80,
              child: Center(child: Text('Card')),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late Map<String, int> fired;
  late List<GlassContextAction> actions;

  setUp(() {
    fired = {'Save': 0, 'Share': 0, 'Delete': 0};
    actions = [
      GlassContextAction(
        label: 'Save',
        icon: AssetPaths.bookmarkSimple,
        onSelected: () => fired['Save'] = fired['Save']! + 1,
      ),
      GlassContextAction(
        label: 'Share',
        icon: AssetPaths.shareNetwork,
        onSelected: () => fired['Share'] = fired['Share']! + 1,
      ),
      GlassContextAction(
        label: 'Delete',
        icon: AssetPaths.trash,
        destructive: true,
        onSelected: () => fired['Delete'] = fired['Delete']! + 1,
      ),
    ];
  });

  testWidgets('a long press shows every action', (tester) async {
    await _pump(tester, actions: actions);

    await tester.longPress(find.text('Card'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('choosing an action closes the menu and fires it once', (
    tester,
  ) async {
    await _pump(tester, actions: actions);
    await tester.longPress(find.text('Card'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share'), findsNothing);
    expect(fired, {'Save': 0, 'Share': 1, 'Delete': 0});
  });

  testWidgets('tapping outside closes it without firing anything', (
    tester,
  ) async {
    await _pump(tester, actions: actions);
    await tester.longPress(find.text('Card'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(12, 60));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsNothing);
    expect(fired.values, everyElement(0));
  });

  testWidgets('near the bottom it opens above the finger, inside the screen', (
    tester,
  ) async {
    await _pump(
      tester,
      actions: actions,
      alignment: AlignmentDirectional.bottomCenter,
    );
    final press = tester.getCenter(find.text('Card'));

    await tester.longPress(find.text('Card'));
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byType(KitGlassLayer));
    expect(menu.bottom, lessThanOrEqualTo(press.dy));
    expect(menu.bottom, lessThanOrEqualTo(_screen.height - 12));
    expect(menu.width, 240);
  });

  testWidgets('each row is a labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, actions: actions);
    await tester.longPress(find.text('Card'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Delete')),
      isSemantics(label: 'Delete', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
